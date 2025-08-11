from time import perf_counter_ns
from regex import match_first, findall, search


# ===-----------------------------------------------------------------------===#
# Test Data Generation
# ===-----------------------------------------------------------------------===#


fn make_test_string(length: Int) -> String:
    """Generate test string by repeating alphabet."""
    var result = String()
    var pattern = "abcdefghijklmnopqrstuvwxyz"
    var pattern_len = len(pattern)
    var full_repeats = length // pattern_len
    var remainder = length % pattern_len

    for _ in range(full_repeats):
        result += pattern
    for i in range(remainder):
        result += pattern[i]
    return result


# ===-----------------------------------------------------------------------===#
# Manual Benchmark Infrastructure
# ===-----------------------------------------------------------------------===#


fn benchmark_match_first(
    name: String, pattern: String, text: String, internal_iterations: Int
) raises:
    """Benchmark match_first with manual timing."""

    # Warmup (3 iterations like Python)
    for _ in range(3):
        _ = match_first(pattern, text)

    # Target runtime: 100ms like Python
    var target_runtime = 100_000_000  # 100ms in nanoseconds
    var total_time: Int = 0
    var actual_iterations = 0

    # Run until we hit target runtime or max iterations
    while total_time < target_runtime and actual_iterations < 100_000:
        var start_time = perf_counter_ns()

        # Internal loop matches Python benchmark structure
        for _ in range(internal_iterations):
            var result = match_first(pattern, text)
            if not result:
                print("ERROR: No match in", name, "for pattern:", pattern)
                return

        var end_time = perf_counter_ns()
        total_time += end_time - start_time
        actual_iterations += 1

    # Calculate and print results
    var mean_time_per_match = (
        Float64(total_time)
        / Float64(actual_iterations)
        / Float64(internal_iterations)
    )
    var time_ms = mean_time_per_match / 1_000_000.0
    var total_matches = actual_iterations * internal_iterations

    # Format output to match Mojo's benchmark format
    var padded_name = name + " " * (25 - len(name))
    print(
        "| "
        + padded_name
        + " | "
        + String(time_ms)[:20]
        + " " * (21 - len(String(time_ms)[:20]))
        + " | "
        + String(total_matches)
        + " " * (6 - len(String(total_matches)))
        + " |"
    )


fn benchmark_search(
    name: String, pattern: String, text: String, internal_iterations: Int
) raises:
    """Benchmark search (match_next) with manual timing."""

    # Warmup (3 iterations like Python)
    for _ in range(3):
        _ = search(pattern, text)

    # Target runtime: 100ms like Python
    var target_runtime = 100_000_000  # 100ms in nanoseconds
    var total_time: Int = 0
    var actual_iterations = 0

    # Run until we hit target runtime or max iterations
    while total_time < target_runtime and actual_iterations < 100_000:
        var start_time = perf_counter_ns()

        # Internal loop matches Python benchmark structure
        for _ in range(internal_iterations):
            var result = search(pattern, text)
            if not result:
                print(
                    "ERROR: No search match in", name, "for pattern:", pattern
                )
                return

        var end_time = perf_counter_ns()
        total_time += end_time - start_time
        actual_iterations += 1

    # Calculate and print results
    var mean_time_per_match = (
        Float64(total_time)
        / Float64(actual_iterations)
        / Float64(internal_iterations)
    )
    var time_ms = mean_time_per_match / 1_000_000.0
    var total_matches = actual_iterations * internal_iterations

    # Format output to match Mojo's benchmark format
    var padded_name = name + " " * (25 - len(name))
    print(
        "| "
        + padded_name
        + " | "
        + String(time_ms)[:20]
        + " " * (21 - len(String(time_ms)[:20]))
        + " | "
        + String(total_matches)
        + " " * (6 - len(String(total_matches)))
        + " |"
    )


fn benchmark_findall(
    name: String, pattern: String, text: String, internal_iterations: Int
) raises:
    """Benchmark findall with manual timing."""

    # Warmup
    for _ in range(3):
        _ = findall(pattern, text)

    var target_runtime = 100_000_000
    var total_time: Int = 0
    var actual_iterations = 0

    while total_time < target_runtime and actual_iterations < 100_000:
        var start_time = perf_counter_ns()

        for _ in range(internal_iterations):
            var results = findall(pattern, text)
            # Touch the result to ensure it's not optimized away
            if len(results) < 0:  # Always false, but compiler doesn't know
                print("ERROR: Unexpected result")

        var end_time = perf_counter_ns()
        total_time += end_time - start_time
        actual_iterations += 1

    # Calculate and print results
    var mean_time_per_match = (
        Float64(total_time)
        / Float64(actual_iterations)
        / Float64(internal_iterations)
    )
    var time_ms = mean_time_per_match / 1_000_000.0
    var total_matches = actual_iterations * internal_iterations

    var padded_name = name + " " * (25 - len(name))
    print(
        "| "
        + padded_name
        + " | "
        + String(time_ms)[:20]
        + " " * (21 - len(String(time_ms)[:20]))
        + " | "
        + String(total_matches)
        + " " * (6 - len(String(total_matches)))
        + " |"
    )


fn detect_and_report_engine(pattern: String, test_name: String):
    """Simple pattern reporting."""
    print("# Testing pattern:", pattern)


# ===-----------------------------------------------------------------------===#
# Main Benchmark Runner
# ===-----------------------------------------------------------------------===#


fn main() raises:
    """Run all regex benchmarks with manual timing."""
    print("=== REGEX ENGINE BENCHMARKS (Manual Timing) ===")
    print("Using Python-compatible time.perf_counter_ns() for fair comparison")
    print()

    # Prepare test data - same as original benchmarks
    var text_1000 = make_test_string(1000)
    var text_5000 = make_test_string(5000)
    var text_10000 = make_test_string(10000)
    var text_range_10000 = make_test_string(10000) + "0123456789"

    # Add hello to texts to ensure literal matches
    text_1000 += "hello world"
    text_5000 += "hello world"
    text_10000 += "hello world"

    # Test data for optimization benchmarks
    var short_text = (
        "hello world this is a test with hello again and hello there"
    )
    var medium_text = short_text * 100
    var long_text = short_text * 1000
    var email_text = (
        "test@example.com user@test.org admin@example.com support@example.com"
        " no-reply@example.com"
        * 50
    )

    print("| name                      | met (ms)              | iters  |")
    print("|---------------------------|-----------------------|--------|")

    # ===== Literal Matching Benchmarks =====
    print("# Literal Matching")
    detect_and_report_engine("hello", "literal_match_short")
    benchmark_search("literal_match_short", "hello", text_1000, 2000)

    detect_and_report_engine("hello", "literal_match_long")
    benchmark_search("literal_match_long", "hello", text_10000, 2000)

    # ===== Wildcard and Quantifier Benchmarks =====
    print("# Wildcard and Quantifiers")
    detect_and_report_engine(".*", "wildcard_match_any")
    benchmark_match_first("wildcard_match_any", ".*", text_10000, 1000)

    detect_and_report_engine("a*", "quantifier_zero_or_more")
    benchmark_match_first("quantifier_zero_or_more", "a*", text_10000, 1000)

    detect_and_report_engine("a+", "quantifier_one_or_more")
    benchmark_match_first("quantifier_one_or_more", "a+", text_10000, 1000)

    detect_and_report_engine("a?", "quantifier_zero_or_one")
    benchmark_match_first("quantifier_zero_or_one", "a?", text_10000, 1000)

    # ===== Character Range Benchmarks =====
    print("# Character Ranges")
    detect_and_report_engine("[a-z]+", "range_lowercase")
    benchmark_match_first("range_lowercase", "[a-z]+", text_range_10000, 1000)

    detect_and_report_engine("[0-9]+", "range_digits")
    benchmark_search("range_digits", "[0-9]+", text_range_10000, 1000)

    detect_and_report_engine("[a-zA-Z0-9]+", "range_alphanumeric")
    benchmark_match_first(
        "range_alphanumeric", "[a-zA-Z0-9]+", text_range_10000, 1000
    )

    # ===== Anchor Benchmarks =====
    print("# Anchors")
    detect_and_report_engine("^abc", "anchor_start")
    benchmark_match_first("anchor_start", "^abc", text_10000, 2000)

    detect_and_report_engine("xyz$", "anchor_end")
    benchmark_match_first("anchor_end", "xyz$", text_10000, 2000)

    # ===== Alternation Benchmarks =====
    print("# Alternations")
    detect_and_report_engine("a|b|c", "alternation_simple")
    benchmark_match_first("alternation_simple", "a|b|c", text_10000, 1000)

    detect_and_report_engine("(a|b)", "group_alternation")
    benchmark_match_first("group_alternation", "(a|b)", text_10000, 1000)

    # ===== Global Matching (findall) =====
    print("# Global Matching")
    benchmark_findall("match_all_simple", "hello", medium_text, 200)
    benchmark_findall("match_all_digits", "[0-9]+", text_range_10000 * 10, 200)

    # ===== Literal Optimization Benchmarks =====
    print("# Literal Optimizations")
    benchmark_findall("literal_prefix_short", "hello.*", short_text, 1)
    benchmark_findall("literal_prefix_long", "hello.*", long_text, 1)
    benchmark_findall(
        "required_literal_short", ".*@example\\.com", email_text, 1
    )
    benchmark_match_first("no_literal_baseline", "[a-z]+", medium_text, 1)
    benchmark_match_first(
        "alternation_common_prefix", "(hello|help|helicopter)", medium_text, 1
    )

    # ===== Complex Pattern Benchmarks =====
    print("# Complex Patterns")
    var complex_email_text = (
        "Contact: john@example.com, support@test.org, admin@company.net" * 20
    )
    detect_and_report_engine(
        "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", "complex_email"
    )
    benchmark_findall(
        "complex_email",
        "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
        complex_email_text,
        40,
    )

    var complex_number_text = (
        "Price: $123.45, Quantity: 67, Total: $890.12, Tax: 15.5%" * 100
    )
    detect_and_report_engine("[0-9]+\\.[0-9]+", "complex_number")
    benchmark_findall(
        "complex_number", "[0-9]+\\.[0-9]+", complex_number_text, 500
    )

    print()
    print("=== Manual Timing Benchmark Complete ===")
    print("Results are directly comparable with Python benchmarks")
