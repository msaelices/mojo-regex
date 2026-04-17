# Benchmark Results

Comparison of mojo-regex (post PR #139), Python `re`, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, default optimization
- **Python**: CPython, `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 140.012 ns | 7.390 ns | 2.039 us | **18.9x faster** | **275.9x faster** |
| alternation_quantifiers | 530.772 us | 32.184 us | 85.901 us | **16.5x faster** | **2.7x faster** |
| alternation_simple | 146.002 ns | 3.411 ns | 15.542 ns | **42.8x faster** | **4.6x faster** |
| anchor_start | 146.606 ns | 8.176 ns | 29.218 ns | **17.9x faster** | **3.6x faster** |
| complex_email | 16.902 us | 5.101 us | - | **3.3x faster** |   |
| complex_group_5_children | 285.534 ns | 56.201 ns | 63.679 ns | **5.1x faster** | **1.1x faster** |
| complex_number | 71.043 us | 6.733 us | - | **10.6x faster** |   |
| datetime_quantifiers | 69.002 us | 33.633 us | 58.312 us | **2.1x faster** | **1.7x faster** |
| deep_nested_groups_depth4 | 154.206 ns | 11.575 ns | 20.811 ns | **13.3x faster** | **1.8x faster** |
| dense_quantifiers | 129.515 us | 11.859 us | 15.048 us | **10.9x faster** | **1.3x faster** |
| dfa_digits_only | 1.139 ms | 101.165 us | 47.476 us | **11.3x faster** | 2.1x slower |
| dfa_dot_phone | 626.300 us | 60.925 us | 36.482 us | **10.3x faster** | 1.7x slower |
| dfa_paren_phone | 42.212 us | 5.472 us | 14.931 us | **7.7x faster** | **2.7x faster** |
| dfa_simple_phone | 1.183 ms | 35.190 us | 59.901 us | **33.6x faster** | **1.7x faster** |
| dual_quantifiers | 70.896 us | 19.815 us | 14.490 us | **3.6x faster** | 1.4x slower |
| flexible_datetime | 138.776 us | 12.358 us | 39.131 us | **11.2x faster** | **3.2x faster** |
| flexible_phone | 2.514 ms | 54.246 us | 250.519 us | **46.3x faster** | **4.6x faster** |
| group_alternation | 163.529 ns | 5.333 ns | 47.337 ns | **30.7x faster** | **8.9x faster** |
| grouped_quantifiers | 97.393 us | 5.443 us | 8.525 us | **17.9x faster** | **1.6x faster** |
| is_match_alphanumeric | 14.022 us | 1.414 ns | 12.419 ns | **9,917x faster** | **8.8x faster** |
| is_match_digits | 16.262 us | 1.261 ns | 37.137 ns | **12,901x faster** | **29.5x faster** |
| is_match_lowercase | 9.869 us | 1.427 ns | 12.103 ns | **6,918x faster** | **8.5x faster** |
| is_match_predefined_digits | 23.916 us | 1.337 ns | 19.050 ns | **17,889x faster** | **14.2x faster** |
| is_match_predefined_word | 23.554 us | 1.525 ns | 12.590 ns | **15,444x faster** | **8.3x faster** |
| large_8_alternations | 480.325 ns | 50.953 ns | 81.172 ns | **9.4x faster** | **1.6x faster** |
| literal_heavy_alternation | 374.926 ns | 59.432 ns | 88.719 ns | **6.3x faster** | **1.5x faster** |
| literal_match_long | 6.768 us | 4.782 us | 2.990 us | **1.4x faster** | 1.6x slower |
| literal_match_short | 816.364 ns | 477.260 ns | 442.979 ns | **1.7x faster** | 1.1x slower |
| literal_prefix_long | 31.537 us | 2.023 us | 21.598 us | **15.6x faster** | **10.7x faster** |
| literal_prefix_short | 152.702 ns | 95.456 ns | 231.034 ns | **1.6x faster** | **2.4x faster** |
| match_all_digits | 753.055 us | 7.601 us | - | **99.1x faster** |   |
| match_all_simple | 24.188 us | 4.804 us | 8.140 us | **5.0x faster** | **1.7x faster** |
| mixed_range_quantifiers | 61.905 us | 5.198 us | 3.971 us | **11.9x faster** | 1.3x slower |
| multi_format_phone | 3.162 ms | 94.633 us | 152.970 us | **33.4x faster** | **1.6x faster** |
| nanpa_findall | 41.072 us | 5.278 us | 11.683 us | **7.8x faster** | **2.2x faster** |
| nanpa_match_first | 183.527 ns | 15.321 ns | 59.881 ns | **12.0x faster** | **3.9x faster** |
| nanpa_search | 236.798 ns | 32.818 ns | 47.262 ns | **7.2x faster** | **1.4x faster** |
| national_phone_validation | 941.630 us | 47.710 us | 69.340 us | **19.7x faster** | **1.5x faster** |
| no_literal_baseline | 144.389 ns | 11.166 ns | 8.363 us | **12.9x faster** | **749.0x faster** |
| optimize_extreme_quantifiers | 6.808 us | 2.147 us | 253.682 ns | **3.2x faster** | 8.5x slower |
| optimize_large_quantifiers | 6.435 us | 3.484 us | 8.368 us | **1.8x faster** | **2.4x faster** |
| optimize_multiple_quantifiers | 206.664 us | 13.230 us | 14.066 us | **15.6x faster** | **1.1x faster** |
| optimize_phone_quantifiers | 178.505 us | 25.363 us | 68.277 us | **7.0x faster** | **2.7x faster** |
| optimize_range_quantifier | 85.114 us | 12.720 us | 32.218 us | **6.7x faster** | **2.5x faster** |
| phone_validation | 285.064 ns | 992.968 ns | 32.025 ns | 3.5x slower | 31.0x slower |
| predefined_digits | 165.232 us | 637.351 ns | 68.556 ns | **259.2x faster** | 9.3x slower |
| predefined_word | 37.992 us | 14.645 us | 56.146 us | **2.6x faster** | **3.8x faster** |
| pure_dfa_dash | - | 1.435 us | - |   |   |
| pure_dfa_dot | - | 149.380 ns | - |   |   |
| pure_dfa_paren | - | 221.976 ns | - |   |   |
| quad_quantifiers | 128.731 us | 4.930 us | 9.368 us | **26.1x faster** | **1.9x faster** |
| quantifier_one_or_more | 145.554 ns | 3.695 ns | 43.580 ns | **39.4x faster** | **11.8x faster** |
| quantifier_zero_or_more | 238.550 ns | 3.811 ns | 49.204 ns | **62.6x faster** | **12.9x faster** |
| quantifier_zero_or_one | 153.599 ns | 4.283 ns | 41.971 ns | **35.9x faster** | **9.8x faster** |
| range_alphanumeric | 12.775 us | 453.867 ns | 62.708 us | **28.1x faster** | **138.2x faster** |
| range_digits | 131.185 us | 621.060 ns | 53.984 ns | **211.2x faster** | 11.5x slower |
| range_lowercase | 13.111 us | 205.847 ns | 43.139 ns | **63.7x faster** | 4.8x slower |
| range_quantifiers | 71.163 us | 24.298 us | 44.022 us | **2.9x faster** | **1.8x faster** |
| required_literal_short | 1.539 us | 178.845 ns | 278.589 ns | **8.6x faster** | **1.6x faster** |
| simple_phone | 836.943 us | 34.550 us | 110.750 us | **24.2x faster** | **3.2x faster** |
| single_quantifier_alpha | 90.701 us | 17.531 us | 50.589 us | **5.2x faster** | **2.9x faster** |
| single_quantifier_digits | 110.550 us | 15.725 us | 13.781 us | **7.0x faster** | 1.1x slower |
| smart_phone_primary | - | 23.085 us | - |   |   |
| sparse_email_findall | 256.148 us | 865.699 ns | 1.468 us | **295.9x faster** | **1.7x faster** |
| sparse_flex_phone_findall | 544.460 us | 1.853 us | 30.814 us | **293.8x faster** | **16.6x faster** |
| sparse_phone_findall | 629.087 us | 1.513 us | 2.392 us | **415.7x faster** | **1.6x faster** |
| sparse_phone_search | 26.055 us | 6.078 us | 1.247 us | **4.3x faster** | 4.9x slower |
| sub_char_class | 924.912 us | 101.630 us | 296.922 us | **9.1x faster** | **2.9x faster** |
| sub_digits | 887.920 us | 109.888 us | 111.554 us | **8.1x faster** | ~same |
| sub_group_date_fmt | 60.763 us | 12.493 us | 45.235 us | **4.9x faster** | **3.6x faster** |
| sub_group_phone_fmt | 87.054 us | 23.934 us | 44.135 us | **3.6x faster** | **1.8x faster** |
| sub_group_word_swap | 54.596 us | 76.102 us | 27.262 us | 1.4x slower | 2.8x slower |
| sub_limited_count | 26.866 us | 11.510 us | 8.690 us | **2.3x faster** | 1.3x slower |
| sub_literal | 6.682 us | 2.386 us | 2.024 us | **2.8x faster** | 1.2x slower |
| sub_whitespace | 100.176 us | 16.923 us | 25.679 us | **5.9x faster** | **1.5x faster** |
| toll_free_complex | 29.009 us | 11.624 us | - | **2.5x faster** |   |
| toll_free_simple | 50.271 us | 8.817 us | - | **5.7x faster** |   |
| triple_quantifiers | 70.449 us | 6.677 us | 13.038 us | **10.6x faster** | **2.0x faster** |
| ultra_dense_quantifiers | 197.035 us | 8.874 us | 48.065 us | **22.2x faster** | **5.4x faster** |
| wildcard_match_any | 4.382 us | 0.952 ns | 42.172 us | **4,604x faster** | **44,305x faster** |

## Summary

**Mojo vs Python:** 74 wins, 2 losses out of 76 benchmarks (97% win rate)
  - Geometric mean speedup: **19.01x**

**Mojo vs Rust:** 55 wins, 16 losses out of 71 common benchmarks (77% win rate)
  - Geometric mean speedup: **2.61x**
