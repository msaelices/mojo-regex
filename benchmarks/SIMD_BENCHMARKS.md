# SIMD-Optimized Regex Benchmarks

This document describes the SIMD-focused benchmarks created to demonstrate performance improvements in the mojo-regex library.

## Overview

The mojo-regex library includes SIMD optimizations for character class matching patterns. These benchmarks are designed to showcase scenarios where SIMD optimizations provide significant performance benefits.

## Benchmark Files

### 1. `simd_focused_benchmark.mojo`
Direct NFA engine benchmarks that test SIMD-optimized patterns:
- **Digit Matching (`\d+`)**: Tests SIMD digit character class matching
- **Whitespace Matching (`\s+`)**: Tests SIMD whitespace character class matching
- **Character Range Matching (`[a-zA-Z0-9]+`)**: Tests SIMD alphanumeric character class matching
- **Negated Character Range (`[^a-zA-Z0-9]+`)**: Tests SIMD negated character class matching
- **Quantified Character Range (`[a-z]{3,10}`)**: Tests SIMD with quantified character classes

### 2. `simd_focused_benchmark.py`
Equivalent Python benchmarks for comparison:
- Uses Python's `re` module to provide baseline performance comparison
- Identical patterns and test data generation to ensure fair comparison
- Provides timing results for direct performance comparison

### 3. `bench_engine.mojo` (Enhanced)
The existing benchmark file includes SIMD-optimized sections:
- **SIMD-Optimized Character Filtering**: Large-scale character class matching tests
- Mixed content text generation for realistic SIMD performance testing

## Key SIMD Optimizations

The benchmarks test these SIMD optimization areas:

1. **Character Class Lookup Tables**: Using SIMD instructions for fast character class membership testing
2. **Bulk Character Processing**: Processing multiple characters simultaneously using SIMD vectors
3. **Quantified Pattern Matching**: Optimized repetition counting for character classes

## SIMD Infrastructure

The SIMD optimizations leverage:
- `regex.simd_ops` module for SIMD character class operations
- `CharacterClassSIMD` for efficient character set matching
- `enable_simd` flags on AST nodes to control SIMD usage
- Specialized SIMD matchers for digits, whitespace, and custom character ranges

## Usage

### Running Mojo Benchmarks
```bash
# Run the focused SIMD benchmarks
mojo benchmarks/simd_focused_benchmark.mojo
```

### Running Python Comparison
```bash
# Run equivalent Python benchmarks
python3 benchmarks/python/simd_focused_benchmark.py
```

## Performance Characteristics

SIMD optimizations show the most benefit in:
- **Large text processing**: SIMD overhead is amortized over many characters
- **Character class patterns**: `[a-z]`, `\d`, `\s`, etc. benefit from lookup table optimizations
- **Repetitive patterns**: Quantified character classes like `[a-z]+` show significant improvements
- **Mixed content**: Real-world text with varied character types

## Comparison with Previous Approach

Unlike previous attempts that modified the hybrid engine routing, these benchmarks:
- **Preserve existing architecture**: No changes to the optimal DFA/NFA routing logic
- **Focus on NFA strengths**: Direct testing of NFA engine SIMD capabilities
- **Avoid performance degradation**: No overhead introduced to existing fast paths
- **Isolate SIMD benefits**: Clear demonstration of where SIMD provides value

## Expected Results

When comparing the simd-optimizations branch to the main branch:
- **Character class patterns should show 2-10x improvements** for large text processing
- **Simple literal patterns may show no difference** (correctly routed to DFA)
- **Complex patterns without character classes show minimal difference**
- **Python comparison provides baseline** for understanding relative performance

## Technical Notes

- SIMD optimizations are implemented in the NFA engine's `_apply_quantifier` method
- The `ast.enable_simd` flag controls whether SIMD optimizations are used
- SIMD bulk matching is particularly effective for consecutive character class matches
- The benchmarks use realistic text patterns to ensure representative performance testing
