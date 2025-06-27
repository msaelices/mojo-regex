#!/usr/bin/env python3
"""
Python benchmark script for comparing performance with Python's re module.
This mirrors the benchmarks/bench_engine.mojo file for direct comparison.
"""

import re
import time
import statistics
from typing import Callable


# ===-----------------------------------------------------------------------===#
# Benchmark Infrastructure
# ===-----------------------------------------------------------------------===#


class Benchmark:
    """Simple benchmark infrastructure to mirror Mojo's benchmark system."""

    def __init__(self, num_repetitions: int = 5):
        self.num_repetitions = num_repetitions
        self.results = {}

    def bench_function(
        self, name: str, fn: Callable[[], None], warmup_iterations: int = 3
    ):
        """Benchmark a function with warmup and multiple repetitions."""
        print(f"Benchmarking: {name}")

        # Warmup
        for _ in range(warmup_iterations):
            fn()

        # Actual benchmarking
        times = []
        for _ in range(self.num_repetitions):
            start_time = time.perf_counter()
            fn()
            end_time = time.perf_counter()
            times.append(end_time - start_time)

        # Calculate statistics
        mean_time = statistics.mean(times)
        min_time = min(times)
        max_time = max(times)

        self.results[name] = {
            "mean": mean_time,
            "min": min_time,
            "max": max_time,
            "times": times,
        }

        print(
            f"  Mean: {mean_time * 1000:.3f}ms, Min: {min_time * 1000:.3f}ms, Max: {max_time * 1000:.3f}ms"
        )

    def dump_report(self):
        """Print summary report of all benchmarks."""
        print("\n" + "=" * 60)
        print("BENCHMARK SUMMARY REPORT")
        print("=" * 60)
        for name, stats in self.results.items():
            print(
                f"{name:30} | {stats['mean'] * 1000:8.3f}ms ± {statistics.stdev(stats['times']) * 1000:6.3f}ms"
            )


# ===-----------------------------------------------------------------------===#
# Benchmark Data Generation
# ===-----------------------------------------------------------------------===#


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


def bench_literal_match(text_length: int, pattern: str) -> Callable[[], None]:
    """Benchmark literal string matching."""
    test_text = make_test_string(text_length)
    compiled_pattern = re.compile(pattern)

    def benchmark_fn():
        for _ in range(100):
            result = compiled_pattern.search(test_text)
            # Keep result to prevent optimization
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Wildcard and Quantifier Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_wildcard_match(text_length: int, pattern: str) -> Callable[[], None]:
    """Benchmark wildcard and quantifier patterns."""
    test_text = make_test_string(text_length)
    compiled_pattern = re.compile(pattern)

    def benchmark_fn():
        for _ in range(50):
            result = compiled_pattern.search(test_text)
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Character Range Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_range_match(text_length: int, pattern: str) -> Callable[[], None]:
    """Benchmark character range patterns."""
    test_text = make_test_string(text_length, "abc123XYZ")
    compiled_pattern = re.compile(pattern)

    def benchmark_fn():
        for _ in range(50):
            result = compiled_pattern.search(test_text)
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Anchor Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_anchor_match(text_length: int, pattern: str) -> Callable[[], None]:
    """Benchmark anchor patterns (^ and $)."""
    test_text = make_test_string(text_length)
    compiled_pattern = re.compile(pattern)

    def benchmark_fn():
        for _ in range(100):
            result = compiled_pattern.search(test_text)
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Alternation (OR) Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_alternation_match(text_length: int, pattern: str) -> Callable[[], None]:
    """Benchmark alternation patterns (|)."""
    test_text = make_test_string(text_length, "abcdefghijklmnopqrstuvwxyz")
    compiled_pattern = re.compile(pattern)

    def benchmark_fn():
        for _ in range(50):
            result = compiled_pattern.search(test_text)
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Group Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_group_match(text_length: int, pattern: str) -> Callable[[], None]:
    """Benchmark group patterns with quantifiers."""
    test_text = make_test_string(text_length, "abcabcabc")
    compiled_pattern = re.compile(pattern)

    def benchmark_fn():
        for _ in range(50):
            result = compiled_pattern.search(test_text)
            bool(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Match All Benchmarks (Global Matching)
# ===-----------------------------------------------------------------------===#


def bench_match_all(text_length: int, pattern: str) -> Callable[[], None]:
    """Benchmark finding all matches in text."""
    test_text = make_test_string(text_length)
    compiled_pattern = re.compile(pattern)

    def benchmark_fn():
        for _ in range(10):  # Fewer iterations since findall is more expensive
            results = compiled_pattern.findall(test_text)
            len(results)  # Keep result

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Complex Pattern Benchmarks
# ===-----------------------------------------------------------------------===#


def bench_complex_email_match(text_length: int) -> Callable[[], None]:
    """Benchmark complex email validation pattern."""
    # Create text with embedded emails
    base_text = make_test_string(text_length // 2)
    email_text = f"{base_text} user@example.com more text john@test.org {base_text}"
    pattern = re.compile(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")

    def benchmark_fn():
        for _ in range(25):
            results = pattern.findall(email_text)
            len(results)

    return benchmark_fn


def bench_complex_number_extraction(text_length: int) -> Callable[[], None]:
    """Benchmark extracting numbers from text."""
    # Create text with embedded numbers
    base_text = make_test_string(text_length // 2, "abc def ghi ")
    number_text = f"{base_text} 123 price $456.78 quantity 789 {base_text}"
    pattern = re.compile(r"\d+\.?\d*")

    def benchmark_fn():
        for _ in range(25):
            results = pattern.findall(number_text)
            len(results)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Benchmark Main
# ===-----------------------------------------------------------------------===#


def main():
    """Run all benchmarks and display results."""
    print("Python RE Module Benchmark Suite")
    print("=" * 50)
    print(f"Python version: {re.__doc__}")
    print("Using compiled patterns for optimal performance")
    print()

    m = Benchmark(num_repetitions=5)

    # Basic literal matching
    print("=== Literal Matching Benchmarks ===")
    m.bench_function("literal_match_short", bench_literal_match(1000, "hello"))
    m.bench_function("literal_match_long", bench_literal_match(10000, "hello"))

    # Wildcard and quantifiers
    print("\n=== Wildcard and Quantifier Benchmarks ===")
    m.bench_function("wildcard_match_any", bench_wildcard_match(1000, ".*"))
    m.bench_function("quantifier_zero_or_more", bench_wildcard_match(1000, "a*"))
    m.bench_function("quantifier_one_or_more", bench_wildcard_match(1000, "a+"))
    m.bench_function("quantifier_zero_or_one", bench_wildcard_match(1000, "a?"))

    # Character ranges
    print("\n=== Character Range Benchmarks ===")
    m.bench_function("range_lowercase", bench_range_match(1000, "[a-z]+"))
    m.bench_function("range_digits", bench_range_match(1000, "[0-9]+"))
    m.bench_function("range_alphanumeric", bench_range_match(1000, "[a-zA-Z0-9]+"))

    # Anchors
    print("\n=== Anchor Benchmarks ===")
    m.bench_function("anchor_start", bench_anchor_match(1000, "^abc"))
    m.bench_function("anchor_end", bench_anchor_match(1000, "xyz$"))

    # Alternation
    print("\n=== Alternation Benchmarks ===")
    m.bench_function("alternation_simple", bench_alternation_match(1000, "a|b|c"))
    m.bench_function("alternation_words", bench_alternation_match(1000, "abc|def|ghi"))

    # Groups
    print("\n=== Group Benchmarks ===")
    m.bench_function("group_quantified", bench_group_match(1000, "(abc)+"))
    m.bench_function("group_alternation", bench_group_match(1000, "(a|b)*"))

    # Global matching (unique to our implementation)
    print("\n=== Global Matching Benchmarks ===")
    m.bench_function("match_all_simple", bench_match_all(1000, "a"))
    m.bench_function("match_all_pattern", bench_match_all(1000, "[a-z]+"))

    # Complex real-world patterns
    print("\n=== Complex Pattern Benchmarks ===")
    m.bench_function("complex_email_extraction", bench_complex_email_match(1000))
    m.bench_function("complex_number_extraction", bench_complex_number_extraction(1000))

    # Results summary
    m.dump_report()

    print("\nNote: This benchmark uses Python's re module with compiled patterns")
    print("for optimal performance comparison with the Mojo regex implementation.")
    print("Run the Mojo benchmark with: pixi run mojo benchmarks/bench_engine.mojo")


if __name__ == "__main__":
    main()
