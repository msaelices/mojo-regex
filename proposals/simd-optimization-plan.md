# SIMD Optimization Plan for mojo-regex

## Problem Analysis

Based on benchmarking and analysis of the ishlib SIMD implementation, the key performance issue in our SIMD implementation is:

**We're still using lookup tables in the hot path, which causes random memory access and defeats SIMD optimization.**

### Current Performance Gap
- **Main branch**: nfa_simd_digits_10k runs in ~7.1ms
- **SIMD branch (optimized)**: Same test runs in ~17.8ms (2.5x slower)

### Root Cause
Even after optimizations, the `_check_chunk_simd` method for custom character classes falls back to:
```mojo
for i in range(SIMD_WIDTH):
    if is_ascii[i]:
        var char_code = Int(chunk[i])
        matches[i] = self.lookup_table[char_code] == 1  # Random memory access!
```

This is essentially a gather operation which is slow on most CPUs, as the expert mentioned: "Gathers are not particularly fast on most CPUs. I would do comparisons instead."

## Key Insights from ishlib

The ishlib implementation achieves high performance through:

1. **Profile-based preprocessing**: Query patterns are preprocessed into SIMD-friendly "profiles"
2. **No lookup tables in hot path**: All operations use direct SIMD comparisons
3. **Aligned memory**: Uses aligned memory structures for optimal SIMD performance
4. **Saturating arithmetic**: Uses LLVM intrinsics for efficient operations

## Proposed Solution: Profile-Based SIMD Matching

### 1. Create ProfiledCharacterClass Struct

Replace the lookup table approach with a profile-based representation:

```mojo
struct ProfiledCharacterClass:
    # For simple sets like [aeiou], store as bit masks
    var set_masks: List[SIMD[DType.uint8, SIMD_WIDTH]]

    # For ranges like [a-z], store start/end pairs
    var ranges: List[Tuple[UInt8, UInt8]]

    # For complex patterns, use multiple representations
    var is_negated: Bool
```

### 2. Implement Pure SIMD Character Testing

For character sets like [aeiou]:
```mojo
# Instead of lookup table, use SIMD comparisons
var is_a = chunk == SIMD[DType.uint8, SIMD_WIDTH](ord('a'))
var is_e = chunk == SIMD[DType.uint8, SIMD_WIDTH](ord('e'))
var is_i = chunk == SIMD[DType.uint8, SIMD_WIDTH](ord('i'))
var is_o = chunk == SIMD[DType.uint8, SIMD_WIDTH](ord('o'))
var is_u = chunk == SIMD[DType.uint8, SIMD_WIDTH](ord('u'))
var matches = is_a | is_e | is_i | is_o | is_u
```

For complex patterns like [a-zA-Z0-9]:
```mojo
# Use range comparisons (already partially implemented)
var is_lower = (chunk >= ord('a')) & (chunk <= ord('z'))
var is_upper = (chunk >= ord('A')) & (chunk <= ord('Z'))
var is_digit = (chunk >= ord('0')) & (chunk <= ord('9'))
var matches = is_lower | is_upper | is_digit
```

### 3. Bit-Packing for Arbitrary Character Sets

For arbitrary character sets, use bit-packing:
```mojo
# Pack 256 ASCII characters into 256 bits (32 bytes)
# Use SIMD to extract and test bits
struct BitPackedSet:
    var bits: SIMD[DType.uint64, 4]  # 256 bits total

    fn test_simd(self, chunk: SIMD[DType.uint8, SIMD_WIDTH]) -> SIMD[DType.bool, SIMD_WIDTH]:
        # Use SIMD bit manipulation to test membership
        # Extract bit positions and test in parallel
```

### 4. Memory Alignment Optimizations

- Ensure text chunks are loaded from aligned addresses
- Use aligned SIMD loads where possible
- Minimize cache line splits

## Implementation Steps

1. **Phase 1: Remove lookup tables**
   - Replace all lookup table accesses in `_check_chunk_simd`
   - Implement direct SIMD comparisons for all character classes

2. **Phase 2: Profile-based preprocessing**
   - Create ProfiledCharacterClass struct
   - Convert character classes at compile time or initialization

3. **Phase 3: Bit-packing optimization**
   - Implement bit-packed representation for arbitrary sets
   - Use SIMD bit manipulation for testing

4. **Phase 4: Memory alignment**
   - Add aligned memory support
   - Optimize chunk loading

## Expected Results

By eliminating random memory access and using pure SIMD operations, we expect:
- Performance similar to or better than the main branch
- True SIMD speedup for character class matching
- Better CPU cache utilization

## Alternative Approach: Hybrid Strategy

If full conversion proves complex, consider a hybrid approach:
- Use SIMD for common patterns (digits, letters, alphanumeric)
- Fall back to scalar for truly arbitrary character sets
- This would still cover 90%+ of real-world regex patterns
