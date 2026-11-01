use std::ops::RangeInclusive;

use serde::{Deserialize, Serialize};

use crate::instrument::{BuiltinSound, Instrument, SLOT_COUNT};
use crate::pattern::Pattern;
use crate::step::Step;

pub const BPM_RANGE: RangeInclusive<f64> = 40.0..=300.0;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Song {
    pub name: String,
    bpm: f64,
    pub patterns: Vec<Pattern>,
    pub instruments: Vec<Instrument>,
}

impl Default for Song {
    fn default() -> Self {
        Self {
            name: "Neuer Song".into(),
            bpm: 120.0,
            patterns: vec![Pattern::default()],
            instruments: vec![Instrument::default(); SLOT_COUNT],
        }
    }
}

impl Song {
    pub fn bpm(&self) -> f64 {
        self.bpm
    }

    pub fn set_bpm(&mut self, bpm: f64) {
        self.bpm = bpm.clamp(*BPM_RANGE.start(), *BPM_RANGE.end());
    }

    pub fn pattern(&self, index: usize) -> &Pattern {
        self.patterns.get(index).unwrap_or(&self.patterns[0])
    }

    /// Kleiner Startsong mit eingebauten Klängen.
    pub fn demo() -> Self {
        let mut instruments = vec![
            Instrument::builtin("Kick", BuiltinSound::Kick, 0.9),
            Instrument::builtin("Snare", BuiltinSound::Snare, 0.7),
            Instrument::builtin("Hat", BuiltinSound::Hat, 0.5),
            Instrument { release: 0.2, ..Instrument::builtin("Pluck", BuiltinSound::Pluck, 0.6) },
            Instrument { release: 0.08, ..Instrument::builtin("Bass", BuiltinSound::Bass, 0.7) },
        ];
        instruments.resize(SLOT_COUNT, Instrument::default());

        let mut p = Pattern::new(16);
        for s in (0..16).step_by(4) {
            p.set(0, s, Step::note(60, 0));
        }
        for s in [4, 12] {
            p.set(1, s, Step::note(60, 1));
        }
        for s in (2..16).step_by(4) {
            p.set(2, s, Step::note(60, 2).with_volume(60));
        }
        for (s, n) in [(0, 72), (3, 75), (6, 79), (10, 77), (13, 74)] {
            p.set(3, s, Step::note(n, 3));
        }
        for (s, n) in [(0, 36), (6, 36), (8, 39), (14, 34)] {
            p.set(4, s, Step::note(n, 4));
        }
        p.set(4, 11, Step::off());

        Self { name: "Demo".into(), bpm: 118.0, patterns: vec![p], instruments }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bpm_is_clamped() {
        let mut s = Song::default();
        s.set_bpm(1000.0);
        assert_eq!(s.bpm(), 300.0);
        s.set_bpm(1.0);
        assert_eq!(s.bpm(), 40.0);
    }
}
