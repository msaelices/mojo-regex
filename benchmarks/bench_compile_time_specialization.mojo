"""
Benchmark for compile-time pattern specialization.

This benchmark measures the performance improvement from compile-time
specialization for literal patterns.
"""

from time import perf_counter_ns
from regex import compile_regex


fn benchmark_literal_patterns() raises:
    """Benchmark literal pattern matching with compile-time specialization."""

    # Test data
    var test_text = "The quick brown fox jumps over the lazy dog. This is a test string with various words and patterns for benchmarking purposes."

    # Literal patterns to test
    var patterns = List[String](
        "the",
        "fox",
        "test",
        "string",
        "benchmark",
        "pattern",
        "quick",
        "brown",
        "lazy",
        "dog",
    )

    print("Benchmarking Compile-Time Pattern Specialization")
    print("=" * 60)
    print(
        "Pattern".ljust(15),
        "Engine".ljust(12),
        "Time (ns)".ljust(12),
        "Matches",
    )
    print("-" * 60)

    var total_time = 0
    var total_matches = 0

    for pattern in patterns:
        var compiled = compile_regex(pattern)

        # Warmup
        for _ in range(10):
            _ = compiled.match_next(test_text)

        # Benchmark
        var start_time = perf_counter_ns()
        var iterations = 1000

        for _ in range(iterations):
            var result = compiled.match_next(test_text)
            if result:
                total_matches += 1

        var end_time = perf_counter_ns()
        var avg_time = (end_time - start_time) // iterations

        var engine_type = (
            compiled.get_stats().split(", Engine: ")[1].split(", ")[0]
        )

        print(
            pattern.ljust(15),
            engine_type.ljust(12),
            String(avg_time).ljust(12),
            String(total_matches),
        )

        total_time += avg_time

    print("-" * 60)
    print(
        "Average time per pattern:", String(total_time // len(patterns)), "ns"
    )
    print("Total matches found:", String(total_matches))


fn main() raises:
    """Main benchmark function."""
    benchmark_literal_patterns()
