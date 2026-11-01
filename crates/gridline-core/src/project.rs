//! Projektformat: JSON mit Versionsfeld. Samples liegen als Dateipfade daneben.

use serde::{Deserialize, Serialize};

use crate::song::Song;

pub const FORMAT_VERSION: u32 = 1;
pub const FILE_EXTENSION: &str = "gridline";

#[derive(Debug)]
pub enum ProjectError {
    Json(serde_json::Error),
    UnsupportedVersion(u32),
}

impl std::fmt::Display for ProjectError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ProjectError::Json(e) => write!(f, "Projektdatei ungültig: {e}"),
            ProjectError::UnsupportedVersion(v) => write!(f, "Projektformat {v} wird nicht unterstützt"),
        }
    }
}

impl std::error::Error for ProjectError {}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Document {
    format_version: u32,
    song: Song,
}

pub fn encode(song: &Song) -> String {
    serde_json::to_string_pretty(&Document { format_version: FORMAT_VERSION, song: song.clone() })
        .expect("Song ist immer serialisierbar")
}

pub fn decode(text: &str) -> Result<Song, ProjectError> {
    #[derive(Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct Header {
        format_version: u32,
    }
    let header: Header = serde_json::from_str(text).map_err(ProjectError::Json)?;
    if header.format_version > FORMAT_VERSION {
        return Err(ProjectError::UnsupportedVersion(header.format_version));
    }
    let doc: Document = serde_json::from_str(text).map_err(ProjectError::Json)?;
    Ok(doc.song)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::instrument::SampleSource;
    use crate::step::{EffectKind, Step, StepEffect};

    #[test]
    fn round_trip() {
        let mut song = Song::demo();
        song.patterns[0].set(7, 9, Step { fx2: Some(StepEffect::new(EffectKind::Microtime, 12)), ..Step::off() });
        song.instruments[6].source = SampleSource::File("/tmp/test.wav".into());
        let text = encode(&song);
        assert_eq!(decode(&text).unwrap(), song);
    }

    #[test]
    fn rejects_newer_version() {
        let text = encode(&Song::demo()).replacen("\"formatVersion\": 1", "\"formatVersion\": 99", 1);
        assert!(matches!(decode(&text), Err(ProjectError::UnsupportedVersion(99))));
    }
}
