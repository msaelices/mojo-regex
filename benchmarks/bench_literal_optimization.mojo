"""
Benchmark for literal optimization in regex patterns.

This benchmark tests the performance improvements from literal prefiltering
on various types of patterns containing literals.
"""

from benchmark import Benchmark, BenchMetric, BenchId
from time import sleep
from random import random_float64, seed

from regex import HybridMatcher
from regex.nfa import NFAEngine


fn generate_test_text(size: Int) -> String:
    """Generate realistic text with specific patterns for testing.

    The text includes:
    - Common words and phrases
    - Email-like patterns
    - URLs
    - Random noise
    """
    seed(42)  # For reproducible benchmarks

    var text = String("")
    var words = List[String]()
    words.append("hello")
    words.append("world")
    words.append("example")
    words.append("test")
    words.append("benchmark")
    words.append("performance")
    words.append("optimization")
    words.append("literal")
    words.append("prefix")
    words.append("suffix")

    var domains = List[String]()
    domains.append("example.com")
    domains.append("test.org")
    domains.append("benchmark.net")

    var chars_written = 0
    while chars_written < size:
        var r = random_float64()

        if r < 0.3:
            # Add a random word
            var idx = int(random_float64() * len(words))
            text += words[idx]
            text += " "
            chars_written += len(words[idx]) + 1
        elif r < 0.4:
            # Add an email-like pattern
            var name_idx = int(random_float64() * len(words))
            var domain_idx = int(random_float64() * len(domains))
            var email = words[name_idx] + "@" + domains[domain_idx]
            text += email + " "
            chars_written += len(email) + 1
        elif r < 0.5:
            # Add a URL-like pattern
            var domain_idx = int(random_float64() * len(domains))
            var url = "https://" + domains[domain_idx] + "/path/to/page "
            text += url
            chars_written += len(url)
        elif r < 0.6:
            # Add some numbers
            var num = str(int(random_float64() * 10000))
            text += num + " "
            chars_written += len(num) + 1
        else:
            # Add random characters
            var noise = "abcdefghijklmnopqrstuvwxyz0123456789.,!? "
            for _ in range(10):
                var idx = int(random_float64() * len(noise))
                text += noise[idx]
                chars_written += 1

    return text


@value
struct LiteralBenchmark:
    """Benchmark configuration for a literal optimization test."""

    var name: String
    var pattern: String
    var description: String

    fn __init__(out self, name: String, pattern: String, description: String):
        self.name = name
        self.pattern = pattern
        self.description = description


fn get_benchmarks() -> List[LiteralBenchmark]:
    """Get list of benchmark patterns to test."""
    var benchmarks = List[LiteralBenchmark]()

    # Patterns with literal prefixes
    benchmarks.append(
        LiteralBenchmark(
            "literal_prefix_simple",
            "hello.*world",
            "Simple pattern with literal prefix",
        )
    )

    benchmarks.append(
        LiteralBenchmark(
            "literal_prefix_email",
            "example@.*\\.com",
            "Email pattern with literal prefix",
        )
    )

    benchmarks.append(
        LiteralBenchmark(
            "literal_prefix_url",
            "https://.*\\.com",
            "URL pattern with literal prefix",
        )
    )

    # Patterns with required literals (not prefix)
    benchmarks.append(
        LiteralBenchmark(
            "required_literal_middle",
            ".*@example\\.com",
            "Pattern with required literal in middle",
        )
    )

    benchmarks.append(
        LiteralBenchmark(
            "required_literal_suffix",
            ".*benchmark$",
            "Pattern with literal suffix",
        )
    )

    # Patterns with alternation containing common prefixes
    benchmarks.append(
        LiteralBenchmark(
            "alternation_common_prefix",
            "(hello|help|helicopter).*",
            "Alternation with common prefix 'hel'",
        )
    )

    benchmarks.append(
        LiteralBenchmark(
            "alternation_literals",
            "(example|test|benchmark)",
            "Alternation of literals",
        )
    )

    # Complex patterns with literals
    benchmarks.append(
        LiteralBenchmark(
            "complex_with_literal",
            "[a-z]+@example\\.(com|org|net)",
            "Complex pattern with required literal",
        )
    )

    benchmarks.append(
        LiteralBenchmark(
            "quantified_literal",
            "(hello ){2,5}world",
            "Pattern with quantified literal",
        )
    )

    # Patterns that benefit less from literal optimization
    benchmarks.append(
        LiteralBenchmark(
            "no_literal_benefit",
            "[a-z]+",
            "Pattern with no literals (baseline)",
        )
    )

    return benchmarks


fn bench_literal_optimization(mut b: Benchmark) raises:
    """Benchmark literal optimization performance."""
    # Generate test texts of different sizes
    var small_text = generate_test_text(1000)  # 1KB
    var medium_text = generate_test_text(10000)  # 10KB
    var large_text = generate_test_text(100000)  # 100KB

    var benchmarks = get_benchmarks()

    # Test each pattern on different text sizes
    for i in range(len(benchmarks)):
        var bench = benchmarks[i]

        # Small text benchmarks
        @parameter
        fn bench_small_no_opt(b: Benchmark) raises:
            """Benchmark without literal optimization (baseline)."""
            # Create engine without literal optimization (simulated by using pattern that prevents it)
            var engine = NFAEngine(
                "(?:)" + bench.pattern
            )  # Prefix with empty group to prevent optimization

            @always_inline
            @parameter
            fn call_fn():
                var matches = engine.match_all(small_text)
                # Ensure matches are used to prevent optimization
                if len(matches) > 0:
                    _ = matches[0].start

            b.iter[call_fn]()

        @parameter
        fn bench_small_opt(b: Benchmark) raises:
            """Benchmark with literal optimization."""
            var engine = NFAEngine(bench.pattern)

            @always_inline
            @parameter
            fn call_fn():
                var matches = engine.match_all(small_text)
                if len(matches) > 0:
                    _ = matches[0].start

            b.iter[call_fn]()

        # Benchmark on small text
        var small_id_no_opt = BenchId(bench.name + "_small_no_opt")
        b.bench_function[bench_small_no_opt](small_id_no_opt)

        var small_id_opt = BenchId(bench.name + "_small_opt")
        b.bench_function[bench_small_opt](small_id_opt)

        # Medium text benchmarks
        @parameter
        fn bench_medium_opt(b: Benchmark) raises:
            """Benchmark with literal optimization on medium text."""
            var engine = NFAEngine(bench.pattern)

            @always_inline
            @parameter
            fn call_fn():
                var matches = engine.match_all(medium_text)
                if len(matches) > 0:
                    _ = matches[0].start

            b.iter[call_fn]()

        var medium_id = BenchId(bench.name + "_medium_opt")
        b.bench_function[bench_medium_opt](medium_id)

        # Large text benchmarks (only for patterns that benefit from optimization)
        if not bench.name.startswith("no_literal"):

            @parameter
            fn bench_large_opt(b: Benchmark) raises:
                """Benchmark with literal optimization on large text."""
                var engine = NFAEngine(bench.pattern)

                @always_inline
                @parameter
                fn call_fn():
                    var matches = engine.match_all(large_text)
                    if len(matches) > 0:
                        _ = matches[0].start

                b.iter[call_fn]()

            var large_id = BenchId(bench.name + "_large_opt")
            b.bench_function[bench_large_opt](large_id)


fn main() raises:
    """Run literal optimization benchmarks."""
    print("=== Literal Optimization Benchmarks ===")
    print("Testing performance improvements from literal prefiltering")
    print()

    var b = Benchmark()
    bench_literal_optimization(b)

    print("\nBenchmark complete!")
    print("\nAnalysis:")
    print("- '_opt' suffixes indicate literal optimization enabled")
    print("- '_no_opt' suffixes indicate baseline (no optimization)")
    print("- Compare same pattern with/without optimization to see speedup")
    print("- Larger texts should show more significant improvements")
