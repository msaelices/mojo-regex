# SIMD Byte Lookup Implementation Plan for Mojo Regex Library

## Overview

This document outlines a plan to implement advanced SIMD byte lookup techniques in the mojo-regex library, based on the research from [0x80.pl's SIMD byte lookup article](http://0x80.pl/notesen/2018-10-18-simd-byte-lookup.html). These techniques can provide 10-30x speedups for character class matching operations.

## Current State Analysis

### Existing Implementation
- **CharacterClassSIMD**: Uses a 256-byte lookup table where each byte indicates if a character is in the set
- **_check_chunk_simd**: Loads SIMD chunks but checks each character individually
- **Limited SIMD usage**: Current implementation doesn't fully leverage SIMD parallelism

### Performance Bottlenecks
1. Sequential character-by-character checking within SIMD chunks
2. Large lookup table (256 bytes) causing cache misses
3. No specialization for common character class patterns
4. Inefficient handling of ranges and negated sets

## Mojo's `_dynamic_shuffle` Discovery

### Important Update
Mojo already provides a `_dynamic_shuffle` function that implements exactly what we need for SIMD byte lookup! This function:
- Performs dynamic vector permutation with runtime indices
- Uses native `pshufb` instruction on x86 (SSE4) and `tbl1` on ARM (NEON)
- Handles various vector sizes through automatic recursion/splitting
- Was added specifically for implementing fast UTF-8 validation (6x faster than stdlib)

### `_dynamic_shuffle` Function Details
```mojo
fn _dynamic_shuffle[mask_size: Int](
    self, 
    mask: SIMD[DType.uint8, mask_size]
) -> SIMD[Self.type, mask_size]
```

**Key characteristics**:
- Fast path for `SIMD[DType.uint8, 16]` with SSE4/NEON
- Automatically handles other sizes via recursion
- Falls back to unrolled loop (~3x slower) when hardware support unavailable
- Private method (prefixed with `_`) to avoid confusion with static shuffle

## Proposed SIMD Techniques

### 1. Nibble-based Lookup Using Shuffle Operations

**When to use**: Character sets that fit in 16 values (e.g., hex digits, small custom sets)

**How it works**:
```
1. Split each input byte into high and low nibbles
2. Use SIMD shuffle to map nibbles to set membership
3. Combine results to determine if byte is in set
```

**Implementation approach (using _dynamic_shuffle)**:
```mojo
struct NibbleBasedMatcher:
    var low_nibble_map: SIMD[DType.uint8, 16]  # Maps low nibbles
    var high_nibble_map: SIMD[DType.uint8, 16]  # Maps high nibbles
    
    fn match_chunk[size: Int](self, chunk: SIMD[DType.uint8, size]) -> SIMD[DType.bool, size]:
        # Extract nibbles
        var low_nibbles = chunk & 0x0F
        var high_nibbles = (chunk >> 4) & 0x0F
        
        # Use _dynamic_shuffle for hardware-accelerated lookup
        var low_result = self.low_nibble_map._dynamic_shuffle(low_nibbles)
        var high_result = self.high_nibble_map._dynamic_shuffle(high_nibbles)
        
        # Combine results
        return (low_result & high_result) != 0
```

### 2. Range-based SIMD Comparisons

**When to use**: Contiguous character ranges ([a-z], [0-9], [A-Z])

**How it works**:
```
1. Use SIMD comparison operations for range boundaries
2. Combine multiple ranges with bitwise OR
3. Handle signed/unsigned comparison edge cases
```

**Implementation approach**:
```mojo
struct RangeBasedMatcher:
    var ranges: List[Tuple[UInt8, UInt8]]  # List of (start, end) pairs
    
    fn match_chunk(self, chunk: SIMD[DType.uint8, SIMD_WIDTH]) -> SIMD[DType.bool, SIMD_WIDTH]:
        var result = SIMD[DType.bool, SIMD_WIDTH](False)
        
        for range in self.ranges:
            var ge_start = chunk >= range.get[0]()
            var le_end = chunk <= range.get[1]()
            result = result | (ge_start & le_end)
        
        return result
```

### 3. Bitmask-based Method for Arbitrary Sets

**When to use**: Complex character sets that don't fit other patterns

**How it works**:
```
1. Create two 128-bit bitmasks indexed by nibbles
2. Use SIMD shuffle to extract relevant bits
3. Test bits in parallel
```

**Implementation approach (using _dynamic_shuffle)**:
```mojo
struct BitmaskMatcher:
    var bitmap_low: SIMD[DType.uint8, 16]   # Bitmap for low nibbles
    var bitmap_high: SIMD[DType.uint8, 16]  # Bitmap for high nibbles
    
    fn match_chunk[size: Int](self, chunk: SIMD[DType.uint8, size]) -> SIMD[DType.bool, size]:
        # Extract nibbles
        var low_nibbles = chunk & 0x0F
        var high_nibbles = chunk >> 4
        
        # Use _dynamic_shuffle to get bitmasks (hardware accelerated)
        var low_bits = self.bitmap_low._dynamic_shuffle(low_nibbles)
        var high_bits = self.bitmap_high._dynamic_shuffle(high_nibbles)
        
        # Create bit position mask
        var bit_pos = SIMD[DType.uint8, size](1) << (high_nibbles & 0x07)
        
        # Test bits
        return (low_bits & bit_pos) != 0
```

### 4. Small Set Optimization

**When to use**: Sets with ≤ 8 distinct elements

**How it works**:
```
1. Assign each element a unique bit in a byte
2. Use SIMD shuffle for fast parallel lookup
3. Test membership with single bit operation
```

## Practical Examples with `_dynamic_shuffle`

### Example 1: Hex Digit Matcher
```mojo
fn create_hex_matcher() -> NibbleBasedMatcher:
    # For hex digits [0-9A-Fa-f]
    # Low nibble map: mark valid low nibbles
    var low_map = SIMD[DType.uint8, 16](
        1, 1, 1, 1, 1, 1, 1, 1,  # 0-7
        1, 1, 0, 0, 0, 0, 0, 0   # 8-9, then invalid
    )
    
    # High nibble map: 0x3 for digits, 0x4/0x6 for letters
    var high_map = SIMD[DType.uint8, 16](
        0, 0, 0, 1, 1, 0, 1, 0,  # Only 0x3, 0x4, 0x6 valid
        0, 0, 0, 0, 0, 0, 0, 0
    )
    
    return NibbleBasedMatcher(low_map, high_map)
```

### Example 2: Using _dynamic_shuffle Directly
```mojo
fn is_hex_digit_simd(chars: SIMD[DType.uint8, 16]) -> SIMD[DType.bool, 16]:
    # Create lookup table: 1 for valid hex chars, 0 otherwise
    var hex_table = SIMD[DType.uint8, 16](
        0, 0, 0, 0, 0, 0, 0, 0,  # 0x30-0x37
        0, 0, 0, 0, 0, 0, 0, 0   # 0x38-0x3F
    )
    
    # For 0x30-0x39 (digits '0'-'9'), 0x41-0x46 ('A'-'F'), 0x61-0x66 ('a'-'f')
    var indices = (chars & 0x0F)  # Get low nibble as index
    var result = hex_table._dynamic_shuffle(indices)
    
    return result != 0
```

## Implementation Plan

### Phase 1: Core SIMD Matchers (Week 1)

1. **Create base trait for SIMD matchers**:
   ```mojo
   trait SIMDMatcher:
       fn match_chunk(self, chunk: SIMD[DType.uint8, SIMD_WIDTH]) -> SIMD[DType.bool, SIMD_WIDTH]
       fn match_single(self, byte: UInt8) -> Bool
   ```

2. **Implement specialized matchers**:
   - `NibbleBasedMatcher` for hex digits, small sets
   - `RangeBasedMatcher` for contiguous ranges
   - `BitmaskMatcher` for arbitrary sets
   - `SmallSetMatcher` for tiny sets (≤8 elements)

3. **Create matcher factory**:
   ```mojo
   fn create_optimal_matcher(char_set: String) -> SIMDMatcher:
       # Analyze character set and return optimal matcher
   ```

### Phase 2: Integration with Regex Engine (Week 2)

1. **Update CharacterClassSIMD**:
   - Replace lookup table with optimal SIMD matcher
   - Rewrite `_check_chunk_simd` to use true SIMD operations
   - Add fast paths for common patterns

2. **Enhance DFA engine**:
   - Integrate SIMD matchers in state transitions
   - Add compile-time specialization for common patterns
   - Optimize character class compilation

3. **Update NFA engine**:
   - Use SIMD matchers in `_match_digit`, `_match_range`, etc.
   - Add literal prefiltering with SIMD
   - Optimize backtracking with SIMD lookahead

### Phase 3: Optimization and Specialization (Week 3)

1. **Pre-built optimized matchers**:
   - `\d` → Optimized digit matcher
   - `\s` → Optimized whitespace matcher
   - `\w` → Optimized word character matcher
   - `[a-z]`, `[A-Z]`, `[0-9]` → Range matchers
   - `[a-zA-Z0-9]` → Combined range matcher

2. **Compile-time optimization**:
   - Generate specialized code for literal patterns
   - Inline common character class checks
   - Use const evaluation where possible

3. **Memory layout optimization**:
   - Align data structures for SIMD access
   - Minimize cache misses
   - Use compact representations

### Phase 4: Testing and Benchmarking (Week 4)

1. **Correctness testing**:
   - Unit tests for each SIMD matcher
   - Integration tests with regex engine
   - Edge case validation
   - Fuzzing with random character sets

2. **Performance benchmarking**:
   - Micro-benchmarks for each technique
   - End-to-end regex benchmarks
   - Comparison with current implementation
   - Memory usage analysis

3. **Optimization iteration**:
   - Profile and identify bottlenecks
   - Fine-tune SIMD operations
   - Adjust heuristics for matcher selection

## Expected Benefits

### Performance Improvements
- **10-30x speedup** for character class matching
- **50% reduction** in memory bandwidth usage
- **Better cache utilization** with smaller lookup structures
- **Reduced CPU cycles** through parallel processing

### Quality Improvements
- More maintainable code with specialized matchers
- Better debuggability with clear technique separation
- Easier to add new optimizations in the future

## Technical Considerations

### Mojo-specific Advantages
1. **SIMD shuffle availability**: ✅ Mojo provides `_dynamic_shuffle` with native hardware support
2. **Hardware optimization**: ✅ Automatic use of `pshufb` (x86) and `tbl1` (ARM) instructions
3. **Size handling**: ✅ `_dynamic_shuffle` automatically handles various vector sizes
4. **Compile-time specialization**: Leverage Mojo's parametric features for optimal code generation
5. **Type safety**: Maintain Mojo's type safety while using low-level SIMD

### Implementation Considerations
1. **Optimal vector size**: Use `SIMD[DType.uint8, 16]` for best performance with `_dynamic_shuffle`
2. **Memory alignment**: Ensure proper alignment for SIMD loads/stores
3. **Fallback handling**: Be aware of 3x performance penalty when SSE4/NEON unavailable
4. **API design**: Use `_dynamic_shuffle` as private implementation detail

### Compatibility Requirements
1. Maintain existing API compatibility
2. Ensure correct handling of Unicode (future consideration)
3. Support all current regex features
4. Graceful fallback for unsupported patterns

### Edge Cases to Handle
1. Empty character sets
2. Full ASCII range [\\x00-\\xFF]
3. Single character sets
4. Negated sets with few exclusions
5. Mixed range and literal sets

Example of `_dynamic_shuffle` usage in the Mojo stdlib:
```

fn validate_chunk[
    simd_size: Int
](
    current_block: SIMD[DType.uint8, simd_size],
    previous_input_block: SIMD[DType.uint8, simd_size],
) -> SIMD[DType.uint8, simd_size]:
    alias v0f = SIMD[DType.uint8, simd_size](0x0F)
    alias v80 = SIMD[DType.uint8, simd_size](0x80)
    alias third_byte = 0b11100000 - 0x80
    alias fourth_byte = 0b11110000 - 0x80
    var prev1 = _extract_vector[simd_size - 1](
        previous_input_block, current_block
    )
    var byte_1_high = shuf1._dynamic_shuffle(prev1 >> 4)
    var byte_1_low = shuf2._dynamic_shuffle(prev1 & v0f)
    var byte_2_high = shuf3._dynamic_shuffle(current_block >> 4)
    var sc = byte_1_high & byte_1_low & byte_2_high

    var prev2 = _extract_vector[simd_size - 2](
        previous_input_block, current_block
    )
    var prev3 = _extract_vector[simd_size - 3](
        previous_input_block, current_block
    )
    var is_third_byte = _sub_with_saturation(prev2, third_byte)
    var is_fourth_byte = _sub_with_saturation(prev3, fourth_byte)
    var must23 = is_third_byte | is_fourth_byte
    var must23_as_80 = must23 & v80
    return must23_as_80 ^ sc


fn _is_valid_utf8_runtime(span: Span[Byte]) -> Bool:
    """Fast utf-8 validation using SIMD instructions.

    References for this algorithm:
    J. Keiser, D. Lemire, Validating UTF-8 In Less Than One Instruction Per
    Byte, Software: Practice and Experience 51 (5), 2021
    https://arxiv.org/abs/2010.03090

    Blog post:
    https://lemire.me/blog/2018/10/19/validating-utf-8-bytes-using-only-0-45-cycles-per-byte-avx-edition/

    Code adapted from:
    https://github.com/simdutf/SimdUnicode/blob/main/src/UTF8.cs
    """

    ptr = span.unsafe_ptr()
    length = len(span)
    alias simd_size = sys.simdbytewidth()
    var i: Int = 0
    var previous = SIMD[DType.uint8, simd_size]()

    while i + simd_size <= length:
        var current_bytes = (ptr + i).load[width=simd_size]()
        var has_error = validate_chunk(current_bytes, previous)
        previous = current_bytes
        if any(has_error != 0):
            return False
        i += simd_size

    var has_error: SIMD[DType.uint8, simd_size]
    # last incomplete chunk
    if i != length:
        var buffer = SIMD[DType.uint8, simd_size](0)
        for j in range(i, length):
            buffer[j - i] = (ptr + j)[]
        has_error = validate_chunk(buffer, previous)
    else:
        # Add a chunk of 0s to the end to validate continuations bytes
        has_error = validate_chunk(SIMD[DType.uint8, simd_size](), previous)

    return all(has_error == 0)


fn _is_valid_utf8(span: Span[Byte]) -> Bool:
    """Verify that the bytes are valid UTF-8.

    Args:
        span: The Span of bytes.

    Returns:
        Whether the data is valid UTF-8.

    #### UTF-8 coding format
    [Table 3-7 page 94](http://www.unicode.org/versions/Unicode6.0.0/ch03.pdf).
    Well-Formed UTF-8 Byte Sequences

    Code Points        | First Byte | Second Byte | Third Byte | Fourth Byte |
    :----------        | :--------- | :---------- | :--------- | :---------- |
    U+0000..U+007F     | 00..7F     |             |            |             |
    U+0080..U+07FF     | C2..DF     | 80..BF      |            |             |
    U+0800..U+0FFF     | E0         | ***A0***..BF| 80..BF     |             |
    U+1000..U+CFFF     | E1..EC     | 80..BF      | 80..BF     |             |
    U+D000..U+D7FF     | ED         | 80..***9F***| 80..BF     |             |
    U+E000..U+FFFF     | EE..EF     | 80..BF      | 80..BF     |             |
    U+10000..U+3FFFF   | F0         | ***90***..BF| 80..BF     | 80..BF      |
    U+40000..U+FFFFF   | F1..F3     | 80..BF      | 80..BF     | 80..BF      |
    U+100000..U+10FFFF | F4         | 80..***8F***| 80..BF     | 80..BF      |
    """
    return _is_valid_utf8_runtime(span)
```

## Success Metrics

1. **Performance**:
   - 10x+ speedup on character class benchmarks
   - No regression on other regex operations
   - Reduced memory usage

2. **Correctness**:
   - Pass all existing tests
   - Pass new SIMD-specific tests
   - No behavioral changes

3. **Code Quality**:
   - Clear separation of concerns
   - Well-documented techniques
   - Easy to understand and modify

## Risks and Mitigations

1. **Risk**: Mojo SIMD API limitations
   - **Mitigation**: Prototype each technique early, have fallback implementations

2. **Risk**: Complexity increase
   - **Mitigation**: Clear documentation, good abstractions, comprehensive tests

3. **Risk**: Platform-specific behavior
   - **Mitigation**: Test on multiple architectures, use portable SIMD operations

4. **Risk**: Regression in edge cases
   - **Mitigation**: Extensive testing, gradual rollout, feature flags

## Conclusion

The discovery of Mojo's `_dynamic_shuffle` function significantly simplifies our implementation of SIMD byte lookup techniques. With native hardware support for `pshufb` (x86) and `tbl1` (ARM) instructions already available, we can achieve the promised 10-30x speedups for character class matching with less implementation complexity than originally anticipated.

The modular approach allows for incremental implementation and testing, ensuring stability while delivering performance improvements. The availability of `_dynamic_shuffle` means we can focus on the high-level matcher design rather than low-level SIMD intrinsics, making the implementation more maintainable and portable.
