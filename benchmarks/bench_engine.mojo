from std.sys import argv
from std.time import perf_counter_ns
from regex.matcher import compile_regex, sub


# ===-----------------------------------------------------------------------===#
# Test Data Generation
# ===-----------------------------------------------------------------------===#


def make_test_string(length: Int) -> String:
    """Generate test string by repeating alphabet."""
    var result = String()
    var pattern = String("abcdefghijklmnopqrstuvwxyz")
    var pattern_len = len(pattern)
    var full_repeats = length // pattern_len
    var remainder = length % pattern_len

    for _ in range(full_repeats):
        result += pattern
    for i in range(remainder):
        result += pattern[byte=i]
    return result


def make_phone_test_data(num_phones: Int) -> String:
    """Generate test data containing US phone numbers in various formats."""
    var result = String()
    var phone_patterns = List[String]()
    phone_patterns.append("555-123-4567")
    phone_patterns.append("(555) 123-4567")
    phone_patterns.append("555.123.4567")
    phone_patterns.append("5551234567")
    phone_patterns.append("+1-555-123-4567")
    phone_patterns.append("1-555-123-4568")
    phone_patterns.append("(555)123-4569")
    phone_patterns.append("555 123 4570")
    var filler_text = " Contact us at "
    var extra_text = " or email support@company.com for assistance. "

    for i in range(num_phones):
        result += filler_text
        # Cycle through different phone patterns
        var pattern_idx = i % len(phone_patterns)
        result += phone_patterns[pattern_idx]
        result += extra_text

    return result


def make_complex_pattern_test_data(num_entries: Int) -> String:
    """Generate test data for US national phone number validation."""
    var result = String()
    var complex_patterns = List[String]()
    complex_patterns.append("305200123456")  # Matches first alternation
    complex_patterns.append("505601234567")  # Matches first alternation
    complex_patterns.append("274212345678")  # Matches second alternation
    complex_patterns.append("305912345678")  # Matches second alternation
    complex_patterns.append("212345672890")  # Matches third alternation
    complex_patterns.append("312345672890")  # Matches third alternation
    complex_patterns.append("412345672890")  # Matches third alternation
    complex_patterns.append("512345672890")  # Matches third alternation
    complex_patterns.append("1234567890")  # Should NOT match
    complex_patterns.append("30520")  # Should NOT match (too short)
    var filler_text = " ID: "
    var extra_text = " Status: ACTIVE "

    for i in range(num_entries):
        result += filler_text
        # Cycle through different patterns (including non-matches)
        var pattern_idx = i % len(complex_patterns)
        result += complex_patterns[pattern_idx]
        result += extra_text

    return result


# ===-----------------------------------------------------------------------===#
# Benchmark Infrastructure
# ===-----------------------------------------------------------------------===#

# Target runtime per benchmark: 500ms prod, 50ms dev
comptime TARGET_RUNTIME_NS_PROD = 500_000_000
comptime TARGET_RUNTIME_NS_DEV = 50_000_000
comptime MAX_ITERATIONS = 200_000
comptime WARMUP_ITERATIONS = 10
# Minimum time per sample: 10ms prod (stable), 1ms dev (fast, noisier)
comptime MIN_SAMPLE_NS_PROD = 10_000_000
comptime MIN_SAMPLE_NS_DEV = 1_000_000


# ===-----------------------------------------------------------------------===#
# CLI flags
# ===-----------------------------------------------------------------------===#
#
# Supported:
#   --dev              Fast mode: 1ms samples, 50ms per-bench budget (10x)
#   --filter=<substr>  Only run benchmarks whose name contains <substr>
#
# Example: mojo run -I src benchmarks/bench_engine.mojo -- --dev --filter=sub_


def _arg_has(flag: StaticString) -> Bool:
    """True if `flag` appears as a bare argv entry."""
    var args = argv()
    for i in range(1, len(args)):
        if args[i] == flag:
            return True
    return False


def _arg_value(prefix: StaticString) -> String:
    """Return the suffix of an argv entry starting with `prefix`, or empty."""
    var args = argv()
    var plen = len(prefix)
    for i in range(1, len(args)):
        var a = args[i]
        if len(a) >= plen and a[byte=0:plen] == prefix:
            return String(a[byte=plen:])
    return ""


def _dev_mode() -> Bool:
    return _arg_has("--dev")


def _min_sample_ns() -> UInt:
    return UInt(MIN_SAMPLE_NS_DEV) if _dev_mode() else UInt(MIN_SAMPLE_NS_PROD)


def _target_runtime_ns() -> UInt:
    return UInt(TARGET_RUNTIME_NS_DEV) if _dev_mode() else UInt(
        TARGET_RUNTIME_NS_PROD
    )


def _bench_skip(name: String) -> Bool:
    """True if --filter=<substr> is set and `name` does not contain it."""
    var f = _arg_value("--filter=")
    return len(f) > 0 and f not in name


def _find_median(mut times: List[Float64]) -> Float64:
    """Find median of a list of times using simple insertion sort."""
    var n = len(times)
    if n == 0:
        return 0.0
    # Insertion sort (fine for small N)
    for i in range(1, n):
        var key = times[i]
        var j = i - 1
        while j >= 0 and times[j] > key:
            times[j + 1] = times[j]
            j -= 1
        times[j + 1] = key
    if n % 2 == 1:
        return times[n // 2]
    return (times[n // 2 - 1] + times[n // 2]) / 2.0


def _print_result(name: String, median_ms: Float64, total_iters: Int):
    """Print benchmark result in table format."""
    var padded_name = name + " " * (25 - len(name))
    print(
        "| "
        + padded_name
        + " | "
        + String(median_ms)[byte=:24]
        + " " * (25 - len(String(median_ms)[byte=:24]))
        + " | "
        + String(total_iters)
        + " " * (6 - len(String(total_iters)))
        + " |"
    )


def benchmark_match_first(
    name: String, pattern: String, text: String, internal_iterations: Int
) raises:
    """Benchmark match_first with pre-compiled regex and median timing."""
    if _bench_skip(name):
        return
    var min_sample_ns = _min_sample_ns()
    var target_runtime_ns = _target_runtime_ns()

    # Pre-compile regex outside timing loop
    var compiled = compile_regex(pattern)
    var stats = compiled.get_stats()
    print("[ENGINE] " + name + " -> " + stats)

    # Warmup with compiled regex
    for _ in range(WARMUP_ITERATIONS):
        _ = compiled.match_first(text)

    # Auto-calibrate: ensure each sample takes >= min_sample_ns
    var iters = internal_iterations
    var cal_start = perf_counter_ns()
    for _ in range(iters):
        _ = compiled.match_first(text)
    var cal_elapsed = perf_counter_ns() - cal_start
    if cal_elapsed < min_sample_ns:
        var multiplier = Int(min_sample_ns // cal_elapsed) + 1
        iters = iters * multiplier

    # Collect per-iteration times
    var times = List[Float64]()
    var total_time: UInt = 0
    var actual_iterations = 0

    while (
        total_time < UInt(target_runtime_ns)
        and actual_iterations < MAX_ITERATIONS
    ):
        var start_time = perf_counter_ns()

        for _ in range(iters):
            var result = compiled.match_first(text)
            if not result:
                print("ERROR: No match in", name, "for pattern:", pattern)
                return

        var end_time = perf_counter_ns()
        var elapsed = end_time - start_time
        total_time += elapsed
        actual_iterations += 1
        times.append(Float64(elapsed) / Float64(iters) / 1_000_000.0)

    var median_ms = _find_median(times)
    _print_result(name, median_ms, actual_iterations * iters)


def benchmark_search(
    name: String, pattern: String, text: String, internal_iterations: Int
) raises:
    """Benchmark search (match_next) with pre-compiled regex and median timing.
    """
    if _bench_skip(name):
        return
    var min_sample_ns = _min_sample_ns()
    var target_runtime_ns = _target_runtime_ns()

    var compiled = compile_regex(pattern)
    var stats = compiled.get_stats()
    print("[ENGINE] " + name + " -> " + stats)

    # Warmup with compiled regex
    for _ in range(WARMUP_ITERATIONS):
        _ = compiled.match_next(text)

    # Auto-calibrate: ensure each sample takes >= min_sample_ns
    var iters = internal_iterations
    var cal_start = perf_counter_ns()
    for _ in range(iters):
        _ = compiled.match_next(text)
    var cal_elapsed = perf_counter_ns() - cal_start
    if cal_elapsed < min_sample_ns:
        var multiplier = Int(min_sample_ns // cal_elapsed) + 1
        iters = iters * multiplier

    var times = List[Float64]()
    var total_time: UInt = 0
    var actual_iterations = 0

    while (
        total_time < UInt(target_runtime_ns)
        and actual_iterations < MAX_ITERATIONS
    ):
        var start_time = perf_counter_ns()

        for _ in range(iters):
            var result = compiled.match_next(text)
            if not result:
                print(
                    "ERROR: No search match in", name, "for pattern:", pattern
                )
                return

        var end_time = perf_counter_ns()
        var elapsed = end_time - start_time
        total_time += elapsed
        actual_iterations += 1
        times.append(Float64(elapsed) / Float64(iters) / 1_000_000.0)

    var median_ms = _find_median(times)
    _print_result(name, median_ms, actual_iterations * iters)


def benchmark_findall(
    name: String, pattern: String, text: String, internal_iterations: Int
) raises:
    """Benchmark findall with pre-compiled regex and median timing."""
    if _bench_skip(name):
        return
    var min_sample_ns = _min_sample_ns()
    var target_runtime_ns = _target_runtime_ns()

    var compiled = compile_regex(pattern)
    var stats = compiled.get_stats()
    print("[ENGINE] " + name + " -> " + stats)

    # Warmup with compiled regex
    for _ in range(WARMUP_ITERATIONS):
        _ = compiled.match_all(text)

    # Auto-calibrate: ensure each sample takes >= min_sample_ns
    var iters = internal_iterations
    var cal_start = perf_counter_ns()
    for _ in range(iters):
        _ = compiled.match_all(text)
    var cal_elapsed = perf_counter_ns() - cal_start
    if cal_elapsed < min_sample_ns:
        var multiplier = Int(min_sample_ns // cal_elapsed) + 1
        iters = iters * multiplier

    var times = List[Float64]()
    var total_time: UInt = 0
    var actual_iterations = 0

    while (
        total_time < UInt(target_runtime_ns)
        and actual_iterations < MAX_ITERATIONS
    ):
        var start_time = perf_counter_ns()

        for _ in range(iters):
            var results = compiled.match_all(text)
            if len(results) < 0:  # Always false, prevents optimization
                print("ERROR: Unexpected result")

        var end_time = perf_counter_ns()
        var elapsed = end_time - start_time
        total_time += elapsed
        actual_iterations += 1
        times.append(Float64(elapsed) / Float64(iters) / 1_000_000.0)

    var median_ms = _find_median(times)
    _print_result(name, median_ms, actual_iterations * iters)


def benchmark_is_match(
    name: String, pattern: String, text: String, internal_iterations: Int
) raises:
    """Benchmark is_match (bool-only) with pre-compiled regex and median timing.
    """
    if _bench_skip(name):
        return
    var min_sample_ns = _min_sample_ns()
    var target_runtime_ns = _target_runtime_ns()

    var compiled = compile_regex(pattern)
    var stats = compiled.get_stats()
    print("[ENGINE] " + name + " -> " + stats)

    # Warmup with compiled regex
    for _ in range(WARMUP_ITERATIONS):
        _ = compiled.is_match(text)

    # Auto-calibrate: ensure each sample takes >= min_sample_ns
    var iters = internal_iterations
    var cal_start = perf_counter_ns()
    for _ in range(iters):
        _ = compiled.is_match(text)
    var cal_elapsed = perf_counter_ns() - cal_start
    if cal_elapsed < min_sample_ns:
        var multiplier = Int(min_sample_ns // cal_elapsed) + 1
        iters = iters * multiplier

    # Collect per-iteration times
    var times = List[Float64]()
    var total_time: UInt = 0
    var actual_iterations = 0

    while (
        total_time < UInt(target_runtime_ns)
        and actual_iterations < MAX_ITERATIONS
    ):
        var start_time = perf_counter_ns()

        for _ in range(iters):
            var result = compiled.is_match(text)
            if not result:
                print("ERROR: No match in", name, "for pattern:", pattern)
                return

        var end_time = perf_counter_ns()
        var elapsed = end_time - start_time
        total_time += elapsed
        actual_iterations += 1
        times.append(Float64(elapsed) / Float64(iters) / 1_000_000.0)

    var median_ms = _find_median(times)
    _print_result(name, median_ms, actual_iterations * iters)


def benchmark_sub(
    name: String,
    pattern: String,
    repl: String,
    text: String,
    internal_iterations: Int,
) raises:
    """Benchmark sub() with pre-compiled regex and median timing."""
    if _bench_skip(name):
        return
    var min_sample_ns = _min_sample_ns()
    var target_runtime_ns = _target_runtime_ns()

    # Warmup
    for _ in range(WARMUP_ITERATIONS):
        _ = sub(pattern, repl, text)

    # Auto-calibrate
    var iters = internal_iterations
    var cal_start = perf_counter_ns()
    for _ in range(iters):
        _ = sub(pattern, repl, text)
    var cal_elapsed = perf_counter_ns() - cal_start
    if cal_elapsed < min_sample_ns:
        var multiplier = Int(min_sample_ns // cal_elapsed) + 1
        iters = iters * multiplier

    var times = List[Float64]()
    var total_time: UInt = 0
    var actual_iterations = 0

    while (
        total_time < UInt(target_runtime_ns)
        and actual_iterations < MAX_ITERATIONS
    ):
        var start_time = perf_counter_ns()

        for _ in range(iters):
            var result = sub(pattern, repl, text)
            if len(result) == 0 and len(text) > 0:
                print("ERROR: Empty result in", name)
                return

        var end_time = perf_counter_ns()
        var elapsed = end_time - start_time
        total_time += elapsed
        actual_iterations += 1
        times.append(Float64(elapsed) / Float64(iters) / 1_000_000.0)

    var median_ms = _find_median(times)
    _print_result(name, median_ms, actual_iterations * iters)


# ===-----------------------------------------------------------------------===#
# Main Benchmark Runner
# ===-----------------------------------------------------------------------===#


def main() raises:
    """Run all regex benchmarks with manual timing."""
    print("=== REGEX ENGINE BENCHMARKS (Pre-compiled, Median Timing) ===")
    if _dev_mode():
        print(
            "Dev mode: 1ms samples, 50ms per-bench budget (use for fast iteration)"
        )
    else:
        print(
            "Target runtime: 500ms per benchmark, reporting median iteration time"
        )
    var filter = _arg_value("--filter=")
    if len(filter) > 0:
        print("Filter: only running benchmarks matching '" + filter + "'")
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
    benchmark_search("predefined_digits", "\\d+", text_range_10000, 1000)

    benchmark_match_first("predefined_word", "\\w+", text_range_10000, 1000)

    # ===== Anchor Benchmarks =====
    benchmark_match_first("anchor_start", "^abc", text_10000, 2000)

    benchmark_match_first("anchor_end", "xyz$", text_10000, 2000)

    # ===== Alternation Benchmarks =====
    benchmark_match_first("alternation_simple", "a|b|c", text_10000, 1000)

    benchmark_match_first("group_alternation", "(a|b)", text_10000, 1000)

    # ===== NEW: Optimization Showcase Benchmarks =====

    # Test case 1: Large alternation (5+ branches) - benefits from increased branch limit (3->8)
    var large_alternation = (
        "(apple|banana|cherry|date|elderberry|fig|grape|honey)"
    )
    var fruit_text = "I love eating apple and banana and cherry and date and elderberry and fig and grape with honey"
    benchmark_search(
        "large_8_alternations", large_alternation, fruit_text, 1000
    )

    # Test case 2: Deeply nested groups (depth 4) - benefits from increased depth tolerance (3->4)
    var deep_nested = "(?:(?:(?:a|b)|(?:c|d))|(?:(?:e|f)|(?:g|h)))"
    var nested_text = "Testing deep nested patterns with abcdefgh characters"
    benchmark_search(
        "deep_nested_groups_depth4", deep_nested, nested_text, 1000
    )

    # Test case 3: Literal-heavy alternation - benefits from 80% threshold detection
    var literal_heavy = "(user123|admin456|guest789|root000|test111|demo222|sample333|client444)"
    var user_text = "Login attempts: user123 failed, admin456 success, guest789 failed, root000 success, test111 pending, demo222 active, sample333 inactive, client444 locked"
    benchmark_search(
        "literal_heavy_alternation", literal_heavy, user_text, 1000
    )

    # Test case 4: Complex group with 5 children - benefits from increased children limit (3->5)
    var complex_group = "(hello|world|test|demo|sample)[0-9]{3}[a-z]{2}"
    var mixed_text = "Found: hello123ab, world456cd, test789ef, demo012gh, sample345ij in the data"
    benchmark_search(
        "complex_group_5_children", complex_group, mixed_text, 1000
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
    var complex_email_text = (
        "Contact: john@example.com, support@test.org, admin@company.net" * 20
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
    benchmark_findall(
        "complex_number", "[0-9]+\\.[0-9]+", complex_number_text, 500
    )

    # ===== US Phone Number Benchmarks =====
    var phone_text = make_phone_test_data(1000)

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

    # ===== Pure DFA Phone Number Benchmarks (Literal Patterns) =====

    # Generate literal test data
    var literal_phone_text = "Contact us at 555-123-4567 or call (555) 123-4567. Our fax is 555.123.4567."

    benchmark_findall("pure_dfa_dash", "555-123-4567", literal_phone_text, 1000)

    benchmark_findall(
        "pure_dfa_paren", "\\(555\\) 123-4567", literal_phone_text, 1000
    )

    benchmark_findall(
        "pure_dfa_dot", "555\\.123\\.4567", literal_phone_text, 1000
    )

    # ===== Smart Multi-Pattern Phone Matcher =====
    # Test smart matching approach - try DFA patterns first, fallback to comprehensive
    benchmark_findall(
        "smart_phone_primary", "[0-9]{3}-[0-9]{3}-[0-9]{4}", phone_text, 100
    )

    # National Phone Number Validation (Complex Pattern)
    var national_phone_text = make_complex_pattern_test_data(500)
    benchmark_findall(
        "national_phone_validation",
        "(?:3052(?:0[0-8]|[1-9]\\d)|5056(?:[0-35-9]\\d|4[0-68]))\\d{4}|(?:2742|305[3-9]|472[247-9]|505[2-57-9]|983[2-47-9])\\d{6}|(?:2(?:0[1-35-9]|1[02-9]|2[03-57-9]|3[1459]|4[08]|5[1-46]|6[0279]|7[0269]|8[13])|3(?:0[1-47-9]|1[02-9]|2[0135-79]|3[0-24679]|4[167]|5[0-2]|6[01349]|8[056])|4(?:0[124-9]|1[02-579]|2[3-5]|3[0245]|4[023578]|58|6[349]|7[0589]|8[04])|5(?:0[1-47-9]|1[0235-8]|20|3[0149]|4[01]|5[179]|6[1-47]|7[0-5]|8[0256])|6(?:0[1-35-9]|1[024-9]|2[03689]|3[016]|4[0156]|5[01679]|6[0-279]|78|8[0-29])|7(?:0[1-46-8]|1[2-9]|2[04-8]|3[0-247]|4[037]|5[47]|6[02359]|7[0-59]|8[156])|8(?:0[1-68]|1[02-8]|2[0168]|3[0-2589]|4[03578]|5[046-9]|6[02-5]|7[028])|9(?:0[1346-9]|1[02-9]|2[0589]|3[0146-8]|4[01357-9]|5[12469]|7[0-389]|8[04-69]))[2-9]\\d{6}",
        national_phone_text,
        10,
    )

    # ===== US Toll-Free Numbers Benchmarks =====

    # Generate toll-free test data
    var toll_free_text = (
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
    # These benchmarks test patterns with multiple {n,m} quantifiers

    # Generate test data for quantifier-intensive patterns
    var serial_number_text = (
        "Serial: ABC1234-DEF5678-GHI9012 Model: XYZ123-ABC456-DEF789 "
        "Part: MNO345-PQR678-STU901 Code: VWX234-YZA567-BCD890 "
        * 50
    )

    var datetime_text = (
        "2024-01-15 14:30:25.123 2024-02-28 09:45:30.456 "
        "2024-03-10 16:20:15.789 2024-04-05 11:35:40.012 "
        * 100
    )

    var structured_data_text = (
        "Record: USER12345-DEPT678-LOC901-ID234 Status:"
        " ACTIVE567-FLAG890-CODE123 Transaction: TXN9876-AMT543-FEE210-TAX087"
        " Reference: REF1357-NUM246-CHK802 "
        * 75
    )

    # Single quantifier patterns (baseline)
    benchmark_findall(
        "single_quantifier_digits", "[0-9]{4}", serial_number_text, 200
    )
    benchmark_findall(
        "single_quantifier_alpha", "[A-Z]{3}", serial_number_text, 200
    )

    # Multiple quantifier patterns - these benefit most from the optimization
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

    # Complex quantifier ranges {min,max} - stress test the parser optimization
    benchmark_findall(
        "range_quantifiers", "[A-Z]{2,4}[0-9]{3,5}", serial_number_text, 100
    )
    benchmark_findall(
        "mixed_range_quantifiers",
        "[A-Z]{1,3}-[0-9]{2,4}-[A-Z]{2,3}[0-9]{3,4}",
        serial_number_text,
        75,
    )

    # DateTime patterns with many quantifiers
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

    # High quantifier density patterns - maximum parser stress
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

    # Nested quantifiers within groups
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

    # Optimization test data for quantifier stress testing
    var optimization_test_text = (
        "Transaction: TXN12345-DEPT678-LOC90123-ID4567 Status:"
        " ACTIVE12-FLAG890-CODE1234 Reference: REF13579-NUM24680-CHK80246"
        " Product: PROD123-CAT456-TYPE789-SUB012 "
        * 100
    )

    # Most significant optimization cases from analysis
    benchmark_findall(
        "optimize_range_quantifier", "a{2,4}", "aaaabbbbccccdddd" * 500, 1000
    )
    benchmark_findall(
        "optimize_multiple_quantifiers",
        "[A-Z]{3}[0-9]{4}-[A-Z]{3}[0-9]{3}-[A-Z]{2}[0-9]{2}",
        optimization_test_text,
        200,
    )
    benchmark_findall(
        "optimize_phone_quantifiers",
        "[0-9]{3}-[0-9]{3}-[0-9]{4}",
        "Call 555-123-4567 or 800-555-1234 or 900-876-5432 for help. " * 200,
        300,
    )
    benchmark_findall(
        "optimize_large_quantifiers",
        "[A-Z]{10,20}[0-9]{15,25}",
        "PREFIX" + "A" * 15 + "1" * 20 + "SUFFIX " * 50,
        100,
    )
    benchmark_findall(
        "optimize_extreme_quantifiers",
        "a{1}b{2}c{3}d{4}e{5}f{6}g{7}h{8}",
        "abcccddddeeeeeffffffggggggghhhhhhhhSEPARATOR" * 20,
        500,
    )

    # ===== is_match (Bool-only) Benchmarks =====
    var text_digits_10000 = "0123456789" * 1000 + "abcdefghijklmnopqrstuvwxyz"
    benchmark_is_match("is_match_lowercase", "[a-z]+", text_range_10000, 1000)
    benchmark_is_match("is_match_digits", "[0-9]+", text_digits_10000, 1000)
    benchmark_is_match(
        "is_match_alphanumeric", "[a-zA-Z0-9]+", text_range_10000, 1000
    )
    benchmark_is_match(
        "is_match_predefined_digits", "\\d+", text_digits_10000, 1000
    )
    benchmark_is_match(
        "is_match_predefined_word", "\\w+", text_range_10000, 1000
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
        "\\d{3}-\\d{3}-\\d{4}",
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
        "\\s+",
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
    # Group-reference substitution (exercises fixed-width DFA fast path)
    var phone_numbers = String()
    for _ in range(100):
        phone_numbers += "Call 6502530000 or 4155551234 today. "
    benchmark_sub(
        "sub_group_phone_fmt",
        "(\\d{3})(\\d{3})(\\d{4})",
        "\\1-\\2-\\3",
        phone_numbers,
        10,
    )
    # Group-reference with literals between groups
    benchmark_sub(
        "sub_group_date_fmt",
        "(\\d{4})-(\\d{2})-(\\d{2})",
        "\\2/\\3/\\1",
        "Event on 2026-04-12 and 2025-12-25 and 2024-01-01. " * 50,
        20,
    )
    # General group path (not fixed-width, falls through to NFA)
    benchmark_sub(
        "sub_group_word_swap",
        "(\\w+) (\\w+)",
        "\\2 \\1",
        "hello world foo bar baz qux " * 50,
        20,
    )

    # ===== Sparse Match Benchmarks (long text, rare matches) =====
    # These exercise the first-byte prefilter skip on long non-matching spans.
    # ~1 match per 2KB of filler text.
    var filler = (
        "The quick brown fox jumps over the lazy dog. " * 40
    )  # ~1800 bytes
    var sparse_phone_text = String()
    for _ in range(20):
        sparse_phone_text += filler + "Call 555-123-4567 now. "

    benchmark_findall(
        "sparse_phone_findall",
        "\\d{3}-\\d{3}-\\d{4}",
        sparse_phone_text,
        5,
    )
    benchmark_search(
        "sparse_phone_search",
        "\\(\\d{3}\\)\\s\\d{3}-\\d{4}",
        filler * 50 + "(555) 123-4567" + filler * 50,
        5,
    )
    benchmark_findall(
        "sparse_email_findall",
        "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
        (filler + "Contact admin@example.com for details. ") * 10,
        5,
    )
    # Sparse match with NFA/lazy-DFA pattern (flexible phone with optional parens)
    var sparse_flex_text = String()
    for _ in range(10):
        sparse_flex_text += filler + "Reach us at (555) 123-4567 today. "
    benchmark_findall(
        "sparse_flex_phone_findall",
        "\\(?\\d{3}\\)?[\\s.-]?\\d{3}[\\s.-]?\\d{4}",
        sparse_flex_text,
        2,
    )

    # ===== Many-State Lazy DFA Benchmarks (NANPA) =====
    # US NANPA area code pattern: 8 outer branches with nested alternation
    # and character classes. 290 PikeVM instructions, exercises lazy DFA
    # with many reachable states.
    comptime NANPA_PATTERN = "(?:2(?:0[1-35-9]|1[02-9]|2[03-57-9]|3[1459]|4[08]|5[1-46]|6[0279]|7[0269]|8[13])|3(?:0[1-47-9]|1[02-9]|2[0135-79]|3[0-24679]|4[167]|5[0-2]|6[01349]|8[056])|4(?:0[124-9]|1[02-579]|2[3-5]|3[0245]|4[023578]|58|6[349]|7[0589]|8[04])|5(?:0[1-47-9]|1[0235-8]|20|3[0149]|4[01]|5[179]|6[1-47]|7[0-5]|8[0256])|6(?:0[1-35-9]|1[024-9]|2[03689]|3[016]|4[0156]|5[01679]|6[0-279]|78|8[0-29])|7(?:0[1-46-8]|1[2-9]|2[04-8]|3[0-247]|4[037]|5[47]|6[02359]|7[0-59]|8[156])|8(?:0[1-68]|1[02-8]|2[0168]|3[0-2589]|4[03578]|5[046-9]|6[02-5]|7[028])|9(?:0[1346-9]|1[02-9]|2[0589]|3[0146-8]|4[01357-9]|5[12469]|7[0-389]|8[04-69]))[2-9]\\d{6}"
    var nanpa_text = String()
    for _ in range(50):
        nanpa_text += "Call 6502530000 or 2125551234 or 9175559876. "
    benchmark_findall("nanpa_findall", NANPA_PATTERN, nanpa_text, 2)
    benchmark_search("nanpa_search", NANPA_PATTERN, nanpa_text, 50)
    benchmark_match_first("nanpa_match_first", NANPA_PATTERN, "6502530000", 500)
