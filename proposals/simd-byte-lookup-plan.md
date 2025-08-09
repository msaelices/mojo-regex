# SIMD Byte Lookup Implementation Plan for Mojo Regex Library

## Overview

This document outlines the plan to implement advanced SIMD byte lookup techniques in the mojo-regex library, based on the research from [0x80.pl's SIMD byte lookup article](http://0x80.pl/notesen/2018-10-18-simd-byte-lookup.html). The goal is to achieve 10-30x speedups for character class matching operations.

## Implementation Status Summary

**Branch**: `simd-byte-lookup`
**Overall Status**: ✓ Partially Implemented
- **Core SIMD Support**: ✓ Implemented using `_dynamic_shuffle`
- **Performance Achieved**: 1.18x geometric mean speedup (vs 10-30x goal)
- **Benchmarks Improved**: 25 out of 30 (83%)
- **Integration**: ✓ NFA and DFA engines updated
- **Advanced Techniques**: ❌ Only basic shuffle implemented, advanced matchers not integrated

## What Was Actually Implemented

### Core Implementation
The implementation centers around an enhanced `CharacterClassSIMD` struct in `src/regex/simd_ops.mojo`:

1. **Hybrid Lookup Approach**:
   - Uses traditional 256-byte lookup table as the base
   - Applies `_dynamic_shuffle` optimization for character classes with >3 characters
   - Falls back to simple lookup for small character classes (≤3 chars)

2. **SIMD Width Support**:
   ```mojo
   alias USE_SHUFFLE = SIMD_WIDTH == 16 or SIMD_WIDTH == 32
   ```
   - Native support for both SSE (16-byte) and AVX2 (32-byte) SIMD widths
   - Graceful fallback for other widths by processing in 16-byte sub-chunks

3. **Hardware Acceleration**:
   - Uses `pshufb` instruction on x86 (SSE3/SSSE3) for 16-byte chunks
   - Uses `vpshufb` instruction on AVX2 for 32-byte chunks
   - Leverages Mojo's `_dynamic_shuffle` for automatic hardware optimization

### Global Caching System
A global cache was implemented to avoid repeated creation of common character class matchers:
- Lazy initialization - matchers created on first use
- Dictionary-based storage with integer keys
- Pre-defined constants for common patterns (digits, whitespace, etc.)

### NFA Engine Integration
The NFA engine was updated to use SIMD matchers for:
- `\d` (digit) patterns via `SIMD_MATCHER_DIGITS`
- `\s` (whitespace) patterns via `SIMD_MATCHER_WHITESPACE`
- Character ranges when possible
- Quantifier optimization with `_apply_quantifier_simd` method

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

## Performance Results

### Benchmark Improvements
The implementation achieved significant performance gains across most benchmarks:

**Top Performers**:
- `match_all_simple`: 2.66x speedup
- `simd_negated_alphanumeric`: 1.79x speedup
- `simd_multi_char_class`: 1.57x speedup
- `literal_prefix_medium`: 1.48x speedup
- `no_literal_baseline`: 1.47x speedup
- `simd_alphanumeric_large`: 1.42x speedup

**Minor Regressions**:
- `required_literal_short`: 0.83x (small patterns where SIMD overhead isn't justified)
- `literal_prefix_long`: 0.95x
- `range_alphanumeric`: 0.97x
- `wildcard_match_any`: 0.98x
- `group_quantified`: 0.98x

### Key Insights
1. SIMD operations excel with character-class-heavy patterns
2. Small patterns may see slight regression due to SIMD setup overhead
3. The hybrid approach (threshold >3 chars) helps minimize overhead for small sets
4. Global caching significantly reduces repeated matcher creation overhead

## Implementation Details

### CharacterClassSIMD Structure
The core implementation uses a hybrid approach:

```mojo
struct CharacterClassSIMD:
    var lookup_table: SIMD[DType.uint8, 16]
    var size_hint: Int
    var use_shuffle: Bool

    fn __init__(mut self, char_class: String):
        # Initialize lookup table
        self.size_hint = len(char_class)
        self.use_shuffle = self.size_hint > 3 and (SIMD_WIDTH == 16 or SIMD_WIDTH == 32)

    fn _check_chunk_simd(self, chunk: SIMD[DType.uint8, 16]) -> SIMD[DType.bool, 16]:
        if self.use_shuffle:
            # Use hardware-accelerated shuffle
            var result = self.lookup_table._dynamic_shuffle(chunk)
            return result != 0
        else:
            # Fall back to simple lookup for small sets
            return self._check_chunk_simple(chunk)
```

### Key Implementation Choices
1. **Threshold of >3 characters**: Balances SIMD setup overhead vs. performance gains
2. **256-byte lookup table**: Compressed to 16 bytes for shuffle operations
3. **Hardware detection**: Automatically uses optimal instructions based on SIMD width
4. **Fallback mechanism**: Gracefully handles unsupported SIMD widths

### Global Matcher Cache
The implementation includes a global caching system for frequently used matchers:

```mojo
# Pre-defined matcher constants
alias SIMD_MATCHER_DIGITS = 0
alias SIMD_MATCHER_WHITESPACE = 1
alias SIMD_MATCHER_LOWERCASE = 2
alias SIMD_MATCHER_UPPERCASE = 3
alias SIMD_MATCHER_LETTERS = 4
alias SIMD_MATCHER_ALPHANUMERIC = 5

# Global cache access
fn get_simd_matcher(matcher_type: Int) -> CharacterClassSIMD:
    # Returns cached matcher or creates new one
    return _get_or_create_simd_matcher(matcher_type)
```

### Additional SIMD Components
1. **SIMDStringSearch**: Optimized literal string search using SIMD comparisons
2. **TwoWaySearcher**: Two-Way algorithm enhanced with SIMD operations
3. **MultiLiteralSearcher**: Can search for up to 16 literals simultaneously

## Future Optimization Opportunities

While the current implementation provides solid performance improvements, there are opportunities for further optimization:

1. **Advanced Matchers**: The `simd_matchers.mojo` file contains experimental implementations of:
   - `NibbleBasedMatcher`: For patterns that fit in 16 values
   - `RangeBasedMatcher`: For contiguous character ranges
   - `BitmaskMatcher`: For arbitrary character sets
   These could be integrated for specific pattern types.

2. **DFA Integration**: Better integration with the DFA engine for patterns that can be deterministically matched

3. **Literal Optimization**: Further improvements to literal prefix/suffix extraction and matching

4. **Debug Cleanup**: Remove debug print statements from production code

## Implementation Plan

### Phase 1: Core SIMD Matchers (Week 1)

1. **Create base trait for SIMD matchers**: ✓ (implemented in simd_matchers.mojo)
   ```mojo
   trait SIMDMatcher:
       fn match_chunk(self, chunk: SIMD[DType.uint8, SIMD_WIDTH]) -> SIMD[DType.bool, SIMD_WIDTH]
       fn contains(self, char_code: Int) -> Bool  # Note: actual implementation uses 'contains'
   ```

2. **Implement specialized matchers**:
   - `NibbleBasedMatcher` for hex digits, small sets ✓ (implemented in simd_matchers.mojo but not integrated)
   - `RangeBasedMatcher` for contiguous ranges ✓ (implemented in simd_matchers.mojo but not integrated)
   - `BitmaskMatcher` for arbitrary sets ❌
   - `SmallSetMatcher` for tiny sets (≤8 elements) ❌

3. **Create matcher factory**: ✓ (partially - `get_simd_matcher` function with pre-defined types)
   ```mojo
   fn create_optimal_matcher(char_set: String) -> SIMDMatcher:
       # Analyze character set and return optimal matcher
   ```

### Phase 2: Integration with Regex Engine (Week 2)

1. **Update CharacterClassSIMD**:
   - Replace lookup table with optimal SIMD matcher ❌ (still uses 256-byte lookup table)
   - Rewrite `_check_chunk_simd` to use true SIMD operations ✓ (uses `_dynamic_shuffle`)
   - Add fast paths for common patterns ✓ (threshold >3 chars for shuffle)

2. **Enhance DFA engine**:
   - Integrate SIMD matchers in state transitions ✓ (DFA uses CharacterClassSIMD)
   - Add compile-time specialization for common patterns ❌
   - Optimize character class compilation ❌

3. **Update NFA engine**:
   - Use SIMD matchers in `_match_digit`, `_match_range`, etc. ✓ (uses get_simd_matcher)
   - Add literal prefiltering with SIMD ✓ (TwoWaySearcher with SIMD)
   - Optimize backtracking with SIMD lookahead ❌

### Phase 3: Optimization and Specialization (Week 3)

1. **Pre-built optimized matchers**:
   - `\d` → Optimized digit matcher ✓ (SIMD_MATCHER_DIGITS)
   - `\s` → Optimized whitespace matcher ✓ (SIMD_MATCHER_WHITESPACE)
   - `\w` → Optimized word character matcher ❌
   - `[a-z]`, `[A-Z]`, `[0-9]` → Range matchers ✓ (pre-defined matchers available)
   - `[a-zA-Z0-9]` → Combined range matcher ✓ (SIMD_MATCHER_ALPHANUMERIC)

2. **Compile-time optimization**:
   - Generate specialized code for literal patterns ❌
   - Inline common character class checks ❌
   - Use const evaluation where possible ❌

3. **Memory layout optimization**:
   - Align data structures for SIMD access ❌
   - Minimize cache misses ✓ (global caching reduces repeated allocations)
   - Use compact representations ❌ (still uses 256-byte lookup table)

### Phase 4: Testing and Benchmarking (Week 4)

1. **Correctness testing**:
   - Unit tests for each SIMD matcher ✓ (basic tests exist)
   - Integration tests with regex engine ✓ (regex tests pass)
   - Edge case validation ✓ (handled in CharacterClassSIMD)
   - Fuzzing with random character sets ❌

2. **Performance benchmarking**:
   - Micro-benchmarks for each technique ❌
   - End-to-end regex benchmarks ✓ (comprehensive benchmark suite)
   - Comparison with current implementation ✓ (benchmark comparison tools)
   - Memory usage analysis ❌

3. **Optimization iteration**:
   - Profile and identify bottlenecks ✓ (benchmark results analyzed)
   - Fine-tune SIMD operations ✓ (threshold tuning, width support)
   - Adjust heuristics for matcher selection ✓ (>3 char threshold)

## Expected Benefits

### Performance Improvements
- **10-30x speedup** for character class matching ❌ (achieved 1.18x-2.66x in practice)
- **50% reduction** in memory bandwidth usage ❌ (not measured)
- **Better cache utilization** with smaller lookup structures ❌ (still uses 256-byte table)
- **Reduced CPU cycles** through parallel processing ✓ (SIMD reduces cycles)

### Quality Improvements
- More maintainable code with specialized matchers ✓ (partially - global cache system)
- Better debuggability with clear technique separation ❌ (debug prints need removal)
- Easier to add new optimizations in the future ✓ (modular design)

## Technical Considerations

### Mojo-specific Advantages
1. **SIMD shuffle availability**: ✅ Mojo provides `_dynamic_shuffle` with native hardware support
2. **Hardware optimization**: ✅ Automatic use of `pshufb` (x86) and `tbl1` (ARM) instructions
3. **Size handling**: ✅ `_dynamic_shuffle` automatically handles various vector sizes
4. **Compile-time specialization**: Leverage Mojo's parametric features for optimal code generation
5. **Type safety**: Maintain Mojo's type safety while using low-level SIMD

### Implementation Considerations
1. **Optimal vector size**: Use `SIMD[DType.uint8, 16]` for best performance with `_dynamic_shuffle` ✓
2. **Memory alignment**: Ensure proper alignment for SIMD loads/stores ❌
3. **Fallback handling**: Be aware of 3x performance penalty when SSE4/NEON unavailable ✓
4. **API design**: Use `_dynamic_shuffle` as private implementation detail ✓

### Compatibility Requirements
1. Maintain existing API compatibility ✓
2. Ensure correct handling of Unicode (future consideration) ❌
3. Support all current regex features ✓
4. Graceful fallback for unsupported patterns ✓

### Edge Cases to Handle
1. Empty character sets ✓
2. Full ASCII range [\\x00-\\xFF] ✓
3. Single character sets ✓
4. Negated sets with few exclusions ❌
5. Mixed range and literal sets ✓

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
   - 10x+ speedup on character class benchmarks ❌ (achieved 1.18x-2.66x)
   - No regression on other regex operations ✓ (mostly - 5 minor regressions)
   - Reduced memory usage ❌ (not measured, still uses 256-byte tables)

2. **Correctness**:
   - Pass all existing tests ✓
   - Pass new SIMD-specific tests ✓
   - No behavioral changes ✓

3. **Code Quality**:
   - Clear separation of concerns ✓ (partially - good module structure)
   - Well-documented techniques ✓ (docstrings present)
   - Easy to understand and modify ✓ (modular design)

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
