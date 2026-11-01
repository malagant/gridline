//! Rendert das Demo-Pattern offline in eine WAV-Datei.
//! `cargo run -p gridline-core --example render_demo -- demo.wav [takte]`

use std::sync::Arc;

use gridline_core::{builtin, new_engine, wav, Command, SampleSource, Snapshot, Song};

fn main() -> std::io::Result<()> {
    let mut args = std::env::args().skip(1);
    let path = args.next().unwrap_or_else(|| "demo.wav".into());
    let bars: usize = args.next().and_then(|s| s.parse().ok()).unwrap_or(4);

    let sr = 48_000.0;
    let song = Song::demo();
    let samples = song
        .instruments
        .iter()
        .map(|i| match i.source {
            SampleSource::Builtin(s) => Some(Arc::new(builtin::make(s, sr))),
            _ => None,
        })
        .collect();
    let frames = (sr * 60.0 / song.bpm() * 4.0 * bars as f64) as usize;
    let (mut controller, mut renderer) = new_engine(sr, Snapshot { song, samples, pattern_index: 0 });
    controller.send(Command::Play { from_step: 0 }).expect("Befehlsring leer");

    let mut left = vec![0.0; frames];
    let mut right = vec![0.0; frames];
    renderer.render(&mut left, &mut right);
    std::fs::write(&path, wav::encode(&left, &right, sr as u32, wav::Encoding::Pcm16))?;
    println!("{path}: {bars} Takte, {frames} Frames");
    Ok(())
}
