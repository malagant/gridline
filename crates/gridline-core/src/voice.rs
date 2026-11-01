use std::sync::Arc;

use crate::sample::SampleData;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Stage {
    Idle,
    Attack,
    Sustain,
    Release,
}

/// Eine Sample-Stimme. Jede Spur ist monophon und besitzt genau eine.
pub(crate) struct Voice {
    stage: Stage,
    sample: Option<Arc<SampleData>>,
    position: f64,
    increment: f64,
    gain: f32,
    envelope: f32,
    attack_step: f32,
    release_step: f32,
    looped: bool,
}

pub(crate) struct Trigger {
    pub ratio: f64,
    pub output_rate: f64,
    pub gain: f32,
    pub attack: f64,
    pub release: f64,
    pub looped: bool,
}

impl Default for Voice {
    fn default() -> Self {
        Self {
            stage: Stage::Idle,
            sample: None,
            position: 0.0,
            increment: 1.0,
            gain: 0.0,
            envelope: 0.0,
            attack_step: 1.0,
            release_step: 1.0,
            looped: false,
        }
    }
}

impl Voice {
    pub fn is_active(&self) -> bool {
        self.stage != Stage::Idle
    }

    pub fn trigger(&mut self, sample: Arc<SampleData>, t: Trigger) {
        self.increment = t.ratio * sample.sample_rate / t.output_rate;
        self.sample = Some(sample);
        self.position = 0.0;
        self.gain = t.gain;
        self.envelope = 0.0;
        self.attack_step = (1.0 / (t.attack * t.output_rate).max(1.0)) as f32;
        self.release_step = (1.0 / (t.release * t.output_rate).max(1.0)) as f32;
        self.looped = t.looped;
        self.stage = Stage::Attack;
    }

    pub fn note_off(&mut self) {
        if self.stage != Stage::Idle {
            self.stage = Stage::Release;
        }
    }

    /// Mischt additiv in die Ausgabepuffer.
    pub fn render(&mut self, left: &mut [f32], right: &mut [f32]) {
        let Some(sample) = self.sample.as_ref() else { return };
        let count = sample.frame_count();
        if count < 2 {
            self.stage = Stage::Idle;
            return;
        }
        let (l, r) = (&sample.left, &sample.right);
        for (ol, or) in left.iter_mut().zip(right.iter_mut()) {
            match self.stage {
                Stage::Attack => {
                    self.envelope += self.attack_step;
                    if self.envelope >= 1.0 {
                        self.envelope = 1.0;
                        self.stage = Stage::Sustain;
                    }
                }
                Stage::Release => {
                    self.envelope -= self.release_step;
                    if self.envelope <= 0.0 {
                        self.envelope = 0.0;
                        self.stage = Stage::Idle;
                        break;
                    }
                }
                Stage::Sustain => {}
                Stage::Idle => break,
            }
            let mut idx = self.position as usize;
            if idx >= count - 1 {
                if self.looped {
                    self.position -= (count - 1) as f64;
                    idx = self.position as usize;
                } else {
                    self.stage = Stage::Idle;
                    break;
                }
            }
            let frac = (self.position - idx as f64) as f32;
            let a = self.gain * self.envelope;
            *ol += (l[idx] + (l[idx + 1] - l[idx]) * frac) * a;
            *or += (r[idx] + (r[idx + 1] - r[idx]) * frac) * a;
            self.position += self.increment;
        }
    }
}
