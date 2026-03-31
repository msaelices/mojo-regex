# Benchmark Results

Comparison of mojo-regex v0.8.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000247 | 0.000041 | 0.002139 | 6.0x faster | 51.6x faster |
| alternation_quantifiers | 0.647911 | 1.881418 | 0.092573 | 2.9x slower | 20.3x slower |
| alternation_simple | 0.000273 | 0.000013 | 0.000051 | 20.7x faster | 3.9x faster |
| anchor_start | 0.000311 | 0.000012 | 0.000066 | 25.5x faster | 5.4x faster |
| complex_email | 0.023882 | 0.017298 | - | 1.4x faster | - |
| complex_group_5_children | 0.000485 | 0.005838 | 0.000072 | 12.0x slower | 80.6x slower |
| complex_number | 0.161025 | 0.035988 | - | 4.5x faster | - |
| datetime_quantifiers | 0.123542 | 0.086057 | 0.089003 | 1.4x faster | ~same |
| deep_nested_groups_depth4 | 0.000291 | 0.003037 | 0.000052 | 10.4x slower | 58.2x slower |
| dense_quantifiers | 0.246299 | 0.121300 | 0.018301 | 2.0x faster | 6.6x slower |
| dfa_digits_only | 3.122447 | 0.223448 | 0.105264 | 14.0x faster | 2.1x slower |
| dfa_dot_phone | 1.911522 | 0.299743 | 0.051540 | 6.4x faster | 5.8x slower |
| dfa_paren_phone | 0.087589 | 0.048467 | 0.017004 | 1.8x faster | 2.9x slower |
| dfa_simple_phone | 1.445533 | 0.276088 | 0.098367 | 5.2x faster | 2.8x slower |
| dual_quantifiers | 0.228602 | 0.119846 | 0.039643 | 1.9x faster | 3.0x slower |
| flexible_datetime | 0.152602 | 0.189078 | 0.054560 | 1.2x slower | 3.5x slower |
| flexible_phone | 3.149638 | 9.218745 | 0.344189 | 2.9x slower | 26.8x slower |
| group_alternation | 0.000243 | 0.000016 | 0.000090 | 14.8x faster | 5.5x faster |
| grouped_quantifiers | 0.169647 | 0.050753 | 0.011659 | 3.3x faster | 4.4x slower |
| is_match_alphanumeric | 0.031113 | 0.000008 | 0.000016 | 3859.1x faster | 2.0x faster |
| is_match_digits | 0.029566 | 0.000011 | 0.000043 | 2766.6x faster | 4.1x faster |
| is_match_lowercase | 0.022720 | 0.000009 | 0.000031 | 2540.2x faster | 3.5x faster |
| is_match_predefined_digits | 0.048489 | 0.000012 | 0.000015 | 4120.6x faster | 1.3x faster |
| is_match_predefined_word | 0.087682 | 0.000009 | 0.000021 | 9458.6x faster | 2.3x faster |
| large_8_alternations | 0.000681 | 0.000263 | 0.000103 | 2.6x faster | 2.5x slower |
| literal_heavy_alternation | 0.000769 | 0.000262 | 0.000126 | 2.9x faster | 2.1x slower |
| literal_match_long | 0.015920 | 0.014799 | 0.003968 | ~same | 3.7x slower |
| literal_match_short | 0.002865 | 0.001206 | 0.001029 | 2.4x faster | 1.2x slower |
| literal_prefix_long | 0.046326 | 0.215552 | 0.029888 | 4.7x slower | 7.2x slower |
| literal_prefix_short | 0.000369 | 0.000839 | 0.000399 | 2.3x slower | 2.1x slower |
| match_all_digits | 1.370260 | 0.005324 | - | 257.4x faster | - |
| match_all_simple | 0.041075 | 0.010526 | 0.011738 | 3.9x faster | ~same |
| mixed_range_quantifiers | 0.113054 | 0.050227 | 0.008144 | 2.3x faster | 6.2x slower |
| multi_format_phone | 7.337037 | 23.175483 | 0.380596 | 3.2x slower | 60.9x slower |
| national_phone_validation | 1.422975 | 0.081674 | 0.133042 | 17.4x faster | 1.6x faster |
| no_literal_baseline | 0.000366 | 0.000032 | 0.007995 | 11.4x faster | 248.6x faster |
| optimize_extreme_quantifiers | 0.020911 | 0.005837 | 0.000476 | 3.6x faster | 12.3x slower |
| optimize_large_quantifiers | 0.015418 | 0.010161 | 0.018357 | 1.5x faster | 1.8x faster |
| optimize_multiple_quantifiers | 0.945701 | 0.110233 | 0.022724 | 8.6x faster | 4.9x slower |
| optimize_phone_quantifiers | 0.366034 | 0.074586 | 0.051105 | 4.9x faster | 1.5x slower |
| optimize_range_quantifier | 0.268679 | 0.666687 | 0.049869 | 2.5x slower | 13.4x slower |
| phone_validation | 0.000657 | 0.002106 | 0.000031 | 3.2x slower | 68.8x slower |
| predefined_digits | 0.290350 | 0.000887 | 0.000051 | 327.4x faster | 17.5x slower |
| predefined_word | 0.061144 | 0.027516 | 0.110993 | 2.2x faster | 4.0x faster |
| quad_quantifiers | 0.139122 | 0.103333 | 0.014519 | 1.3x faster | 7.1x slower |
| quantifier_one_or_more | 0.000388 | 0.000014 | 0.000093 | 27.3x faster | 6.5x faster |
| quantifier_zero_or_more | 0.000190 | 0.000010 | 0.000078 | 19.1x faster | 7.9x faster |
| quantifier_zero_or_one | 0.000276 | 0.000019 | 0.000117 | 14.2x faster | 6.0x faster |
| range_alphanumeric | 0.038755 | 0.034690 | 0.080050 | ~same | 2.3x faster |
| range_digits | 0.277471 | 0.000693 | 0.000099 | 400.4x faster | 7.0x slower |
| range_lowercase | 0.019087 | 0.037552 | 0.000088 | 2.0x slower | 428.5x slower |
| range_quantifiers | 0.165388 | 0.052285 | 0.056353 | 3.2x faster | ~same |
| required_literal_short | 0.003607 | 0.011776 | 0.000308 | 3.3x slower | 38.2x slower |
| simple_phone | 1.737726 | 0.379525 | 0.259925 | 4.6x faster | 1.5x slower |
| single_quantifier_alpha | 0.212080 | 0.032497 | 0.106958 | 6.5x faster | 3.3x faster |
| single_quantifier_digits | 0.186429 | 0.056539 | 0.025992 | 3.3x faster | 2.2x slower |
| toll_free_complex | 0.055994 | 0.033675 | - | 1.7x faster | - |
| toll_free_simple | 0.126067 | 0.060687 | - | 2.1x faster | - |
| triple_quantifiers | 0.112662 | 0.062573 | 0.015724 | 1.8x faster | 4.0x slower |
| ultra_dense_quantifiers | 0.430585 | 0.163839 | 0.054809 | 2.6x faster | 3.0x slower |
| wildcard_match_any | 0.004225 | 0.000001 | 0.067481 | 2836.7x faster | 45303.5x faster |

## Summary

**Mojo vs Python:** 49 wins, 12 losses out of 61 benchmarks (80% win rate)

**Mojo vs Rust:** 22 wins, 34 losses out of 56 common benchmarks (39% win rate)

### Where Mojo excels

- **is_match (bool-only):** 2000-6000x faster than Python, 2-6x faster than Rust.
  O(1) single character check via SIMD lookup table.
- **Simple quantifiers** (`a*`, `a+`, `a?`): 17-80x faster than Python, 5-8x faster
  than Rust. Lightweight DFA with inlined dispatch.
- **Character class search/findall** (`[a-z]+`, `\w+`, `\d+`): 29-350x faster than
  Python using nibble-based SIMD matching (two native `pshufb` ops per 32 chars).
- **Wildcard** (`.*`): 4000+x faster than Python. Constant-time fast path.
- **`.*` prefix patterns** (`.*@example\.com`): Fast path finds literal suffix
  directly, avoiding greedy backtracking (PR #82).
- **DFA findall** (phone numbers, quantifier patterns): 2-8x faster than Python.

### Where Mojo needs improvement

- **NFA backtracking patterns** (`flexible_phone`, `multi_format_phone`):
  1-2x slower than Python, 19-83x slower than Rust.
  Rust uses a lazy DFA that avoids backtracking entirely.
- **Complex NFA patterns** (`deep_nested_groups_depth4`, `complex_group_5_children`):
  5-7x slower than Python due to recursive matching overhead.
- **Alternation with quantifiers** (`alternation_quantifiers`): ~4x slower than
  Python. Top-level OR with capturing groups routes to NFA.

### Notes

- Rust's `regex` crate is a highly optimized production library using Thompson NFA
  simulation, lazy DFA, and Aho-Corasick multi-pattern matching. It represents the
  state-of-the-art in regex performance.
- Python's `re` module is implemented in C and handles backtracking-heavy patterns
  efficiently through its bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA architecture with SIMD-optimized character class
  matching using nibble-based `pshufb` lookups. The DFA compiler handles non-capturing
  alternation groups and flattens capturing groups for non-capture operations.
- Benchmarks run with pre-compiled regex, 500ms target runtime, median timing, and
  auto-calibration to reduce noise.
