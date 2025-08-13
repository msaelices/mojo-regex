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
    var phone_pattern = "96906(?:0[0-8]|1[1-9]|[2-9]\\d)\\d\\d|9(?:69(?:0[0-57-9]|[1-9]\\d)|73(?:[0-8]\\d|9[1-9]))\\d{4}|(?:8(?:[1356]\\d|[28][0-8]|[47][1-9])|9(?:[135]\\d|[268][0-8]|4[1-9]|7[124-9]))\\d{6}"

    # Test texts
    var valid_phone = "96906123456789"  # Should match
    var invalid_phone = "12345678901234"  # Should not match
    var mixed_text = "Contact us at 96906123456 or 8123456789 for more info."

    var iterations = 10000  # More focused iterations

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

    # Performance targets based on proposal
    print("=== PERFORMANCE COMPARISON ===")
    print("Target (Phase 1): ~0.35ms (10-20x improvement from ~3.5ms)")
    if avg_time < 0.35:
        print("✓ SUCCESS: Achieved Phase 1 performance target!")
        var improvement = 3.485 / avg_time
        print(
            "Improvement factor: "
            + String(improvement)
            + "x faster than baseline"
        )
    elif avg_time < 1.0:
        print("✓ GOOD: Significant improvement achieved")
        var improvement = 3.485 / avg_time
        print(
            "Improvement factor: "
            + String(improvement)
            + "x faster than baseline"
        )
    else:
        print("⚠ PARTIAL: Some improvement, but not yet at target")
        var improvement = 3.485 / avg_time
        print(
            "Improvement factor: "
            + String(improvement)
            + "x faster than baseline"
        )
