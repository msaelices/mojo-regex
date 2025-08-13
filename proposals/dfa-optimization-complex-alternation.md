# DFA Optimization for Complex Alternation Patterns

## Executive Summary

The Mojo regex engine currently classifies the national phone validation pattern as COMPLEX, routing it to the slow NFA engine and resulting in 40-80x slower performance compared to Rust's regex engine. Analysis of the Rust regex crate reveals that this pattern **can and should** be DFA-optimized using sophisticated alternation handling techniques.

**Pattern**: `96906(?:0[0-8]|1[1-9]|[2-9]\d)\d\d|9(?:69(?:0[0-57-9]|[1-9]\d)|73(?:[0-8]\d|9[1-9]))\d{4}|(?:8(?:[1356]\d|[28][0-8]|[47][1-9])|9(?:[135]\d|[268][0-8]|4[1-9]|7[124-9]))\d{6}`

**Performance Gap**:
- Rust: 0.040ms (fast DFA with alternation optimization)
- Python: 0.472ms (intermediate optimization)
- Mojo: 3.485ms (slow NFA fallback)

## Root Cause Analysis

### Current Classification Logic Flaws

The Mojo pattern analyzer in `src/regex/optimizer.mojo` is overly conservative:

1. **Depth Limit Too Restrictive** (`_analyze_alternation:363`)
   ```mojo
   if depth > 2:
       return PatternComplexity(PatternComplexity.COMPLEX)
   ```
   - Triggers COMPLEX for patterns with 3+ nesting levels
   - Our phone pattern has legitimate deep nesting but is DFA-compatible

2. **Alternation Count Limits** (`_analyze_alternation:386-391`)
   ```mojo
   if (max_complexity.value == PatternComplexity.SIMPLE
       and ast.get_children_len() <= 3):
       return PatternComplexity(PatternComplexity.SIMPLE)
   ```
   - Limited to 3 alternation branches
   - Phone pattern has more branches but remains DFA-compatible

3. **Non-Capturing Group Bias** (`_analyze_group:406-408`)
   - Non-capturing groups `(?:...)` bias toward MEDIUM/COMPLEX
   - Should analyze content, not syntax structure

### Rust's Superior Strategy

Rust regex crate (`regex-automata/src/meta/strategy.rs`) uses sophisticated analysis:

1. **Alternation Literal Detection** (lines 314-324)
   ```rust
   fn from_alternation_literals(info: &RegexInfo, hirs: &[&Hir]) -> Option<Arc<dyn Strategy>> {
       let lits = alternation_literals(info, hirs)?;
       let ac = AhoCorasick::new(MatchKind::LeftmostFirst, &lits)?;
       Some(Pre::new(ac))
   }
   ```

2. **Multi-Tier Engine Selection**:
   - **Literal-only alternations** → Aho-Corasick (fastest)
   - **Mixed alternations** → Lazy DFA with literal prefilter
   - **Complex patterns** → NFA with optimizations

3. **Threshold-Based Decisions** (`meta/literal.rs:76`)
   ```rust
   if lits.len() < 3000 {
       debug!("skipping Aho-Corasick because there are too few literals");
       return None;
   }
   ```

## Proposed Optimization Strategy

### Phase 1: Pattern Reclassification (Immediate Impact)

**Objective**: Reclassify national phone pattern from COMPLEX to MEDIUM/SIMPLE

#### 1.1 Fix Alternation Depth Analysis
**File**: `src/regex/optimizer.mojo:363-370`

**Current**:
```mojo
if depth > 2:
    return PatternComplexity(PatternComplexity.COMPLEX)
```

**Proposed**:
```mojo
if depth > 4:  # Increase depth tolerance
    # Check if this is a literal-heavy alternation before giving up
    if self._is_literal_heavy_alternation(ast):
        return PatternComplexity(PatternComplexity.MEDIUM)
    return PatternComplexity(PatternComplexity.COMPLEX)
```

#### 1.2 Implement Alternation Literal Detection
**New method** in `PatternAnalyzer`:

```mojo
fn _is_literal_heavy_alternation(self, ast: ASTNode) -> Bool:
    """Check if alternation consists mainly of literal patterns that DFA can handle efficiently."""
    if ast.type != OR:
        return False

    var literal_branches = 0
    var total_branches = ast.get_children_len()

    for i in range(total_branches):
        if self._is_dfa_compatible_branch(ast.get_child(i)):
            literal_branches += 1

    # If 80%+ branches are DFA-compatible, classify as MEDIUM
    return (literal_branches * 5) >= (total_branches * 4)  # 80% threshold
```

#### 1.3 Improve Non-Capturing Group Analysis
**File**: `src/regex/optimizer.mojo:396-472`

**Strategy**: Analyze group **content** rather than **syntax**:

```mojo
fn _analyze_group(self, ast: ASTNode, depth: Int) -> PatternComplexity:
    # ... existing code ...

    # For non-capturing groups, focus on content complexity
    if ast.is_non_capturing():
        var content_complexity = self._analyze_group_content(ast, depth)
        if content_complexity.value == PatternComplexity.SIMPLE:
            return PatternComplexity(PatternComplexity.SIMPLE)
        elif self._has_literal_structure(ast):
            return PatternComplexity(PatternComplexity.MEDIUM)

    # ... rest of existing logic ...
```

### Phase 2: DFA Engine Extensions

#### 2.1 One-Pass DFA Implementation
**New file**: `src/regex/onepass_dfa.mojo`

Based on Rust's `onepass.rs`, implement a specialized DFA for patterns where:
- Each input byte has at most one execution path
- Perfect for phone validation patterns
- Handles capturing groups with DFA performance

**Key features**:
```mojo
struct OnePassDFA:
    """DFA that can return spans for matching capturing groups."""
    var transitions: DTypePointer[StateTransition]
    var capture_slots: List[CaptureSlot]

    fn can_build_onepass(ast: ASTNode) -> Bool:
        """Check if pattern qualifies for one-pass DFA construction."""
        return self._check_onepass_property(ast)
```

#### 2.2 Lazy DFA Enhancement
**File**: `src/regex/dfa.mojo`

Enhance existing DFA with on-demand state construction:

```mojo
struct LazyDFA:
    """DFA that builds states on-demand for memory efficiency."""
    var state_cache: Dict[StateSignature, StateID]
    var max_cache_size: Int

    fn get_or_build_state(self, signature: StateSignature) -> StateID:
        """Build DFA states lazily to handle large alternation patterns."""
```

### Phase 3: Literal Prefilter Optimization

#### 3.1 Multi-Pattern Prefilter
**File**: `src/regex/prefilter.mojo`

Implement Aho-Corasick-style multi-pattern matching:

```mojo
struct AlternationPrefilter:
    """Optimized literal matching for alternation patterns."""
    var patterns: List[String]
    var automaton: AhoCorasickAutomaton

    fn from_alternation(ast: ASTNode) -> Optional[AlternationPrefilter]:
        """Extract literal patterns from alternation for fast prefiltering."""
```

#### 3.2 Enhanced Literal Extraction
**File**: `src/regex/literal_optimizer.mojo`

Improve prefix/suffix extraction for complex alternations:

```mojo
fn extract_alternation_literals(ast: ASTNode) -> LiteralSet:
    """Extract literals from complex alternation patterns."""
    # Extract: 96906, 969, 973, 8, 9 from phone pattern
    # Use for prefiltering before DFA confirmation
```

### Phase 4: Meta-Engine Strategy

#### 4.1 Strategy Selection Engine
**New file**: `src/regex/meta_engine.mojo`

Implement Rust-style automatic engine selection:

```mojo
struct MetaEngine:
    """Meta-engine that selects optimal strategy based on pattern analysis."""

    fn select_strategy(ast: ASTNode) -> EngineStrategy:
        if self._is_pure_alternation_literals(ast):
            return AhoCorasickStrategy(ast)
        elif self._is_onepass_compatible(ast):
            return OnePassDFAStrategy(ast)
        elif self._is_dfa_compatible(ast):
            return LazyDFAStrategy(ast)
        else:
            return NFAStrategy(ast)
```

## Implementation Plan

### Critical Path (Week 1-2)
1. **Fix alternation depth limits** - Immediate 10-20x improvement
2. **Implement literal-heavy alternation detection** - Reclassify phone pattern
3. **Add alternation prefilter** - Fast literal screening

### High Impact (Week 3-4)
1. **One-Pass DFA implementation** - Target 40-60x improvement
2. **Multi-pattern prefilter** - Aho-Corasick for alternations
3. **Enhanced literal extraction** - Better prefix detection

### Advanced Optimizations (Month 2)
1. **Lazy DFA enhancement** - Memory-efficient state construction
2. **Meta-engine strategy** - Automatic optimization selection
3. **Reverse search optimizations** - End-anchored patterns

## Performance Projections

| Phase | Optimization | Expected Improvement | Target Performance |
|-------|--------------|---------------------|-------------------|
| 1 | Pattern Reclassification | 10-20x | ~0.35ms |
| 2 | One-Pass DFA | 40-60x | ~0.08ms |
| 3 | Literal Prefilter | 60-80x | ~0.05ms |
| 4 | Meta-Engine | 80-100x | ~0.04ms (Rust-level) |

## Validation Strategy

### Correctness Testing
1. **Cross-validation** with Python/Rust regex results
2. **Comprehensive test suite** for phone validation patterns
3. **Edge case verification** for complex alternations

### Performance Benchmarking
1. **Micro-benchmarks** for each optimization phase
2. **Comparative analysis** against Rust/Python implementations
3. **Memory usage profiling** for lazy DFA

### Regression Testing
1. **Existing pattern compatibility** - ensure no performance regressions
2. **Accuracy maintenance** - verify all optimizations preserve correctness
3. **Engine fallback testing** - validate graceful degradation

## Risk Assessment

### Low Risk
- **Pattern reclassification fixes** - Conservative improvements to existing logic
- **Literal prefilter enhancements** - Additive optimizations

### Medium Risk
- **One-Pass DFA implementation** - New engine requires thorough testing
- **Lazy DFA modifications** - Changes to core DFA logic

### High Risk
- **Meta-engine strategy** - Major architectural changes
- **Alternation literal detection** - Complex pattern analysis logic

## Success Metrics

### Primary Goals
- **Performance**: Achieve <0.1ms for national phone validation pattern
- **Compatibility**: Maintain 100% accuracy with Python regex results
- **Generalization**: Improve performance for similar alternation patterns

### Secondary Goals
- **Memory efficiency**: Reasonable memory usage for lazy DFA
- **Code maintainability**: Clear separation of optimization strategies
- **Extensibility**: Framework for future DFA optimizations

## Conclusion

The national phone validation pattern represents a class of **DFA-compatible complex alternations** that are currently misclassified by overly conservative heuristics. By implementing Rust-inspired optimization strategies, we can achieve 40-80x performance improvements while maintaining correctness and extending benefits to similar patterns.

The proposed multi-phase approach provides incremental value delivery with manageable risk, ultimately positioning the Mojo regex engine to compete with best-in-class implementations for complex real-world patterns.
