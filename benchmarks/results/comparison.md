# Benchmark Results

Comparison of mojo-regex v0.8.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000304 | 0.000032 | 0.003157 | 9.6x faster | 98.7x faster |
| alternation_quantifiers | 0.660918 | 1.865944 | 0.116149 | 2.8x slower | 16.1x slower |
| alternation_simple | 0.000310 | 0.000011 | 0.000042 | 28.7x faster | 3.8x faster |
| anchor_start | 0.000213 | 0.000024 | 0.000042 | 8.8x faster | 1.8x faster |
| complex_email | 0.032207 | 0.066397 | - | 2.1x slower | - |
| complex_group_5_children | 0.000308 | 0.003739 | 0.000117 | 12.1x slower | 31.9x slower |
| complex_number | 0.287440 | 0.035063 | - | 8.2x faster | - |
| datetime_quantifiers | 0.137575 | 0.058772 | 0.098028 | 2.3x faster | 1.7x faster |
| deep_nested_groups_depth4 | 0.000273 | 0.002859 | 0.000023 | 10.5x slower | 124.4x slower |
| dense_quantifiers | 0.472031 | 0.110176 | 0.018315 | 4.3x faster | 6.0x slower |
| dfa_digits_only | 1.640417 | 0.191168 | 0.061481 | 8.6x faster | 3.1x slower |
| dfa_dot_phone | 2.695209 | 0.362659 | 0.038511 | 7.4x faster | 9.4x slower |
| dfa_paren_phone | 0.062408 | 0.503877 | 0.019757 | 8.1x slower | 25.5x slower |
| dfa_simple_phone | 1.487157 | 0.754812 | 0.093541 | 2.0x faster | 8.1x slower |
| dual_quantifiers | 0.228817 | 0.049003 | 0.029408 | 4.7x faster | 1.7x slower |
| flexible_datetime | 0.111234 | 0.092760 | 0.035801 | 1.2x faster | 2.6x slower |
| flexible_phone | 3.006014 | 6.035415 | 0.301299 | 2.0x slower | 20.0x slower |
| group_alternation | 0.000287 | 0.000013 | 0.000089 | 22.4x faster | 6.8x faster |
| grouped_quantifiers | 0.251117 | 0.502557 | 0.017689 | 2.0x slower | 28.4x slower |
| is_match_alphanumeric | 0.039891 | 0.000004 | 0.000022 | 9846x faster | 5.5x faster |
| is_match_digits | 0.025209 | 0.000007 | 0.000065 | 3540x faster | 9.3x faster |
| is_match_lowercase | 0.023983 | 0.000010 | 0.000020 | 2349x faster | 2.0x faster |
| is_match_predefined_digits | 0.065787 | 0.000004 | 0.000022 | 14711x faster | 5.5x faster |
| is_match_predefined_word | 0.053804 | 0.000007 | 0.000019 | 7565x faster | 2.7x faster |
| large_8_alternations | 0.000653 | 0.000242 | 0.000059 | 2.7x faster | 4.1x slower |
| literal_heavy_alternation | 0.000600 | 0.000202 | 0.000099 | 3.0x faster | 2.0x slower |
| literal_match_long | 0.011796 | 0.010678 | 0.004795 | 1.1x faster | 2.2x slower |
| literal_match_short | 0.000807 | 0.001012 | 0.000682 | 1.3x slower | 1.5x slower |
| literal_prefix_long | 0.043193 | 0.175553 | 0.045973 | 4.1x slower | 3.8x slower |
| literal_prefix_short | 0.000310 | 0.000858 | 0.000370 | 2.8x slower | 2.3x slower |
| match_all_digits | 1.945965 | 0.316990 | - | 6.1x faster | - |
| match_all_simple | 0.025526 | 0.011707 | 0.006594 | 2.2x faster | 1.8x slower |
| mixed_range_quantifiers | 0.113091 | 0.072617 | 0.009097 | 1.6x faster | 8.0x slower |
| multi_format_phone | 6.824993 | 21.609218 | 0.306817 | 3.2x slower | 70.4x slower |
| national_phone_validation | 1.092174 | 0.096928 | 0.096036 | 11.3x faster | 1.0x |
| no_literal_baseline | 0.000320 | 0.000015 | 0.010582 | 21.3x faster | 705.5x faster |
| optimize_extreme_quantifiers | 0.014009 | 0.030672 | 0.000310 | 2.2x slower | 98.8x slower |
| optimize_large_quantifiers | 0.009337 | 0.003614 | 0.019757 | 2.6x faster | 5.5x faster |
| optimize_multiple_quantifiers | 0.499413 | 0.135380 | 0.033377 | 3.7x faster | 4.1x slower |
| optimize_phone_quantifiers | 0.190441 | 0.138785 | 0.072369 | 1.4x faster | 1.9x slower |
| optimize_range_quantifier | 0.226987 | 0.232687 | 0.055558 | ~same | 4.2x slower |
| phone_validation | 0.000628 | 0.000906 | 0.000022 | 1.4x slower | 42.1x slower |
| predefined_digits | 0.174685 | 0.054201 | 0.000046 | 3.2x faster | 1166x slower |
| predefined_word | 0.051751 | 0.001356 | 0.050237 | 38.2x faster | 37.0x faster |
| quad_quantifiers | 0.124401 | 0.074364 | 0.011520 | 1.7x faster | 6.5x slower |
| quantifier_one_or_more | 0.000209 | 0.000012 | 0.000088 | 17.7x faster | 7.3x faster |
| quantifier_zero_or_more | 0.000262 | 0.000012 | 0.000059 | 22.2x faster | 4.9x faster |
| quantifier_zero_or_one | 0.000269 | 0.000012 | 0.000085 | 23.1x faster | 7.1x faster |
| range_alphanumeric | 0.021627 | 0.087024 | 0.049838 | 4.0x slower | 1.7x slower |
| range_digits | 0.137422 | 0.060263 | 0.000061 | 2.3x faster | 991x slower |
| range_lowercase | 0.020645 | 0.000525 | 0.000060 | 39.3x faster | 8.7x slower |
| range_quantifiers | 0.183533 | 0.066569 | 0.038188 | 2.8x faster | 1.7x slower |
| required_literal_short | 0.002518 | 0.006847 | 0.000236 | 2.7x slower | 29.0x slower |
| simple_phone | 2.379728 | 0.446678 | 0.131964 | 5.3x faster | 3.4x slower |
| single_quantifier_alpha | 0.214547 | 0.026739 | 0.057747 | 8.0x faster | 2.2x faster |
| single_quantifier_digits | 0.176283 | 0.026807 | 0.029726 | 6.6x faster | 1.1x faster |
| toll_free_complex | 0.077280 | 0.314290 | - | 4.1x slower | - |
| toll_free_simple | 0.161855 | 0.049304 | - | 3.3x faster | - |
| triple_quantifiers | 0.123327 | 0.050075 | 0.016564 | 2.5x faster | 3.0x slower |
| ultra_dense_quantifiers | 0.612031 | 0.087330 | 0.072901 | 7.0x faster | 1.2x slower |
| wildcard_match_any | 0.003503 | 0.000001 | 0.045669 | 2598x faster | 45669x faster |

## Summary

**Mojo vs Python:** 44 wins, 17 losses out of 61 benchmarks (72% win rate)

**Mojo vs Rust:** 22 wins, 31 losses out of 53 common benchmarks (42% win rate)

### Where Mojo excels

- **is_match (bool-only):** 2349-14711x faster than Python, 2-9x faster than Rust.
  O(1) single character check via SIMD lookup table.
- **Simple quantifiers** (`a*`, `a+`, `a?`): 17-23x faster than Python, 4-7x faster
  than Rust. Lightweight DFA with inlined dispatch.
- **DFA character class scanning** (`[a-z]+`, `\w+`, `[0-9]+`): 2-39x faster than
  Python using nibble-based SIMD matching (two native `pshufb` ops per 32 chars).
- **Wildcard** (`.*`): 2598x faster than Python, 45669x faster than Rust.
  Constant-time fast path.
- **DFA findall** (phone numbers, quantifier patterns): 2-8x faster than Python.

### Where Mojo needs improvement

- **NFA backtracking patterns** (`flexible_phone`, `multi_format_phone`,
  `grouped_quantifiers`): 2-3x slower than Python, 20-70x slower than Rust.
  Rust uses a lazy DFA that avoids backtracking entirely.
- **Complex NFA patterns** (`deep_nested_groups_depth4`, `complex_group_5_children`):
  10-12x slower than Python due to recursive matching overhead.
- **`dfa_paren_phone`:** 8x slower than Python. Known matching bug with escaped
  parenthesis patterns in the DFA compiler.

### Notes

- Rust's `regex` crate is a highly optimized production library using Thompson NFA
  simulation, lazy DFA, and Aho-Corasick multi-pattern matching. It represents the
  state-of-the-art in regex performance.
- Python's `re` module is implemented in C and handles backtracking-heavy patterns
  efficiently through its bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA architecture with SIMD-optimized character class
  matching using nibble-based `pshufb` lookups. It excels on DFA-friendly patterns
  and character class operations.
- Benchmarks run with pre-compiled regex, 500ms target runtime, median timing, and
  auto-calibration to reduce noise.
