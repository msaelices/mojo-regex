# Phone Number Regex DFA Optimization

## Problem Analysis

Current phone number parsing benchmarks show poor performance in Mojo compared to Python and Rust:

- **Simple Phone Pattern** (`\d{3}-\d{3}-\d{4}`): ~2.5ms vs 1.46ms (Python) vs 0.17ms (Rust)
- **Flexible Phone Pattern**: ~7.25ms vs 1.60ms (Python) vs 0.28ms (Rust)
- **Multi-Format Phone Pattern**: ~22.6ms vs 4.95ms (Python) vs 0.23ms (Rust)

### Root Cause Analysis

Investigation reveals that phone number patterns are being classified as **MEDIUM complexity** and routed to slow NFA/Hybrid engines instead of fast DFA:

```mojo
Pattern: \d{3}-\d{3}-\d{4}
  Complexity: SIMPLE (DFA eligible)
  Suggested engine: DFA
  Pure DFA eligible: False  ← Problem!

Pattern: \(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}
  Complexity: MEDIUM (Hybrid)  ← Problem!
  Pure DFA eligible: False
```

#### Specific Issues:

1. **Character Classes with SIMD Overhead**: `\d` triggers SIMD processing instead of pure DFA
2. **Optional Groups**: `\(?...\)?` increases complexity classification to MEDIUM
3. **Character Class Quantifiers**: `[\s.-]?` prevents simple DFA usage
4. **Complex Alternations**: Multiple formats with groups escalate to MEDIUM complexity

## Optimization Strategy

Transform phone number patterns to be **SIMPLE + Pure DFA eligible** for 10-100x performance improvement.

### Core Principles

1. **Replace Character Classes with Literals** when possible
2. **Eliminate Optional Groups** by flattening to explicit alternation
3. **Create Fast-Path DFA Patterns** for common cases (80-90% coverage)
4. **Smart Multi-Pattern Matching** with fallback to comprehensive patterns

## Implementation Plan

### Phase 1: DFA-Optimized Pattern Design

#### Pure DFA Patterns (SIMPLE + Pure DFA eligible)
```regex
# Literal test cases (Pure DFA eligible: True)
555-123-4567
(555) 123-4567

# Explicit digit patterns (avoid \d SIMD overhead)
[0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]
```

#### Semi-Optimized Patterns (SIMPLE complexity, avoid MEDIUM)
```regex
# Use [0-9] instead of \d to avoid SIMD
[0-9]{3}-[0-9]{3}-[0-9]{4}

# Explicit format patterns (no optional groups)
\([0-9]{3}\) [0-9]{3}-[0-9]{4}    # Parentheses format
[0-9]{3}\.[0-9]{3}\.[0-9]{4}      # Dot format
[0-9]{10}                         # Digits only
```

#### Smart Multi-Pattern Approach
```regex
# Fast path: Try DFA-optimized patterns first
1. [0-9]{3}-[0-9]{3}-[0-9]{4}           # Dash format
2. \([0-9]{3}\) [0-9]{3}-[0-9]{4}       # Paren format
3. [0-9]{3}\.[0-9]{3}\.[0-9]{4}         # Dot format
4. [0-9]{10}                            # Digits only

# Fallback: Use current comprehensive pattern for edge cases
5. \(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}  # Comprehensive
```

### Phase 2: Benchmark Implementation

Add new benchmark categories to all languages:

#### DFA-Optimized Benchmarks
1. **`dfa_simple_phone`**: `[0-9]{3}-[0-9]{3}-[0-9]{4}`
2. **`dfa_paren_phone`**: `\([0-9]{3}\) [0-9]{3}-[0-9]{4}`
3. **`dfa_dot_phone`**: `[0-9]{3}\.[0-9]{3}\.[0-9]{4}`
4. **`dfa_digits_only`**: `[0-9]{10}`

#### Smart Matcher Benchmarks
5. **`smart_phone_sequential`**: Try patterns 1-4 sequentially, measure first match
6. **`smart_phone_fallback`**: Try DFA patterns first, fallback to comprehensive

### Phase 3: Performance Validation

#### Expected Performance Improvements
- **Pure DFA patterns**: 10-50x faster (~0.1-0.5ms vs current 2-22ms)
- **SIMPLE DFA patterns**: 3-10x faster (guaranteed DFA usage)
- **Smart matcher**: 80-90% of real phone numbers use fast path

#### Success Metrics
- Mojo phone parsing performance within 2-5x of Rust performance
- 90%+ pattern coverage with DFA-optimized patterns
- Minimal accuracy loss compared to comprehensive patterns

### Phase 4: Integration Strategy

#### Backwards Compatibility
- Keep existing comprehensive patterns as fallback
- Add new DFA-optimized patterns as additional benchmark categories
- Allow users to choose between speed vs coverage

#### Real-World Usage Patterns
Test with realistic phone number datasets:
- US phone numbers from public datasets
- International format handling
- Edge case coverage analysis

## Technical Implementation Details

### Pattern Complexity Classification

Current complexity analyzer classifies patterns based on:
- **SIMPLE**: Literals, basic quantifiers, simple character classes → DFA eligible
- **MEDIUM**: Optional groups, complex quantifiers, alternation → Hybrid engine
- **COMPLEX**: Backreferences, lookahead, deep nesting → NFA only

### Pure DFA Eligibility Rules

Patterns are Pure DFA eligible when:
- SIMPLE complexity AND
- SIMD node count ≤ 1 AND
- No character classes with repetition (avoids SIMD overhead)

### Character Class Optimization

Replace SIMD-triggering patterns:
```regex
# SIMD overhead (not Pure DFA eligible)
\d{3}           → [0-9]{3}
[\s.-]?         → ( |-|\.)?

# Pure DFA eligible alternatives
[0-9][0-9][0-9]  # Explicit repetition
555              # Literal digits
```

## Migration Path

### Step 1: Add DFA-Optimized Benchmarks
- Implement new benchmark functions in all three languages
- Measure performance improvement vs current patterns
- Validate pattern accuracy on test datasets

### Step 2: Pattern Library Enhancement
- Add DFA-optimized patterns to regex library
- Implement smart multi-pattern matcher
- Provide performance/coverage tradeoff options

### Step 3: Documentation and Best Practices
- Document pattern optimization techniques
- Provide guidelines for DFA-friendly pattern design
- Create performance comparison charts

## Expected Outcomes

### Performance Targets
- **Mojo simple phone**: 2.5ms → 0.2-0.5ms (5-10x improvement)
- **Mojo flexible phone**: 7.25ms → 0.5-1.0ms (7-14x improvement)
- **Mojo multi-format**: 22.6ms → 1.0-2.0ms (11-22x improvement)

### Competitive Position
- Bring Mojo phone parsing performance to within 2-5x of Rust
- Maintain accuracy while dramatically improving speed
- Demonstrate DFA optimization techniques for other pattern types

## Future Extensions

### Pattern Optimization Framework
- Automatic pattern complexity analysis
- DFA-optimization suggestions
- Performance prediction tools

### Extended Phone Number Support
- International phone number formats
- Country-specific optimizations
- Multi-locale pattern libraries

### Broader Regex Optimization
- Apply DFA optimization techniques to other common patterns
- Email validation optimization
- URL parsing optimization
- Log parsing pattern optimization

This optimization should serve as a model for systematic regex performance improvement in the Mojo regex library.
