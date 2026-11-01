use std::ops::RangeInclusive;

/// Spielbarer Notenbereich (C-0 bis B-8).
pub const PLAYABLE: RangeInclusive<u8> = 12..=119;

const NAMES: [&str; 12] = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"];

/// Tracker-Schreibweise, MIDI 60 = "C-4".
pub fn note_name(midi: u8) -> String {
    let m = midi.clamp(*PLAYABLE.start(), *PLAYABLE.end());
    format!("{}{}", NAMES[(m % 12) as usize], m / 12 - 1)
}

/// Abspielverhältnis einer Note relativ zum Grundton des Samples.
pub fn pitch_ratio(note: i32, root: i32, tune: f64) -> f64 {
    2f64.powf((f64::from(note - root) + tune) / 12.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tracker_note_names() {
        assert_eq!(note_name(60), "C-4");
        assert_eq!(note_name(61), "C#4");
        assert_eq!(note_name(69), "A-4");
        assert_eq!(note_name(12), "C-0");
        assert_eq!(note_name(119), "B-8");
        assert_eq!(note_name(0), "C-0");
    }

    #[test]
    fn ratios() {
        assert!((pitch_ratio(60, 60, 0.0) - 1.0).abs() < 1e-12);
        assert!((pitch_ratio(72, 60, 0.0) - 2.0).abs() < 1e-12);
        assert!((pitch_ratio(48, 60, 0.0) - 0.5).abs() < 1e-12);
        assert!((pitch_ratio(60, 60, 12.0) - 2.0).abs() < 1e-12);
    }
}
