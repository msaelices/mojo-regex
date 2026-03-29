//! Library functions for Rust regex benchmarks
//! Mirrors the structure and functionality of bench_engine.py

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Benchmark result data structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BenchmarkResult {
    pub time_ns: f64,
    pub time_ms: f64,
    pub iterations: u64,
}

/// Complete benchmark results structure matching Python format
#[derive(Debug, Serialize, Deserialize)]
pub struct BenchmarkResults {
    pub engine: String,
    pub timestamp: String,
    pub results: HashMap<String, BenchmarkResult>,
}

/// Generate test string of specified length by repeating pattern
pub fn make_test_string(length: usize, pattern: &str) -> String {
    if length == 0 {
        return String::new();
    }

    let pattern_len = pattern.len();
    if pattern_len == 0 {
        return String::new();
    }

    let full_repeats = length / pattern_len;
    let remainder = length % pattern_len;

    let mut result = pattern.repeat(full_repeats);
    if remainder > 0 {
        result.push_str(&pattern[..remainder]);
    }

    result
}

/// Generate large mixed content text optimal for SIMD character class testing
pub fn make_mixed_content_text(length: usize) -> String {
    if length == 0 {
        return String::new();
    }

    let base_pattern = "User123 sent email to user456@domain.com with ID abc789! Status: ACTIVE_2024 (priority=HIGH). ";
    let pattern_len = base_pattern.len();
    let full_repeats = length / pattern_len;
    let remainder = length % pattern_len;

    let mut result = base_pattern.repeat(full_repeats);
    if remainder > 0 {
        result.push_str(&base_pattern[..remainder]);
    }

    result
}

/// Benchmark timing infrastructure
pub struct BenchmarkTimer {
    target_runtime_ns: u128,
    max_iterations: u64,
    min_sample_ns: u128,
    warmup_iterations: usize,
}

impl BenchmarkTimer {
    pub fn new() -> Self {
        Self {
            target_runtime_ns: 500_000_000, // 500ms target runtime
            max_iterations: 200_000,
            min_sample_ns: 1_000_000, // 1ms minimum per sample
            warmup_iterations: 10,
        }
    }

    /// Run a benchmark function and measure its performance using median timing
    pub fn bench_function<F>(&self, mut f: F) -> BenchmarkResult
    where
        F: FnMut(),
    {
        // Warmup runs
        for _ in 0..self.warmup_iterations {
            f();
        }

        // Auto-calibrate: measure one run, scale if needed
        let cal_start = std::time::Instant::now();
        f();
        let cal_elapsed = cal_start.elapsed().as_nanos();
        let repetitions = if cal_elapsed < self.min_sample_ns {
            (self.min_sample_ns / cal_elapsed) as usize + 1
        } else {
            1
        };

        let mut times_ns: Vec<f64> = Vec::new();
        let mut total_time_ns = 0u128;
        let mut iterations = 0u64;

        while total_time_ns < self.target_runtime_ns && iterations < self.max_iterations {
            let start = std::time::Instant::now();
            for _ in 0..repetitions {
                f();
            }
            let duration = start.elapsed();
            let elapsed = duration.as_nanos();

            total_time_ns += elapsed;
            iterations += 1;
            times_ns.push(elapsed as f64 / repetitions as f64);
        }

        // Compute median
        times_ns.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let median_time_ns = if times_ns.is_empty() {
            0.0
        } else if times_ns.len() % 2 == 1 {
            times_ns[times_ns.len() / 2]
        } else {
            (times_ns[times_ns.len() / 2 - 1] + times_ns[times_ns.len() / 2]) / 2.0
        };

        BenchmarkResult {
            time_ns: median_time_ns,
            time_ms: median_time_ns / 1_000_000.0,
            iterations: iterations * repetitions as u64,
        }
    }
}

/// Test data constants matching Python benchmarks
pub const SHORT_TEXT: &str = "hello world this is a test with hello again and hello there";
pub const EMAIL_TEXT: &str = "test@example.com user@test.org admin@example.com support@example.com no-reply@example.com";

// Generate derived test strings at compile time would be ideal, but we'll create them at runtime
pub fn get_medium_text() -> String {
    SHORT_TEXT.repeat(10)
}

pub fn get_long_text() -> String {
    SHORT_TEXT.repeat(100)
}

pub fn get_email_long() -> String {
    EMAIL_TEXT.repeat(5)
}
