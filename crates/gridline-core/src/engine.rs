//! Echtzeit-Engine: `Controller` (UI-Thread) und `Renderer` (Audio-Thread).
//!
//! Die beiden Seiten tauschen sich nur über lock-freie SPSC-Ringpuffer aus.
//! Der Audio-Thread blockiert und allokiert nie. Ersetzte Snapshots schickt er
//! über einen zweiten Ring zurück, damit sie auf dem UI-Thread freigegeben werden.

use std::sync::atomic::{AtomicI32, Ordering};
use std::sync::Arc;

use rtrb::{Consumer, Producer, RingBuffer};

use crate::clock::StepClock;
use crate::note::pitch_ratio;
use crate::pattern::{Pattern, TRACK_COUNT};
use crate::sample::SampleData;
use crate::song::Song;
use crate::step::StepNote;
use crate::voice::{Trigger, Voice};

/// Unveränderlicher Zustand, den der Renderer abspielt.
#[derive(Clone, Debug)]
pub struct Snapshot {
    pub song: Song,
    /// Ein Eintrag pro Instrument in `song.instruments`.
    pub samples: Vec<Option<Arc<SampleData>>>,
    pub pattern_index: usize,
}

#[derive(Debug)]
pub enum Command {
    Play { from_step: usize },
    Stop,
    Audition { track: usize, note: u8, instrument: usize },
    Release { track: usize },
    Update(Box<Snapshot>),
}

pub const MASTER_GAIN: f32 = 0.7;
const BLOCK: usize = 1024;
const QUEUE: usize = 256;

/// Seite des UI-Threads.
pub struct Controller {
    commands: Producer<Command>,
    garbage: Consumer<Box<Snapshot>>,
    playhead: Arc<AtomicI32>,
}

impl Controller {
    /// Schickt einen Befehl. Bei vollem Ring kommt der Befehl zurück.
    pub fn send(&mut self, command: Command) -> Result<(), Command> {
        self.collect_garbage();
        self.commands.push(command).map_err(|rtrb::PushError::Full(c)| c)
    }

    pub fn update(&mut self, snapshot: Snapshot) -> Result<(), Command> {
        self.send(Command::Update(Box::new(snapshot)))
    }

    /// Gerade spielender Step, -1 wenn gestoppt.
    pub fn playhead(&self) -> i32 {
        self.playhead.load(Ordering::Relaxed)
    }

    /// Gibt vom Audio-Thread zurückgeschickte Snapshots frei.
    pub fn collect_garbage(&mut self) {
        while self.garbage.pop().is_ok() {}
    }
}

/// Seite des Audio-Threads.
pub struct Renderer {
    sample_rate: f64,
    commands: Consumer<Command>,
    garbage: Producer<Box<Snapshot>>,
    playhead: Arc<AtomicI32>,
    snapshot: Box<Snapshot>,
    clock: StepClock,
    voices: Vec<Voice>,
    last_instrument: [usize; TRACK_COUNT],
    playing: bool,
    current_step: i32,
    events: Vec<(usize, usize)>,
    scratch_l: Vec<f32>,
    scratch_r: Vec<f32>,
}

pub fn new_engine(sample_rate: f64, snapshot: Snapshot) -> (Controller, Renderer) {
    let (cmd_tx, cmd_rx) = RingBuffer::new(QUEUE);
    let (gc_tx, gc_rx) = RingBuffer::new(QUEUE);
    let playhead = Arc::new(AtomicI32::new(-1));
    let bpm = snapshot.song.bpm();
    let controller = Controller { commands: cmd_tx, garbage: gc_rx, playhead: playhead.clone() };
    let renderer = Renderer {
        sample_rate,
        commands: cmd_rx,
        garbage: gc_tx,
        playhead,
        snapshot: Box::new(snapshot),
        clock: StepClock::new(sample_rate, bpm),
        voices: (0..TRACK_COUNT).map(|_| Voice::default()).collect(),
        last_instrument: [0; TRACK_COUNT],
        playing: false,
        current_step: -1,
        events: Vec::with_capacity(256),
        scratch_l: vec![0.0; BLOCK],
        scratch_r: vec![0.0; BLOCK],
    };
    (controller, renderer)
}

impl Renderer {
    pub fn sample_rate(&self) -> f64 {
        self.sample_rate
    }

    /// Rendert in getrennte Kanäle. Beliebige Länge.
    pub fn render(&mut self, left: &mut [f32], right: &mut [f32]) {
        let n = left.len().min(right.len());
        let mut start = 0;
        while start < n {
            let end = (start + BLOCK).min(n);
            self.render_block(&mut left[start..end], &mut right[start..end]);
            start = end;
        }
    }

    /// Rendert in einen interleavten Puffer mit `channels` Kanälen (wie von cpal geliefert).
    pub fn render_interleaved(&mut self, out: &mut [f32], channels: usize) {
        let channels = channels.max(1);
        let frames = out.len() / channels;
        let mut done = 0;
        while done < frames {
            let n = (frames - done).min(BLOCK);
            let mut l = std::mem::take(&mut self.scratch_l);
            let mut r = std::mem::take(&mut self.scratch_r);
            self.render_block(&mut l[..n], &mut r[..n]);
            for i in 0..n {
                let frame = &mut out[(done + i) * channels..(done + i + 1) * channels];
                frame[0] = l[i];
                if channels > 1 {
                    frame[1] = r[i];
                    frame[2..].fill(0.0);
                }
            }
            self.scratch_l = l;
            self.scratch_r = r;
            done += n;
        }
    }

    fn render_block(&mut self, left: &mut [f32], right: &mut [f32]) {
        left.fill(0.0);
        right.fill(0.0);

        while let Ok(command) = self.commands.pop() {
            self.apply(command);
        }

        self.clock.bpm = self.snapshot.song.bpm();
        let frames = left.len();
        let mut cursor = 0;
        if self.playing {
            let length = self.snapshot.song.pattern(self.snapshot.pattern_index).length();
            let mut events = std::mem::take(&mut self.events);
            events.clear();
            self.clock.advance(frames, length, |offset, step| events.push((offset, step)));
            for &(offset, step) in &events {
                self.render_voices(&mut left[cursor..offset], &mut right[cursor..offset]);
                self.trigger_step(step);
                self.current_step = step as i32;
                cursor = offset;
            }
            self.events = events;
        }
        self.render_voices(&mut left[cursor..], &mut right[cursor..]);

        for s in left.iter_mut().chain(right.iter_mut()) {
            *s = (*s * MASTER_GAIN).tanh();
        }
        self.playhead.store(if self.playing { self.current_step } else { -1 }, Ordering::Relaxed);
    }

    fn render_voices(&mut self, left: &mut [f32], right: &mut [f32]) {
        if left.is_empty() {
            return;
        }
        for v in self.voices.iter_mut().filter(|v| v.is_active()) {
            v.render(left, right);
        }
    }

    fn apply(&mut self, command: Command) {
        match command {
            Command::Play { from_step } => {
                self.playing = true;
                self.current_step = -1;
                self.clock.reset(from_step);
            }
            Command::Stop => {
                self.playing = false;
                self.current_step = -1;
                self.voices.iter_mut().for_each(Voice::note_off);
            }
            Command::Audition { track, note, instrument } => self.start(track, note, instrument, None),
            Command::Release { track } => {
                if let Some(v) = self.voices.get_mut(track) {
                    v.note_off();
                }
            }
            Command::Update(next) => {
                let old = std::mem::replace(&mut self.snapshot, next);
                // Freigabe auf dem UI-Thread. Ist der Ring voll, wird hier freigegeben (Ausnahmefall).
                let _ = self.garbage.push(old);
            }
        }
    }

    fn trigger_step(&mut self, index: usize) {
        let pattern: &Pattern = self.snapshot.song.pattern(self.snapshot.pattern_index);
        let tracks = pattern.track_count().min(self.voices.len());
        for track in 0..tracks {
            let step = self.snapshot.song.pattern(self.snapshot.pattern_index).get(track, index);
            match step.note {
                StepNote::Empty => {}
                StepNote::Off => self.voices[track].note_off(),
                StepNote::Note(midi) => {
                    let instrument = step.instrument.map_or(self.last_instrument[track], usize::from);
                    self.start(track, midi, instrument, step.volume);
                }
            }
        }
    }

    fn start(&mut self, track: usize, note: u8, index: usize, volume: Option<u8>) {
        if track >= self.voices.len() {
            return;
        }
        let (Some(instrument), Some(Some(sample))) =
            (self.snapshot.song.instruments.get(index), self.snapshot.samples.get(index))
        else {
            return;
        };
        self.last_instrument[track] = index;
        let step_gain = volume.map_or(1.0, |v| f64::from(v) / 100.0);
        let trigger = Trigger {
            ratio: pitch_ratio(i32::from(note), i32::from(instrument.root_note), instrument.tune),
            output_rate: self.sample_rate,
            gain: (instrument.volume * step_gain) as f32,
            attack: instrument.attack,
            release: instrument.release,
            looped: instrument.looped,
        };
        self.voices[track].trigger(sample.clone(), trigger);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::builtin;
    use crate::instrument::SampleSource;
    use crate::step::Step;

    const SR: f64 = 48_000.0;

    fn snapshot(song: Song) -> Snapshot {
        let samples = song
            .instruments
            .iter()
            .map(|i| match i.source {
                SampleSource::Builtin(s) => Some(Arc::new(builtin::make(s, SR))),
                _ => None,
            })
            .collect();
        Snapshot { song, samples, pattern_index: 0 }
    }

    fn render(r: &mut Renderer, frames: usize) -> (Vec<f32>, Vec<f32>) {
        let mut l = vec![1.0; frames];
        let mut rr = vec![1.0; frames];
        r.render(&mut l, &mut rr);
        (l, rr)
    }

    fn peak(x: &[f32]) -> f32 {
        x.iter().fold(0.0, |m, v| m.max(v.abs()))
    }

    #[test]
    fn silent_when_stopped() {
        let (c, mut r) = new_engine(SR, snapshot(Song::demo()));
        let (l, _) = render(&mut r, 1024);
        assert!(l.iter().all(|&v| v == 0.0));
        assert_eq!(c.playhead(), -1);
    }

    #[test]
    fn plays_demo_pattern() {
        let (mut c, mut r) = new_engine(SR, snapshot(Song::demo()));
        c.send(Command::Play { from_step: 0 }).unwrap();
        let (l, _) = render(&mut r, 2048);
        assert!(peak(&l) > 0.05);
        assert!(l.iter().all(|v| v.is_finite() && v.abs() <= 1.0));
        assert_eq!(c.playhead(), 0);
    }

    #[test]
    fn playhead_advances() {
        let (mut c, mut r) = new_engine(SR, snapshot(Song::demo()));
        c.send(Command::Play { from_step: 0 }).unwrap();
        let per_step = (SR * 60.0 / 118.0 / 4.0) as usize;
        let mut done = 0;
        while done < per_step * 3 + 10 {
            render(&mut r, 512);
            done += 512;
        }
        assert_eq!(c.playhead(), 3);
    }

    #[test]
    fn audition_without_transport() {
        let (mut c, mut r) = new_engine(SR, snapshot(Song::demo()));
        c.send(Command::Audition { track: 0, note: 60, instrument: 3 }).unwrap();
        let (_, right) = render(&mut r, 1024);
        assert!(peak(&right) > 0.01);
        assert_eq!(c.playhead(), -1);
    }

    #[test]
    fn empty_instrument_is_ignored() {
        let mut song = Song::demo();
        song.patterns[0] = Pattern::new(16);
        song.patterns[0].set(0, 0, Step::note(60, 10));
        let (mut c, mut r) = new_engine(SR, snapshot(song));
        c.send(Command::Play { from_step: 0 }).unwrap();
        let (l, _) = render(&mut r, 1024);
        assert!(l.iter().all(|&v| v == 0.0));
    }

    #[test]
    fn update_swaps_song_and_returns_garbage() {
        let (mut c, mut r) = new_engine(SR, snapshot(Song::default()));
        c.send(Command::Play { from_step: 0 }).unwrap();
        let (l, _) = render(&mut r, 1024);
        assert!(l.iter().all(|&v| v == 0.0), "leerer Song ist still");
        c.update(snapshot(Song::demo())).unwrap();
        c.send(Command::Play { from_step: 0 }).unwrap();
        let (l, _) = render(&mut r, 2048);
        assert!(peak(&l) > 0.05, "Demo-Song nach Update hörbar");
        assert_eq!(c.garbage.slots(), 1, "alter Snapshot liegt zur Freigabe bereit");
        c.collect_garbage();
        assert_eq!(c.garbage.slots(), 0);
    }

    #[test]
    fn interleaved_matches_planar() {
        let (mut c1, mut r1) = new_engine(SR, snapshot(Song::demo()));
        let (mut c2, mut r2) = new_engine(SR, snapshot(Song::demo()));
        c1.send(Command::Play { from_step: 0 }).unwrap();
        c2.send(Command::Play { from_step: 0 }).unwrap();
        let (l, rr) = render(&mut r1, 3000);
        let mut inter = vec![0.0; 3000 * 2];
        r2.render_interleaved(&mut inter, 2);
        for i in 0..3000 {
            assert_eq!(inter[2 * i], l[i]);
            assert_eq!(inter[2 * i + 1], rr[i]);
        }
    }
}
