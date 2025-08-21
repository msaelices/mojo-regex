#!/usr/bin/env mojo

from time import perf_counter_ns
from regex.matcher import compile_regex


fn benchmark_pattern(
    pattern: String, text: String, iterations: Int
) raises -> Float64:
    """Benchmark a single pattern against text."""
    var regex = compile_regex(pattern)

    var total_time: Int = 0
    var start_time: Int
    var end_time: Int

    for i in range(iterations):
        start_time = perf_counter_ns()
        _ = regex.test(text)
        end_time = perf_counter_ns()
        total_time += end_time - start_time

    return (
        Float64(total_time) / Float64(iterations) / 1_000_000.0
    )  # Convert to ms


fn main() raises:
    print("=== NATIONAL PHONE PATTERN PERFORMANCE TEST ===")
    print()

    # The complex national phone validation pattern
    var phone_patterns = [
        "(?:3052(?:0[0-8]|[1-9]\\d)|5056(?:[0-35-9]\\d|4[0-68]))\\d{4}|(?:2742|305[3-9]|472[247-9]|505[2-57-9]|983[2-47-9])\\d{6}|(?:2(?:0[1-35-9]|1[02-9]|2[03-57-9]|3[1459]|4[08]|5[1-46]|6[0279]|7[0269]|8[13])|3(?:0[1-47-9]|1[02-9]|2[0135-79]|3[0-24679]|4[167]|5[0-2]|6[01349]|8[056])|4(?:0[124-9]|1[02-579]|2[3-5]|3[0245]|4[023578]|58|6[349]|7[0589]|8[04])|5(?:0[1-47-9]|1[0235-8]|20|3[0149]|4[01]|5[179]|6[1-47]|7[0-5]|8[0256])|6(?:0[1-35-9]|1[024-9]|2[03689]|3[016]|4[0156]|5[01679]|6[0-279]|78|8[0-29])|7(?:0[1-46-8]|1[2-9]|2[04-8]|3[0-247]|4[037]|5[47]|6[02359]|7[0-59]|8[156])|8(?:0[1-68]|1[02-8]|2[0168]|3[0-2589]|4[03578]|5[046-9]|6[02-5]|7[028])|9(?:0[1346-9]|1[02-9]|2[0589]|3[0146-8]|4[01357-9]|5[12469]|7[0-389]|8[04-69]))[2-9]\\d{6}",  # US fixed/mobile lines
        "8(?:00|33|44|55|66|77|88)[2-9]\\d{6}",  # US toll-free
    ]

    # Test texts
    var valid_phone = "96906123456789"  # Should match
    var invalid_phone = "12345678901234"  # Should not match
    var mixed_text = "Contact us at 96906123456 or 8123456789 for more info."

    var iterations = 10000  # More focused iterations

    for phone_pattern in phone_patterns:
        print("Pattern:", phone_pattern[:50] + "...")
        print("Iterations per test:", iterations)
        print()

        # Test different scenarios
        print("| Test Case              | Time (ms)        | Result |")
        print("|------------------------|------------------|--------|")

        var time1 = benchmark_pattern(phone_pattern, valid_phone, iterations)
        var test_regex = compile_regex(phone_pattern)
        print(
            "| Valid phone (match)    | "
            + String(time1)
            + "       | "
            + ("✓" if test_regex.test(valid_phone) else "✗")
            + "     |"
        )

        var time2 = benchmark_pattern(phone_pattern, invalid_phone, iterations)
        print(
            "| Invalid phone (no match)| "
            + String(time2)
            + "       | "
            + ("✓" if not test_regex.test(invalid_phone) else "✗")
            + "     |"
        )

        var time3 = benchmark_pattern(phone_pattern, mixed_text, iterations)
        print(
            "| Mixed text (search)    | "
            + String(time3)
            + "       | "
            + ("✓" if test_regex.test(mixed_text) else "✗")
            + "     |"
        )

        print()
        var avg_time = (time1 + time2 + time3) / 3.0
        print("Average time: " + String(avg_time) + " ms")
        print()
