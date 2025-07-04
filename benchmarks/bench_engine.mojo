# RUN: %mojo-no-debug %s -t

from os import abort
from pathlib import _dir_of_current_file
from random import random_si64, seed
from sys import stderr

from benchmark import Bench, BenchConfig, Bencher, BenchId, Unit, keep, run
from regex import match_first, findall


# ===-----------------------------------------------------------------------===#
# Benchmark Data Generation
# ===-----------------------------------------------------------------------===#
fn make_test_string[
    length: Int
](pattern: String = "abcdefghijklmnopqrstuvwxyz") -> String:
    """Generate a test string of specified length by repeating a pattern.

    Parameters:
        length: The desired length of the test string.

    Args:
        pattern: The pattern to repeat to create the test string.
    """
    if length <= 0:
        return ""

    var result = String()
    var pattern_len = len(pattern)
    var full_repeats = length // pattern_len
    var remainder = length % pattern_len

    # Add full pattern repeats
    for _ in range(full_repeats):
        result += pattern

    # Add partial pattern for remainder
    for i in range(remainder):
        result += pattern[i]

    return result


# ===-----------------------------------------------------------------------===#
# Basic Literal Matching Benchmarks
# ===-----------------------------------------------------------------------===#
@parameter
fn bench_literal_match[
    text_length: Int, pattern: StaticString
](mut b: Bencher) raises:
    """Benchmark literal string matching."""
    var test_text = make_test_string[text_length]()

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(100):
            var result = match_first(pattern, test_text)
            keep(result.__bool__())

    b.iter[call_fn]()
    keep(Bool(test_text))


# ===-----------------------------------------------------------------------===#
# Wildcard and Quantifier Benchmarks
# ===-----------------------------------------------------------------------===#
@parameter
fn bench_wildcard_match[
    text_length: Int, pattern: StaticString
](mut b: Bencher) raises:
    """Benchmark wildcard and quantifier patterns."""
    var test_text = make_test_string[text_length]()

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(50):
            var result = match_first(pattern, test_text)
            keep(result.__bool__())

    b.iter[call_fn]()
    keep(Bool(test_text))


# ===-----------------------------------------------------------------------===#
# Character Range Benchmarks
# ===-----------------------------------------------------------------------===#
@parameter
fn bench_range_match[
    text_length: Int, pattern: StaticString
](mut b: Bencher) raises:
    """Benchmark character range patterns."""
    var test_text = make_test_string[text_length]("abc123XYZ")

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(50):
            var result = match_first(pattern, test_text)
            keep(result.__bool__())

    b.iter[call_fn]()
    keep(Bool(test_text))


# ===-----------------------------------------------------------------------===#
# Anchor Benchmarks
# ===-----------------------------------------------------------------------===#
@parameter
fn bench_anchor_match[
    text_length: Int, pattern: StaticString
](mut b: Bencher) raises:
    """Benchmark anchor patterns (^ and $)."""
    var test_text = make_test_string[text_length]()

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(100):
            var result = match_first(pattern, test_text)
            keep(result.__bool__())

    b.iter[call_fn]()
    keep(Bool(test_text))


# ===-----------------------------------------------------------------------===#
# Alternation (OR) Benchmarks
# ===-----------------------------------------------------------------------===#
@parameter
fn bench_alternation_match[
    text_length: Int, pattern: StaticString
](mut b: Bencher) raises:
    """Benchmark alternation patterns (|)."""
    var test_text = make_test_string[text_length]("abcdefghijklmnopqrstuvwxyz")

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(50):
            var result = match_first(pattern, test_text)
            keep(result.__bool__())

    b.iter[call_fn]()
    keep(Bool(test_text))


# ===-----------------------------------------------------------------------===#
# Group Benchmarks
# ===-----------------------------------------------------------------------===#
@parameter
fn bench_group_match[
    text_length: Int, pattern: StaticString
](mut b: Bencher) raises:
    """Benchmark group patterns with quantifiers."""
    var test_text = make_test_string[text_length]("abcabcabc")

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(50):
            var result = match_first(pattern, test_text)
            keep(result.__bool__())

    b.iter[call_fn]()
    keep(Bool(test_text))


# ===-----------------------------------------------------------------------===#
# Global Matching Benchmarks
# ===-----------------------------------------------------------------------===#
@parameter
fn bench_match_all[
    text_length: Int, pattern: StaticString
](mut b: Bencher) raises:
    """Benchmark finding all matches in text."""
    var test_text = make_test_string[text_length]()

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(10):  # Fewer iterations since findall is more expensive
            var results = findall(pattern, test_text)
            keep(len(results))

    b.iter[call_fn]()
    keep(Bool(test_text))


# ===-----------------------------------------------------------------------===#
# SIMD-Heavy Character Filtering Benchmarks
# ===-----------------------------------------------------------------------===#
fn make_mixed_content_text[length: Int]() -> String:
    """Generate large mixed content text optimal for SIMD character class testing.

    Parameters:
        length: The desired length of the test string.

    Returns:
        String with mixed alphanumeric, punctuation, and whitespace content.
    """
    if length <= 0:
        return ""

    # Pattern that creates realistic mixed content with plenty of alphanumeric sequences
    var base_pattern = "User123 sent email to user456@domain.com with ID abc789! Status: ACTIVE_2024 (priority=HIGH). "
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


@parameter
fn bench_simd_heavy_filtering[
    text_length: Int, pattern: StaticString
](mut b: Bencher) raises:
    """Benchmark SIMD-optimized character class filtering on large mixed content.

    This benchmark is designed to show maximum SIMD performance benefits by:
    - Using character classes that benefit from SIMD lookup tables
    - Processing large amounts of text to amortize SIMD setup costs
    - Using realistic mixed content with alphanumeric sequences
    """
    var test_text = make_mixed_content_text[text_length]()

    @always_inline
    @parameter
    fn call_fn() raises:
        for _ in range(10):  # Fewer iterations due to large text size
            var result = match_first(pattern, test_text)
            keep(result.__bool__())

    b.iter[call_fn]()
    keep(Bool(test_text))


# ===-----------------------------------------------------------------------===#
# Benchmark Main
# ===-----------------------------------------------------------------------===#
def main():
    seed()
    var m = Bench(BenchConfig(num_repetitions=1))

    # Basic literal matching
    print("=== Literal Matching Benchmarks ===")
    m.bench_function[bench_literal_match[1000, "hello"]](
        BenchId(String("literal_match_short"))
    )
    m.bench_function[bench_literal_match[10000, "hello"]](
        BenchId(String("literal_match_long"))
    )

    # Wildcard and quantifiers
    print("=== Wildcard and Quantifier Benchmarks ===")
    m.bench_function[bench_wildcard_match[1000, ".*"]](
        BenchId(String("wildcard_match_any"))
    )
    m.bench_function[bench_wildcard_match[1000, "a*"]](
        BenchId(String("quantifier_zero_or_more"))
    )
    m.bench_function[bench_wildcard_match[1000, "a+"]](
        BenchId(String("quantifier_one_or_more"))
    )
    m.bench_function[bench_wildcard_match[1000, "a?"]](
        BenchId(String("quantifier_zero_or_one"))
    )

    # Character ranges
    print("=== Character Range Benchmarks ===")
    m.bench_function[bench_range_match[1000, "[a-z]+"]](
        BenchId(String("range_lowercase"))
    )
    m.bench_function[bench_range_match[1000, "[0-9]+"]](
        BenchId(String("range_digits"))
    )
    m.bench_function[bench_range_match[1000, "[a-zA-Z0-9]+"]](
        BenchId(String("range_alphanumeric"))
    )

    # Anchors
    print("=== Anchor Benchmarks ===")
    m.bench_function[bench_anchor_match[1000, "^abc"]](
        BenchId(String("anchor_start"))
    )
    m.bench_function[bench_anchor_match[1000, "xyz$"]](
        BenchId(String("anchor_end"))
    )

    # Alternation
    print("=== Alternation Benchmarks ===")
    m.bench_function[bench_alternation_match[1000, "a|b|c"]](
        BenchId(String("alternation_simple"))
    )
    m.bench_function[bench_alternation_match[1000, "abc|def|ghi"]](
        BenchId(String("alternation_words"))
    )

    # Groups
    print("=== Group Benchmarks ===")
    m.bench_function[bench_group_match[1000, "(abc)+"]](
        BenchId(String("group_quantified"))
    )
    m.bench_function[bench_group_match[1000, "(a|b)*"]](
        BenchId(String("group_alternation"))
    )

    # Global matching
    print("=== Global Matching Benchmarks ===")
    m.bench_function[bench_match_all[1000, "a"]](
        BenchId(String("match_all_simple"))
    )
    m.bench_function[bench_match_all[1000, "[a-z]+"]](
        BenchId(String("match_all_pattern"))
    )

    # SIMD-Heavy Character Filtering (designed to show maximum SIMD benefit)
    print("=== SIMD-Optimized Character Filtering Benchmarks ===")
    m.bench_function[bench_simd_heavy_filtering[10000, "[a-zA-Z0-9]+"]](
        BenchId(String("simd_alphanumeric_large"))
    )
    m.bench_function[bench_simd_heavy_filtering[50000, "[a-zA-Z0-9]+"]](
        BenchId(String("simd_alphanumeric_xlarge"))
    )
    m.bench_function[bench_simd_heavy_filtering[10000, "[^a-zA-Z0-9]+"]](
        BenchId(String("simd_negated_alphanumeric"))
    )
    m.bench_function[bench_simd_heavy_filtering[10000, "[a-z]+[0-9]+"]](
        BenchId(String("simd_multi_char_class"))
    )

    # Results summary
    print("\n=== Benchmark Results ===")
    m.dump_report()
