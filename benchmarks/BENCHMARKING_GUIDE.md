# Mojo Regex Benchmarking Guide

This directory contains a comprehensive benchmarking system to compare the performance of Mojo regex implementation with Python's standard `re` module.

## Overview

The benchmarking system consists of:

### Core Benchmark Suites
1. **bench_engine.mojo** & **bench_engine.py** - Main regex engine benchmarks
   - Comprehensive test coverage for all regex features
   - Performance comparison across various pattern types

2. **simd_focused_benchmark.mojo** & **simd_focused_benchmark.py** - SIMD optimization benchmarks
   - Direct NFA engine testing
   - Focus on character class operations that benefit from SIMD

### Supporting Scripts
3. **parse_mojo_output.py** - Parses Mojo console output to JSON
4. **compare_benchmarks.py** - Compares results and generates reports
5. **visualize_results.py** - Creates visualization charts
6. **run_comparison.sh** - Orchestrates the entire comparison with support for multiple benchmark suites

## Quick Start

Run the complete benchmark comparison for the main benchmark suite:

```bash
./benchmarks/run_comparison.sh
# or explicitly:
./benchmarks/run_comparison.sh bench_engine
```

Run SIMD-focused benchmarks:

```bash
./benchmarks/run_comparison.sh simd_focused_benchmark
```

This will:
1. Run Python benchmarks and export to JSON
2. Run Mojo benchmarks and parse output to JSON
3. Compare results and generate a detailed report
4. Create visualization charts (if matplotlib is installed)

## Output Files

All results are saved in the `benchmarks/results/` directory.

For the main benchmark suite (`bench_engine`):
- **mojo_results.json** - Raw benchmark data from Mojo
- **python_results.json** - Raw benchmark data from Python
- **comparison.json** - Detailed comparison data
- **speedup_chart.png** - Bar chart showing speedup factors
- **time_comparison.png** - Side-by-side execution time comparison
- **category_analysis.png** - Performance analysis by regex category

For SIMD-focused benchmarks (`simd_focused_benchmark`):
- **simd_mojo_results.json** - Raw benchmark data from Mojo
- **simd_python_results.json** - Raw benchmark data from Python
- **simd_comparison.json** - Detailed comparison data
- **simd_speedup_chart.png** - Bar chart showing speedup factors
- **simd_time_comparison.png** - Side-by-side execution time comparison
- **simd_category_analysis.png** - Performance analysis by regex category

## Understanding Results

The comparison report shows:

- **Speedup Factor**: How many times faster Mojo is compared to Python
  - `> 1.0x` means Mojo is faster
  - `< 1.0x` means Python is faster
  - `≈ 1.0x` means similar performance

- **Geometric Mean**: Better metric for performance ratios than arithmetic mean

## Example Output

```
====================================================================================================
MOJO REGEX VS PYTHON REGEX BENCHMARK COMPARISON
====================================================================================================

SUMMARY:
  Total benchmarks compared: 30
  Mojo faster: 25 benchmarks
  Python faster: 2 benchmarks
  Average speedup: 15.3x
  Geometric mean speedup: 8.7x

DETAILED RESULTS:
----------------------------------------------------------------------------------------------------
Benchmark                           Mojo (ms)    Python (ms)    Speedup          Status
----------------------------------------------------------------------------------------------------
simd_alphanumeric_xlarge             0.145 ms      12.534 ms      86.45x    🚀 Mojo wins!
simd_alphanumeric_large              0.029 ms       2.507 ms      86.45x    🚀 Mojo wins!
literal_match_long                   0.016 ms       0.456 ms      28.50x    🚀 Mojo wins!
...
```

## Advanced Usage

### Running Individual Scripts

You can also run the benchmark pipeline components individually:

```bash
# Run only Python benchmarks
python3 benchmarks/bench_engine.py
python3 benchmarks/simd_focused_benchmark.py

# Run only Mojo benchmarks
mojo run benchmarks/bench_engine.mojo
mojo run benchmarks/simd_focused_benchmark.mojo

# Parse Mojo output manually
mojo run benchmarks/bench_engine.mojo | python3 benchmarks/parse_mojo_output.py custom_output.json

# Compare specific result files
python3 benchmarks/compare_benchmarks.py python_results.json mojo_results.json comparison.json

# Generate visualizations from comparison file
python3 benchmarks/visualize_results.py comparison.json prefix_
```

### Benchmark Suite Selection

The `run_comparison.sh` script supports different benchmark suites:

```bash
# Usage
./benchmarks/run_comparison.sh [benchmark_suite]

# Available options:
# - bench_engine (default): Main comprehensive benchmark suite
# - simd_focused_benchmark: SIMD-specific NFA engine benchmarks
```

Each suite generates its own set of output files with appropriate prefixes to avoid conflicts.

### Important Notes

- **Benchmark Name Matching**: For proper comparison, benchmark names must match exactly between Python and Mojo implementations. The comparison script matches benchmarks by name.
- **SIMD Benchmarks**: The SIMD-focused benchmarks use `nfa_simd_` prefix for benchmark names in both Python and Mojo implementations.
