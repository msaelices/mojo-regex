# Benchmark Results

Comparison of mojo-regex v0.8.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000342 | 0.000019 | 0.002994 | 17.6x faster | 153.9x faster |
| alternation_quantifiers | 0.444265 | 1.191965 | 0.077645 | 2.7x slower | 15.4x slower |
| alternation_simple | 0.000230 | 0.000010 | 0.000024 | 22.6x faster | 2.4x faster |
| anchor_start | 0.000245 | 0.000013 | 0.000037 | 18.7x faster | 2.8x faster |
| complex_email | 0.020013 | 0.008613 | - | 2.3x faster | - |
| complex_group_5_children | 0.000389 | 0.000146 | 0.000078 | 2.7x faster | 1.9x slower |
| complex_number | 0.129937 | 0.016663 | - | 7.8x faster | - |
| datetime_quantifiers | 0.109677 | 0.060238 | 0.073371 | 1.8x faster | 1.2x faster |
| deep_nested_groups_depth4 | 0.000261 | 0.002127 | 0.000031 | 8.2x slower | 68.2x slower |
| dense_quantifiers | 0.212282 | 0.090046 | 0.025464 | 2.4x faster | 3.5x slower |
| dfa_digits_only | 1.206004 | 0.159114 | 0.057510 | 7.6x faster | 2.8x slower |
| dfa_dot_phone | 0.913144 | 0.193169 | 0.040078 | 4.7x faster | 4.8x slower |
| dfa_paren_phone | 0.060168 | 0.020092 | 0.010141 | 3.0x faster | 2.0x slower |
| dfa_simple_phone | 1.172266 | 0.167944 | 0.076704 | 7.0x faster | 2.2x slower |
| dual_quantifiers | 0.104703 | 0.032846 | 0.017978 | 3.2x faster | 1.8x slower |
| flexible_datetime | 0.119596 | 0.103352 | 0.030507 | 1.2x faster | 3.4x slower |
| flexible_phone | 2.082493 | 6.089330 | 0.224100 | 2.9x slower | 27.2x slower |
| group_alternation | 0.000227 | 0.000008 | 0.000103 | 29.0x faster | 13.2x faster |
| grouped_quantifiers | 0.139642 | 0.033863 | 0.011271 | 4.1x faster | 3.0x slower |
| is_match_alphanumeric | 0.020906 | 0.000005 | 0.000014 | 4591.4x faster | 3.0x faster |
| is_match_digits | 0.014621 | 0.000004 | 0.000037 | 3551.4x faster | 8.9x faster |
| is_match_lowercase | 0.015467 | 0.000005 | 0.000015 | 3310.7x faster | 3.1x faster |
| is_match_predefined_digits | 0.038063 | 0.000004 | 0.000017 | 9122.1x faster | 4.1x faster |
| is_match_predefined_word | 0.038128 | 0.000005 | 0.000017 | 8282.6x faster | 3.7x faster |
| large_8_alternations | 0.000409 | 0.000164 | 0.000076 | 2.5x faster | 2.2x slower |
| literal_heavy_alternation | 0.000494 | 0.000168 | 0.000070 | 2.9x faster | 2.4x slower |
| literal_match_long | 0.008109 | 0.007452 | 0.003998 | ~same | 1.9x slower |
| literal_match_short | 0.000840 | 0.001215 | 0.000428 | 1.4x slower | 2.8x slower |
| literal_prefix_long | 0.040051 | 0.002673 | 0.025809 | 15.0x faster | 9.7x faster |
| literal_prefix_short | 0.000244 | 0.000230 | 0.000251 | ~same | ~same |
| match_all_digits | 1.268676 | 0.005522 | - | 229.8x faster | - |
| match_all_simple | 0.019434 | 0.007570 | 0.007103 | 2.6x faster | ~same |
| mixed_range_quantifiers | 0.138584 | 0.025136 | 0.006784 | 5.5x faster | 3.7x slower |
| multi_format_phone | 4.991031 | 16.891487 | 0.172587 | 3.4x slower | 97.9x slower |
| national_phone_validation | 0.686142 | 0.041388 | 0.053373 | 16.6x faster | 1.3x faster |
| no_literal_baseline | 0.000402 | 0.000020 | 0.007731 | 20.4x faster | 392.1x faster |
| optimize_extreme_quantifiers | 0.010707 | 0.002314 | 0.000329 | 4.6x faster | 7.0x slower |
| optimize_large_quantifiers | 0.008332 | 0.005299 | 0.011675 | 1.6x faster | 2.2x faster |
| optimize_multiple_quantifiers | 0.350855 | 0.125514 | 0.020047 | 2.8x faster | 6.3x slower |
| optimize_phone_quantifiers | 0.164246 | 0.037797 | 0.042608 | 4.3x faster | ~same |
| optimize_range_quantifier | 0.136490 | 0.250190 | 0.031884 | 1.8x slower | 7.8x slower |
| phone_validation | 0.000356 | 0.001184 | 0.000043 | 3.3x slower | 27.4x slower |
| predefined_digits | 0.225610 | 0.000423 | 0.000054 | 533.2x faster | 7.9x slower |
| predefined_word | 0.036252 | 0.027516 | 0.054499 | 1.3x faster | 2.0x faster |
| quad_quantifiers | 0.134277 | 0.034744 | 0.011934 | 3.9x faster | 2.9x slower |
| quantifier_one_or_more | 0.000232 | 0.000009 | 0.000094 | 27.1x faster | 11.1x faster |
| quantifier_zero_or_more | 0.000224 | 0.000008 | 0.000050 | 28.8x faster | 6.4x faster |
| quantifier_zero_or_one | 0.000233 | 0.000007 | 0.000058 | 31.5x faster | 7.8x faster |
| range_alphanumeric | 0.029916 | 0.027321 | 0.054803 | ~same | 2.0x faster |
| range_digits | 0.128995 | 0.000453 | 0.000058 | 284.7x faster | 7.8x slower |
| range_lowercase | 0.014523 | 0.024087 | 0.000073 | 1.7x slower | 331.3x slower |
| range_quantifiers | 0.231320 | 0.027387 | 0.043623 | 8.4x faster | 1.6x faster |
| required_literal_short | 0.004565 | 0.011432 | 0.000296 | 2.5x slower | 38.7x slower |
| simple_phone | 1.608730 | 0.176879 | 0.152127 | 9.1x faster | 1.2x slower |
| single_quantifier_alpha | 0.146658 | 0.018149 | 0.038368 | 8.1x faster | 2.1x faster |
| single_quantifier_digits | 0.104022 | 0.023226 | 0.016574 | 4.5x faster | 1.4x slower |
| toll_free_complex | 0.043782 | 0.014564 | - | 3.0x faster | - |
| toll_free_simple | 0.085809 | 0.020837 | - | 4.1x faster | - |
| triple_quantifiers | 0.120536 | 0.031267 | 0.010623 | 3.9x faster | 2.9x slower |
| ultra_dense_quantifiers | 0.281785 | 0.058729 | 0.046745 | 4.8x faster | 1.3x slower |
| wildcard_match_any | 0.004414 | 0.000001 | 0.059155 | 3488.1x faster | 46742.4x faster |

## Summary

**Mojo vs Python:** 52 wins, 9 losses out of 61 benchmarks (85% win rate)

**Mojo vs Rust:** 24 wins, 32 losses out of 56 common benchmarks (42% win rate)

### Where Mojo excels

- **is_match (bool-only):** 2000-19000x faster than Python, 2-6x faster than Rust.
  O(1) single character check via SIMD lookup table.
- **Simple quantifiers** (`a*`, `a+`, `a?`): 17-80x faster than Python, 5-8x faster
  than Rust. Lightweight DFA with inlined dispatch.
- **Character class search/findall** (`[a-z]+`, `\w+`, `\d+`): 29-350x faster than
  Python using nibble-based SIMD matching (two native `pshufb` ops per 32 chars).
- **Wildcard** (`.*`): 4000+x faster than Python. Constant-time fast path.
- **`.*` prefix/suffix patterns**: Fast paths for `.*LITERAL` (PR #82) and
  `LITERAL.*` (PR #83) skip NFA backtracking entirely.
- **DFA findall** (phone numbers, quantifier patterns): 2-8x faster than Python.
  Variable-length alternation branches now supported (PR #84).

### Where Mojo needs improvement

- **NFA backtracking patterns** (`flexible_phone`, `multi_format_phone`):
  1-3x slower than Python, 19-83x slower than Rust.
  Rust uses a lazy DFA that avoids backtracking entirely.
- **Deeply nested groups** (`deep_nested_groups_depth4`): ~10x slower than Python
  due to recursive NFA matching through nested GROUP wrappers.
- **Alternation with quantifiers** (`alternation_quantifiers`): ~3x slower than
  Python. Top-level OR with capturing groups routes to NFA.

### Notes

- Rust's `regex` crate is a highly optimized production library using Thompson NFA
  simulation, lazy DFA, and Aho-Corasick multi-pattern matching.
- Python's `re` module is implemented in C and handles backtracking-heavy patterns
  efficiently through its bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA architecture with SIMD-optimized character class
  matching using nibble-based `pshufb` lookups. The DFA compiler handles non-capturing
  alternation groups, variable-length literal branches, and flattens capturing groups
  for non-capture operations. Fast paths for `.*` prefix/suffix patterns skip the NFA.
- Benchmarks run with pre-compiled regex, 500ms target runtime, median timing, and
  auto-calibration to reduce noise.
