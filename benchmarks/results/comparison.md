# Benchmark Results

Comparison of mojo-regex v0.8.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000282 | 0.000018 | 0.004550 | 15.3x faster | 246.8x faster |
| alternation_quantifiers | 0.673142 | 1.790974 | 0.066536 | 2.7x slower | 26.9x slower |
| alternation_simple | 0.000247 | 0.000006 | 0.000029 | 39.0x faster | 4.6x faster |
| anchor_start | 0.000308 | 0.000017 | 0.000042 | 18.5x faster | 2.5x faster |
| complex_email | 0.017806 | 0.008941 | - | 2.0x faster | - |
| complex_group_5_children | 0.000512 | 0.003387 | 0.000102 | 6.6x slower | 33.0x slower |
| complex_number | 0.116242 | 0.026838 | - | 4.3x faster | - |
| datetime_quantifiers | 0.150243 | 0.058497 | 0.067463 | 2.6x faster | 1.2x faster |
| deep_nested_groups_depth4 | 0.000484 | 0.002170 | 0.000032 | 4.5x slower | 67.3x slower |
| dense_quantifiers | 0.407477 | 0.067343 | 0.023726 | 6.1x faster | 2.8x slower |
| dfa_digits_only | 1.624592 | 0.263612 | 0.077370 | 6.2x faster | 3.4x slower |
| dfa_dot_phone | 1.732806 | 0.695657 | 0.051516 | 2.5x faster | 13.5x slower |
| dfa_paren_phone | 0.065994 | 0.264198 | 0.017724 | 4.0x slower | 14.9x slower |
| dfa_simple_phone | 1.107789 | 0.478022 | 0.126743 | 2.3x faster | 3.8x slower |
| dual_quantifiers | 0.120906 | 0.035726 | 0.027477 | 3.4x faster | 1.3x slower |
| flexible_datetime | 0.295287 | 0.084198 | 0.028819 | 3.5x faster | 2.9x slower |
| flexible_phone | 3.474112 | 5.736909 | 0.295606 | 1.7x slower | 19.4x slower |
| group_alternation | 0.000271 | 0.000010 | 0.000086 | 28.5x faster | 9.0x faster |
| grouped_quantifiers | 0.189334 | 0.839729 | 0.011643 | 4.4x slower | 72.1x slower |
| is_match_alphanumeric | 0.025252 | 0.000007 | 0.000021 | 3757x faster | 3.2x faster |
| is_match_digits | 0.012605 | 0.000006 | 0.000034 | 2154x faster | 5.8x faster |
| is_match_lowercase | 0.018233 | 0.000006 | 0.000013 | 3191x faster | 2.3x faster |
| is_match_predefined_digits | 0.033749 | 0.000009 | 0.000019 | 3928x faster | 2.2x faster |
| is_match_predefined_word | 0.041704 | 0.000007 | 0.000014 | 5895x faster | 2.0x faster |
| large_8_alternations | 0.000558 | 0.000117 | 0.000052 | 4.8x faster | 2.2x slower |
| literal_heavy_alternation | 0.000515 | 0.000139 | 0.000110 | 3.7x faster | 1.3x slower |
| literal_match_long | 0.013231 | 0.010497 | 0.007002 | 1.3x faster | 1.5x slower |
| literal_match_short | 0.001511 | 0.000984 | 0.000716 | 1.5x faster | 1.4x slower |
| literal_prefix_long | 0.042995 | 0.124081 | 0.057792 | 2.9x slower | 2.1x slower |
| literal_prefix_short | 0.000426 | 0.000534 | 0.000396 | 1.3x slower | 1.4x slower |
| match_all_digits | 1.956951 | 0.007294 | - | 268.3x faster | - |
| match_all_simple | 0.023084 | 0.009850 | 0.013281 | 2.3x faster | 1.3x faster |
| mixed_range_quantifiers | 0.137384 | 0.040995 | 0.008551 | 3.4x faster | 4.8x slower |
| multi_format_phone | 8.891770 | 16.014945 | 0.193845 | 1.8x slower | 82.6x slower |
| national_phone_validation | 0.860395 | 0.093049 | 0.072964 | 9.2x faster | 1.3x slower |
| no_literal_baseline | 0.000267 | 0.000012 | 0.008495 | 22.8x faster | 725.8x faster |
| optimize_extreme_quantifiers | 0.014266 | 0.002959 | 0.000203 | 4.8x faster | 14.6x slower |
| optimize_large_quantifiers | 0.006766 | 0.004735 | 0.023919 | 1.4x faster | 5.1x faster |
| optimize_multiple_quantifiers | 0.559269 | 0.120680 | 0.020639 | 4.6x faster | 5.8x slower |
| optimize_phone_quantifiers | 0.252161 | 0.054310 | 0.064351 | 4.6x faster | 1.2x faster |
| optimize_range_quantifier | 0.177399 | 0.338873 | 0.048082 | 1.9x slower | 7.0x slower |
| phone_validation | 0.000790 | 0.000969 | 0.000029 | ~same | 33.5x slower |
| predefined_digits | 0.207256 | 0.000654 | 0.000064 | 316.7x faster | 10.2x slower |
| predefined_word | 0.053840 | 0.000444 | 0.059598 | 121.2x faster | 134.2x faster |
| quad_quantifiers | 0.167327 | 0.050496 | 0.010476 | 3.3x faster | 4.8x slower |
| quantifier_one_or_more | 0.000292 | 0.000007 | 0.000060 | 41.0x faster | 8.4x faster |
| quantifier_zero_or_more | 0.000226 | 0.000013 | 0.000061 | 17.4x faster | 4.7x faster |
| quantifier_zero_or_one | 0.000248 | 0.000012 | 0.000062 | 20.6x faster | 5.1x faster |
| range_alphanumeric | 0.028077 | 0.061837 | 0.094280 | 2.2x slower | 1.5x faster |
| range_digits | 0.123873 | 0.000737 | 0.000072 | 168.0x faster | 10.2x slower |
| range_lowercase | 0.020985 | 0.000716 | 0.000062 | 29.3x faster | 11.5x slower |
| range_quantifiers | 0.126651 | 0.031015 | 0.041325 | 4.1x faster | 1.3x faster |
| required_literal_short | 0.003136 | 0.074141 | 0.000296 | 23.6x slower | 250.6x slower |
| simple_phone | 1.884110 | 0.429930 | 0.148049 | 4.4x faster | 2.9x slower |
| single_quantifier_alpha | 0.149253 | 0.021970 | 0.045319 | 6.8x faster | 2.1x faster |
| single_quantifier_digits | 0.138936 | 0.025765 | 0.017256 | 5.4x faster | 1.5x slower |
| toll_free_complex | 0.062999 | 0.044062 | - | 1.4x faster | - |
| toll_free_simple | 0.083858 | 0.055116 | - | 1.5x faster | - |
| triple_quantifiers | 0.121667 | 0.054318 | 0.011844 | 2.2x faster | 4.6x slower |
| ultra_dense_quantifiers | 0.656804 | 0.091531 | 0.058152 | 7.2x faster | 1.6x slower |
| wildcard_match_any | 0.007462 | 0.000002 | 0.060958 | 4461x faster | 36441x faster |

## Summary

**Mojo vs Python:** 48 wins, 13 losses out of 61 benchmarks (78% win rate)

**Mojo vs Rust:** 22 wins, 34 losses out of 56 common benchmarks (39% win rate)

### Where Mojo excels

- **is_match (bool-only):** 2154-5895x faster than Python, 2-6x faster than Rust.
  O(1) single character check via SIMD lookup table.
- **Simple quantifiers** (`a*`, `a+`, `a?`): 17-41x faster than Python, 5-8x faster
  than Rust. Lightweight DFA with inlined dispatch.
- **Character class search/findall** (`[a-z]+`, `\w+`, `\d+`): 29-317x faster than
  Python using nibble-based SIMD matching (two native `pshufb` ops per 32 chars)
  across match_first, match_next, and match_all paths.
- **Wildcard** (`.*`): 4461x faster than Python. Constant-time fast path.
- **DFA findall** (phone numbers, quantifier patterns): 2-6x faster than Python.
- **Toll-free complex** (`8(?:00|33|...)[2-9]\d{6}`): 1.4x faster than Python.
  DFA compiler now handles non-capturing alternation groups (PR #79).

### Where Mojo needs improvement

- **NFA backtracking patterns** (`flexible_phone`, `multi_format_phone`,
  `grouped_quantifiers`): 2-4x slower than Python, 19-83x slower than Rust.
  Rust uses a lazy DFA that avoids backtracking entirely.
- **Complex NFA patterns** (`deep_nested_groups_depth4`, `complex_group_5_children`):
  5-7x slower than Python due to recursive matching overhead.
- **`dfa_paren_phone`:** 4x slower than Python. The escaped parenthesis parser bug
  is fixed (PR #77) but the DFA findall path for multi-element patterns with
  literals between quantified ranges is still slower than Python's C engine.
- **`required_literal_short`:** 24x slower than Python. The NFA prefilter literal
  search has overhead that exceeds Python's optimized C implementation for short texts.

### Notes

- Rust's `regex` crate is a highly optimized production library using Thompson NFA
  simulation, lazy DFA, and Aho-Corasick multi-pattern matching. It represents the
  state-of-the-art in regex performance.
- Python's `re` module is implemented in C and handles backtracking-heavy patterns
  efficiently through its bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA architecture with SIMD-optimized character class
  matching using nibble-based `pshufb` lookups. It excels on DFA-friendly patterns
  and character class operations. The DFA compiler now handles non-capturing
  alternation groups, routing more patterns to the fast DFA path.
- Benchmarks run with pre-compiled regex, 500ms target runtime, median timing, and
  auto-calibration to reduce noise.
