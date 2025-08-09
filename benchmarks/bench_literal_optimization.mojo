# RUN: %mojo-no-debug %s -t

"""
Benchmark for literal optimization in regex patterns.

This benchmark tests the performance improvements from literal prefiltering
on various types of patterns containing literals.
"""

from benchmark import Bench, BenchConfig, Bencher, BenchId, Unit, keep, run
from regex import match_first, findall

# Simple test texts
alias SHORT_TEXT = "hello world this is a test with hello again and hello there"
alias MEDIUM_TEXT = SHORT_TEXT * 10
alias LONG_TEXT = SHORT_TEXT * 100

# Email text
alias EMAIL_TEXT = "test@example.com user@test.org admin@example.com support@example.com no-reply@example.com"
alias EMAIL_LONG = EMAIL_TEXT * 20


@parameter
fn bench_literal_prefix_short(mut b: Bencher) raises:
    """Benchmark literal prefix pattern on short text."""

    @always_inline
    @parameter
    fn call_fn() raises:
        var results = findall("hello.*world", SHORT_TEXT)
        keep(len(results))

    b.iter[call_fn]()


@parameter
fn bench_literal_prefix_medium(mut b: Bencher) raises:
    """Benchmark literal prefix pattern on medium text."""

    @always_inline
    @parameter
    fn call_fn() raises:
        var results = findall("hello.*", MEDIUM_TEXT)
        keep(len(results))

    b.iter[call_fn]()


@parameter
fn bench_literal_prefix_long(mut b: Bencher) raises:
    """Benchmark literal prefix pattern on long text."""

    @always_inline
    @parameter
    fn call_fn() raises:
        var results = findall("hello.*", LONG_TEXT)
        keep(len(results))

    b.iter[call_fn]()


@parameter
fn bench_required_literal_short(mut b: Bencher) raises:
    """Benchmark required literal (not prefix) on short text."""

    @always_inline
    @parameter
    fn call_fn() raises:
        var results = findall(".*@example\\.com", EMAIL_TEXT)
        keep(len(results))

    b.iter[call_fn]()


@parameter
fn bench_required_literal_long(mut b: Bencher) raises:
    """Benchmark required literal (not prefix) on long text."""

    @always_inline
    @parameter
    fn call_fn() raises:
        var results = findall(".*@example\\.com", EMAIL_LONG)
        keep(len(results))

    b.iter[call_fn]()


@parameter
fn bench_no_literal_baseline(mut b: Bencher) raises:
    """Benchmark pattern with no literals as baseline."""

    @always_inline
    @parameter
    fn call_fn() raises:
        var results = findall("[a-z]+", MEDIUM_TEXT)
        keep(len(results))

    b.iter[call_fn]()


@parameter
fn bench_alternation_common_prefix(mut b: Bencher) raises:
    """Benchmark alternation with common prefix."""

    @always_inline
    @parameter
    fn call_fn() raises:
        var results = findall("(hello|help|helicopter)", MEDIUM_TEXT)
        keep(len(results))

    b.iter[call_fn]()


def main():
    """Run literal optimization benchmarks."""
    print("=== Literal Optimization Benchmarks ===")
    print("Testing performance improvements from literal prefiltering")
    print()

    var m = Bench(BenchConfig(num_repetitions=1))

    # Literal prefix benchmarks
    print("=== Literal Prefix Patterns ===")
    m.bench_function[bench_literal_prefix_short](
        BenchId("literal_prefix_short")
    )
    m.bench_function[bench_literal_prefix_medium](
        BenchId("literal_prefix_medium")
    )
    m.bench_function[bench_literal_prefix_long](BenchId("literal_prefix_long"))

    # Required literal (not prefix) benchmarks
    print("\n=== Required Literal Patterns ===")
    m.bench_function[bench_required_literal_short](
        BenchId("required_literal_short")
    )
    m.bench_function[bench_required_literal_long](
        BenchId("required_literal_long")
    )

    # Baseline and special cases
    print("\n=== Baseline and Special Cases ===")
    m.bench_function[bench_no_literal_baseline](BenchId("no_literal_baseline"))
    m.bench_function[bench_alternation_common_prefix](
        BenchId("alternation_common_prefix")
    )

    print("\nBenchmark Results:")
    m.dump_report()

    print("\nAnalysis:")
    print("- Literal prefix patterns should show best performance")
    print("- Required literals (not prefix) still benefit from prefiltering")
    print("- Patterns without literals serve as baseline")
    print("- Longer texts should show more significant improvements")
