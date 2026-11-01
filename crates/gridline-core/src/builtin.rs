//! Synthetisch erzeugte Startklänge. Tonale Klänge sind auf C-4 (261,63 Hz) gestimmt.

use std::f64::consts::TAU;

use crate::instrument::BuiltinSound;
use crate::sample::SampleData;

const C4: f64 = 261.625_565;

pub fn make(sound: BuiltinSound, sample_rate: f64) -> SampleData {
    match sound {
        BuiltinSound::Kick => kick(sample_rate),
        BuiltinSound::Snare => snare(sample_rate),
        BuiltinSound::Hat => hat(sample_rate),
        BuiltinSound::Pluck => pluck(sample_rate),
        BuiltinSound::Bass => bass(sample_rate),
    }
}

/// Deterministisches Rauschen, damit Klänge reproduzierbar sind.
struct Noise(u32);

impl Noise {
    fn next(&mut self) -> f32 {
        self.0 = self.0.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
        self.0 as i32 as f32 / i32::MAX as f32
    }
}

fn frames(sr: f64, seconds: f64) -> usize {
    (sr * seconds) as usize
}

fn kick(sr: f64) -> SampleData {
    let n = frames(sr, 0.45);
    let click_len = sr * 0.003;
    let mut phase = 0.0;
    let out = (0..n)
        .map(|i| {
            let t = i as f64 / sr;
            phase += TAU * (45.0 + 110.0 * (-t * 30.0).exp()) / sr;
            let click = if (i as f64) < click_len { 0.3 * (1.0 - i as f64 / click_len) } else { 0.0 };
            (phase.sin() * (-t * 7.0).exp() + click) as f32
        })
        .collect();
    SampleData::mono(out, sr)
}

fn snare(sr: f64) -> SampleData {
    let mut noise = Noise(0x1234_5678);
    let out = (0..frames(sr, 0.25))
        .map(|i| {
            let t = i as f64 / sr;
            let tone = (TAU * 185.0 * t).sin() * (-t * 25.0).exp() * 0.5;
            let hiss = f64::from(noise.next()) * (-t * 14.0).exp() * 0.6;
            (tone + hiss) as f32
        })
        .collect();
    SampleData::mono(out, sr)
}

fn hat(sr: f64) -> SampleData {
    let mut noise = Noise(0xCAFE_F00D);
    let mut prev = 0.0f32;
    let out = (0..frames(sr, 0.08))
        .map(|i| {
            let t = i as f64 / sr;
            let x = noise.next();
            let hp = x - prev; // einfacher Differenzierer als Hochpass
            prev = x;
            hp * (-t * 60.0).exp() as f32 * 0.5
        })
        .collect();
    SampleData::mono(out, sr)
}

/// Karplus-Strong-Saite.
fn pluck(sr: f64) -> SampleData {
    let period = ((sr / C4).round() as usize).max(2);
    let mut noise = Noise(0xBEEF);
    let mut ring: Vec<f32> = (0..period).map(|_| noise.next() * 0.5).collect();
    let mut idx = 0;
    let out = (0..frames(sr, 1.2))
        .map(|_| {
            let next = (idx + 1) % period;
            let v = ring[idx];
            ring[idx] = 0.996 * 0.5 * (v + ring[next]);
            idx = next;
            v
        })
        .collect();
    SampleData::mono(out, sr)
}

/// Gefilterte Sägezahnwelle.
fn bass(sr: f64) -> SampleData {
    let mut phase = 0.0;
    let mut lp = 0.0;
    let out = (0..frames(sr, 0.8))
        .map(|i| {
            let t = i as f64 / sr;
            phase = (phase + C4 / sr) % 1.0;
            let saw = 2.0 * phase - 1.0;
            lp += (0.02 + 0.25 * (-t * 9.0).exp()) * (saw - lp);
            (lp * (-t * 2.5).exp() * 0.9) as f32
        })
        .collect();
    SampleData::mono(out, sr)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_sounds_are_usable() {
        for s in BuiltinSound::ALL {
            let d = make(s, 48_000.0);
            assert!(d.frame_count() > 100, "{s:?}");
            assert!(d.left.iter().all(|x| x.is_finite()), "{s:?}");
            let peak = d.left.iter().fold(0f32, |m, x| m.max(x.abs()));
            assert!(peak > 0.05, "{s:?} peak {peak}");
        }
    }
}
