# Benchmark Results

Comparison of mojo-regex v0.7.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000447 | 0.000133 | 0.001898 | 3.4x faster | 14.3x faster |
| alternation_quantifiers | 0.464705 | 3.133097 | 0.076108 | 6.7x slower | 41.2x slower |
| alternation_simple | 0.000152 | - | 0.000021 | - | - |
| alternation_words | - | - | 0.000025 | - | - |
| anchor_end | - | - | 0.000026 | - | - |
| anchor_start | 0.000153 | - | 0.000023 | - | - |
| complex_email | 0.017288 | 0.060812 | - | 3.5x slower | - |
| complex_email_extraction | - | - | 0.000693 | - | - |
| complex_group_5_children | 0.000564 | 0.001974 | 0.000141 | 3.5x slower | 14.0x slower |
| complex_number | 0.123989 | 0.097972 | - | 1.3x faster | - |
| complex_number_extraction | - | - | 0.133753 | - | - |
| datetime_quantifiers | 0.104941 | 0.125713 | 0.074798 | 1.2x slower | 1.7x slower |
| deep_nested_groups_depth4 | 0.000169 | 0.001643 | 0.000040 | 9.7x slower | 41.2x slower |
| dense_quantifiers | 0.205270 | 0.159845 | 0.019507 | 1.3x faster | 8.2x slower |
| dfa_digits_only | 1.080449 | 0.781966 | 0.047837 | 1.4x faster | 16.3x slower |
| dfa_dot_phone | 0.906748 | 1.215649 | 0.030413 | 1.3x slower | 40.0x slower |
| dfa_paren_phone | 0.060222 | 0.707517 | 0.013031 | 11.7x slower | 54.3x slower |
| dfa_simple_phone | 0.762736 | 0.863845 | 0.080499 | 1.1x slower | 10.7x slower |
| dual_quantifiers | 0.148094 | 0.055806 | 0.025090 | 2.7x faster | 2.2x slower |
| flexible_datetime | 0.148136 | 0.150834 | 0.047114 | ~same | 3.2x slower |
| flexible_phone | 1.825029 | 4.563600 | 0.175172 | 2.5x slower | 26.1x slower |
| group_alternation | 0.000145 | 0.000144 | 0.000065 | ~same | 2.2x slower |
| group_quantified | - | - | 0.054643 | - | - |
| grouped_quantifiers | 0.110250 | 1.753648 | 0.008426 | 15.9x slower | 208.1x slower |
| large_8_alternations | 0.000324 | 0.000470 | 0.000084 | 1.5x slower | 5.6x slower |
| literal_heavy_alternation | 0.000566 | 0.000208 | 0.000174 | 2.7x faster | 1.2x slower |
| literal_match_long | 0.006832 | 0.007148 | 0.008192 | ~same | 1.1x faster |
| literal_match_short | 0.000750 | 0.000894 | 0.000636 | 1.2x slower | 1.4x slower |
| literal_prefix_long | 0.038410 | 0.071588 | 0.035387 | 1.9x slower | 2.0x slower |
| literal_prefix_medium | - | - | 0.004028 | - | - |
| literal_prefix_short | 0.000548 | 0.000369 | 0.000531 | 1.5x faster | 1.4x faster |
| match_all_digits | 1.149143 | 0.143035 | - | 8.0x faster | - |
| match_all_pattern | - | - | 0.070033 | - | - |
| match_all_simple | 0.017265 | 0.009012 | 0.009981 | 1.9x faster | 1.1x faster |
| mixed_range_quantifiers | 0.095882 | 0.066321 | 0.006373 | 1.4x faster | 10.4x slower |
| multi_format_phone | 3.688427 | 10.470579 | 0.170865 | 2.8x slower | 61.3x slower |
| national_phone_validation | 0.766063 | 0.088685 | 0.045135 | 8.6x faster | 2.0x slower |
| no_literal_baseline | 0.000473 | 0.000133 | 0.005353 | 3.6x faster | 40.3x faster |
| optimize_extreme_quantifiers | 0.020683 | 0.026042 | 0.000258 | 1.3x slower | 101.1x slower |
| optimize_large_quantifiers | 0.010686 | 0.004655 | 0.009427 | 2.3x faster | 2.0x faster |
| optimize_multiple_quantifiers | 0.225952 | 0.156302 | 0.015153 | 1.4x faster | 10.3x slower |
| optimize_phone_quantifiers | 0.162562 | 0.110152 | 0.040217 | 1.5x faster | 2.7x slower |
| optimize_range_quantifier | 0.122503 | 0.287469 | 0.030155 | 2.3x slower | 9.5x slower |
| phone_validation | 0.000304 | 0.001709 | 0.000015 | 5.6x slower | 117.8x slower |
| predefined_digits | 0.141826 | 0.018750 | 0.000050 | 7.6x faster | 376.7x slower |
| predefined_word | 0.026424 | 0.036205 | 0.000017 | 1.4x slower | 2146.3x slower |
| pure_dfa_dash | - | 0.003487 | - | - | - |
| pure_dfa_dot | - | 0.003697 | - | - | - |
| pure_dfa_paren | - | 0.001710 | - | - | - |
| quad_quantifiers | 0.112913 | 0.056072 | 0.016503 | 2.0x faster | 3.4x slower |
| quantifier_one_or_more | 0.000236 | 0.000283 | 0.000026 | 1.2x slower | 10.8x slower |
| quantifier_zero_or_more | 0.000242 | 0.000226 | 0.000015 | ~same | 15.5x slower |
| quantifier_zero_or_one | 0.000287 | - | 0.000037 | - | - |
| range_alphanumeric | 0.021714 | 0.050369 | 0.000018 | 2.3x slower | 2731.1x slower |
| range_digits | 0.132666 | 0.026576 | 0.000032 | 5.0x faster | 840.1x slower |
| range_lowercase | 0.022769 | 0.056854 | 0.000016 | 2.5x slower | 3611.9x slower |
| range_quantifiers | 0.103679 | 0.038713 | 0.047171 | 2.7x faster | 1.2x faster |
| required_literal_long | - | - | 0.001201 | - | - |
| required_literal_short | 0.003292 | 0.004070 | 0.000364 | 1.2x slower | 11.2x slower |
| simd_alphanumeric_large | - | - | 0.000012 | - | - |
| simd_alphanumeric_xlarge | - | - | 0.000020 | - | - |
| simd_multi_char_class | - | - | 0.000028 | - | - |
| simd_negated_alphanumeric | - | - | 0.000030 | - | - |
| simple_phone | 1.468969 | 1.072143 | 0.113908 | 1.4x faster | 9.4x slower |
| single_quantifier_alpha | 0.181023 | 0.031436 | 0.050543 | 5.8x faster | 1.6x faster |
| single_quantifier_digits | 0.122010 | 0.050499 | 0.018544 | 2.4x faster | 2.7x slower |
| smart_phone_primary | - | 0.692193 | - | - | - |
| toll_free_complex | 0.057387 | 0.255135 | - | 4.4x slower | - |
| toll_free_simple | 0.098604 | 0.049667 | - | 2.0x faster | - |
| triple_quantifiers | 0.127432 | 0.058717 | 0.013296 | 2.2x faster | 4.4x slower |
| ultra_dense_quantifiers | 0.226551 | 0.152129 | 0.043125 | 1.5x faster | 3.5x slower |
| wildcard_match_any | 0.007899 | 0.000168 | 0.000046 | 47.1x faster | 3.6x slower |

## Summary

**Mojo vs Python:** Mojo wins 26, Python wins 23, same 4

**Mojo vs Rust:** Mojo wins 8, Rust wins 40, same 0

### Notes

- Rust's `regex` crate is a highly optimized production library with decades of
  development, using Thompson NFA simulation, lazy DFA, and Aho-Corasick multi-pattern
  matching. It represents the state-of-the-art in regex performance.
- Python's `re` module is implemented in C and handles backtracking-heavy patterns
  efficiently through its bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA architecture with SIMD-optimized character class
  matching. It excels on DFA-friendly patterns and character class operations.
