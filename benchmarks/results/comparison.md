# Benchmark Results

Comparison of mojo-regex v0.7.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000519 | 0.000181 | 0.002530 | 2.9x faster | 14.0x faster |
| alternation_quantifiers | 0.611071 | 1.550685 | 0.080563 | 2.5x slower | 19.2x slower |
| alternation_simple | 0.000167 | 0.000106 | 0.000011 | 1.6x faster | 9.9x slower |
| anchor_start | 0.000285 | 7.334563 | 0.000015 | 25768.2x slower | 498391.5x slower |
| complex_email | 0.017835 | 0.050336 | - | 2.8x slower | - |
| complex_group_5_children | 0.000235 | 0.002662 | 0.000151 | 11.3x slower | 17.6x slower |
| complex_number | 0.086565 | 0.078166 | - | ~same | - |
| datetime_quantifiers | 0.072876 | 0.091591 | 0.063214 | 1.3x slower | 1.4x slower |
| deep_nested_groups_depth4 | 0.000301 | 0.002526 | 0.000031 | 8.4x slower | 80.6x slower |
| dense_quantifiers | 0.211845 | 0.136500 | 0.016216 | 1.6x faster | 8.4x slower |
| dfa_digits_only | 1.111382 | 0.283456 | 0.065977 | 3.9x faster | 4.3x slower |
| dfa_dot_phone | 1.374895 | 1.118042 | 0.045922 | 1.2x faster | 24.3x slower |
| dfa_paren_phone | 0.101932 | 1.001709 | 0.012024 | 9.8x slower | 83.3x slower |
| dfa_simple_phone | 1.769614 | 1.172262 | 0.066720 | 1.5x faster | 17.6x slower |
| dual_quantifiers | 0.154609 | 0.112198 | 0.021276 | 1.4x faster | 5.3x slower |
| flexible_datetime | 0.084357 | 0.103989 | 0.036066 | 1.2x slower | 2.9x slower |
| flexible_phone | 1.743989 | 10.041166 | 0.178992 | 5.8x slower | 56.1x slower |
| group_alternation | 0.000201 | 9.608248 | 0.000059 | 47737.2x slower | 163564.7x slower |
| grouped_quantifiers | 0.181053 | 1.509174 | 0.009761 | 8.3x slower | 154.6x slower |
| large_8_alternations | 0.000564 | 0.000304 | 0.000076 | 1.9x faster | 4.0x slower |
| literal_heavy_alternation | 0.000716 | 0.000369 | 0.000116 | 1.9x faster | 3.2x slower |
| literal_match_long | 0.014417 | 0.016049 | 0.005244 | 1.1x slower | 3.1x slower |
| literal_match_short | 0.001694 | 0.001655 | 0.000670 | ~same | 2.5x slower |
| literal_prefix_long | 0.018686 | 1.434604 | 0.027319 | 76.8x slower | 52.5x slower |
| literal_prefix_short | 0.000307 | 0.001400 | 0.000318 | 4.6x slower | 4.4x slower |
| match_all_digits | 0.780193 | 0.132982 | - | 5.9x faster | - |
| match_all_simple | 0.012944 | 0.009622 | 0.012693 | 1.3x faster | 1.3x faster |
| mixed_range_quantifiers | 0.069287 | 0.058701 | 0.006109 | 1.2x faster | 9.6x slower |
| multi_format_phone | 3.841894 | 19.761748 | 0.218651 | 5.1x slower | 90.4x slower |
| national_phone_validation | 0.771611 | 0.090152 | 0.051403 | 8.6x faster | 1.8x slower |
| no_literal_baseline | 0.000387 | 0.000208 | 0.008158 | 1.9x faster | 39.2x faster |
| optimize_extreme_quantifiers | 0.010686 | 0.035208 | 0.000189 | 3.3x slower | 186.4x slower |
| optimize_large_quantifiers | 0.004858 | 0.007063 | 0.019291 | 1.5x slower | 2.7x faster |
| optimize_multiple_quantifiers | 0.178185 | 0.137058 | 0.031653 | 1.3x faster | 4.3x slower |
| optimize_phone_quantifiers | 0.105485 | 0.135363 | 0.067784 | 1.3x slower | 2.0x slower |
| optimize_range_quantifier | 0.197602 | 0.330111 | 0.055058 | 1.7x slower | 6.0x slower |
| phone_validation | 0.000360 | 0.001246 | 0.000016 | 3.5x slower | 76.4x slower |
| predefined_digits | 0.150855 | 0.046089 | 0.000059 | 3.3x faster | 779.8x slower |
| predefined_word | 0.035023 | 0.056374 | 0.000018 | 1.6x slower | 3195.7x slower |
| quad_quantifiers | 0.071939 | 0.064897 | 0.011708 | ~same | 5.5x slower |
| quantifier_one_or_more | 0.000245 | 8.146760 | 0.000023 | 33280.3x slower | 352760.6x slower |
| quantifier_zero_or_more | 0.000122 | 7.784783 | 0.000025 | 63571.6x slower | 316155.1x slower |
| quantifier_zero_or_one | 0.000326 | 0.000168 | 0.000022 | 1.9x faster | 7.5x slower |
| range_alphanumeric | 0.015006 | 0.094480 | 0.000013 | 6.3x slower | 7160.0x slower |
| range_digits | 0.108943 | 0.029529 | 0.000025 | 3.7x faster | 1171.9x slower |
| range_lowercase | 0.021390 | 0.095737 | 0.000011 | 4.5x slower | 8645.1x slower |
| range_quantifiers | 0.099338 | 0.033689 | 0.032040 | 2.9x faster | ~same |
| required_literal_short | 0.001651 | 0.007792 | 0.000263 | 4.7x slower | 29.6x slower |
| simple_phone | 0.887110 | 1.007476 | 0.126557 | 1.1x slower | 8.0x slower |
| single_quantifier_alpha | 0.217978 | 0.060204 | 0.032744 | 3.6x faster | 1.8x slower |
| single_quantifier_digits | 0.197733 | 0.050122 | 0.013036 | 3.9x faster | 3.8x slower |
| toll_free_complex | 0.024345 | 0.537866 | - | 22.1x slower | - |
| toll_free_simple | 0.083773 | 0.064178 | - | 1.3x faster | - |
| triple_quantifiers | 0.052907 | 0.155139 | 0.011306 | 2.9x slower | 13.7x slower |
| ultra_dense_quantifiers | 0.404460 | 0.207549 | 0.039702 | 1.9x faster | 5.2x slower |
| wildcard_match_any | 0.002484 | 0.000160 | 0.000032 | 15.5x faster | 5.0x slower |

## Summary

**Mojo vs Python:** Mojo wins 24, Python wins 29, same 3

**Mojo vs Rust:** Mojo wins 4, Rust wins 46, same 1

### Notes

- Rust's `regex` crate is a highly optimized production library with decades of
  development, using Thompson NFA simulation, lazy DFA, and Aho-Corasick multi-pattern
  matching. It represents the state-of-the-art in regex performance.
- Python's `re` module is implemented in C and handles backtracking-heavy patterns
  efficiently through its bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA architecture with SIMD-optimized character class
  matching. It excels on DFA-friendly patterns and character class operations.