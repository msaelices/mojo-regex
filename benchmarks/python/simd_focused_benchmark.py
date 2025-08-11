#!/usr/bin/env python3

"""
SIMD-Focused Python Benchmark for Comparison with Mojo NFA Engine

This benchmark provides equivalent Python regex patterns to compare against
the Mojo NFA engine's SIMD optimizations.
"""

import re
import time
import json
import os
from datetime import datetime
from typing import Callable, List


# ===-----------------------------------------------------------------------===#
# Benchmark Infrastructure
# ===-----------------------------------------------------------------------===#


class Benchmark:
    """Simple benchmark infrastructure to mirror Mojo's benchmark system."""

    def __init__(self, num_repetitions: int = 3):
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
            total_time += fn_time
            actual_iterations += 1

        # Calculate mean time per run
        mean_time = total_time / actual_iterations

        # All SIMD benchmarks have 20 internal iterations
        internal_iterations = 20

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

    def export_json(self, filename: str = "benchmarks/results/python_simd_results.json"):
        """Export benchmark results to JSON file.

        Args:
            filename: Path to output JSON file
        """
        # Ensure directory exists
        os.makedirs(os.path.dirname(filename), exist_ok=True)

        # Convert results to JSON-serializable format
        json_results = {
            "engine": "python_simd",
            "timestamp": datetime.now().isoformat(),
            "results": {}
        }

        for name in self.results:
            json_results["results"][name] = {
                "time_ns": self.results[name],
                "time_ms": self.results[name] / 1_000_000,
                "iterations": self.iterations[name]
            }

        # Write to file
        with open(filename, "w") as f:
            json.dump(json_results, f, indent=2)

        print(f"\nResults exported to {filename}")


# ===-----------------------------------------------------------------------===#
# Test Data Generation
# ===-----------------------------------------------------------------------===#


def make_digit_heavy_text(length: int) -> str:
    """Generate text with heavy digit content for digit matching.

    Args:
        length: The desired length of the test string.

    Returns:
        String with lots of digits interspersed with non-digits.
    """
    if length <= 0:
        return ""

    base_pattern = "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567"
    pattern_len = len(base_pattern)
    full_repeats = length // pattern_len
    remainder = length % pattern_len

    # Add full pattern repeats
    result = base_pattern * full_repeats

    # Add partial pattern for remainder
    result += base_pattern[:remainder]

    return result


def make_space_heavy_text(length: int) -> str:
    """Generate text with heavy whitespace content for whitespace matching.

    Args:
        length: The desired length of the test string.

    Returns:
        String with lots of whitespace interspersed with other characters.
    """
    if length <= 0:
        return ""

    base_pattern = "word1 \t word2\n\rword3   word4\t\t\nword5 word6"
    pattern_len = len(base_pattern)
    full_repeats = length // pattern_len
    remainder = length % pattern_len

    # Add full pattern repeats
    result = base_pattern * full_repeats

    # Add partial pattern for remainder
    result += base_pattern[:remainder]

    return result


def make_range_heavy_text(length: int) -> str:
    """Generate text with heavy character range content for range matching.

    Args:
        length: The desired length of the test string.

    Returns:
        String with lots of alphanumeric characters interspersed with others.
    """
    if length <= 0:
        return ""

    base_pattern = "abc123XYZ!@#def456GHI$%^jkl789MNO&*()pqr012STU+={}wxy345VWZ"
    pattern_len = len(base_pattern)
    full_repeats = length // pattern_len
    remainder = length % pattern_len

    # Add full pattern repeats
    result = base_pattern * full_repeats

    # Add partial pattern for remainder
    result += base_pattern[:remainder]

    return result


# ===-----------------------------------------------------------------------===#
# SIMD Benchmark Functions
# ===-----------------------------------------------------------------------===#


def bench_python_simd_digits(test_text: str) -> Callable[[], None]:
    """Benchmark Python regex with digit matching."""
    pattern = re.compile(r'\d+')

    def benchmark_fn():
        for _ in range(20):
            result = pattern.findall(test_text)
            # Keep result to prevent optimization
            len(result)

    return benchmark_fn


def bench_python_simd_whitespace(test_text: str) -> Callable[[], None]:
    """Benchmark Python regex with whitespace matching."""
    pattern = re.compile(r'\s+')

    def benchmark_fn():
        for _ in range(20):
            result = pattern.findall(test_text)
            # Keep result to prevent optimization
            len(result)

    return benchmark_fn


def bench_python_simd_range(test_text: str) -> Callable[[], None]:
    """Benchmark Python regex with character range matching."""
    pattern = re.compile(r'[a-zA-Z0-9]+')

    def benchmark_fn():
        for _ in range(20):
            result = pattern.findall(test_text)
            # Keep result to prevent optimization
            len(result)

    return benchmark_fn


def bench_python_simd_negated_range(test_text: str) -> Callable[[], None]:
    """Benchmark Python regex with negated character range matching."""
    pattern = re.compile(r'[^a-zA-Z0-9]+')

    def benchmark_fn():
        for _ in range(20):
            result = pattern.findall(test_text)
            # Keep result to prevent optimization
            len(result)

    return benchmark_fn


def bench_python_simd_quantified_range(test_text: str) -> Callable[[], None]:
    """Benchmark Python regex with quantified character range matching."""
    pattern = re.compile(r'[a-z]{3,10}')

    def benchmark_fn():
        for _ in range(20):
            result = pattern.findall(test_text)
            # Keep result to prevent optimization
            len(result)

    return benchmark_fn


# ===-----------------------------------------------------------------------===#
# Benchmark Main
# ===-----------------------------------------------------------------------===#


def main():
    """Run all benchmarks and display results."""
    m = Benchmark(num_repetitions=3)

    print("=== SIMD-Focused Python Regex Benchmarks ===")
    print("These benchmarks provide Python baselines for comparison with Mojo NFA engine SIMD optimizations.")
    print("")

    # Pre-create test strings to avoid measurement overhead
    text_10k = make_digit_heavy_text(10000)
    text_50k = make_digit_heavy_text(50000)
    space_text_10k = make_space_heavy_text(10000)
    space_text_50k = make_space_heavy_text(50000)
    range_text_10k = make_range_heavy_text(10000)
    range_text_50k = make_range_heavy_text(50000)

    # Digit matching benchmarks
    print("--- Digit Matching (\\d+) ---")
    m.bench_function(
        "nfa_simd_digits_10k",
        bench_python_simd_digits(text_10k)
    )
    m.bench_function(
        "nfa_simd_digits_50k",
        bench_python_simd_digits(text_50k)
    )

    # Whitespace matching benchmarks
    print("--- Whitespace Matching (\\s+) ---")
    m.bench_function(
        "nfa_simd_whitespace_10k",
        bench_python_simd_whitespace(space_text_10k)
    )
    m.bench_function(
        "nfa_simd_whitespace_50k",
        bench_python_simd_whitespace(space_text_50k)
    )

    # Character range matching benchmarks
    print("--- Character Range Matching ([a-zA-Z0-9]+) ---")
    m.bench_function(
        "nfa_simd_range_10k",
        bench_python_simd_range(range_text_10k)
    )
    m.bench_function(
        "nfa_simd_range_50k",
        bench_python_simd_range(range_text_50k)
    )

    # Negated character range matching benchmarks
    print("--- Negated Character Range Matching ([^a-zA-Z0-9]+) ---")
    m.bench_function(
        "nfa_simd_negated_range_10k",
        bench_python_simd_negated_range(range_text_10k)
    )
    m.bench_function(
        "nfa_simd_negated_range_50k",
        bench_python_simd_negated_range(range_text_50k)
    )

    # Quantified character range matching benchmarks
    print("--- Quantified Character Range Matching ([a-z]{3,10}) ---")
    m.bench_function(
        "nfa_simd_quantified_range_10k",
        bench_python_simd_quantified_range(range_text_10k)
    )
    m.bench_function(
        "nfa_simd_quantified_range_50k",
        bench_python_simd_quantified_range(range_text_50k)
    )

    # Results summary
    m.dump_report()

    # Export to JSON
    m.export_json()


if __name__ == "__main__":
    main()
