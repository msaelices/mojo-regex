#!/usr/bin/env python3

import re
import time

def benchmark_pattern(pattern, text, iterations=1000):
    """Benchmark a pattern in Python."""
    regex = re.compile(pattern)

    total_time = 0
    for _ in range(iterations):
        start = time.perf_counter()
        regex.search(text)
        end = time.perf_counter()
        total_time += end - start

    return (total_time / iterations) * 1000  # Convert to ms

if __name__ == "__main__":
    print("=== PYTHON PERFORMANCE COMPARISON ===")

    # The complex national phone validation pattern
    complex_pattern = r"(?:3052(?:0[0-8]|[1-9]\d)|5056(?:[0-35-9]\d|4[0-68]))\d{4}|(?:2742|305[3-9]|472[247-9]|505[2-57-9]|983[2-47-9])\d{6}|(?:2(?:0[1-35-9]|1[02-9]|2[03-57-9]|3[1459]|4[08]|5[1-46]|6[0279]|7[0269]|8[13])|3(?:0[1-47-9]|1[02-9]|2[0135-79]|3[0-24679]|4[167]|5[0-2]|6[01349]|8[056])|4(?:0[124-9]|1[02-579]|2[3-5]|3[0245]|4[023578]|58|6[349]|7[0589]|8[04])|5(?:0[1-47-9]|1[0235-8]|20|3[0149]|4[01]|5[179]|6[1-47]|7[0-5]|8[0256])|6(?:0[1-35-9]|1[024-9]|2[03689]|3[016]|4[0156]|5[01679]|6[0-279]|78|8[0-29])|7(?:0[1-46-8]|1[2-9]|2[04-8]|3[0-247]|4[037]|5[47]|6[02359]|7[0-59]|8[156])|8(?:0[1-68]|1[02-8]|2[0168]|3[0-2589]|4[03578]|5[046-9]|6[02-5]|7[028])|9(?:0[1346-9]|1[02-9]|2[0589]|3[0146-8]|4[01357-9]|5[12469]|7[0-389]|8[04-69]))[2-9]\d{6}"

    test_cases = [
        ("3052001234", "Valid phone"),
        ("12345678901234", "Invalid phone"),
        ("Contact us at 3052001234 or 212345672890 for more info.", "Mixed text")
    ]

    print("Complex US phone pattern:")
    print("Pattern:", complex_pattern[:60] + "...")
    print()

    for text, name in test_cases:
        time_ms = benchmark_pattern(complex_pattern, text, 1000)
        matches = bool(re.search(complex_pattern, text))
        print(f"{name:20s}: {time_ms:.6f} ms (matches: {matches})")

    # Average
    total_time = sum(benchmark_pattern(complex_pattern, text, 1000) for text, _ in test_cases)
    avg_time = total_time / len(test_cases)
    print(f"{'Average':20s}: {avg_time:.6f} ms")

    print()
    print("=== COMPARISON WITH MOJO ===")
    print("Mojo average: ~0.00012 ms")
    print("Python average: {:.6f} ms".format(avg_time))
    if avg_time > 0.00012:
        ratio = avg_time / 0.00012
        print(f"Mojo is {ratio:.1f}x faster than Python for this pattern!")
