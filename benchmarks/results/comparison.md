# Benchmark Results

Comparison of mojo-regex v0.7.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000519 | 0.000152 | 0.002530 | 3.4x faster | 16.7x faster |
| alternation_quantifiers | 0.611071 | 1.441028 | 0.080563 | 2.4x slower | 17.9x slower |
| alternation_simple | 0.000167 | 0.000163 | 0.000011 | ~same | 15.3x slower |
| anchor_start | 0.000285 | 0.000127 | 0.000015 | 2.2x faster | 8.6x slower |
| complex_email | 0.017835 | 0.042196 | - | 2.4x slower | - |
| complex_group_5_children | 0.000235 | 0.002114 | 0.000151 | 9.0x slower | 14.0x slower |
| complex_number | 0.086565 | 0.047166 | - | 1.8x faster | - |
| datetime_quantifiers | 0.072876 | 0.104569 | 0.063214 | 1.4x slower | 1.7x slower |
| deep_nested_groups_depth4 | 0.000301 | 0.001549 | 0.000031 | 5.1x slower | 49.4x slower |
| dense_quantifiers | 0.211845 | 0.098402 | 0.016216 | 2.2x faster | 6.1x slower |
| dfa_digits_only | 1.111382 | 0.315106 | 0.065977 | 3.5x faster | 4.8x slower |
| dfa_dot_phone | 1.374895 | 0.601161 | 0.045922 | 2.3x faster | 13.1x slower |
| dfa_paren_phone | 0.101932 | 0.590613 | 0.012024 | 5.8x slower | 49.1x slower |
| dfa_simple_phone | 1.769614 | 0.837976 | 0.066720 | 2.1x faster | 12.6x slower |
| dual_quantifiers | 0.154609 | 0.052934 | 0.021276 | 2.9x faster | 2.5x slower |
| flexible_datetime | 0.084357 | 0.091362 | 0.036066 | ~same | 2.5x slower |
| flexible_phone | 1.743989 | 7.433960 | 0.178992 | 4.3x slower | 41.5x slower |
| group_alternation | 0.000201 | 0.000123 | 0.000059 | 1.6x faster | 2.1x slower |
| grouped_quantifiers | 0.181053 | 0.589102 | 0.009761 | 3.3x slower | 60.4x slower |
| large_8_alternations | 0.000564 | 0.000258 | 0.000076 | 2.2x faster | 3.4x slower |
| literal_heavy_alternation | 0.000716 | 0.000265 | 0.000116 | 2.7x faster | 2.3x slower |
| literal_match_long | 0.014417 | 0.006793 | 0.005244 | 2.1x faster | 1.3x slower |
| literal_match_short | 0.001694 | 0.001024 | 0.000670 | 1.7x faster | 1.5x slower |
| literal_prefix_long | 0.018686 | 1.891735 | 0.027319 | 101.2x slower | 69.2x slower |
| literal_prefix_short | 0.000307 | 0.001214 | 0.000318 | 3.9x slower | 3.8x slower |
| match_all_digits | 0.780193 | 0.119949 | - | 6.5x faster | - |
| match_all_simple | 0.012944 | 0.008724 | 0.012693 | 1.5x faster | 1.5x faster |
| mixed_range_quantifiers | 0.069287 | 0.093870 | 0.006109 | 1.4x slower | 15.4x slower |
| multi_format_phone | 3.841894 | 14.925242 | 0.218651 | 3.9x slower | 68.3x slower |
| national_phone_validation | 0.771611 | 0.125445 | 0.051403 | 6.2x faster | 2.4x slower |
| no_literal_baseline | 0.000387 | 0.000174 | 0.008158 | 2.2x faster | 46.9x faster |
| optimize_extreme_quantifiers | 0.010686 | 0.032408 | 0.000189 | 3.0x slower | 171.6x slower |
| optimize_large_quantifiers | 0.004858 | 0.008576 | 0.019291 | 1.8x slower | 2.2x faster |
| optimize_multiple_quantifiers | 0.178185 | 0.234829 | 0.031653 | 1.3x slower | 7.4x slower |
| optimize_phone_quantifiers | 0.105485 | 0.172276 | 0.067784 | 1.6x slower | 2.5x slower |
| optimize_range_quantifier | 0.197602 | 0.436492 | 0.055058 | 2.2x slower | 7.9x slower |
| phone_validation | 0.000360 | 0.002689 | 0.000016 | 7.5x slower | 164.9x slower |
| predefined_digits | 0.150855 | 0.020195 | 0.000059 | 7.5x faster | 341.7x slower |
| predefined_word | 0.035023 | 0.039046 | 0.000018 | 1.1x slower | 2213.4x slower |
| quad_quantifiers | 0.071939 | 0.085751 | 0.011708 | 1.2x slower | 7.3x slower |
| quantifier_one_or_more | 0.000245 | 0.000109 | 0.000023 | 2.2x faster | 4.7x slower |
| quantifier_zero_or_more | 0.000122 | 0.000143 | 0.000025 | 1.2x slower | 5.8x slower |
| quantifier_zero_or_one | 0.000326 | 0.000107 | 0.000022 | 3.0x faster | 4.8x slower |
| range_alphanumeric | 0.015006 | 0.056984 | 0.000013 | 3.8x slower | 4318.5x slower |
| range_digits | 0.108943 | 0.024424 | 0.000025 | 4.5x faster | 969.3x slower |
| range_lowercase | 0.021390 | 0.054366 | 0.000011 | 2.5x slower | 4909.2x slower |
| range_quantifiers | 0.099338 | 0.079242 | 0.032040 | 1.3x faster | 2.5x slower |
| required_literal_short | 0.001651 | 0.008035 | 0.000263 | 4.9x slower | 30.5x slower |
| simple_phone | 0.887110 | 0.612678 | 0.126557 | 1.4x faster | 4.8x slower |
| single_quantifier_alpha | 0.217978 | 0.028602 | 0.032744 | 7.6x faster | 1.1x faster |
| single_quantifier_digits | 0.197733 | 0.038758 | 0.013036 | 5.1x faster | 3.0x slower |
| toll_free_complex | 0.024345 | 0.291293 | - | 12.0x slower | - |
| toll_free_simple | 0.083773 | 0.054742 | - | 1.5x faster | - |
| triple_quantifiers | 0.052907 | 0.058114 | 0.011306 | ~same | 5.1x slower |
| ultra_dense_quantifiers | 0.404460 | 0.100297 | 0.039702 | 4.0x faster | 2.5x slower |
| wildcard_match_any | 0.002484 | 0.000134 | 0.000032 | 18.6x faster | 4.2x slower |

## Summary

**Mojo vs Python:** Mojo wins 28, Python wins 25, same 3

**Mojo vs Rust:** Mojo wins 5, Rust wins 46, same 0

### Notes

- Rust's `regex` crate is a highly optimized production library with decades of
  development, using Thompson NFA simulation, lazy DFA, and Aho-Corasick multi-pattern
  matching. It represents the state-of-the-art in regex performance.
- Python's `re` module is implemented in C and handles backtracking-heavy patterns
  efficiently through its bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA architecture with SIMD-optimized character class
  matching. It excels on DFA-friendly patterns and character class operations.
