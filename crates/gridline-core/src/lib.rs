//! Gridline-Kern: Datenmodell, sample-genauer Sequencer und Echtzeit-Renderer.
//!
//! Der Kern hat keine Plattformabhängigkeiten. Audio-Ausgabe und Oberfläche
//! liegen in eigenen Crates bzw. in der Flutter-App.

pub mod builtin;
pub mod clock;
pub mod engine;
pub mod instrument;
pub mod note;
pub mod pattern;
pub mod project;
pub mod sample;
pub mod song;
pub mod step;
mod voice;
pub mod wav;

pub use clock::StepClock;
pub use engine::{new_engine, Command, Controller, Renderer, Snapshot};
pub use instrument::{BuiltinSound, Instrument, SampleSource};
pub use note::{note_name, pitch_ratio};
pub use pattern::Pattern;
pub use sample::SampleData;
pub use song::Song;
pub use step::{EffectKind, Step, StepEffect, StepNote};
