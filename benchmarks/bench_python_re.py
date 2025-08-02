#!/usr/bin/env python3
"""
Python benchmark script for comparing performance with Python's re module.
This mirrors the benchmarks/bench_engine.mojo file for direct comparison.
"""

import re
import time
from typing import Callable


# ===-----------------------------------------------------------------------===#
# Benchmark Infrastructure
# ===-----------------------------------------------------------------------===#


class Benchmark:
    """Simple benchmark infrastructure to mirror Mojo's benchmark system."""

    def __init__(self, num_repetitions: int = 5):
        self.num_repetitions = num_repetitions
        self.results = {}
        self.iterations = {}

    def bench_function(
        self, name: str, fn: Callable[[], None], warmup_iterations: int = 3
    ):
        """Benchmark a function with warmup and multiple repetitions."""
        # Warmup silently
        for _ in range(warmup_iterations):
            fn()

        # Determine target runtime and calculate iterations
        target_runtime = 100_000_000  # 100ms target

        # Run the actual benchmark
        total_time = 0
        actual_iterations = 0

        while total_time < target_runtime and actual_iterations < 100_000:
            start_time = time.perf_counter_ns()
            fn()
            end_time = time.perf_counter_ns()
            fn_time = end_time - start_time
            # print(f"Function {name} took {fn_time} ns")
            total_time += fn_time
            actual_iterations += 1

        # Calculate mean time per run
        mean_time = total_time / actual_iterations

        # Get internal iteration count for accurate per-operation timing
        iterations_map = {
            "literal_match": 100,
            "wildcard_match": 50,
            "range_": 50,
            "anchor_": 100,
            "alternation_": 50,
            "group_": 50,
            "match_all_": 10,
            "complex_email": 2,
            "complex_number": 25,
            "simd_": 10,
            "literal_prefix_": 1,  # Already optimized in Python's re
            "required_literal_": 1,
            "no_literal_baseline": 1,
            "alternation_common_prefix": 1,
        }

        internal_iterations = 1
        for prefix, iters in iterations_map.items():
            if name.startswith(prefix):
                internal_iterations = iters
                break

        # Store results
        self.results[name] = mean_time / internal_iterations
        self.iterations[name] = actual_iterations * internal_iterations

    def dump_report(self):
        """Print summary report of all benchmarks in Mojo format."""
        print("\n=== Benchmark Results ===")
        print("| name                      | met (ms)              | iters  |")
        print("|---------------------------|-----------------------|--------|")

        for name in self.results:
            # Format time in milliseconds with proper precision
            time_ms = self.results[name] / 1_000_000
            iters = self.iterations[name]

            # Right-align values to match Mojo format
            print(f"| {name:<25} | {time_ms:>21.17f} | {iters:>6} |")


# ===-----------------------------------------------------------------------===#
# Benchmark Data Generation
# ===-----------------------------------------------------------------------===#

# Literal optimization test texts
SHORT_TEXT = "hello world this is a test with hello again and hello there"
MEDIUM_TEXT = SHORT_TEXT * 10
LONG_TEXT = SHORT_TEXT * 100
EMAIL_TEXT = "test@example.com user@test.org admin@example.com support@example.com no-reply@example.com"
EMAIL_LONG = EMAIL_TEXT * 5


def make_test_string(length: int, pattern: str = "abcdefghijklmnopqrstuvwxyz") -> str:
    """Generate a test string of specified length by repeating a pattern."""
    if length <= 0:
        return ""

    pattern_len = len(pattern)
    full_repeats = length // pattern_len
    remainder = length % pattern_len

    result = pattern * full_repeats + pattern[:remainder]
    return result


# ===-----------------------------------------------------------------------===#
# Basic Literal Matching Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_literal_match(test_text: str, pattern: str) -> Callable[[], None]:
    """Benchmark literal string matching."""

    def benchmark_fn():
        for _ in range(100):
            result = re.search(pattern, test_text)
            # Keep result to prevent optimization
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Wildcard and Quantifier Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_wildcard_match(test_text: str, pattern: str) -> Callable[[], None]:
    """Benchmark wildcard and quantifier patterns."""

    def benchmark_fn():
        for _ in range(50):
            result = re.match(pattern, test_text)
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Character Range Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_range_match(test_text: str, pattern: str) -> Callable[[], None]:
    """Benchmark character range patterns."""

    def benchmark_fn():
        for _ in range(50):
            result = re.match(pattern, test_text)
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Anchor Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_anchor_match(test_text: str, pattern: str) -> Callable[[], None]:
    """Benchmark anchor patterns (^ and $)."""

    def benchmark_fn():
        for _ in range(100):
            result = re.match(pattern, test_text)
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Alternation (OR) Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_alternation_match(test_text: str, pattern: str) -> Callable[[], None]:
    """Benchmark alternation patterns (|)."""

    def benchmark_fn():
        for _ in range(50):
            result = re.search(pattern, test_text)
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Group Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_group_match(test_text: str, pattern: str) -> Callable[[], None]:
    """Benchmark group patterns with quantifiers."""

    def benchmark_fn():
        for _ in range(50):
            result = re.search(pattern, test_text)
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Match All Benchmarks (Global Matching)
# ===-----------------------------------------------------------------------===#


def bench_match_all(test_text: str, pattern: str) -> Callable[[], None]:
    """Benchmark finding all matches in text."""

    def benchmark_fn():
        for _ in range(10):  # Fewer iterations since findall is more expensive
            results = re.findall(pattern, test_text)
            len(results)  # Keep result

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Complex Pattern Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_complex_email_match(email_text: str) -> Callable[[], None]:
    """Benchmark complex email validation pattern."""
    pattern = r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"

    def benchmark_fn():
        for _ in range(2):
            results = re.findall(pattern, email_text)
            len(results)

    return benchmark_fn


def bench_complex_number_extraction(number_text: str) -> Callable[[], None]:
    """Benchmark extracting numbers from text."""
    pattern = r"\d+\.?\d*"

    def benchmark_fn():
        for _ in range(25):
            results = re.findall(pattern, number_text)
            len(results)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# SIMD-Heavy Character Filtering Benchmarks
# ===-----------------------------------------------------------------------===#


def make_mixed_content_text(length: int) -> str:
    """Generate large mixed content text optimal for SIMD character class testing.

    Args:
        length: The desired length of the test string.

    Returns:
        String with mixed alphanumeric, punctuation, and whitespace content.
    """
    if length <= 0:
        return ""

    # Pattern that creates realistic mixed content with plenty of alphanumeric sequences
    base_pattern = "User123 sent email to user456@domain.com with ID abc789! Status: ACTIVE_2024 (priority=HIGH). "
    pattern_len = len(base_pattern)
    full_repeats = length // pattern_len
    remainder = length % pattern_len

    result = base_pattern * full_repeats + base_pattern[:remainder]
    return result


def bench_simd_heavy_filtering(test_text: str, pattern: str) -> Callable[[], None]:
    """Benchmark SIMD-optimized character class filtering on large mixed content.

    This benchmark is designed to show maximum SIMD performance benefits by:
    - Using character classes that benefit from SIMD lookup tables
    - Processing large amounts of text to amortize SIMD setup costs
    - Using realistic mixed content with alphanumeric sequences
    """

    def benchmark_fn():
        for _ in range(10):  # Fewer iterations due to large text size
            result = re.match(pattern, test_text)
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Literal Optimization Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_literal_optimization(
    test_text: str, pattern: str, iterations: int
) -> Callable[[], None]:
    """Benchmark literal optimization patterns."""

    def benchmark_fn():
        for _ in range(iterations):
            results = re.findall(pattern, test_text)
            len(results)  # Keep result

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Benchmark Main
# ===-----------------------------------------------------------------------===#


def main():
    """Run all benchmarks and display results."""
    m = Benchmark(num_repetitions=5)

    # Pre-create test strings to avoid measurement overhead
    text_1000 = make_test_string(1000)
    text_10000 = make_test_string(10000)
    text_range_1000 = make_test_string(1000, "abc123XYZ")
    text_alternation_1000 = make_test_string(1000, "abcdefghijklmnopqrstuvwxyz")
    text_group_1000 = make_test_string(1000, "abcabcabc")

    # Create complex text patterns
    base_text = make_test_string(100)
    emails = " user@example.com more text john@test.org "
    email_text = f"{base_text} {emails} {base_text} {emails} {base_text}"

    base_number_text = make_test_string(500, "abc def ghi ")
    number_text = (
        f"{base_number_text} 123 price $456.78 quantity 789 {base_number_text}"
    )

    # Basic literal matching
    m.bench_function(
        "literal_match_short",
        bench_literal_match(
            text_1000 + " hello world" + text_1000,  # Ensure "hello" is present
            "hello",
        ),
    )
    m.bench_function(
        "literal_match_long",
        bench_literal_match(
            text_10000 + " hello world" + text_1000,  # Ensure "hello" is present
            "hello",
        ),
    )

    # Wildcard and quantifiers
    m.bench_function("wildcard_match_any", bench_wildcard_match(text_1000, ".*"))
    m.bench_function("quantifier_zero_or_more", bench_wildcard_match(text_1000, "a*"))
    m.bench_function("quantifier_one_or_more", bench_wildcard_match(text_1000, "a+"))
    m.bench_function("quantifier_zero_or_one", bench_wildcard_match(text_1000, "a?"))

    # Character ranges
    m.bench_function("range_lowercase", bench_range_match(text_range_1000, "[a-z]+"))
    m.bench_function("range_digits", bench_range_match(text_range_1000, "[0-9]+"))
    m.bench_function(
        "range_alphanumeric", bench_range_match(text_range_1000, "[a-zA-Z0-9]+")
    )

    # Anchors
    m.bench_function("anchor_start", bench_anchor_match(text_1000, "^abc"))
    m.bench_function("anchor_end", bench_anchor_match(text_1000, "xyz$"))

    # Alternation
    m.bench_function(
        "alternation_simple", bench_alternation_match(text_alternation_1000, "a|b|c")
    )
    m.bench_function(
        "alternation_words",
        bench_alternation_match(text_alternation_1000, "abc|def|ghi"),
    )

    # Groups
    m.bench_function("group_quantified", bench_group_match(text_group_1000, "(abc)+"))
    m.bench_function("group_alternation", bench_group_match(text_group_1000, "(a|b)*"))

    # Global matching (unique to our implementation)
    m.bench_function("match_all_simple", bench_match_all(text_1000, "a"))
    m.bench_function("match_all_pattern", bench_match_all(text_1000, "[a-z]+"))

    # Complex real-world patterns
    m.bench_function("complex_email_extraction", bench_complex_email_match(email_text))
    m.bench_function(
        "complex_number_extraction", bench_complex_number_extraction(number_text)
    )

    # SIMD-Heavy Character Filtering (designed to show maximum SIMD benefit in Mojo comparison)
    large_mixed_text = make_mixed_content_text(10000)
    xlarge_mixed_text = make_mixed_content_text(50000)

    m.bench_function(
        "simd_alphanumeric_large",
        bench_simd_heavy_filtering(large_mixed_text, r"[a-zA-Z0-9]+"),
    )
    m.bench_function(
        "simd_alphanumeric_xlarge",
        bench_simd_heavy_filtering(xlarge_mixed_text, r"[a-zA-Z0-9]+"),
    )
    m.bench_function(
        "simd_negated_alphanumeric",
        bench_simd_heavy_filtering(large_mixed_text, r"[^a-zA-Z0-9]+"),
    )
    m.bench_function(
        "simd_multi_char_class",
        bench_simd_heavy_filtering(large_mixed_text, r"[a-z]+[0-9]+"),
    )

    # Literal Optimization Benchmarks
    m.bench_function(
        "literal_prefix_short",
        bench_literal_optimization(SHORT_TEXT, r"hello.*world", 1),
    )
    m.bench_function(
        "literal_prefix_medium", bench_literal_optimization(MEDIUM_TEXT, r"hello.*", 1)
    )
    m.bench_function(
        "literal_prefix_long", bench_literal_optimization(LONG_TEXT, r"hello.*", 1)
    )
    m.bench_function(
        "required_literal_short",
        bench_literal_optimization(EMAIL_TEXT, r".*@example\.com", 1),
    )
    m.bench_function(
        "required_literal_long",
        bench_literal_optimization(EMAIL_LONG, r".*@example\.com", 1),
    )
    m.bench_function(
        "no_literal_baseline", bench_literal_optimization(MEDIUM_TEXT, r"[a-z]+", 1)
    )
    m.bench_function(
        "alternation_common_prefix",
        bench_literal_optimization(MEDIUM_TEXT, r"(hello|help|helicopter)", 1),
    )

    # Results summary
    m.dump_report()


if __name__ == "__main__":
    main()
