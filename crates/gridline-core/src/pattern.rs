use serde::{Deserialize, Serialize};

use crate::step::Step;

pub const MAX_LENGTH: usize = 128;
pub const TRACK_COUNT: usize = 8;

/// `tracks[track][step]`; jede Spur hat immer `MAX_LENGTH` Steps,
/// damit Daten beim Kürzen erhalten bleiben.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Pattern {
    length: usize,
    tracks: Vec<Vec<Step>>,
}

impl Default for Pattern {
    fn default() -> Self {
        Self::new(16)
    }
}

impl Pattern {
    pub fn new(length: usize) -> Self {
        Self { length: length.clamp(1, MAX_LENGTH), tracks: vec![vec![Step::EMPTY; MAX_LENGTH]; TRACK_COUNT] }
    }

    pub fn length(&self) -> usize {
        self.length
    }

    pub fn set_length(&mut self, length: usize) {
        self.length = length.clamp(1, MAX_LENGTH);
    }

    pub fn track_count(&self) -> usize {
        self.tracks.len()
    }

    pub fn get(&self, track: usize, step: usize) -> Step {
        self.tracks.get(track).and_then(|t| t.get(step)).copied().unwrap_or(Step::EMPTY)
    }

    pub fn set(&mut self, track: usize, step: usize, value: Step) {
        if let Some(slot) = self.tracks.get_mut(track).and_then(|t| t.get_mut(step)) {
            *slot = value;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn length_is_clamped_and_data_survives() {
        let mut p = Pattern::new(16);
        p.set(0, 20, Step::note(60, 0));
        p.set_length(500);
        assert_eq!(p.length(), MAX_LENGTH);
        p.set_length(0);
        assert_eq!(p.length(), 1);
        p.set_length(32);
        assert_eq!(p.get(0, 20), Step::note(60, 0));
    }

    #[test]
    fn out_of_range_is_safe() {
        let mut p = Pattern::default();
        p.set(99, 0, Step::note(60, 0));
        assert_eq!(p.get(99, 0), Step::EMPTY);
        assert_eq!(p.get(0, 999), Step::EMPTY);
    }
}
