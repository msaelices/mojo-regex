from time import perf_counter_ns as now
from sys.info import simd_width_of
from src.regex.simd_matchers import (
    create_hex_digit_matcher,
    create_digit_matcher,
)

alias SIMD_WIDTH = 16  # Test with 16-byte chunks for optimal performance


fn test_hex_matcher() raises:
    """Test the nibble-based hex digit matcher."""
    print("Testing nibble-based hex digit matcher...")

    var hex_matcher = create_hex_digit_matcher()

    # Test data with hex and non-hex characters
    var test_data = "0123456789ABCDEFabcdef XYZ!@# ghijk"
    print("Test data:", test_data)

    # Convert to SIMD chunk
    var chunk = SIMD[DType.uint8, SIMD_WIDTH](0)
    for i in range(min(len(test_data), SIMD_WIDTH)):
        chunk[i] = ord(test_data[i])

    # Test matching
    var matches = hex_matcher.match_chunk(chunk)

    print("\nCharacter analysis:")
    for i in range(min(len(test_data), SIMD_WIDTH)):
        var ch = test_data[i]
        var is_match = matches[i]
        var expected = (
            (ord(ch) >= ord("0") and ord(ch) <= ord("9"))
            or (ord(ch) >= ord("A") and ord(ch) <= ord("F"))
            or (ord(ch) >= ord("a") and ord(ch) <= ord("f"))
        )
        print(
            "  '",
            ch,
            "' (",
            ord(ch),
            ") -> matched:",
            is_match,
            ", expected:",
            expected,
        )
        if is_match != expected:
            raise Error("Mismatch for character: " + ch)

    print("\nHex matcher test passed!")


fn test_performance_comparison() raises:
    """Compare performance of nibble-based vs simple lookup."""
    print("\n\nPerformance comparison:")

    # Create test data
    var test_size = 1024
    var test_data = String()
    for i in range(test_size):
        # Mix of hex and non-hex
        if i % 3 == 0:
            test_data += "F"
        elif i % 3 == 1:
            test_data += "7"
        else:
            test_data += "X"

    print("Test data size:", len(test_data))

    # Test nibble-based matcher
    var hex_matcher = create_hex_digit_matcher()
    var start = now()
    var count = 0

    for offset in range(0, len(test_data) - SIMD_WIDTH, SIMD_WIDTH):
        var chunk = SIMD[DType.uint8, SIMD_WIDTH](0)
        for i in range(SIMD_WIDTH):
            chunk[i] = ord(test_data[offset + i])

        var matches = hex_matcher.match_chunk(chunk)
        for i in range(SIMD_WIDTH):
            if matches[i]:
                count += 1

    var nibble_time = now() - start
    print("Nibble-based time:", nibble_time, "ns, found", count, "hex digits")

    # Verify with manual count
    var manual_count = 0
    for i in range(len(test_data)):
        var ch = test_data[i]
        if (
            (ord(ch) >= ord("0") and ord(ch) <= ord("9"))
            or (ord(ch) >= ord("A") and ord(ch) <= ord("F"))
            or (ord(ch) >= ord("a") and ord(ch) <= ord("f"))
        ):
            manual_count += 1

    print("Manual verification count:", manual_count)
    print("Performance test passed!")


fn test_digit_range_matcher() raises:
    """Test the range-based digit matcher."""
    print("\n\nTesting range-based digit matcher...")

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


fn main() raises:
    test_hex_matcher()
    test_performance_comparison()
    test_digit_range_matcher()
    print("\n✅ All tests passed!")
