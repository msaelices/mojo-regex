# RUN: %mojo-no-debug %s -t

from benchmark import Bench, BenchConfig, Bencher, BenchId, Unit, keep, run
from regex.nfa import NFAEngine
from regex.ast import ASTNode
from regex.parser import parse

# ===-----------------------------------------------------------------------===#
# SIMD-Focused Benchmark for Direct NFA Engine Testing
# ===-----------------------------------------------------------------------===#


fn make_digit_heavy_text[length: Int]() -> String:
    """Generate text with heavy digit content for SIMD digit matching.

    Parameters:
        length: The desired length of the test string.

    Returns:
        String with lots of digits interspersed with non-digits.
    """
    if length <= 0:
        return ""

    var base_pattern = "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567"
    var pattern_len = len(base_pattern)
    var result = String()
    var full_repeats = length // pattern_len
    var remainder = length % pattern_len

    # Add full pattern repeats
    for _ in range(full_repeats):
        result += base_pattern

    # Add partial pattern for remainder
    for i in range(remainder):
        result += base_pattern[i]

    return result


fn make_space_heavy_text[length: Int]() -> String:
    """Generate text with heavy whitespace content for SIMD whitespace matching.

    Parameters:
        length: The desired length of the test string.

    Returns:
        String with lots of whitespace interspersed with other characters.
    """
    if length <= 0:
        return ""

    var base_pattern = "word1 \t word2\n\rword3   word4\t\t\nword5 word6"
    var pattern_len = len(base_pattern)
    var result = String()
    var full_repeats = length // pattern_len
    var remainder = length % pattern_len

    # Add full pattern repeats
    for _ in range(full_repeats):
        result += base_pattern

    # Add partial pattern for remainder
    for i in range(remainder):
        result += base_pattern[i]

    return result


fn make_range_heavy_text[length: Int]() -> String:
    """Generate text with heavy character range content for SIMD range matching.

    Parameters:
        length: The desired length of the test string.

    Returns:
        String with lots of alphanumeric characters interspersed with others.
    """
    if length <= 0:
        return ""

    var base_pattern = (
        "abc123XYZ!@#def456GHI$%^jkl789MNO&*()pqr012STU+={}wxy345VWZ"
    )
    var pattern_len = len(base_pattern)
    var result = String()
    var full_repeats = length // pattern_len
    var remainder = length % pattern_len

    # Add full pattern repeats
    for _ in range(full_repeats):
        result += base_pattern

    # Add partial pattern for remainder
    for i in range(remainder):
        result += base_pattern[i]

    return result


# ===-----------------------------------------------------------------------===#
# Direct NFA Engine SIMD Benchmarks
# ===-----------------------------------------------------------------------===#


@parameter
fn bench_nfa_simd_digits[text_length: Int](mut b: Bencher) raises:
    """Benchmark NFA engine with SIMD-optimized digit matching."""
    var test_text = make_digit_heavy_text[text_length]()
    var engine = NFAEngine("\\d+")

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(20):
            var result = engine.match_all(test_text)
            keep(len(result))

    b.iter[call_fn]()
    keep(Bool(test_text))


@parameter
fn bench_nfa_simd_whitespace[text_length: Int](mut b: Bencher) raises:
    """Benchmark NFA engine with SIMD-optimized whitespace matching."""
    var test_text = make_space_heavy_text[text_length]()
    var engine = NFAEngine("\\s+")

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(20):
            var result = engine.match_all(test_text)
            keep(len(result))

    b.iter[call_fn]()
    keep(Bool(test_text))


@parameter
fn bench_nfa_simd_range[text_length: Int](mut b: Bencher) raises:
    """Benchmark NFA engine with SIMD-optimized character range matching."""
    var test_text = make_range_heavy_text[text_length]()
    var engine = NFAEngine("[a-zA-Z0-9]+")

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(20):
            var result = engine.match_all(test_text)
            keep(len(result))

    b.iter[call_fn]()
    keep(Bool(test_text))


@parameter
fn bench_nfa_simd_negated_range[text_length: Int](mut b: Bencher) raises:
    """Benchmark NFA engine with SIMD-optimized negated character range matching.
    """
    var test_text = make_range_heavy_text[text_length]()
    var engine = NFAEngine("[^a-zA-Z0-9]+")

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(20):
            var result = engine.match_all(test_text)
            keep(len(result))

    b.iter[call_fn]()
    keep(Bool(test_text))


@parameter
fn bench_nfa_simd_quantified_range[text_length: Int](mut b: Bencher) raises:
    """Benchmark NFA engine with SIMD-optimized quantified character range matching.
    """
    var test_text = make_range_heavy_text[text_length]()
    var engine = NFAEngine("[a-z]{3,10}")

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(20):
            var result = engine.match_all(test_text)
            keep(len(result))

    b.iter[call_fn]()
    keep(Bool(test_text))


def main():
    var m = Bench(BenchConfig(num_repetitions=1))

    print("=== SIMD-Focused NFA Engine Benchmarks ===")
    print(
        "These benchmarks directly test the NFA engine with patterns that"
        " benefit from SIMD optimizations."
    )
    print("")

    # Digit matching with SIMD optimizations
    print("--- Digit Matching (\\d+) ---")
    m.bench_function[bench_nfa_simd_digits[10000]](
        BenchId(String("nfa_simd_digits_10k"))
    )
    m.bench_function[bench_nfa_simd_digits[50000]](
        BenchId(String("nfa_simd_digits_50k"))
    )

    # Whitespace matching with SIMD optimizations
    print("--- Whitespace Matching (\\s+) ---")
    m.bench_function[bench_nfa_simd_whitespace[10000]](
        BenchId(String("nfa_simd_whitespace_10k"))
    )
    m.bench_function[bench_nfa_simd_whitespace[50000]](
        BenchId(String("nfa_simd_whitespace_50k"))
    )

    # Character range matching with SIMD optimizations
    print("--- Character Range Matching ([a-zA-Z0-9]+) ---")
    m.bench_function[bench_nfa_simd_range[10000]](
        BenchId(String("nfa_simd_range_10k"))
    )
    m.bench_function[bench_nfa_simd_range[50000]](
        BenchId(String("nfa_simd_range_50k"))
    )

    # Negated character range matching with SIMD optimizations
    print("--- Negated Character Range Matching ([^a-zA-Z0-9]+) ---")
    m.bench_function[bench_nfa_simd_negated_range[10000]](
        BenchId(String("nfa_simd_negated_range_10k"))
    )
    m.bench_function[bench_nfa_simd_negated_range[50000]](
        BenchId(String("nfa_simd_negated_range_50k"))
    )

    # Quantified character range matching with SIMD optimizations
    print("--- Quantified Character Range Matching ([a-z]{3,10}) ---")
    m.bench_function[bench_nfa_simd_quantified_range[10000]](
        BenchId(String("nfa_simd_quantified_range_10k"))
    )
    m.bench_function[bench_nfa_simd_quantified_range[50000]](
        BenchId(String("nfa_simd_quantified_range_50k"))
    )

    print("\n=== Benchmark Results ===")
    m.dump_report()
