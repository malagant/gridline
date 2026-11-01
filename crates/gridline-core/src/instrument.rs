use serde::{Deserialize, Serialize};

pub const SLOT_COUNT: usize = 16;

/// Eingebaute, im Code erzeugte Klänge. Keine fremden Samples.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum BuiltinSound {
    Kick,
    Snare,
    Hat,
    Pluck,
    Bass,
}

impl BuiltinSound {
    pub const ALL: [BuiltinSound; 5] =
        [BuiltinSound::Kick, BuiltinSound::Snare, BuiltinSound::Hat, BuiltinSound::Pluck, BuiltinSound::Bass];
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SampleSource {
    #[default]
    None,
    Builtin(BuiltinSound),
    File(String),
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(default, rename_all = "camelCase")]
pub struct Instrument {
    pub name: String,
    pub source: SampleSource,
    /// 0..=1
    pub volume: f64,
    /// Halbtöne, darf gebrochen sein.
    pub tune: f64,
    /// Note, auf der das Sample unverändert klingt.
    pub root_note: u8,
    /// Sekunden
    pub attack: f64,
    /// Sekunden
    pub release: f64,
    pub looped: bool,
}

impl Default for Instrument {
    fn default() -> Self {
        Self {
            name: "—".into(),
            source: SampleSource::None,
            volume: 0.8,
            tune: 0.0,
            root_note: 60,
            attack: 0.002,
            release: 0.05,
            looped: false,
        }
    }
}

impl Instrument {
    pub fn builtin(name: &str, sound: BuiltinSound, volume: f64) -> Self {
        Self { name: name.into(), source: SampleSource::Builtin(sound), volume, ..Self::default() }
    }
}
