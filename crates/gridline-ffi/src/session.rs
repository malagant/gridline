//! App-Sitzung: besitzt Song, Samples und die Engine. Wird vom UI-Thread benutzt.

use std::path::Path;
use std::sync::Arc;

use gridline_core::instrument::SampleSource;
use gridline_core::note::PLAYABLE;
use gridline_core::pattern::TRACK_COUNT;
use gridline_core::{builtin, new_engine, project, wav, Command, Controller, SampleData, Snapshot, Song, Step};
use serde_json::{json, Value};

use crate::audio::{self, Output};

const FALLBACK_RATE: f64 = 48_000.0;

pub struct Session {
    pub song: Song,
    pub pattern_index: usize,
    samples: Vec<Option<Arc<SampleData>>>,
    controller: Controller,
    output: Option<Output>,
    pub audio_status: String,
    playing: bool,
}

impl Session {
    /// Startet mit dem Demo-Song. `with_audio = false` für Tests und Headless-Betrieb.
    pub fn new(with_audio: bool) -> Self {
        let song = Song::demo();
        let rate = if with_audio { audio::default_sample_rate().unwrap_or(FALLBACK_RATE) } else { FALLBACK_RATE };
        let samples = song.instruments.iter().map(|i| load_source(&i.source, rate)).collect::<Vec<_>>();
        let (controller, renderer) =
            new_engine(rate, Snapshot { song: song.clone(), samples: samples.clone(), pattern_index: 0 });

        let (output, audio_status) = if with_audio {
            match audio::start(renderer) {
                Ok(out) => {
                    let status = format!("Audio: {} · {} Hz", out.device, out.sample_rate as u32);
                    (Some(out), status)
                }
                Err(e) => (None, e),
            }
        } else {
            (None, "Audio aus".into())
        };

        Self { song, pattern_index: 0, samples, controller, output, audio_status, playing: false }
    }

    pub fn has_audio(&self) -> bool {
        self.output.is_some()
    }

    fn sample_rate(&self) -> f64 {
        self.output.as_ref().map_or(FALLBACK_RATE, |o| o.sample_rate)
    }

    fn sync(&mut self) {
        let snapshot =
            Snapshot { song: self.song.clone(), samples: self.samples.clone(), pattern_index: self.pattern_index };
        let _ = self.controller.update(snapshot);
    }

    fn send(&mut self, command: Command) {
        let _ = self.controller.send(command);
    }

    // Transport

    pub fn play(&mut self, from_step: usize) {
        self.playing = true;
        self.send(Command::Play { from_step });
    }

    pub fn stop(&mut self) {
        self.playing = false;
        self.send(Command::Stop);
    }

    pub fn is_playing(&self) -> bool {
        self.playing
    }

    pub fn playhead(&self) -> i32 {
        self.controller.playhead()
    }

    pub fn set_bpm(&mut self, bpm: f64) {
        self.song.set_bpm(bpm);
        self.sync();
    }

    pub fn set_pattern_length(&mut self, length: usize) {
        self.song.patterns[self.pattern_index].set_length(length);
        self.sync();
    }

    // Editieren

    pub fn enter_note(&mut self, track: usize, step: usize, midi: u8, instrument: usize) {
        let midi = midi.clamp(*PLAYABLE.start(), *PLAYABLE.end());
        let pattern = &mut self.song.patterns[self.pattern_index];
        let mut cell = pattern.get(track, step);
        cell.note = gridline_core::StepNote::Note(midi);
        cell.instrument = Some(instrument as u8);
        pattern.set(track, step, cell);
        self.sync();
        self.audition(track, midi, instrument);
    }

    pub fn note_off(&mut self, track: usize, step: usize) {
        self.song.patterns[self.pattern_index].set(track, step, Step::off());
        self.sync();
    }

    pub fn clear(&mut self, track: usize, step: usize) {
        self.song.patterns[self.pattern_index].set(track, step, Step::EMPTY);
        self.sync();
    }

    pub fn audition(&mut self, track: usize, midi: u8, instrument: usize) {
        self.send(Command::Audition { track, note: midi, instrument });
    }

    // Instrumente

    pub fn set_instrument_param(&mut self, index: usize, param: u32, value: f64) -> bool {
        let Some(i) = self.song.instruments.get_mut(index) else { return false };
        match param {
            0 => i.volume = value.clamp(0.0, 1.0),
            1 => i.tune = value.clamp(-24.0, 24.0),
            2 => i.attack = value.clamp(0.001, 2.0),
            3 => i.release = value.clamp(0.005, 4.0),
            4 => i.looped = value != 0.0,
            _ => return false,
        }
        self.sync();
        true
    }

    pub fn load_sample(&mut self, index: usize, path: &str) -> Result<(), String> {
        if index >= self.song.instruments.len() {
            return Err("Ungültiger Instrument-Slot".into());
        }
        let bytes = std::fs::read(path).map_err(|e| format!("Datei nicht lesbar: {e}"))?;
        let data = wav::decode(&bytes).map_err(|e| e.to_string())?;
        let name = Path::new(path).file_stem().and_then(|s| s.to_str()).unwrap_or("Sample").to_string();
        self.samples[index] = Some(Arc::new(data));
        let inst = &mut self.song.instruments[index];
        inst.source = SampleSource::File(path.into());
        inst.name = name;
        self.sync();
        Ok(())
    }

    // Projekt

    pub fn save(&self, path: &str) -> Result<(), String> {
        std::fs::write(path, project::encode(&self.song)).map_err(|e| e.to_string())
    }

    pub fn load(&mut self, path: &str) -> Result<(), String> {
        let text = std::fs::read_to_string(path).map_err(|e| e.to_string())?;
        let song = project::decode(&text).map_err(|e| e.to_string())?;
        let rate = self.sample_rate();
        self.samples = song.instruments.iter().map(|i| load_source(&i.source, rate)).collect();
        self.song = song;
        self.pattern_index = 0;
        self.stop();
        self.sync();
        Ok(())
    }

    /// Rendert `bars` Takte des aktuellen Patterns offline als WAV (16 Bit, Stereo).
    pub fn export_wav(&self, path: &str, bars: usize) -> Result<(), String> {
        let rate = self.sample_rate();
        let snapshot =
            Snapshot { song: self.song.clone(), samples: self.samples.clone(), pattern_index: self.pattern_index };
        let pattern_len = self.song.pattern(self.pattern_index).length();
        let steps = pattern_len * bars.max(1);
        let frames = (rate * 60.0 / self.song.bpm() / 4.0 * steps as f64) as usize + (rate * 0.5) as usize;
        let (mut controller, mut renderer) = new_engine(rate, snapshot);
        let _ = controller.send(Command::Play { from_step: 0 });
        let mut left = vec![0.0; frames];
        let mut right = vec![0.0; frames];
        renderer.render(&mut left, &mut right);
        std::fs::write(path, wav::encode(&left, &right, rate as u32, wav::Encoding::Pcm16)).map_err(|e| e.to_string())
    }

    // Abfragen für die Oberfläche (JSON)

    pub fn pattern_json(&self) -> Value {
        let p = self.song.pattern(self.pattern_index);
        let tracks: Vec<Value> = (0..TRACK_COUNT)
            .map(|t| {
                (0..p.length())
                    .map(|s| {
                        let c = p.get(t, s);
                        json!([c.note_text(), c.instrument_text(), c.volume_text(), Step::effect_text(c.fx1)])
                    })
                    .collect()
            })
            .collect();
        json!({ "length": p.length(), "tracks": tracks, "bpm": self.song.bpm() })
    }

    pub fn instruments_json(&self) -> Value {
        let list: Vec<Value> = self
            .song
            .instruments
            .iter()
            .zip(&self.samples)
            .map(|(i, s)| {
                json!({
                    "name": i.name, "volume": i.volume, "tune": i.tune, "attack": i.attack,
                    "release": i.release, "looped": i.looped, "hasSample": s.is_some(),
                })
            })
            .collect();
        Value::Array(list)
    }
}

fn load_source(source: &SampleSource, rate: f64) -> Option<Arc<SampleData>> {
    match source {
        SampleSource::None => None,
        SampleSource::Builtin(s) => Some(Arc::new(builtin::make(*s, rate))),
        SampleSource::File(path) => std::fs::read(path).ok().and_then(|b| wav::decode(&b).ok()).map(Arc::new),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn edit_and_query() {
        let mut s = Session::new(false);
        s.clear(0, 0);
        s.enter_note(0, 1, 62, 3);
        s.note_off(1, 2);
        let p = s.pattern_json();
        assert_eq!(p["length"], 16);
        assert_eq!(p["tracks"][0][0][0], "---");
        assert_eq!(p["tracks"][0][1], json!(["D-4", "04", "--", "---"]));
        assert_eq!(p["tracks"][1][2][0], "OFF");
        s.set_pattern_length(32);
        assert_eq!(s.pattern_json()["tracks"][0].as_array().unwrap().len(), 32);
    }

    #[test]
    fn instrument_params_are_clamped() {
        let mut s = Session::new(false);
        assert!(s.set_instrument_param(0, 0, 5.0));
        assert!(s.set_instrument_param(0, 4, 1.0));
        assert!(!s.set_instrument_param(99, 0, 1.0));
        assert!(!s.set_instrument_param(0, 42, 1.0));
        let i = &s.instruments_json()[0];
        assert_eq!(i["volume"], 1.0);
        assert_eq!(i["looped"], true);
        assert_eq!(i["hasSample"], true);
        assert_eq!(s.instruments_json()[10]["hasSample"], false);
    }

    #[test]
    fn save_load_export_and_sample_import() {
        let dir = std::env::temp_dir().join(format!("gridline-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let file = |n: &str| dir.join(n).to_string_lossy().into_owned();

        let mut s = Session::new(false);
        s.enter_note(5, 7, 48, 2);
        s.set_bpm(140.0);
        s.save(&file("song.gridline")).unwrap();

        s.export_wav(&file("export.wav"), 1).unwrap();
        let exported = wav::decode(&std::fs::read(file("export.wav")).unwrap()).unwrap();
        assert!(exported.frame_count() > 10_000);
        assert!(exported.left.iter().any(|v| v.abs() > 0.05));

        s.load_sample(9, &file("export.wav")).unwrap();
        assert_eq!(s.instruments_json()[9]["name"], "export");
        assert_eq!(s.instruments_json()[9]["hasSample"], true);
        assert!(s.load_sample(9, &file("fehlt.wav")).is_err());

        let mut t = Session::new(false);
        t.load(&file("song.gridline")).unwrap();
        assert_eq!(t.song.bpm(), 140.0);
        assert_eq!(t.pattern_json()["tracks"][5][7][0], "C-3");
        std::fs::remove_dir_all(dir).ok();
    }
}
