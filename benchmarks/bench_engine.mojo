from time import perf_counter_ns
from regex import match_first, findall, search


# ===-----------------------------------------------------------------------===#
# Test Data Generation
# ===-----------------------------------------------------------------------===#


fn make_test_string(length: Int) -> String:
    """Generate test string by repeating alphabet."""
    var result = String()
    var pattern = String("abcdefghijklmnopqrstuvwxyz")
    var pattern_len = len(pattern)
    var full_repeats = length // pattern_len
    var remainder = length % pattern_len

    for _ in range(full_repeats):
        result += pattern
    for i in range(remainder):
        result += pattern[i]
    return result


fn make_phone_test_data(num_phones: Int) -> String:
    """Generate test data containing US phone numbers in various formats."""
    var result = String()
    var phone_patterns = List[String](
        "555-123-4567",
        "(555) 123-4567",
        "555.123.4567",
        "5551234567",
        "+1-555-123-4567",
        "1-555-123-4568",
        "(555)123-4569",
        "555 123 4570",
    )
    var filler_text = " Contact us at "
    var extra_text = " or email support@company.com for assistance. "

    for i in range(num_phones):
        result += filler_text
        # Cycle through different phone patterns
        var pattern_idx = i % len(phone_patterns)
        result += phone_patterns[pattern_idx]
        result += extra_text

    return result


fn make_complex_pattern_test_data(num_entries: Int) -> String:
    """Generate test data for US national phone number validation."""
    var result = String()
    var complex_patterns = List[String](
        "305200123456",  # Matches first alternation
        "505601234567",  # Matches first alternation
        "274212345678",  # Matches second alternation
        "305912345678",  # Matches second alternation
        "212345672890",  # Matches third alternation
        "312345672890",  # Matches third alternation
        "412345672890",  # Matches third alternation
        "512345672890",  # Matches third alternation
        "1234567890",  # Should NOT match
        "30520",  # Should NOT match (too short)
    )
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
# Manual Benchmark Infrastructure
# ===-----------------------------------------------------------------------===#


fn benchmark_match_first(
    name: String, pattern: String, text: String, internal_iterations: Int
) raises:
    """Benchmark match_first with manual timing."""

    # Warmup (3 iterations like Python)
    for _ in range(3):
        _ = match_first(pattern, text)

    # Target runtime: 100ms like Python
    var target_runtime = 100_000_000  # 100ms in nanoseconds
    var total_time: Int = 0
    var actual_iterations = 0

    # Run until we hit target runtime or max iterations
    while total_time < target_runtime and actual_iterations < 100_000:
        var start_time = perf_counter_ns()

        # Internal loop matches Python benchmark structure
        for _ in range(internal_iterations):
            var result = match_first(pattern, text)
            if not result:
                print("ERROR: No match in", name, "for pattern:", pattern)
                return

        var end_time = perf_counter_ns()
        total_time += end_time - start_time
        actual_iterations += 1

    # Calculate and print results
    var mean_time_per_match = (
        Float64(total_time)
        / Float64(actual_iterations)
        / Float64(internal_iterations)
    )
    var time_ms = mean_time_per_match / 1_000_000.0
    var total_matches = actual_iterations * internal_iterations

    # Format output to match Mojo's benchmark format
    var padded_name = name + " " * (25 - len(name))
    print(
        "| "
        + padded_name
        + " | "
        + String(time_ms)[:20]
        + " " * (21 - len(String(time_ms)[:20]))
        + " | "
        + String(total_matches)
        + " " * (6 - len(String(total_matches)))
        + " |"
    )


fn benchmark_search(
    name: String, pattern: String, text: String, internal_iterations: Int
) raises:
    """Benchmark search (match_next) with manual timing."""

    # Warmup (3 iterations like Python)
    for _ in range(3):
        _ = search(pattern, text)

    # Target runtime: 100ms like Python
    var target_runtime = 100_000_000  # 100ms in nanoseconds
    var total_time: Int = 0
    var actual_iterations = 0

    # Run until we hit target runtime or max iterations
    while total_time < target_runtime and actual_iterations < 100_000:
        var start_time = perf_counter_ns()

        # Internal loop matches Python benchmark structure
        for _ in range(internal_iterations):
            var result = search(pattern, text)
            if not result:
                print(
                    "ERROR: No search match in", name, "for pattern:", pattern
                )
                return

        var end_time = perf_counter_ns()
        total_time += end_time - start_time
        actual_iterations += 1

    # Calculate and print results
    var mean_time_per_match = (
        Float64(total_time)
        / Float64(actual_iterations)
        / Float64(internal_iterations)
    )
    var time_ms = mean_time_per_match / 1_000_000.0
    var total_matches = actual_iterations * internal_iterations

    # Format output to match Mojo's benchmark format
    var padded_name = name + " " * (25 - len(name))
    print(
        "| "
        + padded_name
        + " | "
        + String(time_ms)[:20]
        + " " * (21 - len(String(time_ms)[:20]))
        + " | "
        + String(total_matches)
        + " " * (6 - len(String(total_matches)))
        + " |"
    )


fn benchmark_findall(
    name: String, pattern: String, text: String, internal_iterations: Int
) raises:
    """Benchmark findall with manual timing."""

    # Warmup
    for _ in range(3):
        _ = findall(pattern, text)

    var target_runtime = 100_000_000
    var total_time: Int = 0
    var actual_iterations = 0

    while total_time < target_runtime and actual_iterations < 100_000:
        var start_time = perf_counter_ns()

        for _ in range(internal_iterations):
            var results = findall(pattern, text)
            # Touch the result to ensure it's not optimized away
            if len(results) < 0:  # Always false, but compiler doesn't know
                print("ERROR: Unexpected result")

        var end_time = perf_counter_ns()
        total_time += end_time - start_time
        actual_iterations += 1

    # Calculate and print results
    var mean_time_per_match = (
        Float64(total_time)
        / Float64(actual_iterations)
        / Float64(internal_iterations)
    )
    var time_ms = mean_time_per_match / 1_000_000.0
    var total_matches = actual_iterations * internal_iterations

    var padded_name = name + " " * (25 - len(name))
    print(
        "| "
        + padded_name
        + " | "
        + String(time_ms)[:20]
        + " " * (21 - len(String(time_ms)[:20]))
        + " | "
        + String(total_matches)
        + " " * (6 - len(String(total_matches)))
        + " |"
    )


# ===-----------------------------------------------------------------------===#
# Main Benchmark Runner
# ===-----------------------------------------------------------------------===#


fn main() raises:
    """Run all regex benchmarks with manual timing."""
    print("=== REGEX ENGINE BENCHMARKS (Manual Timing) ===")
    print("Using Python-compatible time.perf_counter_ns() for fair comparison")
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

    print("| name                      | met (ms)              | iters  |")
    print("|---------------------------|-----------------------|--------|")

    # ===== Literal Matching Benchmarks =====
    print("# Literal Matching")
    benchmark_search("literal_match_short", "hello", text_1000, 2000)

    benchmark_search("literal_match_long", "hello", text_10000, 2000)

    # ===== Wildcard and Quantifier Benchmarks =====
    print("# Wildcard and Quantifiers")
    benchmark_match_first("wildcard_match_any", ".*", text_10000, 1000)

    benchmark_match_first("quantifier_zero_or_more", "a*", text_10000, 1000)

    benchmark_match_first("quantifier_one_or_more", "a+", text_10000, 1000)

    benchmark_match_first("quantifier_zero_or_one", "a?", text_10000, 1000)

    # ===== Character Range Benchmarks =====
    print("# Character Ranges")
    benchmark_match_first("range_lowercase", "[a-z]+", text_range_10000, 1000)

    benchmark_search("range_digits", "[0-9]+", text_range_10000, 1000)

    benchmark_match_first(
        "range_alphanumeric", "[a-zA-Z0-9]+", text_range_10000, 1000
    )

    # ===== Anchor Benchmarks =====
    print("# Anchors")
    benchmark_match_first("anchor_start", "^abc", text_10000, 2000)

    benchmark_match_first("anchor_end", "xyz$", text_10000, 2000)

    # ===== Alternation Benchmarks =====
    print("# Alternations")
    benchmark_match_first("alternation_simple", "a|b|c", text_10000, 1000)

    benchmark_match_first("group_alternation", "(a|b)", text_10000, 1000)

    # ===== NEW: Optimization Showcase Benchmarks =====
    print("# Optimization Showcase (part1 branch improvements)")

    # Test case 1: Large alternation (5+ branches) - benefits from increased branch limit (3→8)
    var large_alternation = (
        "(apple|banana|cherry|date|elderberry|fig|grape|honey)"
    )
    var fruit_text = "I love eating apple and banana and cherry and date and elderberry and fig and grape with honey"
    benchmark_search(
        "large_alternation_8_branches", large_alternation, fruit_text, 1000
    )

    # Test case 2: Deeply nested groups (depth 4) - benefits from increased depth tolerance (3→4)
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

    # Test case 4: Complex group with 5 children - benefits from increased children limit (3→5)
    var complex_group = "(hello|world|test|demo|sample)[0-9]{3}[a-z]{2}"
    var mixed_text = "Found: hello123ab, world456cd, test789ef, demo012gh, sample345ij in the data"
    benchmark_search(
        "complex_group_5_children", complex_group, mixed_text, 1000
    )

    # ===== Global Matching (findall) =====
    print("# Global Matching")
    benchmark_findall("match_all_simple", "hello", medium_text, 200)
    benchmark_findall("match_all_digits", "[0-9]+", text_range_10000 * 10, 200)

    # ===== Literal Optimization Benchmarks =====
    print("# Literal Optimizations")
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
    print("# Complex Patterns")
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
    print("# US Phone Number Parsing")
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
    print("# DFA-Optimized Phone Number Parsing")

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
    print("# Pure DFA Phone Number Parsing (Literals)")

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
    print("# Smart Multi-Pattern Phone Parsing")

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
