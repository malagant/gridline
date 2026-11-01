/// Unveränderliche, dekodierte Sample-Daten (getrennte Kanäle, f32).
#[derive(Clone, Debug, PartialEq)]
pub struct SampleData {
    pub left: Vec<f32>,
    pub right: Vec<f32>,
    pub sample_rate: f64,
}

impl SampleData {
    pub fn stereo(left: Vec<f32>, right: Vec<f32>, sample_rate: f64) -> Self {
        assert_eq!(left.len(), right.len(), "Kanäle müssen gleich lang sein");
        Self { left, right, sample_rate }
    }

    pub fn mono(samples: Vec<f32>, sample_rate: f64) -> Self {
        Self { right: samples.clone(), left: samples, sample_rate }
    }

    pub fn frame_count(&self) -> usize {
        self.left.len()
    }
}
