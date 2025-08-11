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
}

impl BenchmarkTimer {
    pub fn new() -> Self {
        Self {
            target_runtime_ns: 100_000_000, // 100ms target runtime
            max_iterations: 100_000,
        }
    }

    /// Run a benchmark function and measure its performance
    pub fn bench_function<F>(&self, mut f: F) -> BenchmarkResult
    where
        F: FnMut(),
    {
        // Warmup runs
        for _ in 0..3 {
            f();
        }

        let mut total_time_ns = 0u128;
        let mut iterations = 0u64;

        while total_time_ns < self.target_runtime_ns && iterations < self.max_iterations {
            let start = std::time::Instant::now();
            f();
            let duration = start.elapsed();

            total_time_ns += duration.as_nanos();
            iterations += 1;
        }

        let mean_time_ns = if iterations > 0 {
            total_time_ns as f64 / iterations as f64
        } else {
            0.0
        };

        BenchmarkResult {
            time_ns: mean_time_ns,
            time_ms: mean_time_ns / 1_000_000.0,
            iterations,
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
