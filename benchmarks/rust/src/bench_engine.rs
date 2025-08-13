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

    // Pre-create test strings to avoid measurement overhead - scaled up to match Mojo benchmarks
    let text_10000 = make_test_string(10000, "abcdefghijklmnopqrstuvwxyz");     // Increased from 1000 to 10000
    let text_100000 = make_test_string(100000, "abcdefghijklmnopqrstuvwxyz");   // Increased from 10000 to 100000
    let text_range_10000 = make_test_string(10000, "abc123XYZ");
    let text_alternation_10000 = make_test_string(10000, "abcdefghijklmnopqrstuvwxyz");
    let text_group_10000 = make_test_string(10000, "abcabcabc");

    // Create complex text patterns - scaled up to match Mojo benchmarks
    let base_text = make_test_string(2000, "abcdefghijklmnopqrstuvwxyz");  // Increased from 100 to 2000
    let emails = " user@example.com more text john@test.org ";
    let email_text = format!("{} {} {} {} {}", base_text, emails, base_text, emails, base_text);

    let base_number_text = make_test_string(20000, "abc def ghi ");  // Increased from 500 to 20000
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
        &format!("{} hello world {}", text_10000, text_10000),  // Updated variable names
        2000,  // Increased from 100 to 2000
        BenchType::Search
    );

    run_benchmark(
        &timer,
        &mut all_results,
        "literal_match_long",
        &patterns.hello,
        &format!("{} hello world {}", text_100000, text_10000),  // Updated variable names
        2000,  // Increased from 100 to 2000
        BenchType::Search
    );

    // ===-----------------------------------------------------------------------===
    // Wildcard and Quantifier Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Wildcard and Quantifier Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "wildcard_match_any", &patterns.dot_star, &text_10000, 1000, BenchType::IsMatch);  // Updated text size and iterations (50->1000)
    run_benchmark(&timer, &mut all_results, "quantifier_zero_or_more", &patterns.a_star, &text_10000, 1000, BenchType::IsMatch);  // Updated text size and iterations (50->1000)
    run_benchmark(&timer, &mut all_results, "quantifier_one_or_more", &patterns.a_plus, &text_10000, 1000, BenchType::IsMatch);  // Updated text size and iterations (50->1000)
    run_benchmark(&timer, &mut all_results, "quantifier_zero_or_one", &patterns.a_question, &text_10000, 1000, BenchType::IsMatch);  // Updated text size and iterations (50->1000)

    // ===-----------------------------------------------------------------------===
    // Character Range Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Character Range Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "range_lowercase", &patterns.range_a_z, &text_range_10000, 1000, BenchType::IsMatch);  // Updated text size and iterations (50->1000)
    run_benchmark(&timer, &mut all_results, "range_digits", &patterns.range_0_9, &text_range_10000, 1000, BenchType::IsMatch);  // Updated text size and iterations (50->1000)
    run_benchmark(&timer, &mut all_results, "range_alphanumeric", &patterns.range_alnum, &text_range_10000, 1000, BenchType::IsMatch);  // Updated text size and iterations (50->1000)

    // ===-----------------------------------------------------------------------===
    // Anchor Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Anchor Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "anchor_start", &patterns.anchor_start, &text_10000, 2000, BenchType::IsMatch);  // Updated text size and iterations (100->2000)
    run_benchmark(&timer, &mut all_results, "anchor_end", &patterns.anchor_end, &text_10000, 2000, BenchType::IsMatch);  // Updated text size and iterations (100->2000)

    // ===-----------------------------------------------------------------------===
    // Alternation Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Alternation Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "alternation_simple", &patterns.alt_simple, &text_alternation_10000, 1000, BenchType::Search);  // Updated text size and iterations (50->1000)
    run_benchmark(&timer, &mut all_results, "alternation_words", &patterns.alt_words, &text_alternation_10000, 1000, BenchType::Search);  // Updated text size and iterations (50->1000)

    // ===-----------------------------------------------------------------------===
    // Group Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Group Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "group_quantified", &patterns.group_quantified, &text_group_10000, 1000, BenchType::Search);  // Updated text size and iterations (50->1000)
    run_benchmark(&timer, &mut all_results, "group_alternation", &patterns.group_alternation, &text_group_10000, 1000, BenchType::Search);  // Updated text size and iterations (50->1000)

    // ===-----------------------------------------------------------------------===
    // Global Matching Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Global Matching Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "match_all_simple", &patterns.a, &text_10000, 200, BenchType::FindAll);  // Updated text size and iterations (10->200)
    run_benchmark(&timer, &mut all_results, "match_all_pattern", &patterns.range_a_z, &text_10000, 200, BenchType::FindAll);  // Updated text size and iterations (10->200)

    // ===-----------------------------------------------------------------------===
    // Complex Pattern Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== Complex Pattern Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "complex_email_extraction", &patterns.email, &email_text, 40, BenchType::FindAll);  // Increased from 2 to 40
    run_benchmark(&timer, &mut all_results, "complex_number_extraction", &patterns.number, &number_text, 500, BenchType::FindAll);  // Increased from 25 to 500

    // ===-----------------------------------------------------------------------===
    // SIMD-Optimized Character Filtering Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== SIMD-Optimized Character Filtering Benchmarks ===");

    let large_mixed_text = make_mixed_content_text(100000);  // Increased from 10000 to 100000
    let xlarge_mixed_text = make_mixed_content_text(500000);  // Increased from 50000 to 500000

    run_benchmark(&timer, &mut all_results, "simd_alphanumeric_large", &patterns.range_alnum, &large_mixed_text, 200, BenchType::IsMatch);  // Increased from 10 to 200
    run_benchmark(&timer, &mut all_results, "simd_alphanumeric_xlarge", &patterns.range_alnum, &xlarge_mixed_text, 200, BenchType::IsMatch);  // Increased from 10 to 200
    run_benchmark(&timer, &mut all_results, "simd_negated_alphanumeric", &patterns.negated_alnum, &large_mixed_text, 200, BenchType::IsMatch);  // Increased from 10 to 200
    run_benchmark(&timer, &mut all_results, "simd_multi_char_class", &patterns.multi_char_class, &large_mixed_text, 200, BenchType::IsMatch);  // Increased from 10 to 200

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
    // US Phone Number Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== US Phone Number Benchmarks ===");

    let phone_text = make_phone_test_data(1000);

    run_benchmark(&timer, &mut all_results, "simple_phone", &patterns.simple_phone, &phone_text, 100, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "flexible_phone", &patterns.flexible_phone, &phone_text, 100, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "multi_format_phone", &patterns.multi_format_phone, &phone_text, 50, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "phone_validation", &patterns.phone_validation, "555-123-4567", 500, BenchType::IsMatch);

    // ===-----------------------------------------------------------------------===
    // DFA-Optimized Phone Number Benchmarks
    // ===-----------------------------------------------------------------------===
    println!("=== DFA-Optimized Phone Number Benchmarks ===");

    run_benchmark(&timer, &mut all_results, "dfa_simple_phone", &patterns.dfa_simple_phone, &phone_text, 100, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "dfa_paren_phone", &patterns.dfa_paren_phone, &phone_text, 100, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "dfa_dot_phone", &patterns.dfa_dot_phone, &phone_text, 100, BenchType::FindAll);
    run_benchmark(&timer, &mut all_results, "dfa_digits_only", &patterns.dfa_digits_only, &phone_text, 100, BenchType::FindAll);

    // National Phone Number Validation (Complex Pattern)
    let national_phone_text = make_complex_pattern_test_data(500);
    run_benchmark(&timer, &mut all_results, "national_phone_validation", &patterns.national_phone_validation, &national_phone_text, 10, BenchType::FindAll);

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
    simple_phone: Regex,
    flexible_phone: Regex,
    multi_format_phone: Regex,
    phone_validation: Regex,
    dfa_simple_phone: Regex,
    dfa_paren_phone: Regex,
    dfa_dot_phone: Regex,
    dfa_digits_only: Regex,
    national_phone_validation: Regex,
}

fn make_phone_test_data(num_phones: usize) -> String {
    let phone_patterns = [
        "555-123-4567",
        "(555) 123-4567",
        "555.123.4567",
        "5551234567",
        "+1-555-123-4567",
        "1-555-123-4568",
        "(555)123-4569",
        "555 123 4570"
    ];
    let filler_text = " Contact us at ";
    let extra_text = " or email support@company.com for assistance. ";

    let mut result = String::new();
    for i in 0..num_phones {
        result.push_str(filler_text);
        let pattern_idx = i % phone_patterns.len();
        result.push_str(phone_patterns[pattern_idx]);
        result.push_str(extra_text);
    }

    result
}

fn make_complex_pattern_test_data(num_entries: usize) -> String {
    // Generate test data for US national phone number validation
    let complex_patterns = [
        "96906001234",      // Matches first alternation
        "969060012",        // Matches first alternation
        "969000012345",     // Matches second alternation
        "973001234",        // Matches second alternation
        "81234567890",      // Matches third alternation
        "91234567890",      // Matches third alternation
        "8356123456789",    // Matches third alternation
        "9268012345678",    // Matches third alternation
        "1234567890",       // Should NOT match
        "96906",            // Should NOT match (too short)
    ];
    let filler_text = " ID: ";
    let extra_text = " Status: ACTIVE ";

    let mut result = String::new();
    for i in 0..num_entries {
        result.push_str(filler_text);
        let pattern_idx = i % complex_patterns.len();
        result.push_str(complex_patterns[pattern_idx]);
        result.push_str(extra_text);
    }

    result
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
        simple_phone: Regex::new(r"\d{3}-\d{3}-\d{4}")?,
        flexible_phone: Regex::new(r"\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}")?,
        multi_format_phone: Regex::new(r"\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}|\d{3}-\d{3}-\d{4}|\d{10}")?,
        phone_validation: Regex::new(r"^\+?1?[\s.-]?\(?([2-9]\d{2})\)?[\s.-]?([2-9]\d{2})[\s.-]?(\d{4})$")?,
        dfa_simple_phone: Regex::new(r"[0-9]{3}-[0-9]{3}-[0-9]{4}")?,
        dfa_paren_phone: Regex::new(r"\([0-9]{3}\) [0-9]{3}-[0-9]{4}")?,
        dfa_dot_phone: Regex::new(r"[0-9]{3}\.[0-9]{3}\.[0-9]{4}")?,
        dfa_digits_only: Regex::new(r"[0-9]{10}")?,
        national_phone_validation: Regex::new(r"96906(?:0[0-8]|1[1-9]|[2-9]\d)\d\d|9(?:69(?:0[0-57-9]|[1-9]\d)|73(?:[0-8]\d|9[1-9]))\d{4}|(?:8(?:[1356]\d|[28][0-8]|[47][1-9])|9(?:[135]\d|[268][0-8]|4[1-9]|7[124-9]))\d{6}")?,
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

    std::fs::create_dir_all("../results")?;

    let json_content = serde_json::to_string_pretty(&benchmark_results)?;
    std::fs::write("../results/rust_results.json", json_content)?;

    println!("\n=== BENCHMARK COMPLETE ===");
    println!("Results exported to: ../results/rust_results.json");

    Ok(())
}
