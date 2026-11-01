use serde::{Deserialize, Serialize};

use crate::note::note_name;

/// Inhalt der Notenspalte.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum StepNote {
    #[default]
    Empty,
    Note(u8),
    Off,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum EffectKind {
    Retrigger,
    Arpeggio,
    Slide,
    VolumeSlide,
    Microtime,
    Chance,
}

impl EffectKind {
    pub const ALL: [EffectKind; 6] = [
        EffectKind::Retrigger,
        EffectKind::Arpeggio,
        EffectKind::Slide,
        EffectKind::VolumeSlide,
        EffectKind::Microtime,
        EffectKind::Chance,
    ];

    /// Ein-Zeichen-Kürzel im Grid.
    pub fn code(self) -> char {
        match self {
            EffectKind::Retrigger => 'R',
            EffectKind::Arpeggio => 'A',
            EffectKind::Slide => 'S',
            EffectKind::VolumeSlide => 'V',
            EffectKind::Microtime => 'M',
            EffectKind::Chance => 'C',
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct StepEffect {
    pub kind: EffectKind,
    /// 0..=99
    pub value: u8,
}

impl StepEffect {
    pub fn new(kind: EffectKind, value: u8) -> Self {
        Self { kind, value: value.min(99) }
    }
}

/// Eine Zelle im Pattern.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(default)]
pub struct Step {
    pub note: StepNote,
    /// Index in `Song::instruments`. `None` = letztes Instrument der Spur.
    pub instrument: Option<u8>,
    /// 0..=100, `None` = Instrumentlautstärke.
    pub volume: Option<u8>,
    pub fx1: Option<StepEffect>,
    pub fx2: Option<StepEffect>,
}

impl Step {
    pub const EMPTY: Step = Step { note: StepNote::Empty, instrument: None, volume: None, fx1: None, fx2: None };

    pub fn note(midi: u8, instrument: u8) -> Self {
        Step { note: StepNote::Note(midi), instrument: Some(instrument), ..Step::EMPTY }
    }

    pub fn off() -> Self {
        Step { note: StepNote::Off, ..Step::EMPTY }
    }

    pub fn with_volume(mut self, volume: u8) -> Self {
        self.volume = Some(volume.min(100));
        self
    }

    pub fn is_empty(&self) -> bool {
        *self == Step::EMPTY
    }

    // Textdarstellung der Spalten.

    pub fn note_text(&self) -> String {
        match self.note {
            StepNote::Empty => "---".into(),
            StepNote::Off => "OFF".into(),
            StepNote::Note(m) => note_name(m),
        }
    }

    /// 1-basiert, wie Musiker es lesen.
    pub fn instrument_text(&self) -> String {
        self.instrument.map_or("--".into(), |i| format!("{:02}", u16::from(i) + 1))
    }

    pub fn volume_text(&self) -> String {
        match self.volume {
            None => "--".into(),
            Some(v) if v >= 100 => "FF".into(),
            Some(v) => format!("{v:02}"),
        }
    }

    pub fn effect_text(fx: Option<StepEffect>) -> String {
        fx.map_or("---".into(), |f| format!("{}{:02}", f.kind.code(), f.value))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn formatting() {
        let e = Step::EMPTY;
        assert_eq!(e.note_text(), "---");
        assert_eq!(e.instrument_text(), "--");
        assert_eq!(e.volume_text(), "--");
        assert_eq!(Step::effect_text(None), "---");

        let s = Step { fx1: Some(StepEffect::new(EffectKind::Retrigger, 3)), ..Step::note(62, 0).with_volume(100) };
        assert_eq!(s.note_text(), "D-4");
        assert_eq!(s.instrument_text(), "01");
        assert_eq!(s.volume_text(), "FF");
        assert_eq!(Step::effect_text(s.fx1), "R03");
        assert_eq!(Step::off().note_text(), "OFF");
    }

    #[test]
    fn clamping() {
        assert_eq!(Step::EMPTY.with_volume(250).volume, Some(100));
        assert_eq!(StepEffect::new(EffectKind::Chance, 200).value, 99);
    }
}
