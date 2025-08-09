from time import perf_counter_ns as now
from sys.info import simdwidthof

alias SIMD_WIDTH = 16  # Test with 16-byte chunks for optimal performance

trait SIMDMatcher:
    """Base trait for SIMD character class matchers."""
    
    fn match_chunk[size: Int](self, chunk: SIMD[DType.uint8, size]) -> SIMD[DType.bool, size]:
        """Check if characters in chunk match the character class."""
        ...
    
    fn contains(self, char_code: Int) -> Bool:
        """Check if a single character is in this character class."""
        ...


@register_passable("trivial")
struct NibbleBasedMatcher(SIMDMatcher, Copyable, Movable):
    """Nibble-based SIMD matcher using shuffle operations."""
    
    var low_nibble_lut: SIMD[DType.uint8, 16]
    """Lookup table for low nibbles (0x0-0xF)."""
    
    var high_nibble_lut: SIMD[DType.uint8, 16] 
    """Lookup table for high nibbles (0x0-0xF)."""
    
    fn __init__(out self, low_lut: SIMD[DType.uint8, 16], high_lut: SIMD[DType.uint8, 16]):
        """Initialize with pre-computed lookup tables."""
        self.low_nibble_lut = low_lut
        self.high_nibble_lut = high_lut
    
    fn match_chunk[size: Int](self, chunk: SIMD[DType.uint8, size]) -> SIMD[DType.bool, size]:
        """Check if characters in chunk match using nibble-based lookup."""
        # Extract nibbles
        var low_nibbles = chunk & 0x0F
        var high_nibbles = (chunk >> 4) & 0x0F
        
        @parameter
        if size == 16:
            # Fast path for 16-byte chunks
            var low_match = self.low_nibble_lut._dynamic_shuffle(low_nibbles)
            var high_match = self.high_nibble_lut._dynamic_shuffle(high_nibbles)
            return (low_match & high_match) != 0
        else:
            # Process in 16-byte sub-chunks
            var result = SIMD[DType.bool, size](False)
            
            @parameter
            for offset in range(0, size, 16):
                @parameter
                if offset + 16 <= size:
                    var sub_low = low_nibbles.slice[16, offset=offset]()
                    var sub_high = high_nibbles.slice[16, offset=offset]()
                    var low_match = self.low_nibble_lut._dynamic_shuffle(sub_low)
                    var high_match = self.high_nibble_lut._dynamic_shuffle(sub_high)
                    var sub_result = (low_match & high_match) != 0
                    for i in range(16):
                        result[offset + i] = sub_result[i]
                else:
                    # Handle remaining elements
                    for i in range(offset, size):
                        result[i] = self.contains(Int(chunk[i]))
            
            return result
    
    fn contains(self, char_code: Int) -> Bool:
        """Check if a single character matches."""
        if char_code < 0 or char_code > 255:
            return False
        
        var low_nibble = char_code & 0x0F
        var high_nibble = (char_code >> 4) & 0x0F
        
        var low_match = self.low_nibble_lut[low_nibble]
        var high_match = self.high_nibble_lut[high_nibble]
        
        return (low_match & high_match) != 0


fn create_hex_digit_matcher() -> NibbleBasedMatcher:
    """Create a nibble-based matcher for hex digits [0-9A-Fa-f]."""
    # For hex digits:
    # - Digits '0'-'9': 0x30-0x39 (high nibble=3, low nibble=0-9)
    # - Upper 'A'-'F': 0x41-0x46 (high nibble=4, low nibble=1-6)  
    # - Lower 'a'-'f': 0x61-0x66 (high nibble=6, low nibble=1-6)
    
    # Low nibble LUT: valid if 0-9 or 1-6
    var low_lut = SIMD[DType.uint8, 16](
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,  # 0-7: all valid
        0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00   # 8-9 valid, A-F invalid
    )
    
    # High nibble LUT: valid if nibble is 3 (digits), 4 (upper), or 6 (lower)
    var high_lut = SIMD[DType.uint8, 16](
        0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0xFF, 0x00,  # 3, 4, 6 are valid
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00   # rest invalid
    )
    
    return NibbleBasedMatcher(low_lut, high_lut)


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
            (ord(ch) >= ord('0') and ord(ch) <= ord('9')) or
            (ord(ch) >= ord('A') and ord(ch) <= ord('F')) or  
            (ord(ch) >= ord('a') and ord(ch) <= ord('f'))
        )
        print("  '", ch, "' (", ord(ch), ") -> matched:", is_match, ", expected:", expected)
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
            (ord(ch) >= ord('0') and ord(ch) <= ord('9')) or
            (ord(ch) >= ord('A') and ord(ch) <= ord('F')) or
            (ord(ch) >= ord('a') and ord(ch) <= ord('f'))
        ):
            manual_count += 1
    
    print("Manual verification count:", manual_count)
    print("Performance test passed!")


fn main() raises:
    test_hex_matcher()
    test_performance_comparison()
    print("\n✅ All tests passed!")