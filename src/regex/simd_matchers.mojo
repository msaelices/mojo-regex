"""
SIMD-optimized matchers for character classes using advanced byte lookup techniques.

Based on techniques from: http://0x80.pl/notesen/2018-10-18-simd-byte-lookup.html
"""

from sys.info import simdwidthof

alias SIMD_WIDTH = simdwidthof[DType.uint8]()


trait SIMDMatcher:
    """Base trait for SIMD character class matchers."""
    
    fn match_chunk[size: Int](self, chunk: SIMD[DType.uint8, size]) -> SIMD[DType.bool, size]:
        """Check if characters in chunk match the character class.
        
        Parameters:
            size: Size of the SIMD chunk to process.
            
        Args:
            chunk: SIMD vector of characters to check.
            
        Returns:
            SIMD vector of booleans indicating matches.
        """
        ...
    
    fn contains(self, char_code: Int) -> Bool:
        """Check if a single character is in this character class.
        
        Args:
            char_code: Character code to check (0-255).
            
        Returns:
            True if character is in the class.
        """
        ...


@register_passable("trivial")
struct NibbleBasedMatcher(SIMDMatcher, Copyable, Movable):
    """Nibble-based SIMD matcher using shuffle operations.
    
    This matcher splits bytes into high and low nibbles and uses
    _dynamic_shuffle for hardware-accelerated lookups.
    """
    
    var low_nibble_lut: SIMD[DType.uint8, 16]
    """Lookup table for low nibbles (0x0-0xF)."""
    
    var high_nibble_lut: SIMD[DType.uint8, 16] 
    """Lookup table for high nibbles (0x0-0xF)."""
    
    fn __init__(out self, low_lut: SIMD[DType.uint8, 16], high_lut: SIMD[DType.uint8, 16]):
        """Initialize with pre-computed lookup tables.
        
        Args:
            low_lut: Lookup table for low nibbles.
            high_lut: Lookup table for high nibbles.
        """
        self.low_nibble_lut = low_lut
        self.high_nibble_lut = high_lut
    
    fn match_chunk[size: Int](self, chunk: SIMD[DType.uint8, size]) -> SIMD[DType.bool, size]:
        """Check if characters in chunk match using nibble-based lookup.
        
        Parameters:
            size: Size of the SIMD chunk to process.
            
        Args:
            chunk: SIMD vector of characters to check.
            
        Returns:
            SIMD vector of booleans indicating matches.
        """
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
        """Check if a single character matches.
        
        Args:
            char_code: Character code to check (0-255).
            
        Returns:
            True if character matches.
        """
        if char_code < 0 or char_code > 255:
            return False
        
        var low_nibble = char_code & 0x0F
        var high_nibble = (char_code >> 4) & 0x0F
        
        var low_match = self.low_nibble_lut[low_nibble]
        var high_match = self.high_nibble_lut[high_nibble]
        
        return (low_match & high_match) != 0


fn create_hex_digit_matcher() -> RangeBasedMatcher:
    """Create a matcher for hex digits [0-9A-Fa-f].
    
    Note: Using range-based matcher for now as nibble-based approach
    requires more complex bit manipulation for this specific pattern.
    
    Returns:
        Optimized matcher for hex digits.
    """
    var matcher = RangeBasedMatcher()
    matcher.add_range(ord("0"), ord("9"))
    matcher.add_range(ord("A"), ord("F"))
    matcher.add_range(ord("a"), ord("f"))
    return matcher


struct RangeBasedMatcher(SIMDMatcher, Copyable, Movable):
    """Range-based SIMD matcher using comparison operations.
    
    Efficient for contiguous character ranges like [a-z], [0-9], [A-Z].
    """
    
    var start_ranges: SIMD[DType.uint8, 4]
    """Start values for up to 4 ranges."""
    
    var end_ranges: SIMD[DType.uint8, 4]
    """End values for up to 4 ranges."""
    
    var num_ranges: Int
    """Number of active ranges."""
    
    fn __init__(out self):
        """Initialize empty range matcher."""
        self.start_ranges = SIMD[DType.uint8, 4](0)
        self.end_ranges = SIMD[DType.uint8, 4](0)
        self.num_ranges = 0
    
    fn add_range(mut self, start: UInt8, end: UInt8):
        """Add a character range.
        
        Args:
            start: Start of range (inclusive).
            end: End of range (inclusive).
        """
        if self.num_ranges < 4:
            self.start_ranges[self.num_ranges] = start
            self.end_ranges[self.num_ranges] = end
            self.num_ranges += 1
    
    fn match_chunk[size: Int](self, chunk: SIMD[DType.uint8, size]) -> SIMD[DType.bool, size]:
        """Check if characters in chunk match any range.
        
        Parameters:
            size: Size of the SIMD chunk to process.
            
        Args:
            chunk: SIMD vector of characters to check.
            
        Returns:
            SIMD vector of booleans indicating matches.
        """
        var result = SIMD[DType.bool, size](False)
        
        for i in range(self.num_ranges):
            var range_start = self.start_ranges[i]
            var range_end = self.end_ranges[i]
            
            var ge_start = chunk >= range_start
            var le_end = chunk <= range_end  
            result = result | (ge_start & le_end)
        
        return result
    
    fn contains(self, char_code: Int) -> Bool:
        """Check if a single character matches any range.
        
        Args:
            char_code: Character code to check (0-255).
            
        Returns:
            True if character is in any range.
        """
        if char_code < 0 or char_code > 255:
            return False
            
        var ch = UInt8(char_code)
        for i in range(self.num_ranges):
            var range_start = self.start_ranges[i]
            var range_end = self.end_ranges[i]
            if ch >= range_start and ch <= range_end:
                return True
        
        return False


fn create_digit_matcher() -> RangeBasedMatcher:
    """Create a range-based matcher for digits [0-9].
    
    Returns:
        Optimized matcher for digits.
    """
    var matcher = RangeBasedMatcher()
    matcher.add_range(ord("0"), ord("9"))
    return matcher


fn create_alpha_matcher() -> RangeBasedMatcher:
    """Create a range-based matcher for alphabetic characters [a-zA-Z].
    
    Returns:
        Optimized matcher for alphabetic characters.
    """
    var matcher = RangeBasedMatcher()
    matcher.add_range(ord("a"), ord("z"))
    matcher.add_range(ord("A"), ord("Z"))
    return matcher


fn create_alnum_matcher() -> RangeBasedMatcher:
    """Create a range-based matcher for alphanumeric characters [a-zA-Z0-9].
    
    Returns:
        Optimized matcher for alphanumeric characters.
    """
    var matcher = RangeBasedMatcher()
    matcher.add_range(ord("a"), ord("z"))
    matcher.add_range(ord("A"), ord("Z"))
    matcher.add_range(ord("0"), ord("9"))
    return matcher


fn create_whitespace_matcher() -> NibbleBasedMatcher:
    """Create a nibble-based matcher for whitespace characters.
    
    Matches: space (0x20), tab (0x09), newline (0x0A), carriage return (0x0D),
    form feed (0x0C), vertical tab (0x0B).
    
    Returns:
        Optimized matcher for whitespace characters.
    """
    # Whitespace characters:
    # - Space ' ': 0x20 (high nibble=2, low nibble=0)
    # - Tab '\t': 0x09 (high nibble=0, low nibble=9)
    # - Newline '\n': 0x0A (high nibble=0, low nibble=A)
    # - Vertical tab '\v': 0x0B (high nibble=0, low nibble=B)
    # - Form feed '\f': 0x0C (high nibble=0, low nibble=C)
    # - Carriage return '\r': 0x0D (high nibble=0, low nibble=D)
    
    # Low nibble LUT: valid for 0 (space), 9-D (tab, \n, \v, \f, \r)
    var low_lut = SIMD[DType.uint8, 16](
        0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  # 0 valid
        0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00   # 9-D valid
    )
    
    # High nibble LUT: valid for 0 (tab/newline/etc) and 2 (space)
    var high_lut = SIMD[DType.uint8, 16](
        0xFF, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00,  # 0, 2 valid
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    )
    
    return NibbleBasedMatcher(low_lut, high_lut)


fn analyze_character_class_pattern(pattern: String) -> String:
    """Analyze a character class pattern and determine the optimal SIMD strategy.
    
    Args:
        pattern: Character class pattern (e.g., "[a-z]", "[0-9A-Fa-f]", etc.)
        
    Returns:
        String indicating the optimal strategy: "range", "nibble", or "lookup".
    """
    # Check for common patterns
    if pattern == "[0-9]" or pattern == "\\d":
        return "range"
    elif pattern == "[a-z]" or pattern == "[A-Z]":
        return "range"
    elif pattern == "[a-zA-Z]" or pattern == "[0-9a-zA-Z]" or pattern == "[a-zA-Z0-9]" or pattern == "\\w":
        return "range"
    elif pattern == "[0-9A-Fa-f]" or pattern == "[0-9a-fA-F]":
        return "range"  # Using range-based for hex digits
    elif pattern == "\\s":
        return "nibble"
    else:
        # Check if it's a simple range
        if pattern.startswith("[") and pattern.endswith("]") and "-" in pattern:
            var inner = pattern[1:-1]
            if len(inner) == 3 and inner[1] == "-":
                return "range"
        return "lookup"