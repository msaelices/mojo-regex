#!/usr/bin/env -S cargo +stable run --release --bin bench_engine --
//! Rust regex benchmark program
//! Mirrors benchmarks/bench_engine.py for direct performance comparison

use mojo_regex_rust_bench::*;
use regex::Regex;
use std::collections::HashMap;
use std::hint::black_box;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let timer = BenchmarkTimer::new();
    let mut all_results = HashMap::new();

    println!("=== RUST REGEX BENCHMARKS ===");
    println!();

    // Pre-create test strings to avoid measurement overhead
    let text_1000 = make_test_string(1000, "abcdefghijklmnopqrstuvwxyz");
    let text_10000 = make_test_string(10000, "abcdefghijklmnopqrstuvwxyz");
    let text_range_1000 = make_test_string(1000, "abc123XYZ");
    let text_alternation_1000 = make_test_string(1000, "abcdefghijklmnopqrstuvwxyz");
    let text_group_1000 = make_test_string(1000, "abcabcabc");

    // Create complex text patterns
    let base_text = make_test_string(100, "abcdefghijklmnopqrstuvwxyz");
    let emails = " user@example.com more text john@test.org ";
    let email_text = format!("{} {} {} {} {}", base_text, emails, base_text, emails, base_text);

    let base_number_text = make_test_string(500, "abc def ghi ");
    let number_text = format!("{} 123 price $456.78 quantity 789 {}", base_number_text, base_number_text);

    // Pre-compile all regex patterns to avoid compilation overhead in benchmarks
    let patterns = create_all_patterns()?;

    // ===-----------------------------------------------------------------------===
    // Basic Literal Matching Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Literal Matching Benchmarks ===");

    run_benchmark(
        &timer,
        &mut all_results,
        "literal_match_short",
        &patterns.hello,
        &format!("{} hello world {}", text_1000, text_1000),
        100,
        BenchType::Search
    );

    run_benchmark(
        &timer,
        &mut all_results,
        "literal_match_long",
        &patterns.hello,
        &format!("{} hello world {}", text_10000, text_1000),
        100,
        BenchType::Search
    );

    // ===-----------------------------------------------------------------------===
    // Wildcard and Quantifier Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Wildcard and Quantifier Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "wildcard_match_any", &patterns.dot_star, &text_1000, 50, BenchType::IsMatch);
    run_benchmark(&timer, &mut all_results, "quantifier_zero_or_more", &patterns.a_star, &text_1000, 50, BenchType::IsMatch);
    run_benchmark(&timer, &mut all_results, "quantifier_one_or_more", &patterns.a_plus, &text_1000, 50, BenchType::IsMatch);
    run_benchmark(&timer, &mut all_results, "quantifier_zero_or_one", &patterns.a_question, &text_1000, 50, BenchType::IsMatch);

    // ===-----------------------------------------------------------------------===
    // Character Range Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Character Range Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "range_lowercase", &patterns.range_a_z, &text_range_1000, 50, BenchType::IsMatch);
    run_benchmark(&timer, &mut all_results, "range_digits", &patterns.range_0_9, &text_range_1000, 50, BenchType::IsMatch);
    run_benchmark(&timer, &mut all_results, "range_alphanumeric", &patterns.range_alnum, &text_range_1000, 50, BenchType::IsMatch);

    // ===-----------------------------------------------------------------------===
    // Anchor Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Anchor Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "anchor_start", &patterns.anchor_start, &text_1000, 100, BenchType::IsMatch);
    run_benchmark(&timer, &mut all_results, "anchor_end", &patterns.anchor_end, &text_1000, 100, BenchType::IsMatch);

    // ===-----------------------------------------------------------------------===
    // Alternation Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Alternation Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "alternation_simple", &patterns.alt_simple, &text_alternation_1000, 50, BenchType::Search);
    run_benchmark(&timer, &mut all_results, "alternation_words", &patterns.alt_words, &text_alternation_1000, 50, BenchType::Search);

    // ===-----------------------------------------------------------------------===
    // Group Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Group Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "group_quantified", &patterns.group_quantified, &text_group_1000, 50, BenchType::Search);
    run_benchmark(&timer, &mut all_results, "group_alternation", &patterns.group_alternation, &text_group_1000, 50, BenchType::Search);

    // ===-----------------------------------------------------------------------===
    // Global Matching Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Global Matching Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "match_all_simple", &patterns.a, &text_1000, 10, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "match_all_pattern", &patterns.range_a_z, &text_1000, 10, BenchType::FindAll);

    // ===-----------------------------------------------------------------------===
    // Complex Pattern Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Complex Pattern Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "complex_email_extraction", &patterns.email, &email_text, 2, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "complex_number_extraction", &patterns.number, &number_text, 25, BenchType::FindAll);

    // ===-----------------------------------------------------------------------===
    // SIMD-Optimized Character Filtering Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== SIMD-Optimized Character Filtering Benchmarks ===");

    let large_mixed_text = make_mixed_content_text(10000);
    let xlarge_mixed_text = make_mixed_content_text(50000);

    run_benchmark(&timer, &mut all_results, "simd_alphanumeric_large", &patterns.range_alnum, &large_mixed_text, 10, BenchType::IsMatch);
    run_benchmark(&timer, &mut all_results, "simd_alphanumeric_xlarge", &patterns.range_alnum, &xlarge_mixed_text, 10, BenchType::IsMatch);
    run_benchmark(&timer, &mut all_results, "simd_negated_alphanumeric", &patterns.negated_alnum, &large_mixed_text, 10, BenchType::IsMatch);
    run_benchmark(&timer, &mut all_results, "simd_multi_char_class", &patterns.multi_char_class, &large_mixed_text, 10, BenchType::IsMatch);

    // ===-----------------------------------------------------------------------===
    // Literal Optimization Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Literal Optimization Benchmarks ===");

    let medium_text = get_medium_text();
    let long_text = get_long_text();
    let email_long = get_email_long();

    run_benchmark(&timer, &mut all_results, "literal_prefix_short", &patterns.literal_prefix_short, SHORT_TEXT, 1, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "literal_prefix_medium", &patterns.literal_prefix_medium, &medium_text, 1, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "literal_prefix_long", &patterns.literal_prefix_long, &long_text, 1, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "required_literal_short", &patterns.required_literal, EMAIL_TEXT, 1, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "required_literal_long", &patterns.required_literal, &email_long, 1, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "no_literal_baseline", &patterns.range_a_z, &medium_text, 1, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "alternation_common_prefix", &patterns.alt_common_prefix, &medium_text, 1, BenchType::FindAll);

    // ===-----------------------------------------------------------------------===
    // Results Summary
    // ===-----------------------------------------------------------------------===
    println!("\n=== Benchmark Results ===");
    print_results_table(&all_results);

    // Export to JSON
    export_json_results(&all_results)?;

    Ok(())
}

#[derive(Debug)]
enum BenchType {
    IsMatch,
    Search,
    FindAll,
}

struct CompiledPatterns {
    hello: Regex,
    dot_star: Regex,
    a_star: Regex,
    a_plus: Regex,
    a_question: Regex,
    a: Regex,
    range_a_z: Regex,
    range_0_9: Regex,
    range_alnum: Regex,
    negated_alnum: Regex,
    multi_char_class: Regex,
    anchor_start: Regex,
    anchor_end: Regex,
    alt_simple: Regex,
    alt_words: Regex,
    alt_common_prefix: Regex,
    group_quantified: Regex,
    group_alternation: Regex,
    email: Regex,
    number: Regex,
    literal_prefix_short: Regex,
    literal_prefix_medium: Regex,
    literal_prefix_long: Regex,
    required_literal: Regex,
}

fn create_all_patterns() -> Result<CompiledPatterns, Box<dyn std::error::Error>> {
    Ok(CompiledPatterns {
        hello: Regex::new("hello")?,
        dot_star: Regex::new(".*")?,
        a_star: Regex::new("a*")?,
        a_plus: Regex::new("a+")?,
        a_question: Regex::new("a?")?,
        a: Regex::new("a")?,
        range_a_z: Regex::new("[a-z]+")?,
        range_0_9: Regex::new("[0-9]+")?,
        range_alnum: Regex::new("[a-zA-Z0-9]+")?,
        negated_alnum: Regex::new("[^a-zA-Z0-9]+")?,
        multi_char_class: Regex::new("[a-z]+[0-9]+")?,
        anchor_start: Regex::new("^abc")?,
        anchor_end: Regex::new("xyz$")?,
        alt_simple: Regex::new("a|b|c")?,
        alt_words: Regex::new("abc|def|ghi")?,
        alt_common_prefix: Regex::new("(hello|help|helicopter)")?,
        group_quantified: Regex::new("(abc)+")?,
        group_alternation: Regex::new("(a|b)*")?,
        email: Regex::new(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")?,
        number: Regex::new(r"\d+\.?\d*")?,
        literal_prefix_short: Regex::new("hello.*world")?,
        literal_prefix_medium: Regex::new("hello.*")?,
        literal_prefix_long: Regex::new("hello.*")?,
        required_literal: Regex::new(r".*@example\.com")?,
    })
}

fn run_benchmark(
    timer: &BenchmarkTimer,
    results: &mut HashMap<String, BenchmarkResult>,
    name: &str,
    pattern: &Regex,
    text: &str,
    inner_iterations: usize,
    bench_type: BenchType,
) {
    let result = match bench_type {
        BenchType::IsMatch => {
            timer.bench_function(|| {
                for _ in 0..inner_iterations {
                    black_box(pattern.is_match(black_box(text)));
                }
            })
        }
        BenchType::Search => {
            timer.bench_function(|| {
                for _ in 0..inner_iterations {
                    black_box(pattern.find(black_box(text)));
                }
            })
        }
        BenchType::FindAll => {
            timer.bench_function(|| {
                for _ in 0..inner_iterations {
                    let matches: Vec<_> = pattern.find_iter(black_box(text)).collect();
                    black_box(matches.len());
                }
            })
        }
    };

    // Adjust time per operation by dividing by inner iterations
    let adjusted_result = BenchmarkResult {
        time_ns: result.time_ns / inner_iterations as f64,
        time_ms: result.time_ms / inner_iterations as f64,
        iterations: result.iterations * inner_iterations as u64,
    };

    results.insert(name.to_string(), adjusted_result);
    println!("✓ {}", name);
}

fn print_results_table(results: &HashMap<String, BenchmarkResult>) {
    println!("| name                      | met (ms)              | iters  |");
    println!("|---------------------------|-----------------------|--------|");

    let mut sorted_results: Vec<_> = results.iter().collect();
    sorted_results.sort_by_key(|(name, _)| name.as_str());

    for (name, result) in sorted_results {
        println!("| {:<25} | {:>21.17} | {:>6} |",
                 name, result.time_ms, result.iterations);
    }
}

fn export_json_results(results: &HashMap<String, BenchmarkResult>) -> Result<(), Box<dyn std::error::Error>> {
    let benchmark_results = BenchmarkResults {
        engine: "rust".to_string(),
        timestamp: chrono::Utc::now().to_rfc3339(),
        results: results.clone(),
    };

    std::fs::create_dir_all("benchmarks/results")?;

    let json_content = serde_json::to_string_pretty(&benchmark_results)?;
    std::fs::write("benchmarks/results/rust_results.json", json_content)?;

    println!("\n=== BENCHMARK COMPLETE ===");
    println!("Results exported to: benchmarks/results/rust_results.json");

    Ok(())
}
