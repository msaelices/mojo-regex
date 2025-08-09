from time import perf_counter_ns as now
from sys.info import simdwidthof

alias SIMD_WIDTH = simdwidthof[DType.uint8]()

@register_passable("trivial")
struct CharacterClassSIMD(Copyable, Movable):
    """SIMD-optimized character class matcher."""

    var lookup_table: SIMD[DType.uint8, 256]

    fn __init__(out self, owned char_class: String):
        self.lookup_table = SIMD[DType.uint8, 256](0)
        for i in range(len(char_class)):
            var char_code = ord(char_class[i])
            if char_code >= 0 and char_code < 256:
                self.lookup_table[char_code] = 1

    fn _check_chunk_simd(
        self, text: String, pos: Int
    ) -> SIMD[DType.bool, SIMD_WIDTH]:
        """Check a chunk of characters using SIMD operations."""
        # Load chunk of characters
        var chunk = text.unsafe_ptr().load[width=SIMD_WIDTH](pos)

        # For small chunks or when _dynamic_shuffle isn't optimal,
        # we need to check if we can use the fast path
        @parameter
        if SIMD_WIDTH == 16:
            # Fast path: use _dynamic_shuffle for 16-byte chunks
            # The lookup table acts as our shuffle table
            var result = self.lookup_table._dynamic_shuffle(chunk)
            return result != 0
        else:
            # Fallback for other sizes - still avoid the loop by using vectorized operations
            var matches = SIMD[DType.bool, SIMD_WIDTH](False)
            
            # Process in 16-byte sub-chunks when possible
            @parameter
            for offset in range(0, SIMD_WIDTH, 16):
                @parameter
                if offset + 16 <= SIMD_WIDTH:
                    var sub_chunk = chunk.slice[16, offset=offset]()
                    var sub_result = self.lookup_table._dynamic_shuffle(sub_chunk)
                    for i in range(16):
                        matches[offset + i] = sub_result[i] != 0
                else:
                    # Handle remaining elements
                    for i in range(offset, SIMD_WIDTH):
                        var char_code = Int(chunk[i])
                        matches[i] = self.lookup_table[char_code] == 1
            
            return matches

fn test_simd_performance() raises:
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
        var ch = test_data[i]
        if ord(ch) >= ord("0") and ord(ch) <= ord("9"):
            manual_count += 1
    
    print("Manual count:", manual_count)
    # The SIMD count might be slightly less due to not processing the tail
    if count > manual_count or count < manual_count - SIMD_WIDTH:
        raise Error("Count mismatch!")
    print("Test passed!")

fn main() raises:
    test_simd_performance()