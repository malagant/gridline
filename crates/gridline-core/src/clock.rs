/// Sample-genaue Step-Uhr. Läuft im Audio-Thread und allokiert nicht.
#[derive(Clone, Debug)]
pub struct StepClock {
    pub sample_rate: f64,
    pub bpm: f64,
    pub steps_per_beat: u32,
    next_step: usize,
    samples_until_next: f64,
}

impl StepClock {
    pub fn new(sample_rate: f64, bpm: f64) -> Self {
        Self { sample_rate, bpm, steps_per_beat: 4, next_step: 0, samples_until_next: 0.0 }
    }

    pub fn samples_per_step(&self) -> f64 {
        self.sample_rate * 60.0 / self.bpm.max(1.0) / f64::from(self.steps_per_beat.max(1))
    }

    pub fn next_step(&self) -> usize {
        self.next_step
    }

    /// Setzt auf `step` zurück; dieser Step fällt im nächsten Puffer auf Frame 0.
    pub fn reset(&mut self, step: usize) {
        self.next_step = step;
        self.samples_until_next = 0.0;
    }

    /// Schiebt die Uhr um `frames` vor und meldet jeden Step mit seinem Frame-Offset.
    pub fn advance(&mut self, frames: usize, step_count: usize, mut on_step: impl FnMut(usize, usize)) {
        let count = step_count.max(1);
        if self.next_step >= count {
            self.next_step = 0;
        }
        let end = frames as f64;
        let len = self.samples_per_step();
        let mut t = self.samples_until_next;
        while t < end {
            on_step(t.max(0.0) as usize, self.next_step);
            self.next_step = (self.next_step + 1) % count;
            t += len;
        }
        self.samples_until_next = t - end;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn step_spacing() {
        let mut c = StepClock::new(48_000.0, 120.0);
        assert!((c.samples_per_step() - 6000.0).abs() < 1e-9);
        let mut hits = vec![];
        c.advance(13_000, 16, |o, s| hits.push((o, s)));
        assert_eq!(hits, vec![(0, 0), (6000, 1), (12_000, 2)]);
    }

    #[test]
    fn across_buffer_boundaries() {
        let mut c = StepClock::new(48_000.0, 120.0);
        let mut abs = vec![];
        for b in 0..50 {
            c.advance(512, 16, |o, _| abs.push(b * 512 + o));
        }
        assert_eq!(abs, (0..50 * 512).step_by(6000).collect::<Vec<_>>());
    }

    #[test]
    fn wraps_at_pattern_length() {
        let mut c = StepClock::new(1000.0, 60.0);
        c.steps_per_beat = 1;
        let mut steps = vec![];
        c.advance(5000, 3, |_, s| steps.push(s));
        assert_eq!(steps, vec![0, 1, 2, 0, 1]);
    }

    #[test]
    fn reset_starts_at_step() {
        let mut c = StepClock::new(1000.0, 60.0);
        c.steps_per_beat = 1;
        c.advance(2500, 8, |_, _| {});
        c.reset(5);
        let mut first = None;
        c.advance(10, 8, |o, s| {
            first.get_or_insert((o, s));
        });
        assert_eq!(first, Some((0, 5)));
    }
}
