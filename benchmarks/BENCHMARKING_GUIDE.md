# Mojo Regex Benchmarking Guide

This directory contains a comprehensive benchmarking system to compare the performance of Mojo regex implementation with Python's standard `re` module.

## Overview

The benchmarking system consists of:

1. **bench_engine.mojo** - Mojo benchmark suite
2. **bench_engine.py** - Equivalent Python benchmark suite
3. **parse_mojo_output.py** - Parses Mojo console output to JSON
4. **compare_benchmarks.py** - Compares results and generates reports
5. **visualize_results.py** - Creates visualization charts
6. **run_comparison.sh** - Orchestrates the entire comparison

## Quick Start

Run the complete benchmark comparison:

```bash
./benchmarks/run_comparison.sh
```

This will:
1. Run Python benchmarks and export to JSON
2. Run Mojo benchmarks and parse output to JSON
3. Compare results and generate a detailed report
4. Create visualization charts (if matplotlib is installed)

## Output Files

All results are saved in the `benchmarks/results/` directory:

- **mojo_results.json** - Raw benchmark data from Mojo
- **python_results.json** - Raw benchmark data from Python
- **comparison.json** - Detailed comparison data
- **speedup_chart.png** - Bar chart showing speedup factors
- **time_comparison.png** - Side-by-side execution time comparison
- **category_analysis.png** - Performance analysis by regex category

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
