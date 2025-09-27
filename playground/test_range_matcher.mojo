from time import perf_counter_ns as now
from regex.simd_matchers import (
    RangeBasedMatcher,
    create_digit_matcher,
    create_alpha_matcher,
    create_alnum_matcher,
)


fn test_digit_range_matcher() raises:
    """Test the range-based digit matcher."""
    print("Testing range-based digit matcher...")

    var digit_matcher = create_digit_matcher()

    # Test data
    var test_data = "0123456789 ABC abc !@#"
    var chunk = SIMD[DType.uint8, 16](0)
    for i in range(min(len(test_data), 16)):
        chunk[i] = ord(test_data[i])

    var matches = digit_matcher.match_chunk(chunk)

    print("Digit matcher results:")
    for i in range(min(len(test_data), 16)):
        var ch = test_data[i]
        var is_match = matches[i]
        var expected = ord(ch) >= ord("0") and ord(ch) <= ord("9")
        print("  '", ch, "' -> matched:", is_match, ", expected:", expected)
        if is_match != expected:
            raise Error("Digit matcher failed for: " + ch)

    print("Digit range matcher test passed!")


fn test_alpha_range_matcher() raises:
    """Test the range-based alphabetic matcher."""
    print("\n\nTesting range-based alphabetic matcher...")

    var alpha_matcher = create_alpha_matcher()

    # Test data
    var test_data = "ABCabc123 !@#"
    var chunk = SIMD[DType.uint8, 16](0)
    for i in range(min(len(test_data), 16)):
        chunk[i] = ord(test_data[i])

    var matches = alpha_matcher.match_chunk(chunk)

    print("Alpha matcher results:")
    for i in range(min(len(test_data), 16)):
        var ch = test_data[i]
        var is_match = matches[i]
        var expected = (ord(ch) >= ord("a") and ord(ch) <= ord("z")) or (
            ord(ch) >= ord("A") and ord(ch) <= ord("Z")
        )
        print("  '", ch, "' -> matched:", is_match, ", expected:", expected)
        if is_match != expected:
            raise Error("Alpha matcher failed for: " + ch)

    print("Alpha range matcher test passed!")


fn test_alnum_range_matcher() raises:
    """Test the range-based alphanumeric matcher."""
    print("\n\nTesting range-based alphanumeric matcher...")

    var alnum_matcher = create_alnum_matcher()

    # Test data
    var test_data = "Test123!@# XYZ"
    var chunk = SIMD[DType.uint8, 16](0)
    for i in range(min(len(test_data), 16)):
        chunk[i] = ord(test_data[i])

    var matches = alnum_matcher.match_chunk(chunk)

    print("Alnum matcher results:")
    for i in range(min(len(test_data), 16)):
        var ch = test_data[i]
        var is_match = matches[i]
        var expected = (
            (ord(ch) >= ord("a") and ord(ch) <= ord("z"))
            or (ord(ch) >= ord("A") and ord(ch) <= ord("Z"))
            or (ord(ch) >= ord("0") and ord(ch) <= ord("9"))
        )
        print("  '", ch, "' -> matched:", is_match, ", expected:", expected)
        if is_match != expected:
            raise Error("Alnum matcher failed for: " + ch)

    print("Alnum range matcher test passed!")


fn benchmark_range_vs_nibble() raises:
    """Compare performance of range-based vs nibble-based matchers."""
    print("\n\nPerformance comparison: range-based vs nibble-based")

    # Create test data
    var test_size = 10000
    var test_data = String()
    for i in range(test_size):
        if i % 3 == 0:
            test_data += "7"
        elif i % 3 == 1:
            test_data += "A"
        else:
            test_data += " "

    print("Test data size:", len(test_data))

    # Test range-based digit matcher
    var digit_matcher = create_digit_matcher()
    var start = now()
    var count = 0

    for offset in range(0, len(test_data) - 16, 16):
        var chunk = SIMD[DType.uint8, 16](0)
        for i in range(16):
            chunk[i] = ord(test_data[offset + i])

        var matches = digit_matcher.match_chunk(chunk)
        for i in range(16):
            if matches[i]:
                count += 1

    var range_time = now() - start
    print("\nRange-based digit matcher:")
    print("  Time:", range_time, "ns")
    print("  Found", count, "digits")
    print(
        "  Throughput:",
        Float64(len(test_data)) / Float64(range_time) * 1e9 / 1e6,
        "MB/s",
    )

    # Test with CharacterClassSIMD for comparison
    from regex.simd_ops import _create_ascii_digits

    var simd_digit_matcher = _create_ascii_digits()

    start = now()
    var simd_count = simd_digit_matcher.count_matches(test_data)
    var simd_time = now() - start

    print("\nCharacterClassSIMD digit matcher:")
    print("  Time:", simd_time, "ns")
    print("  Found", simd_count, "digits")
    print(
        "  Throughput:",
        Float64(len(test_data)) / Float64(simd_time) * 1e9 / 1e6,
        "MB/s",
    )

    var speedup = Float64(simd_time) / Float64(range_time)
    print("\nRange-based is", speedup, "x faster than lookup-based")


fn main() raises:
    test_digit_range_matcher()
    test_alpha_range_matcher()
    test_alnum_range_matcher()
    benchmark_range_vs_nibble()
    print("\n✅ All range matcher tests passed!")
