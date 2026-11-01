//! WAV-Leser und -Schreiber (RIFF/WAVE).
//! Lesen: PCM 8/16/24/32 Bit, Float 32/64 Bit, auch WAVE_FORMAT_EXTENSIBLE.
//! Schreiben: Stereo, 16-Bit-PCM oder 32-Bit-Float.

use crate::sample::SampleData;

#[derive(Debug, PartialEq, Eq)]
pub enum WavError {
    NotWave,
    MissingChunk(&'static str),
    Unsupported { tag: u16, bits: u16 },
}

impl std::fmt::Display for WavError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            WavError::NotWave => write!(f, "keine WAV-Datei"),
            WavError::MissingChunk(c) => write!(f, "WAV-Datei ohne '{c}'-Block"),
            WavError::Unsupported { tag, bits } => write!(f, "WAV-Format {tag} mit {bits} Bit wird nicht unterstützt"),
        }
    }
}

impl std::error::Error for WavError {}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Encoding {
    Pcm16,
    Float32,
}

const FORMAT_PCM: u16 = 1;
const FORMAT_FLOAT: u16 = 3;
const FORMAT_EXTENSIBLE: u16 = 0xFFFE;

fn u16_at(b: &[u8], i: usize) -> u16 {
    u16::from_le_bytes([b[i], b[i + 1]])
}

fn u32_at(b: &[u8], i: usize) -> u32 {
    u32::from_le_bytes([b[i], b[i + 1], b[i + 2], b[i + 3]])
}

pub fn decode(bytes: &[u8]) -> Result<SampleData, WavError> {
    if bytes.len() < 12 || &bytes[0..4] != b"RIFF" || &bytes[8..12] != b"WAVE" {
        return Err(WavError::NotWave);
    }

    let mut format: Option<(u16, usize, f64, u16)> = None;
    let mut payload: Option<(usize, usize)> = None;
    let mut offset = 12;
    while offset + 8 <= bytes.len() {
        let id = &bytes[offset..offset + 4];
        let size = u32_at(bytes, offset + 4) as usize;
        let body = offset + 8;
        let end = (body + size).min(bytes.len());
        match id {
            b"fmt " => {
                if end - body < 16 {
                    return Err(WavError::MissingChunk("fmt "));
                }
                let mut tag = u16_at(bytes, body);
                let channels = usize::from(u16_at(bytes, body + 2)).max(1);
                let rate = f64::from(u32_at(bytes, body + 4));
                let bits = u16_at(bytes, body + 14);
                if tag == FORMAT_EXTENSIBLE && end - body >= 26 {
                    tag = u16_at(bytes, body + 24); // erstes Feld der SubFormat-GUID
                }
                format = Some((tag, channels, rate, bits));
            }
            b"data" => payload = Some((body, end)),
            _ => {}
        }
        offset = body + size + (size & 1); // Blöcke sind auf gerade Längen gepolstert
    }

    let (tag, channels, rate, bits) = format.ok_or(WavError::MissingChunk("fmt "))?;
    let (start, end) = payload.ok_or(WavError::MissingChunk("data"))?;

    let width = usize::from(bits / 8);
    let read: fn(&[u8], usize) -> f32 = match (tag, bits) {
        (FORMAT_PCM, 8) => |b, i| (f32::from(b[i]) - 128.0) / 128.0,
        (FORMAT_PCM, 16) => |b, i| f32::from(u16_at(b, i) as i16) / 32_768.0,
        (FORMAT_PCM, 24) => |b, i| {
            let raw = i32::from_le_bytes([0, b[i], b[i + 1], b[i + 2]]) >> 8;
            raw as f32 / 8_388_608.0
        },
        (FORMAT_PCM, 32) => |b, i| u32_at(b, i) as i32 as f32 / 2_147_483_648.0,
        (FORMAT_FLOAT, 32) => |b, i| f32::from_bits(u32_at(b, i)),
        (FORMAT_FLOAT, 64) => |b, i| {
            let v = u64::from(u32_at(b, i)) | u64::from(u32_at(b, i + 4)) << 32;
            f64::from_bits(v) as f32
        },
        _ => return Err(WavError::Unsupported { tag, bits }),
    };

    let frame = width * channels;
    let frames = (end - start) / frame;
    let mut left = Vec::with_capacity(frames);
    let mut right = Vec::with_capacity(frames);
    for f in 0..frames {
        let base = start + f * frame;
        let l = read(bytes, base);
        left.push(l);
        right.push(if channels > 1 { read(bytes, base + width) } else { l });
    }
    Ok(SampleData::stereo(left, right, rate))
}

pub fn encode(left: &[f32], right: &[f32], sample_rate: u32, encoding: Encoding) -> Vec<u8> {
    assert_eq!(left.len(), right.len(), "Kanäle müssen gleich lang sein");
    let channels: u16 = 2;
    let bits: u16 = if encoding == Encoding::Pcm16 { 16 } else { 32 };
    let block = channels * bits / 8;
    let data_size = left.len() as u32 * u32::from(block);

    let mut out = Vec::with_capacity(44 + data_size as usize);
    out.extend_from_slice(b"RIFF");
    out.extend_from_slice(&(36 + data_size).to_le_bytes());
    out.extend_from_slice(b"WAVEfmt ");
    out.extend_from_slice(&16u32.to_le_bytes());
    out.extend_from_slice(&(if encoding == Encoding::Pcm16 { FORMAT_PCM } else { FORMAT_FLOAT }).to_le_bytes());
    out.extend_from_slice(&channels.to_le_bytes());
    out.extend_from_slice(&sample_rate.to_le_bytes());
    out.extend_from_slice(&(sample_rate * u32::from(block)).to_le_bytes());
    out.extend_from_slice(&block.to_le_bytes());
    out.extend_from_slice(&bits.to_le_bytes());
    out.extend_from_slice(b"data");
    out.extend_from_slice(&data_size.to_le_bytes());
    for (l, r) in left.iter().zip(right) {
        for v in [*l, *r] {
            match encoding {
                Encoding::Pcm16 => {
                    out.extend_from_slice(&((v.clamp(-1.0, 1.0) * 32_767.0).round() as i16).to_le_bytes())
                }
                Encoding::Float32 => out.extend_from_slice(&v.to_bits().to_le_bytes()),
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    const L: [f32; 6] = [0.0, 0.5, -0.5, 1.0, -1.0, 0.25];
    const R: [f32; 6] = [0.1, -0.1, 0.2, -0.2, 0.3, -0.3];

    #[test]
    fn round_trip_pcm16() {
        let bytes = encode(&L, &R, 44_100, Encoding::Pcm16);
        assert_eq!(bytes.len(), 44 + L.len() * 4);
        let s = decode(&bytes).unwrap();
        assert_eq!(s.sample_rate, 44_100.0);
        for i in 0..L.len() {
            assert!((s.left[i] - L[i]).abs() < 1.0 / 16_000.0);
            assert!((s.right[i] - R[i]).abs() < 1.0 / 16_000.0);
        }
    }

    #[test]
    fn round_trip_float32_is_exact() {
        let s = decode(&encode(&L, &R, 48_000, Encoding::Float32)).unwrap();
        assert_eq!(s.left, L);
        assert_eq!(s.right, R);
    }

    #[test]
    fn mono_8bit_with_odd_extra_chunk() {
        let mut b: Vec<u8> = b"RIFF\0\0\0\0WAVE".to_vec();
        b.extend_from_slice(b"LIST\x03\0\0\0\x01\x02\x03\0");
        b.extend_from_slice(b"fmt \x10\0\0\0\x01\0\x01\0");
        b.extend_from_slice(&[0x40, 0x1F, 0, 0, 0x40, 0x1F, 0, 0, 1, 0, 8, 0]);
        b.extend_from_slice(b"data\x03\0\0\0");
        b.extend_from_slice(&[128, 255, 0]);
        let s = decode(&b).unwrap();
        assert_eq!(s.sample_rate, 8000.0);
        assert_eq!(s.left, vec![0.0, 127.0 / 128.0, -1.0]);
        assert_eq!(s.right, s.left);
    }

    #[test]
    fn pcm24_sign() {
        let mut b: Vec<u8> = b"RIFF\0\0\0\0WAVEfmt \x10\0\0\0\x01\0\x01\0".to_vec();
        b.extend_from_slice(&[0x80, 0xBB, 0, 0, 0, 0, 0, 0, 3, 0, 24, 0]);
        b.extend_from_slice(b"data\x06\0\0\0");
        b.extend_from_slice(&[0, 0, 0x80, 0xFF, 0xFF, 0x7F]); // -1.0 und fast +1.0
        let s = decode(&b).unwrap();
        assert_eq!(s.left[0], -1.0);
        assert!(s.left[1] > 0.999);
    }

    #[test]
    fn rejects_non_wave() {
        assert_eq!(decode(b"hello world, no wave"), Err(WavError::NotWave));
    }
}
