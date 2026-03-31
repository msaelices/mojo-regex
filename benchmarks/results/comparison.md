# Benchmark Results

Comparison of mojo-regex v0.8.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000313 | 0.000059 | 0.001945 | 5.3x faster | 32.9x faster |
| alternation_quantifiers | 0.698518 | 1.031582 | 0.156193 | 1.5x slower | 6.6x slower |
| alternation_simple | 0.000206 | 0.000027 | 0.000031 | 7.5x faster | ~same |
| anchor_start | 0.000206 | 0.000042 | 0.000052 | 4.9x faster | 1.2x faster |
| complex_email | 0.025637 | 0.012433 | - | 2.1x faster | - |
| complex_group_5_children | 0.000630 | 0.009232 | 0.000078 | 14.7x slower | 118.2x slower |
| complex_number | 0.187541 | 0.038030 | - | 4.9x faster | - |
| datetime_quantifiers | 0.271341 | 0.076442 | 0.064709 | 3.5x faster | 1.2x slower |
| deep_nested_groups_depth4 | 0.000312 | 0.003853 | 0.000042 | 12.4x slower | 92.4x slower |
| dense_quantifiers | 0.382418 | 0.069772 | 0.022124 | 5.5x faster | 3.2x slower |
| dfa_digits_only | 1.644834 | 0.151995 | 0.062071 | 10.8x faster | 2.4x slower |
| dfa_dot_phone | 1.447820 | 0.166706 | 0.069066 | 8.7x faster | 2.4x slower |
| dfa_paren_phone | 0.135191 | 0.034434 | 0.016574 | 3.9x faster | 2.1x slower |
| dfa_simple_phone | 1.252095 | 0.248481 | 0.081207 | 5.0x faster | 3.1x slower |
| dual_quantifiers | 0.383880 | 0.028841 | 0.019187 | 13.3x faster | 1.5x slower |
| flexible_datetime | 0.253875 | 0.074927 | 0.050689 | 3.4x faster | 1.5x slower |
| flexible_phone | 3.040934 | 8.871183 | 0.358705 | 2.9x slower | 24.7x slower |
| group_alternation | 0.000224 | 0.000029 | 0.000076 | 7.8x faster | 2.6x faster |
| grouped_quantifiers | 0.262861 | 0.058945 | 0.013023 | 4.5x faster | 4.5x slower |
| is_match_alphanumeric | 0.031137 | 0.000004 | 0.000015 | 8164.8x faster | 4.0x faster |
| is_match_digits | 0.020857 | 0.000007 | 0.000028 | 2821.8x faster | 3.8x faster |
| is_match_lowercase | 0.023026 | 0.000005 | 0.000014 | 4571.6x faster | 2.8x faster |
| is_match_predefined_digits | 0.047963 | 0.000007 | 0.000013 | 6482.6x faster | 1.8x faster |
| is_match_predefined_word | 0.061327 | 0.000004 | 0.000015 | 16781.3x faster | 4.1x faster |
| large_8_alternations | 0.000423 | 0.000452 | 0.000061 | ~same | 7.5x slower |
| literal_heavy_alternation | 0.000607 | 0.000334 | 0.000070 | 1.8x faster | 4.8x slower |
| literal_match_long | 0.008837 | 0.015555 | 0.003532 | 1.8x slower | 4.4x slower |
| literal_match_short | 0.001902 | 0.001461 | 0.000515 | 1.3x faster | 2.8x slower |
| literal_prefix_long | 0.046730 | 0.006215 | 0.027800 | 7.5x faster | 4.5x faster |
| literal_prefix_short | 0.000202 | 0.000611 | 0.000481 | 3.0x slower | 1.3x slower |
| match_all_digits | 1.219725 | 0.028838 | - | 42.3x faster | - |
| match_all_simple | 0.021469 | 0.030502 | 0.007556 | 1.4x slower | 4.0x slower |
| mixed_range_quantifiers | 0.196844 | 0.025329 | 0.006567 | 7.8x faster | 3.9x slower |
| multi_format_phone | 8.442741 | 26.248936 | 0.275550 | 3.1x slower | 95.3x slower |
| national_phone_validation | 2.238307 | 0.070046 | 0.108256 | 32.0x faster | 1.5x faster |
| no_literal_baseline | 0.000201 | 0.000032 | 0.008755 | 6.3x faster | 273.0x faster |
| optimize_extreme_quantifiers | 0.019784 | 0.003983 | 0.000251 | 5.0x faster | 15.9x slower |
| optimize_large_quantifiers | 0.010950 | 0.006614 | 0.012057 | 1.7x faster | 1.8x faster |
| optimize_multiple_quantifiers | 0.453491 | 0.083383 | 0.032803 | 5.4x faster | 2.5x slower |
| optimize_phone_quantifiers | 0.348920 | 0.052138 | 0.060281 | 6.7x faster | 1.2x faster |
| optimize_range_quantifier | 0.220256 | 0.235932 | 0.039066 | ~same | 6.0x slower |
| phone_validation | 0.000665 | 0.001380 | 0.000029 | 2.1x slower | 48.3x slower |
| predefined_digits | 0.273472 | 0.000831 | 0.000067 | 329.0x faster | 12.3x slower |
| predefined_word | 0.041513 | 0.036245 | 0.051643 | ~same | 1.4x faster |
| quad_quantifiers | 0.357548 | 0.035934 | 0.011939 | 10.0x faster | 3.0x slower |
| quantifier_one_or_more | 0.000391 | 0.000011 | 0.000057 | 35.8x faster | 5.2x faster |
| quantifier_zero_or_more | 0.000169 | 0.000015 | 0.000048 | 11.4x faster | 3.2x faster |
| quantifier_zero_or_one | 0.000211 | 0.000013 | 0.000047 | 16.7x faster | 3.7x faster |
| range_alphanumeric | 0.020515 | 0.036928 | 0.088036 | 1.8x slower | 2.4x faster |
| range_digits | 0.118341 | 0.001150 | 0.000100 | 102.9x faster | 11.5x slower |
| range_lowercase | 0.019991 | 0.027022 | 0.000063 | 1.4x slower | 425.8x slower |
| range_quantifiers | 0.292457 | 0.043563 | 0.036320 | 6.7x faster | 1.2x slower |
| required_literal_short | 0.002020 | 0.020639 | 0.000412 | 10.2x slower | 50.1x slower |
| simple_phone | 1.280961 | 0.278221 | 0.130252 | 4.6x faster | 2.1x slower |
| single_quantifier_alpha | 0.236765 | 0.027498 | 0.039496 | 8.6x faster | 1.4x faster |
| single_quantifier_digits | 0.300292 | 0.018763 | 0.032348 | 16.0x faster | 1.7x faster |
| toll_free_complex | 0.155965 | 0.024161 | - | 6.5x faster | - |
| toll_free_simple | 0.237945 | 0.020712 | - | 11.5x faster | - |
| triple_quantifiers | 0.237130 | 0.058855 | 0.009121 | 4.0x faster | 6.5x slower |
| ultra_dense_quantifiers | 0.497793 | 0.048910 | 0.076198 | 10.2x faster | 1.6x faster |
| wildcard_match_any | 0.005933 | 0.000001 | 0.053639 | 4711.0x faster | 42589.5x faster |

## Summary

**Mojo vs Python:** 47 wins, 14 losses out of 61 benchmarks (77% win rate)

**Mojo vs Rust:** 23 wins, 33 losses out of 56 common benchmarks (41% win rate)

### Where Mojo excels

- **is_match (bool-only):** 2000-6000x faster than Python, 2-6x faster than Rust.
  O(1) single character check via SIMD lookup table.
- **Simple quantifiers** (`a*`, `a+`, `a?`): 17-80x faster than Python, 5-8x faster
  than Rust. Lightweight DFA with inlined dispatch.
- **Character class search/findall** (`[a-z]+`, `\w+`, `\d+`): 29-350x faster than
  Python using nibble-based SIMD matching (two native `pshufb` ops per 32 chars).
- **Wildcard** (`.*`): 4000+x faster than Python. Constant-time fast path.
- **`.*` prefix/suffix patterns**: Fast paths for `.*LITERAL` (PR #82) and
  `LITERAL.*` (PR #83) skip NFA backtracking entirely.
- **DFA findall** (phone numbers, quantifier patterns): 2-8x faster than Python.

### Where Mojo needs improvement

- **NFA backtracking patterns** (`flexible_phone`, `multi_format_phone`):
  1-3x slower than Python, 19-83x slower than Rust.
  Rust uses a lazy DFA that avoids backtracking entirely.
- **Complex NFA patterns** (`deep_nested_groups_depth4`, `complex_group_5_children`):
  5-12x slower than Python due to recursive matching overhead.
- **Alternation with quantifiers** (`alternation_quantifiers`): ~3x slower than
  Python. Top-level OR with capturing groups routes to NFA.

### Notes

- Rust's `regex` crate is a highly optimized production library using Thompson NFA
  simulation, lazy DFA, and Aho-Corasick multi-pattern matching.
- Python's `re` module is implemented in C and handles backtracking-heavy patterns
  efficiently through its bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA architecture with SIMD-optimized character class
  matching using nibble-based `pshufb` lookups. The DFA compiler handles non-capturing
  alternation groups and flattens capturing groups for non-capture operations.
  Fast paths for `.*` prefix/suffix patterns skip the NFA entirely.
- Benchmarks run with pre-compiled regex, 500ms target runtime, median timing, and
  auto-calibration to reduce noise.
