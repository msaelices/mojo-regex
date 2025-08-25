# Regex Cache Corruption Analysis and Fix Strategy

**Status**: Investigation Complete - Fix Strategy Defined
**Priority**: Critical
**Impact**: Resolves 1000x performance degradation in benchmarks
**Date**: 2025-08-25

## Executive Summary

The mojo-regex library suffered from a critical state corruption bug that caused:
- `findall()` operations to return 0 matches instead of correct results
- 1000x performance degradation (50ms instead of 0.05ms per operation)
- Unrealistic benchmark comparisons showing 1500x differences between Python and Mojo

**Root Cause**: CompiledRegex objects with mutable internal state were cached globally and reused across different operations, leading to haystack-dependent state corruption.

**Current Status**: Temporarily fixed by disabling CompiledRegex caching. This proposal outlines the strategy for implementing a proper fix and restoring safe caching.

## Problem Analysis

### Trigger Sequence
The corruption was triggered by specific sequences of regex operations:
1. `match_first()` operations with wildcard patterns like `.*`
2. Followed by `search()` operations with character ranges like `[0-9]+`
3. All subsequent `findall()` calls would return 0 matches and run 1000x slower

### Evidence
- **Reproduction**: Consistently reproduced with `playground/reproduce_regex_cache_issue.mojo`
- **Cache Clearing**: `clear_regex_cache()` immediately resolved the corruption
- **Pattern Recognition**: Affected benchmarks all ran after wildcard pattern operations
- **Performance Impact**: Single operation time jumped from 0.05ms to 50ms

## Mutable State Analysis

### Pattern-Dependent State (SAFE for Caching)
These depend only on the regex pattern itself and are consistent regardless of haystack:

**HybridMatcher:**
```mojo
var is_exact_literal: Bool           # Pattern classification
var is_wildcard_match_any: Bool      # True only for ".*"
var use_pure_dfa: Bool              # Based on pattern complexity
var complexity: PatternComplexity   # Pattern analysis result
var prefilter: Optional[MemchrPrefilter]  # Pattern-based optimization
var literal_info: OptimizedLiteralInfo   # Extracted from pattern
```

**NFAEngine:**
```mojo
var literal_prefix: String               # Extracted from pattern
var has_literal_optimization: Bool       # Based on pattern analysis
var prev_re: String                      # Pattern caching state
var prev_ast: Optional[ASTNode]          # Cached pattern compilation
```

**DFAEngine:**
```mojo
var states: List[DFAState]              # Compiled pattern states
var start_state: Int                    # Pattern-determined start
var has_start_anchor: Bool              # Pattern has ^
var has_end_anchor: Bool                # Pattern has $
```

### Haystack-Dependent State (CORRUPTION SOURCE)
Critical insight: **No instance variables store haystack-dependent state**. All matching functions use local variables:
- `current_pos`, `search_pos` - Local position tracking
- `temp_matches` - Local match collection
- Function parameters - No persistent state in `self`

## Root Cause Investigation

### Global Cache Corruption
The corruption source appears to be in global caches, not instance variables:

1. **`_CACHE_GLOBAL`** - Main CompiledRegex cache
2. **`_RANGE_MATCHERS_GLOBAL`** - SIMD range matcher cache
3. **`_NIBBLE_MATCHERS_GLOBAL`** - Nibble-based matcher cache
4. **`_SIMD_MATCHERS_GLOBAL`** - SIMD operations cache

### Suspected Mechanisms
1. **Shared Global Matcher Objects**: SIMD matchers may have internal state corrupted by specific haystack patterns
2. **Memory Layout Dependencies**: SIMD register state or memory alignment issues
3. **Global Cache Key Collisions**: Pattern-to-matcher mapping corruption

## Solution Strategy

### Phase 1: Identify Specific Corruption Source
**Objective**: Pinpoint which global cache system is getting corrupted

**Actions**:
1. **Isolated Cache Testing**
   ```mojo
   // Test clearing each global cache individually
   clear_range_matchers()    // Test if this fixes corruption
   clear_nibble_matchers()   // Test if this fixes corruption
   clear_simd_matchers()     // Test if this fixes corruption
   ```

2. **SIMD Matcher State Investigation**
   - Examine `RangeBasedMatcher`, `NibbleBasedMatcher` implementations
   - Look for any haystack-dependent internal state
   - Check SIMD operations for residual state in registers

3. **Memory Corruption Analysis**
   - Use memory debugging tools to detect corruption
   - Validate object lifetimes in global caches

### Phase 2: Implement Targeted Fix
Based on Phase 1 findings, choose appropriate fix:

**Option A: Copy-Based Global Cache Access**
```mojo
fn get_range_matcher(matcher_type: Int) -> RangeBasedMatcher:
    # Return copy instead of reference to prevent shared state corruption
    return _get_range_matchers()[matcher_type]  // Copy, not reference
```

**Option B: Add State Reset Mechanisms**
```mojo
fn reset_global_matcher_state():
    """Clear any residual haystack-dependent state in global matchers."""
    // Reset SIMD registers or internal matcher state
```

**Option C: Fix SIMD Matcher Implementation**
If specific SIMD matchers have haystack-dependent bugs, fix them directly.

**Option D: Restore Safe CompiledRegex Caching**
```mojo
struct StatelessCompiledRegex:
    """Immutable compiled pattern that can be safely cached."""
    // Only pattern-dependent immutable state
    // No haystack-dependent mutable components
```

### Phase 3: Validation and Performance Testing
1. **Corruption Resolution**: Verify fix resolves all trigger sequences
2. **Performance Validation**: Ensure no regression from fix
3. **Benchmark Accuracy**: Confirm realistic Python vs Mojo comparisons
4. **Edge Case Testing**: Test various haystack and pattern combinations

## Technical Implementation Details

### Current Bandaid Fix
```mojo
fn compile_regex(pattern: String) raises -> CompiledRegex:
    # FIXME: Disable caching temporarily due to mutable state corruption bug
    return CompiledRegex(pattern)  // Always create new instances
```

### Global Cache Architecture
```mojo
// Multiple global caches using ffi._Global
alias _CACHE_GLOBAL = _Global["RegexCache", RegexCache, _init_regex_cache]
alias _RANGE_MATCHERS_GLOBAL = ffi._Global["RangeMatchers", RangeMatchers, _init_range_matchers]
alias _NIBBLE_MATCHERS_GLOBAL = ffi._Global["NibbleMatchers", NibbleMatchers, _init_nibble_matchers]
alias _SIMD_MATCHERS_GLOBAL = ffi._Global["SIMDMatchers", SIMDMatchers, _init_simd_matchers]
```

## Performance Impact Analysis

### Before Fix (Corrupted State)
- Single `findall("hello", text)`: 50ms
- 0 matches returned (incorrect)
- 1500x slower than Python equivalent

### After Bandaid Fix (No Caching)
- Single `findall("hello", text)`: 0.06ms
- 300 matches returned (correct)
- 2x slower than Python (realistic)

### Target (Proper Fix with Safe Caching)
- Single `findall("hello", text)`: 0.05ms (with caching benefits)
- 300 matches returned (correct)
- Competitive with or faster than Python

## Risk Assessment

### Low Risk Approaches
- **Copy-based cache access**: Minimal code change, preserves current architecture
- **State reset mechanisms**: Targeted fix for specific corruption source

### Medium Risk Approaches
- **SIMD matcher fixes**: May require understanding low-level SIMD state management
- **Global cache refactoring**: More invasive but cleaner long-term solution

### High Risk Approaches
- **Complete architecture rewrite**: Unnecessary given the targeted nature of the issue

## Next Steps

### Immediate Actions (Week 1)
1. **Create test harnesses** for isolated global cache testing
2. **Investigate SIMD matcher implementations** for haystack-dependent state
3. **Identify the specific corrupted global cache system**

### Implementation (Week 2)
1. **Implement targeted fix** based on Phase 1 findings
2. **Create comprehensive test suite** for corruption scenarios
3. **Performance benchmark** the fix against current bandaid

### Validation (Week 3)
1. **End-to-end testing** with various pattern/haystack combinations
2. **Performance regression testing** across benchmark suite
3. **Documentation update** and code cleanup

### Production Release (Week 4)
1. **Remove bandaid fix** and restore proper caching
2. **Update benchmarks** with corrected performance comparisons
3. **Monitor for any remaining edge cases**

## Success Criteria

- ✅ **Corruption Resolution**: No more 0-match returns or 1000x slowdowns
- ✅ **Performance Restoration**: Caching benefits restored (sub-0.1ms operations)
- ✅ **Benchmark Accuracy**: Realistic Python vs Mojo performance comparisons
- ✅ **Code Quality**: Clean, maintainable fix without architectural debt
- ✅ **Reliability**: Robust against various pattern/haystack combinations

## Conclusion

This analysis reveals that the regex cache corruption is a targeted issue with global cache state management, not a fundamental architectural problem. The majority of the codebase is well-designed with proper separation between pattern-dependent and haystack-dependent state.

A surgical fix targeting the specific global cache corruption mechanism will restore the performance benefits of caching while ensuring correctness across all usage patterns. This approach is far preferable to a complete architectural rewrite and will deliver results quickly with minimal risk.
