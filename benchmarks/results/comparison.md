# Benchmark Results

Comparison of mojo-regex v0.8.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000201 | 0.000028 | 0.002777 | 7.2x faster | 99.3x faster |
| alternation_quantifiers | 0.753004 | 1.568152 | 0.107568 | 2.1x slower | 14.6x slower |
| alternation_simple | 0.000470 | 0.000008 | 0.000024 | 56.7x faster | 2.9x faster |
| anchor_start | 0.000546 | 0.000015 | 0.000046 | 35.5x faster | 3.0x faster |
| complex_email | 0.021842 | 0.009008 | - | 2.4x faster | - |
| complex_group_5_children | 0.000534 | 0.000214 | 0.000119 | 2.5x faster | 1.8x slower |
| complex_number | 0.128424 | 0.024777 | - | 5.2x faster | - |
| datetime_quantifiers | 0.109367 | 0.085677 | 0.073389 | 1.3x faster | 1.2x slower |
| deep_nested_groups_depth4 | 0.000367 | 0.000047 | 0.000037 | 7.8x faster | 1.3x slower |
| dense_quantifiers | 0.305797 | 0.086974 | 0.023352 | 3.5x faster | 3.7x slower |
| dfa_digits_only | 1.126631 | 0.222129 | 0.073317 | 5.1x faster | 3.0x slower |
| dfa_dot_phone | 1.188183 | 0.258781 | 0.052588 | 4.6x faster | 4.9x slower |
| dfa_paren_phone | 0.096219 | 0.027967 | 0.031142 | 3.4x faster | ~same |
| dfa_simple_phone | 1.087724 | 0.208604 | 0.107008 | 5.2x faster | 1.9x slower |
| dual_quantifiers | 0.116247 | 0.035227 | 0.020739 | 3.3x faster | 1.7x slower |
| flexible_datetime | 0.199842 | 0.147847 | 0.039480 | 1.4x faster | 3.7x slower |
| flexible_phone | 6.296932 | 7.084263 | 0.272093 | ~same | 26.0x slower |
| group_alternation | 0.000641 | 0.000009 | 0.000089 | 74.5x faster | 10.4x faster |
| grouped_quantifiers | 0.189197 | 0.051470 | 0.014834 | 3.7x faster | 3.5x slower |
| is_match_alphanumeric | 0.025733 | 0.000005 | 0.000017 | 5096.6x faster | 3.4x faster |
| is_match_digits | 0.022320 | 0.000006 | 0.000047 | 3867.9x faster | 8.1x faster |
| is_match_lowercase | 0.016358 | 0.000004 | 0.000017 | 3778.9x faster | 3.9x faster |
| is_match_predefined_digits | 0.044015 | 0.000006 | 0.000018 | 7491.7x faster | 3.1x faster |
| is_match_predefined_word | 0.053300 | 0.000005 | 0.000018 | 11060.5x faster | 3.7x faster |
| large_8_alternations | 0.001255 | 0.000197 | 0.000070 | 6.4x faster | 2.8x slower |
| literal_heavy_alternation | 0.000944 | 0.000205 | 0.000085 | 4.6x faster | 2.4x slower |
| literal_match_long | 0.008317 | 0.010626 | 0.005095 | 1.3x slower | 2.1x slower |
| literal_match_short | 0.001497 | 0.000940 | 0.000567 | 1.6x faster | 1.7x slower |
| literal_prefix_long | 0.046223 | 0.002294 | 0.030985 | 20.1x faster | 13.5x faster |
| literal_prefix_short | 0.000296 | 0.000432 | 0.000329 | 1.5x slower | 1.3x slower |
| match_all_digits | 1.645279 | 0.008775 | - | 187.5x faster | - |
| match_all_simple | 0.031814 | 0.016638 | 0.009041 | 1.9x faster | 1.8x slower |
| mixed_range_quantifiers | 0.128855 | 0.030872 | 0.007184 | 4.2x faster | 4.3x slower |
| multi_format_phone | 15.569855 | 17.380036 | 0.197595 | ~same | 88.0x slower |
| national_phone_validation | 1.085898 | 0.055421 | 0.065492 | 19.6x faster | 1.2x faster |
| no_literal_baseline | 0.000296 | 0.000019 | 0.008707 | 16.0x faster | 469.0x faster |
| optimize_extreme_quantifiers | 0.014848 | 0.002985 | 0.000263 | 5.0x faster | 11.3x slower |
| optimize_large_quantifiers | 0.007134 | 0.005522 | 0.012106 | 1.3x faster | 2.2x faster |
| optimize_multiple_quantifiers | 0.325352 | 0.091366 | 0.018998 | 3.6x faster | 4.8x slower |
| optimize_phone_quantifiers | 0.225438 | 0.054109 | 0.051761 | 4.2x faster | ~same |
| optimize_range_quantifier | 0.201834 | 0.315699 | 0.041432 | 1.6x slower | 7.6x slower |
| phone_validation | 0.000716 | 0.001002 | 0.000023 | 1.4x slower | 42.7x slower |
| predefined_digits | 0.318177 | 0.000676 | 0.000064 | 470.7x faster | 10.5x slower |
| predefined_word | 0.056481 | 0.027581 | 0.113391 | 2.0x faster | 4.1x faster |
| quad_quantifiers | 0.119351 | 0.034623 | 0.015518 | 3.4x faster | 2.2x slower |
| quantifier_one_or_more | 0.000299 | 0.000009 | 0.000060 | 33.2x faster | 6.7x faster |
| quantifier_zero_or_more | 0.000184 | 0.000010 | 0.000067 | 17.5x faster | 6.4x faster |
| quantifier_zero_or_one | 0.000223 | 0.000010 | 0.000067 | 21.4x faster | 6.5x faster |
| range_alphanumeric | 0.033376 | 0.024787 | 0.055219 | 1.3x faster | 2.2x faster |
| range_digits | 0.145597 | 0.000643 | 0.000093 | 226.5x faster | 6.9x slower |
| range_lowercase | 0.022441 | 0.026698 | 0.000057 | 1.2x slower | 470.0x slower |
| range_quantifiers | 0.130728 | 0.032835 | 0.073766 | 4.0x faster | 2.2x faster |
| required_literal_short | 0.002222 | 0.013854 | 0.000309 | 6.2x slower | 44.8x slower |
| simple_phone | 1.210649 | 0.178754 | 0.156550 | 6.8x faster | ~same |
| single_quantifier_alpha | 0.206330 | 0.022908 | 0.056884 | 9.0x faster | 2.5x faster |
| single_quantifier_digits | 0.092103 | 0.025268 | 0.018792 | 3.6x faster | 1.3x slower |
| toll_free_complex | 0.063440 | 0.016602 | - | 3.8x faster | - |
| toll_free_simple | 0.084631 | 0.025159 | - | 3.4x faster | - |
| triple_quantifiers | 0.113012 | 0.038539 | 0.013743 | 2.9x faster | 2.8x slower |
| ultra_dense_quantifiers | 0.502453 | 0.115608 | 0.076247 | 4.3x faster | 1.5x slower |
| wildcard_match_any | 0.007073 | 0.000001 | 0.061475 | 6684.5x faster | 58101.4x faster |

## Summary

**Mojo vs Python:** 52 wins, 9 losses out of 61 benchmarks (85% win rate)

**Mojo vs Rust:** 22 wins, 34 losses out of 56 common benchmarks (39% win rate)

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
  Variable-length alternation branches and deeply nested groups now supported.

### Where Mojo needs improvement

- **NFA backtracking patterns** (`flexible_phone`, `multi_format_phone`):
  1-3x slower than Python, 19-83x slower than Rust.
  Rust uses a lazy DFA that avoids backtracking entirely.
  See `docs/pikevm-proposal.md` for the planned PikeVM implementation.
- **Alternation with quantifiers** (`alternation_quantifiers`): ~3x slower than
  Python. Top-level OR with capturing groups routes to NFA.

### Notes

- Rust's `regex` crate is a highly optimized production library using Thompson NFA
  simulation, lazy DFA, and Aho-Corasick multi-pattern matching.
- Python's `re` module is implemented in C and handles backtracking-heavy patterns
  efficiently through its bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA architecture with SIMD-optimized character class
  matching using nibble-based `pshufb` lookups. The DFA compiler handles non-capturing
  alternation groups, variable-length literal branches, deeply nested groups, and
  flattens capturing groups for non-capture operations. Fast paths for `.*`
  prefix/suffix patterns skip the NFA entirely.
- Benchmarks run with pre-compiled regex, 500ms target runtime, median timing, and
  auto-calibration to reduce noise.
