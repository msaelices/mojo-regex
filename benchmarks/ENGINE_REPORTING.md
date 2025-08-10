# Engine Reporting in Benchmarks

This document describes the engine reporting improvements made to the Mojo regex benchmarks.

## Overview

The benchmarks now display which engine (DFA or NFA) is used for each regex pattern, along with the pattern's complexity classification. This provides valuable insight into how the hybrid matcher routes different patterns to optimal engines.

## How It Works

The improved `bench_engine.mojo` now:

1. **Detects Engine Type**: Uses `HybridMatcher.get_engine_type()` to determine which engine handles each pattern
2. **Reports Complexity**: Uses `HybridMatcher.get_complexity()` to show pattern complexity classification
3. **Console Output**: Displays `[ENGINE]` lines showing pattern → engine mapping before each benchmark
4. **JSON Export**: Enhanced to include engine metadata (simplified version due to global variable limitations)

## Engine Selection Rules

Based on the analysis, the hybrid matcher follows these rules:

### DFA Engine (47% of benchmark patterns)
- **Simple literals**: `hello`
- **Anchors**: `^abc`, `xyz$`
- **Character classes**: `[a-z]+`, `[0-9]+`, `[a-zA-Z0-9]+`
- **Negated classes**: `[^a-zA-Z0-9]+`
- **Sequential patterns**: `[a-z]+[0-9]+`
- **Complex email regex**: Even `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+[.][a-zA-Z]{2,}` uses DFA

### NFA Engine (52% of benchmark patterns)
- **Wildcards**: `.*`, `a*`, `a+`, `a?`
- **Alternation**: `a|b|c`, `abc|def|ghi`
- **Groups**: `(abc)+`, `(a|b)*`
- **Complex patterns**: `hello.*world`, `.*@example\.com`
- **Nested structures**: `(hello|help|helicopter)`

## Complexity Distribution

- **SIMPLE**: 73% of patterns (mostly use DFA, some wildcards/alternation use NFA)
- **MEDIUM**: 21% of patterns (always use NFA)
- **COMPLEX**: 4% of patterns (always use NFA)

## Usage

### Individual Benchmark
Run the enhanced benchmark:
```bash
mojo run benchmarks/bench_engine.mojo
```

The output will show engine detection results like:
```
[ENGINE] literal_match_short -> Pattern: 'hello' | Engine: DFA | Complexity: SIMPLE
[ENGINE] wildcard_match_any -> Pattern: '.*' | Engine: NFA | Complexity: SIMPLE
[ENGINE] group_quantified -> Pattern: '(abc)+' | Engine: NFA | Complexity: MEDIUM
```

### Comparison Scripts
The comparison scripts have also been enhanced to show engine usage summaries:

**Branch vs Branch Comparison:**
```bash
./benchmarks/run_comparison_with.sh main
```
This will show engine usage for both branches being compared.

**Mojo vs Python Comparison:**
```bash
./benchmarks/run_comparison_with_python.sh
```
This will show Mojo's hybrid engine usage vs Python's single engine approach.

## Testing

Use the test files in `playground/` to verify engine detection:
- `test_engine_detection.mojo` - Basic engine detection test
- `engine_summary.mojo` - Complete analysis with statistics

## Key Insights

1. **Smart Routing**: The hybrid matcher intelligently chooses the optimal engine
2. **DFA Efficiency**: Simple patterns get routed to the high-performance DFA engine
3. **NFA Flexibility**: Complex patterns requiring backtracking use the NFA engine
4. **Performance Optimization**: Pattern complexity analysis ensures optimal engine selection
5. **SIMD Benefits**: Character class patterns can leverage DFA's SIMD optimizations

## Enhanced Comparison Scripts

The benchmark comparison scripts (`run_comparison_with.sh` and `run_comparison_with_python.sh`) now include:

1. **Engine Usage Summary**: Shows count of patterns using each engine type
2. **Complexity Breakdown**: Distribution of pattern complexity classifications
3. **Cross-Branch Comparison**: Engine usage differences between branches
4. **Mojo vs Python Analysis**: Explanation of hybrid vs single-engine approaches

Example output from comparison scripts:
```
Engine Usage Summary for current_branch:
==============================
DFA Engine: 11 patterns
NFA Engine: 12 patterns
SIMPLE Complexity: 17 patterns
MEDIUM Complexity: 5 patterns
COMPLEX Complexity: 1 patterns
```

This enhancement provides full visibility into the regex engine's internal behavior, enabling better performance analysis and optimization validation across different branches and implementations.
