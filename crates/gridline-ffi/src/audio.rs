//! Audio-Ausgabe über cpal (CoreAudio auf macOS/iOS, ALSA auf Linux).

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{FromSample, SampleFormat, SizedSample, Stream, StreamConfig};
use gridline_core::Renderer;

pub struct Output {
    // Muss am Leben bleiben, solange gespielt wird.
    _stream: Stream,
    pub sample_rate: f64,
    pub device: String,
}

/// Abtastrate des Standard-Ausgabegeräts, falls vorhanden.
pub fn default_sample_rate() -> Option<f64> {
    let device = cpal::default_host().default_output_device()?;
    device.default_output_config().ok().map(|c| f64::from(c.sample_rate()))
}

/// Öffnet das Standard-Ausgabegerät und übergibt den Renderer an den Audio-Thread.
pub fn start(renderer: Renderer) -> Result<Output, String> {
    let host = cpal::default_host();
    let device = host.default_output_device().ok_or("Kein Audio-Ausgabegerät gefunden")?;
    let name = device.description().map(|d| d.to_string()).unwrap_or_else(|_| "Standardausgabe".into());
    let supported = device.default_output_config().map_err(|e| format!("Audiogerät nicht nutzbar: {e}"))?;
    let format = supported.sample_format();
    let config: StreamConfig = supported.into();
    let sample_rate = f64::from(config.sample_rate);

    let stream = match format {
        SampleFormat::F32 => build::<f32>(&device, config, renderer),
        SampleFormat::I16 => build::<i16>(&device, config, renderer),
        SampleFormat::I32 => build::<i32>(&device, config, renderer),
        SampleFormat::U16 => build::<u16>(&device, config, renderer),
        other => return Err(format!("Sample-Format {other} wird nicht unterstützt")),
    }?;
    stream.play().map_err(|e| format!("Audio konnte nicht gestartet werden: {e}"))?;
    Ok(Output { _stream: stream, sample_rate, device: name })
}

fn build<T>(device: &cpal::Device, config: StreamConfig, mut renderer: Renderer) -> Result<Stream, String>
where
    T: SizedSample + FromSample<f32> + Send + 'static,
{
    let channels = usize::from(config.channels);
    // Vorab reservierter Zwischenpuffer für Nicht-f32-Formate.
    let mut scratch: Vec<f32> = vec![0.0; 16_384];
    device
        .build_output_stream(
            config,
            move |data: &mut [T], _| {
                if scratch.len() < data.len() {
                    // Nur bei ungewöhnlich großen Puffern; danach nie wieder.
                    scratch.resize(data.len(), 0.0);
                }
                let buf = &mut scratch[..data.len()];
                renderer.render_interleaved(buf, channels);
                for (out, v) in data.iter_mut().zip(buf.iter()) {
                    *out = T::from_sample(*v);
                }
            },
            |err| eprintln!("Gridline-Audio: {err}"),
            None,
        )
        .map_err(|e| format!("Audio-Stream konnte nicht geöffnet werden: {e}"))
}
