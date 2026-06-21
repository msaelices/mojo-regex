from std.time import perf_counter_ns as now
from std.sys.info import simd_width_of

alias SIMD_WIDTH = simd_width_of[DType.uint8]()


struct CharacterClassSIMD(Copyable, Movable, TrivialRegisterPassable):
    """SIMD-optimized character class matcher."""

    var lookup_table: SIMD[DType.uint8, 256]

    def __init__(out self, var char_class: String):
        self.lookup_table = SIMD[DType.uint8, 256](0)
        for i in range(len(char_class)):
            var char_code = ord(char_class[byte=i])
            if char_code >= 0 and char_code < 256:
                self.lookup_table[char_code] = 1

    def _check_chunk_simd(
        self, text: String, pos: Int
    ) -> SIMD[DType.bool, SIMD_WIDTH]:
        """Check a chunk of characters using SIMD operations."""
        # Load chunk of characters
        var chunk = text.unsafe_ptr().load[width=SIMD_WIDTH](pos)

        # The 256-entry lookup table is too wide for a hardware shuffle
        # (pshufb/vpshufb only support 16/32-byte tables), so gather each
        # byte's membership from the table into a uint8 vector and turn it
        # into a per-lane mask with `.eq` (constructing a bool SIMD and
        # writing it lane-by-lane crashes codegen on this toolchain).
        var gathered = SIMD[DType.uint8, SIMD_WIDTH](0)
        for i in range(SIMD_WIDTH):
            var char_code = Int(chunk[i])
            gathered[i] = self.lookup_table[char_code]
        return gathered.eq(SIMD[DType.uint8, SIMD_WIDTH](1))


def test_simd_performance() raises:
    """Test that our SIMD optimization actually works."""
    # Create a character class for digits
    var digit_class = CharacterClassSIMD("0123456789")

    # Create test data with mixed content
    var test_data = String()
    for i in range(100):
        test_data += "abc123def456"

    print("Test data length:", len(test_data))
    print("SIMD_WIDTH:", SIMD_WIDTH)

    # Test with SIMD operations
    var start = now()
    var count = 0
    var pos = 0
    while pos + SIMD_WIDTH <= len(test_data):
        var matches = digit_class._check_chunk_simd(test_data, pos)
        # Count true values in the SIMD vector
        for i in range(SIMD_WIDTH):
            if matches[i]:
                count += 1
        pos += SIMD_WIDTH

    var simd_time = now() - start
    print("SIMD time:", simd_time, "ns, found", count, "digits")

    # Verify correctness - count digits manually
    var manual_count = 0
    for i in range(len(test_data)):
        var ch = test_data[byte=i]
        if ord(ch) >= ord("0") and ord(ch) <= ord("9"):
            manual_count += 1

    print("Manual count:", manual_count)
    # The SIMD count might be slightly less due to not processing the tail
    if count > manual_count or count < manual_count - SIMD_WIDTH:
        raise Error("Count mismatch!")
    print("Test passed!")


def main() raises:
    test_simd_performance()
