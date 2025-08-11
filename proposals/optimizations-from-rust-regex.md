# Optimizations from Rust Regex: Performance Regression Analysis & Fixes

## Current Status (Updated 2025-08-11)

### Performance Regression Findings
Recent benchmarks on PR #28 revealed performance regressions for certain pattern types:
- `group_alternation: 0.78x` - Complex alternation handling overhead
- `quantifier_zero_or_more: 0.80x` - NFA quantifier processing overhead
- `range_digits: 0.81x` - SIMD integration causing NFA fallbacks
- `alternation_common_prefix: 0.83x` - Pattern classification misrouting
- `no_literal_baseline: 0.85x` - Overhead from literal optimization checks

**Root Cause**: Prefilter system and SIMD integration adding overhead to patterns that should use fast DFA path.

### Fixes Implemented
1. **Updated PatternAnalyzer** (`src/regex/optimizer.mojo`):
   - Made SIMD benefit analysis more selective (only for patterns with >2 SIMD nodes)
   - Added `should_use_pure_dfa()` method for patterns that don't need SIMD overhead
   - Fixed alternation classification to be more conservative

2. **Enhanced HybridMatcher** (`src/regex/matcher.mojo`):
   - Added `use_pure_dfa` flag to bypass prefilter overhead for simple patterns
   - Improved `_is_simple_pattern_skip_prefilter()` to catch more cases
   - Better routing for SIMPLE patterns to prioritize DFA

3. **Fixed NFA Quantifier Overhead** (`src/regex/ast.mojo`):
   - Made `is_simd_optimizable()` much more selective
   - Simple patterns like `[0-9]+` now use regular matching instead of SIMD
   - Only complex patterns (>8 chars) or high repetition (min>3) use SIMD

### Original Problem Analysis

### Previous Issue
- **Gap Identified**: 22 patterns classified as SIMPLE by PatternAnalyzer, but only 16 successfully use DFA engines
- **Root Cause**: 6 SIMPLE patterns fail DFA compilation in `compile_ast_pattern()` at `/src/regex/dfa.mojo:1325` and fall back to NFA
- **Impact**: Mismatch between theoretical complexity assessment and actual implementation coverage leads to suboptimal performance

### Technical Context
The issue occurs in the `compile_ast_pattern` function where patterns that don't match any of the implemented DFA handlers throw an error "Pattern too complex for current DFA implementation" and fall back to NFA execution in the HybridMatcher.

## Rust Architecture Study

### Key Insights from `regex-automata` Crate

1. **Multi-Engine Strategy System** (`strategy.rs:443-592`):
   - Core strategy with engine hierarchy: Dense DFA → Hybrid DFA → OnePass → Backtracker → PikeVM
   - Intelligent fallback system that tries engines in order of efficiency
   - Each engine wrapper handles availability and suitability checks

2. **Comprehensive Pattern Handling**:
   - Determinization system handles complex patterns through powerset construction
   - Multiple engine types provide different trade-offs (compile time vs runtime performance)
   - Meta strategy automatically selects best engine combination

3. **Engine Wrapper Architecture**:
   - Conditional compilation features for optional engines
   - Uniform API regardless of engine availability
   - Local logic for engine applicability decisions

## Implementation Plan

### Phase 1: Immediate DFA Coverage Expansion (High Priority)

#### 1.1 Identify Missing Pattern Handlers
Add support for common pattern types causing SIMPLE→NFA fallbacks:
- **Alternation patterns**: `a|b`, `cat|dog`
- **Basic quantified groups**: `(abc)+`, `(test)*`
- **Simple character class combinations**: `[a-z][0-9]`, `[A-Za-z]+`
- **Word boundary patterns**: `\b\w+\b`, `\btest\b`
- **Optional sequences**: `abc?def`, `test(ing)?`

#### 1.2 Enhance `compile_ast_pattern()` Function
**Location**: `/src/regex/dfa.mojo:1267-1327`

**Current Structure**:
```mojo
# Existing handlers:
# - Literal patterns
# - Pure anchors
# - Simple character classes
# - Multi-character sequences
# - Sequential patterns
# - Mixed sequential patterns
else:
    raise Error("Pattern too complex for current DFA implementation")
```

**Proposed Enhancement**:
```mojo
# Add before the error case:
elif _is_alternation_pattern(ast):
    var alt_info = _extract_alternation_info(ast)
    dfa.compile_alternation(alt_info)
elif _is_quantified_group(ast):
    var group_info = _extract_quantified_group_info(ast)
    dfa.compile_quantified_group(group_info)
elif _is_word_boundary_pattern(ast):
    var wb_info = _extract_word_boundary_info(ast)
    dfa.compile_word_boundary(wb_info)
# ... additional handlers
else:
    raise Error("Pattern too complex for current DFA implementation")
```

### Phase 2: Multi-Engine Architecture (Medium Priority)

#### 2.1 Introduce Hybrid DFA Engine
- **Purpose**: Implement lazy DFA that builds states on-demand (like Rust's hybrid engine)
- **Benefits**: Provides middle ground between full DFA compilation and NFA fallback
- **Use Case**: Handles patterns too complex for dense DFA but suitable for state-by-state construction

**Implementation**:
- Create `HybridDFAEngine` struct
- Implement on-demand state construction
- Add cache management for constructed states
- Integrate with existing HybridMatcher selection logic

#### 2.2 Add OnePass Engine
- **Purpose**: Implement OnePass DFA for linear-time regex subset
- **Benefits**: Handles patterns with specific structural properties that guarantee linear performance
- **Position**: Falls between DFA and NFA in the engine hierarchy

**Implementation**:
- Create `OnePassEngine` struct
- Implement pattern suitability analysis
- Add linear-time matching algorithm
- Integrate with engine selection strategy

### Phase 3: Engine Selection Strategy (Medium Priority)

#### 3.1 Implement Meta Strategy System
**Inspired by**: Rust's Core strategy in `/rust-regex/regex-automata/src/meta/strategy.rs`

**Engine Hierarchy**:
```mojo
fn try_search_mayfail(input: Input) -> Option[Result[Match, Error]]:
    if let engine = dfa.get(input):
        return engine.try_search(input)
    elif let engine = hybrid.get(input):
        return engine.try_search(input)
    elif let engine = onepass.get(input):
        return engine.try_search(input)
    else:
        return None  # Fall back to NFA engines
```

**Features**:
- Try engines in order of efficiency
- Engine availability and suitability checks
- Proper error handling and fallback logic
- Configuration-driven engine selection

#### 3.2 Engine Wrapper System
Create wrapper structs for each engine type:
- `DFAWrapper` - manages dense DFA availability
- `HybridWrapper` - manages hybrid DFA with cache
- `OnePassWrapper` - manages onepass engine suitability
- `NFAWrapper` - manages NFA fallback engines

### Phase 4: Advanced Optimizations (Lower Priority)

#### 4.1 Pattern Analysis Enhancement
**Location**: `/src/regex/optimizer.mojo` - PatternAnalyzer

**Current**: Basic SIMPLE/MEDIUM/COMPLEX classification
**Proposed**:
- Add engine-specific suitability metrics
- Implement pattern complexity scoring
- Add optimization hints for engine selection
- Pattern-specific heuristics (literal density, quantifier complexity, etc.)

#### 4.2 Prefilter Integration
- Implement literal extraction similar to Rust's approach
- Add Boyer-Moore-like fast literal searching
- Integrate with engine selection for hybrid strategies

## Performance Analysis

### Optimizations That Work Well
Recent benchmarks show these optimizations provide significant improvements:
- **`wildcard_match_any: 423.99x faster`** - Special handling for `.*` pattern
- **`literal_prefix_short: 89.16x faster`** - Literal prefix optimization
- **`quantifier_zero_or_one: 1.25x faster`** - Simple quantifier handling
- **`match_all_simple: 1.16x faster`** - Basic pattern matching
- **`literal_match_long: 1.14x faster`** - Literal string matching

### Patterns That Need Optimization
These patterns show regressions that were fixed:
- **`no_literal_baseline: 0.85x`** - Fixed by bypassing prefilter for simple patterns
- **`alternation_common_prefix: 0.83x`** - Fixed by conservative alternation classification
- **`range_digits: 0.81x`** - Fixed by selective SIMD application
- **`quantifier_zero_or_more: 0.80x`** - Fixed by optimizing NFA quantifier logic
- **`group_alternation: 0.78x`** - Fixed by better pattern routing

### Expected Results After Fixes
- **SIMPLE patterns**: Should return to 1.0x or better performance
- **Complex patterns**: Keep massive improvements (423x, 89x speedups)
- **Overall**: Maintain high-impact optimizations while eliminating regressions

## Expected Outcomes

### Immediate Benefits (Phase 1) - COMPLETED
- **✅ Reduced overhead**: Simple patterns bypass expensive prefilter analysis
- **✅ Performance improvement**: Better routing prevents NFA fallback for simple patterns
- **✅ Selective SIMD**: Only complex patterns use SIMD to avoid overhead

### Short-term Benefits (Phase 2-3)
- **Achieve 90%+ DFA coverage**: For SIMPLE patterns through multi-engine approach
- **Better scalability**: Handle more complex patterns without NFA fallback
- **Robust architecture**: Rust-inspired engine selection system

### Long-term Benefits (Phase 4)
- **Optimal engine selection**: Automatic best-engine selection per pattern
- **Advanced optimizations**: Prefilters and pattern-specific optimizations
- **Extensible design**: Easy addition of new engines and strategies

## Implementation Priority

1. **Phase 1**: Direct fix for current gap - expand `compile_ast_pattern()` handlers
2. **Phase 2**: Add Hybrid DFA for intermediate complexity patterns
3. **Phase 3**: Implement full meta strategy system
4. **Phase 4**: Advanced optimizations and analysis improvements

This approach provides immediate improvement with minimal architectural changes, then progressively builds the sophisticated multi-engine system inspired by Rust's proven architecture.

## References

- Rust regex-automata crate: `/rust-regex/regex-automata/src/meta/strategy.rs`
- Mojo DFA implementation: `/src/regex/dfa.mojo:1267-1327`
- Pattern analyzer: `/src/regex/optimizer.mojo`
- Hybrid matcher: `/src/regex/matcher.mojo:129-216`
