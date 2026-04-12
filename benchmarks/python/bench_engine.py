#!/usr/bin/env python3
"""
Python benchmark script for comparing regex performance with Python's re module.
"""

import re
import time
import json
import os
import statistics
from datetime import datetime


# ===-----------------------------------------------------------------------===#
# Benchmark Infrastructure
# ===-----------------------------------------------------------------------===#

# Target runtime per benchmark: 500ms for more stable measurements
TARGET_RUNTIME_NS = 500_000_000
MAX_ITERATIONS = 200_000
WARMUP_ITERATIONS = 10
# Minimum time per sample (1ms) to ensure OS jitter is a small fraction
MIN_SAMPLE_NS = 1_000_000


def _find_median(times: list[float]) -> float:
    """Find median of a list of times."""
    if not times:
        return 0.0
    return statistics.median(times)


def _auto_calibrate(fn, iters: int) -> int:
    """Auto-calibrate iterations so each sample takes >= MIN_SAMPLE_NS."""
    start = time.perf_counter_ns()
    for _ in range(iters):
        fn()
    elapsed = time.perf_counter_ns() - start
    if elapsed < MIN_SAMPLE_NS and elapsed > 0:
        multiplier = int(MIN_SAMPLE_NS // elapsed) + 1
        iters = iters * multiplier
    return iters


# ===-----------------------------------------------------------------------===#
# Direct Benchmark Functions (Mirroring Mojo Architecture)
# ===-----------------------------------------------------------------------===#


def benchmark_search(
    name: str, pattern: str, text: str, internal_iterations: int
):
    """Benchmark search with pre-compiled regex and median timing."""

    compiled_pattern = re.compile(pattern)

    # Warmup
    for _ in range(WARMUP_ITERATIONS):
        compiled_pattern.search(text)

    # Auto-calibrate: ensure each sample takes >= MIN_SAMPLE_NS
    iters = _auto_calibrate(lambda: compiled_pattern.search(text), internal_iterations)

    # Collect per-iteration times
    times = []
    total_time = 0
    actual_iterations = 0

    while total_time < TARGET_RUNTIME_NS and actual_iterations < MAX_ITERATIONS:
        start_time = time.perf_counter_ns()

        for _ in range(iters):
            result = compiled_pattern.search(text)
            if not result:
                print(
                    f"ERROR: No search match in {name} for pattern: {pattern}"
                )
                return

        end_time = time.perf_counter_ns()
        elapsed = end_time - start_time
        total_time += elapsed
        actual_iterations += 1
        times.append(elapsed / iters / 1_000_000.0)

    median_ms = _find_median(times)
    total_matches = actual_iterations * iters

    padded_name = name + " " * (25 - len(name))
    print(f"| {padded_name} | {median_ms:>21.17f} | {total_matches:>6} |")

    _store_benchmark_result(name, median_ms, total_matches)


def benchmark_match_first(
    name: str, pattern: str, text: str, internal_iterations: int
):
    """Benchmark match_first with pre-compiled regex and median timing."""

    compiled_pattern = re.compile(pattern)

    # Warmup
    for _ in range(WARMUP_ITERATIONS):
        compiled_pattern.match(text)

    # Auto-calibrate: ensure each sample takes >= MIN_SAMPLE_NS
    iters = _auto_calibrate(lambda: compiled_pattern.match(text), internal_iterations)

    # Collect per-iteration times
    times = []
    total_time = 0
    actual_iterations = 0

    while total_time < TARGET_RUNTIME_NS and actual_iterations < MAX_ITERATIONS:
        start_time = time.perf_counter_ns()

        for _ in range(iters):
            result = compiled_pattern.match(text)
            if not result:
                print(f"ERROR: No match in {name} for pattern: {pattern}")
                return

        end_time = time.perf_counter_ns()
        elapsed = end_time - start_time
        total_time += elapsed
        actual_iterations += 1
        times.append(elapsed / iters / 1_000_000.0)

    median_ms = _find_median(times)
    total_matches = actual_iterations * iters

    padded_name = name + " " * (25 - len(name))
    print(f"| {padded_name} | {median_ms:>21.17f} | {total_matches:>6} |")

    _store_benchmark_result(name, median_ms, total_matches)


def benchmark_findall(
    name: str, pattern: str, text: str, internal_iterations: int
):
    """Benchmark findall with pre-compiled regex and median timing."""

    compiled_pattern = re.compile(pattern)

    # Warmup
    for _ in range(WARMUP_ITERATIONS):
        compiled_pattern.findall(text)

    # Auto-calibrate: ensure each sample takes >= MIN_SAMPLE_NS
    iters = _auto_calibrate(lambda: compiled_pattern.findall(text), internal_iterations)

    # Collect per-iteration times
    times = []
    total_time = 0
    actual_iterations = 0

    while total_time < TARGET_RUNTIME_NS and actual_iterations < MAX_ITERATIONS:
        start_time = time.perf_counter_ns()

        for _ in range(iters):
            compiled_pattern.findall(text)

        end_time = time.perf_counter_ns()
        elapsed = end_time - start_time
        total_time += elapsed
        actual_iterations += 1
        times.append(elapsed / iters / 1_000_000.0)

    median_ms = _find_median(times)
    total_matches = actual_iterations * iters

    padded_name = name + " " * (25 - len(name))
    print(f"| {padded_name} | {median_ms:>21.17f} | {total_matches:>6} |")

    _store_benchmark_result(name, median_ms, total_matches)


def benchmark_is_match(
    name: str, pattern: str, text: str, internal_iterations: int
):
    """Benchmark bool-only match check with pre-compiled regex and median timing.
    Uses re.match which returns a match object, then checks truthiness (like is_match).
    """

    compiled_pattern = re.compile(pattern)

    # Warmup
    for _ in range(WARMUP_ITERATIONS):
        bool(compiled_pattern.match(text))

    # Auto-calibrate
    iters = _auto_calibrate(lambda: bool(compiled_pattern.match(text)), internal_iterations)

    # Collect per-iteration times
    times = []
    total_time = 0
    actual_iterations = 0

    while total_time < TARGET_RUNTIME_NS and actual_iterations < MAX_ITERATIONS:
        start_time = time.perf_counter_ns()

        for _ in range(iters):
            bool(compiled_pattern.match(text))

        end_time = time.perf_counter_ns()
        elapsed = end_time - start_time
        total_time += elapsed
        actual_iterations += 1
        times.append(elapsed / iters / 1_000_000.0)

    median_ms = _find_median(times)
    total_matches = actual_iterations * iters

    padded_name = name + " " * (25 - len(name))
    print(f"| {padded_name} | {median_ms:>21.17f} | {total_matches:>6} |")

    _store_benchmark_result(name, median_ms, total_matches)


def benchmark_sub(
    name: str,
    pattern: str,
    repl: str,
    text: str,
    internal_iterations: int,
):
    """Benchmark re.sub with pre-compiled regex and median timing."""

    compiled_pattern = re.compile(pattern)

    # Warmup
    for _ in range(WARMUP_ITERATIONS):
        compiled_pattern.sub(repl, text)

    # Auto-calibrate
    iters = _auto_calibrate(
        lambda: compiled_pattern.sub(repl, text), internal_iterations
    )

    # Collect per-iteration times
    times = []
    total_time = 0
    actual_iterations = 0

    while total_time < TARGET_RUNTIME_NS and actual_iterations < MAX_ITERATIONS:
        start_time = time.perf_counter_ns()

        for _ in range(iters):
            compiled_pattern.sub(repl, text)

        end_time = time.perf_counter_ns()
        elapsed = end_time - start_time
        total_time += elapsed
        actual_iterations += 1
        times.append(elapsed / iters / 1_000_000.0)

    median_ms = _find_median(times)
    total_matches = actual_iterations * iters

    padded_name = name + " " * (25 - len(name))
    print(f"| {padded_name} | {median_ms:>21.17f} | {total_matches:>6} |")

    _store_benchmark_result(name, median_ms, total_matches)


# ===-----------------------------------------------------------------------===#
# Result Collection for JSON Export
# ===-----------------------------------------------------------------------===#

_benchmark_results = {}
_benchmark_iterations = {}


def _store_benchmark_result(name: str, time_ms: float, total_iterations: int):
    """Store benchmark result for JSON export."""
    _benchmark_results[name] = time_ms * 1_000_000  # Convert to nanoseconds
    _benchmark_iterations[name] = total_iterations


def export_json_results(
    filename: str = "benchmarks/results/python_results.json",
):
    """Export collected benchmark results to JSON file."""
    os.makedirs(os.path.dirname(filename), exist_ok=True)

    json_results = {
        "engine": "python",
        "timestamp": datetime.now().isoformat(),
        "results": {},
    }

    for name in _benchmark_results:
        json_results["results"][name] = {
            "time_ns": _benchmark_results[name],
            "time_ms": _benchmark_results[name] / 1_000_000,
            "iterations": _benchmark_iterations[name],
        }

    with open(filename, "w") as f:
        json.dump(json_results, f, indent=2)

    print(f"\nResults exported to {filename}")


# ===-----------------------------------------------------------------------===#
# Test Data Generation
# ===-----------------------------------------------------------------------===


def make_test_string(
    length: int, pattern: str = "abcdefghijklmnopqrstuvwxyz"
) -> str:
    """Generate a test string of specified length by repeating a pattern."""
    if length <= 0:
        return ""

    pattern_len = len(pattern)
    full_repeats = length // pattern_len
    remainder = length % pattern_len

    result = pattern * full_repeats + pattern[:remainder]
    return result


def make_phone_test_data(num_phones: int) -> str:
    """Generate test data containing US phone numbers in various formats."""
    phone_patterns = [
        "555-123-4567",
        "(555) 123-4567",
        "555.123.4567",
        "5551234567",
        "+1-555-123-4567",
        "1-555-123-4568",
        "(555)123-4569",
        "555 123 4570",
    ]
    filler_text = " Contact us at "
    extra_text = " or email support@company.com for assistance. "

    result = ""
    for i in range(num_phones):
        result += filler_text
        pattern_idx = i % len(phone_patterns)
        result += phone_patterns[pattern_idx]
        result += extra_text

    return result


def make_complex_pattern_test_data(num_entries: int) -> str:
    """Generate test data for US national phone number validation."""
    complex_patterns = [
        "305200123456",
        "505601234567",
        "274212345678",
        "305912345678",
        "212345672890",
        "312345672890",
        "412345672890",
        "512345672890",
        "1234567890",
        "30520",
    ]
    filler_text = " ID: "
    extra_text = " Status: ACTIVE "

    result = ""
    for i in range(num_entries):
        result += filler_text
        pattern_idx = i % len(complex_patterns)
        result += complex_patterns[pattern_idx]
        result += extra_text

    return result


# ===-----------------------------------------------------------------------===#
# Benchmark Main
# ===-----------------------------------------------------------------------===#


def main():
    """Run all regex benchmarks."""
    print("=== REGEX ENGINE BENCHMARKS (Pre-compiled, Median Timing) ===")
    print(
        "Target runtime: 500ms per benchmark, reporting median iteration time"
    )
    print()

    # Prepare test data - same as Mojo benchmarks
    text_1000 = make_test_string(1000)
    text_10000 = make_test_string(10000)
    text_range_10000 = make_test_string(10000) + "0123456789"

    text_1000 += "hello world"
    text_10000 += "hello world"

    short_text = "hello world this is a test with hello again and hello there"
    medium_text = short_text * 100
    long_text = short_text * 1000
    email_text = (
        "test@example.com user@test.org admin@example.com support@example.com"
        " no-reply@example.com"
        * 50
    )

    print("| name                      | med (ms)              | iters  |")
    print("|---------------------------|-----------------------|--------|")

    # ===== Literal Matching Benchmarks =====
    benchmark_search("literal_match_short", "hello", text_1000, 2000)
    benchmark_search("literal_match_long", "hello", text_10000, 2000)

    # ===== Wildcard and Quantifier Benchmarks =====
    benchmark_match_first("wildcard_match_any", ".*", text_10000, 1000)
    benchmark_match_first("quantifier_zero_or_more", "a*", text_10000, 1000)
    benchmark_match_first("quantifier_one_or_more", "a+", text_10000, 1000)
    benchmark_match_first("quantifier_zero_or_one", "a?", text_10000, 1000)

    # ===== Character Range Benchmarks =====
    benchmark_match_first("range_lowercase", "[a-z]+", text_range_10000, 1000)
    benchmark_search("range_digits", "[0-9]+", text_range_10000, 1000)
    benchmark_match_first(
        "range_alphanumeric", "[a-zA-Z0-9]+", text_range_10000, 1000
    )

    # ===== Predefined Character Class Benchmarks =====
    benchmark_search("predefined_digits", r"\d+", text_range_10000, 1000)
    benchmark_match_first("predefined_word", r"\w+", text_range_10000, 1000)

    # ===== Anchor Benchmarks =====
    benchmark_match_first("anchor_start", "^abc", text_10000, 2000)
    benchmark_match_first("anchor_end", "xyz$", text_10000, 2000)

    # ===== Alternation Benchmarks =====
    benchmark_match_first("alternation_simple", "a|b|c", text_10000, 1000)
    benchmark_match_first("group_alternation", "(a|b)", text_10000, 1000)

    # ===== Optimization Showcase Benchmarks =====
    fruit_text = (
        "I love eating apple and banana and cherry and date and elderberry and"
        " fig and grape with honey"
    )
    benchmark_search(
        "large_8_alternations",
        "(apple|banana|cherry|date|elderberry|fig|grape|honey)",
        fruit_text,
        1000,
    )

    nested_text = "Testing deep nested patterns with abcdefgh characters"
    benchmark_search(
        "deep_nested_groups_depth4",
        "(?:(?:(?:a|b)|(?:c|d))|(?:(?:e|f)|(?:g|h)))",
        nested_text,
        1000,
    )

    user_text = (
        "Login attempts: user123 failed, admin456 success, guest789 failed,"
        " root000 success, test111 pending, demo222 active, sample333 inactive,"
        " client444 locked"
    )
    benchmark_search(
        "literal_heavy_alternation",
        "(user123|admin456|guest789|root000|test111|demo222|sample333|client444)",
        user_text,
        1000,
    )

    mixed_text = (
        "Found: hello123ab, world456cd, test789ef, demo012gh, sample345ij in"
        " the data"
    )
    benchmark_search(
        "complex_group_5_children",
        "(hello|world|test|demo|sample)[0-9]{3}[a-z]{2}",
        mixed_text,
        1000,
    )

    # ===== Global Matching (findall) =====
    benchmark_findall("match_all_simple", "hello", medium_text, 200)
    benchmark_findall("match_all_digits", "[0-9]+", text_range_10000 * 10, 200)

    # ===== Literal Optimization Benchmarks =====
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
    complex_email_text = (
        "Contact: john@example.com, support@test.org, admin@company.net" * 20
    )
    benchmark_findall(
        "complex_email",
        "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
        complex_email_text,
        40,
    )

    complex_number_text = (
        "Price: $123.45, Quantity: 67, Total: $890.12, Tax: 15.5%" * 100
    )
    benchmark_findall(
        "complex_number", "[0-9]+\\.[0-9]+", complex_number_text, 500
    )

    # ===== US Phone Number Benchmarks =====
    phone_text = make_phone_test_data(1000)

    benchmark_findall("simple_phone", "\\d{3}-\\d{3}-\\d{4}", phone_text, 100)
    benchmark_findall(
        "flexible_phone",
        "\\(?\\d{3}\\)?[\\s.-]?\\d{3}[\\s.-]?\\d{4}",
        phone_text,
        100,
    )
    benchmark_findall(
        "multi_format_phone",
        "\\(?\\d{3}\\)?[\\s.-]\\d{3}[\\s.-]\\d{4}|\\d{3}-\\d{3}-\\d{4}|\\d{10}",
        phone_text,
        50,
    )
    benchmark_match_first(
        "phone_validation",
        "^\\+?1?[\\s.-]?\\(?([2-9]\\d{2})\\)?[\\s.-]?([2-9]\\d{2})[\\s.-]?(\\d{4})$",
        "234-567-8901",
        500,
    )

    # ===== DFA-Optimized Phone Number Benchmarks =====
    benchmark_findall(
        "dfa_simple_phone", "[0-9]{3}-[0-9]{3}-[0-9]{4}", phone_text, 100
    )
    benchmark_findall(
        "dfa_paren_phone", "\\([0-9]{3}\\) [0-9]{3}-[0-9]{4}", phone_text, 100
    )
    benchmark_findall(
        "dfa_dot_phone", "[0-9]{3}\\.[0-9]{3}\\.[0-9]{4}", phone_text, 100
    )
    benchmark_findall("dfa_digits_only", "[0-9]{10}", phone_text, 100)

    # National Phone Number Validation (Complex Pattern)
    national_phone_text = make_complex_pattern_test_data(500)
    national_phone_pattern = (
        r"(?:3052(?:0[0-8]|[1-9]\d)|5056(?:[0-35-9]\d|4[0-68]))\d{4}|"
        r"(?:2742|305[3-9]|472[247-9]|505[2-57-9]|983[2-47-9])\d{6}|"
        r"(?:2(?:0[1-35-9]|1[02-9]|2[03-57-9]|3[1459]|4[08]|5[1-46]|6[0279]|7[0269]|8[13])|"
        r"3(?:0[1-47-9]|1[02-9]|2[0135-79]|3[0-24679]|4[167]|5[0-2]|6[01349]|8[056])|"
        r"4(?:0[124-9]|1[02-579]|2[3-5]|3[0245]|4[023578]|58|6[349]|7[0589]|8[04])|"
        r"5(?:0[1-47-9]|1[0235-8]|20|3[0149]|4[01]|5[179]|6[1-47]|7[0-5]|8[0256])|"
        r"6(?:0[1-35-9]|1[024-9]|2[03689]|3[016]|4[0156]|5[01679]|6[0-279]|78|8[0-29])|"
        r"7(?:0[1-46-8]|1[2-9]|2[04-8]|3[0-247]|4[037]|5[47]|6[02359]|7[0-59]|8[156])|"
        r"8(?:0[1-68]|1[02-8]|2[0168]|3[0-2589]|4[03578]|5[046-9]|6[02-5]|7[028])|"
        r"9(?:0[1346-9]|1[02-9]|2[0589]|3[0146-8]|4[01357-9]|5[12469]|7[0-389]|8[04-69]))[2-9]\d{6}"
    )
    benchmark_findall(
        "national_phone_validation",
        national_phone_pattern,
        national_phone_text,
        10,
    )

    # ===== US Toll-Free Numbers Benchmarks =====
    toll_free_text = (
        "Call 8001234567 or 9005551234 for assistance. Try 8775559999 or"
        " 8006667777."
        * 100
    )

    benchmark_findall("toll_free_simple", "[89]00\\d{6}", toll_free_text, 100)
    benchmark_findall(
        "toll_free_complex",
        "8(?:00|33|44|55|66|77|88)[2-9]\\d{6}",
        toll_free_text,
        100,
    )

    # ===== Quantifier Parser Optimization Benchmarks =====
    serial_number_text = (
        "Serial: ABC1234-DEF5678-GHI9012 Model: XYZ123-ABC456-DEF789 "
        "Part: MNO345-PQR678-STU901 Code: VWX234-YZA567-BCD890 "
        * 50
    )

    datetime_text = (
        "2024-01-15 14:30:25.123 2024-02-28 09:45:30.456 "
        "2024-03-10 16:20:15.789 2024-04-05 11:35:40.012 "
        * 100
    )

    structured_data_text = (
        "Record: USER12345-DEPT678-LOC901-ID234 Status:"
        " ACTIVE567-FLAG890-CODE123 Transaction: TXN9876-AMT543-FEE210-TAX087"
        " Reference: REF1357-NUM246-CHK802 "
        * 75
    )

    benchmark_findall(
        "single_quantifier_digits", "[0-9]{4}", serial_number_text, 200
    )
    benchmark_findall(
        "single_quantifier_alpha", "[A-Z]{3}", serial_number_text, 200
    )
    benchmark_findall(
        "dual_quantifiers", "[A-Z]{3}[0-9]{4}", serial_number_text, 150
    )
    benchmark_findall(
        "triple_quantifiers",
        "[A-Z]{3}[0-9]{4}-[A-Z]{3}[0-9]{3}",
        serial_number_text,
        100,
    )
    benchmark_findall(
        "quad_quantifiers",
        "[A-Z]{3}[0-9]{4}-[A-Z]{3}[0-9]{3}-[A-Z]{3}[0-9]{3}",
        serial_number_text,
        100,
    )
    benchmark_findall(
        "range_quantifiers", "[A-Z]{2,4}[0-9]{3,5}", serial_number_text, 100
    )
    benchmark_findall(
        "mixed_range_quantifiers",
        "[A-Z]{1,3}-[0-9]{2,4}-[A-Z]{2,3}[0-9]{3,4}",
        serial_number_text,
        75,
    )
    benchmark_findall(
        "datetime_quantifiers",
        "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}",
        datetime_text,
        100,
    )
    benchmark_findall(
        "flexible_datetime",
        "[0-9]{4}-[0-9]{1,2}-[0-9]{1,2} [0-9]{1,2}:[0-9]{2}:[0-9]{2}",
        datetime_text,
        100,
    )
    benchmark_findall(
        "dense_quantifiers",
        "[A-Z]{2}[0-9]{5}-[A-Z]{4}[0-9]{3}-[A-Z]{3}[0-9]{3}-[A-Z]{2}[0-9]{3}",
        structured_data_text,
        50,
    )
    benchmark_findall(
        "ultra_dense_quantifiers",
        "[A-Z]{1,2}[0-9]{3,5}-[A-Z]{2,4}[0-9]{2,4}-[A-Z]{1,3}[0-9]{2,4}-[A-Z]{2,3}[0-9]{2,3}",
        structured_data_text,
        25,
    )
    benchmark_findall(
        "grouped_quantifiers",
        "([A-Z]{3}[0-9]{4})-([A-Z]{3}[0-9]{3})",
        serial_number_text,
        100,
    )
    benchmark_findall(
        "alternation_quantifiers",
        "([A-Z]{2,3}[0-9]{3,4})|([0-9]{4}-[A-Z]{3})",
        structured_data_text,
        75,
    )

    optimization_test_text = (
        "Transaction: TXN12345-DEPT678-LOC90123-ID4567 Status:"
        " ACTIVE12-FLAG890-CODE1234 Reference: REF13579-NUM24680-CHK80246"
        " Product: PROD123-CAT456-TYPE789-SUB012 "
        * 100
    )

    benchmark_findall(
        "optimize_range_quantifier", r"a{2,4}", "aaaabbbbccccdddd" * 500, 1000
    )
    benchmark_findall(
        "optimize_multiple_quantifiers",
        r"[A-Z]{3}[0-9]{4}-[A-Z]{3}[0-9]{3}-[A-Z]{2}[0-9]{2}",
        optimization_test_text,
        200,
    )
    benchmark_findall(
        "optimize_phone_quantifiers",
        r"[0-9]{3}-[0-9]{3}-[0-9]{4}",
        "Call 555-123-4567 or 800-555-1234 or 900-876-5432 for help. " * 200,
        300,
    )
    benchmark_findall(
        "optimize_large_quantifiers",
        r"[A-Z]{10,20}[0-9]{15,25}",
        "PREFIX" + "A" * 15 + "1" * 20 + "SUFFIX " * 50,
        100,
    )
    benchmark_findall(
        "optimize_extreme_quantifiers",
        r"a{1}b{2}c{3}d{4}e{5}f{6}g{7}h{8}",
        "abcccddddeeeeeffffffggggggghhhhhhhhSEPARATOR" * 20,
        500,
    )

    # ===== is_match (Bool-only) Benchmarks =====
    text_digits_10000 = "0123456789" * 1000 + "abcdefghijklmnopqrstuvwxyz"
    benchmark_is_match("is_match_lowercase", "[a-z]+", text_range_10000, 1000)
    benchmark_is_match("is_match_digits", "[0-9]+", text_digits_10000, 1000)
    benchmark_is_match(
        "is_match_alphanumeric", "[a-zA-Z0-9]+", text_range_10000, 1000
    )
    benchmark_is_match(
        "is_match_predefined_digits", r"\d+", text_digits_10000, 1000
    )
    benchmark_is_match(
        "is_match_predefined_word", r"\w+", text_range_10000, 1000
    )

    # ===== sub (replacement) Benchmarks =====
    # Simple literal replacement
    benchmark_sub(
        "sub_literal",
        "hello",
        "REPLACED",
        short_text * 20,
        100,
    )
    # Digit replacement in phone-like text
    benchmark_sub(
        "sub_digits",
        r"\d{3}-\d{3}-\d{4}",
        "XXX-XXX-XXXX",
        phone_text,
        10,
    )
    # Character class replacement
    benchmark_sub(
        "sub_char_class",
        "[0-9]+",
        "#",
        phone_text,
        10,
    )
    # Whitespace normalization
    benchmark_sub(
        "sub_whitespace",
        r"\s+",
        " ",
        "  hello   world   foo   bar   baz  " * 100,
        50,
    )
    # Limited count replacement (first 5 only)
    benchmark_sub(
        "sub_limited_count",
        "hello",
        "HI",
        short_text * 100,
        100,
    )

    print()
    export_json_results()


if __name__ == "__main__":
    main()
