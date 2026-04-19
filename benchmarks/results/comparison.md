# Benchmark Results

Comparison of mojo-regex (post PRs #140/#143/#144), Python `re`, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, default optimization
- **Python**: CPython 3.12, `re` module (C implementation)
- **Rust**: `regex` crate, `--release` with `-C target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing

## Full comparison

| Benchmark | Python | Mojo | Rust | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 264.403 ns | 12.326 ns | 3.953 us | **21x faster** | **321x faster** |
| alternation_quantifiers | 556.531 us | 49.491 us | 107.863 us | **11x faster** | **2.2x faster** |
| alternation_simple | 286.017 ns | 5.383 ns | 25.884 ns | **53x faster** | **4.8x faster** |
| alternation_words | - | - | 41.508 ns |    |    |
| anchor_end | - | - | 41.532 ns |    |    |
| anchor_start | 213.245 ns | 8.117 ns | 57.465 ns | **26x faster** | **7.1x faster** |
| complex_email | 16.640 us | 8.191 us | - | **2.0x faster** |    |
| complex_email_extraction | - | - | 605.691 ns |    |    |
| complex_group_5_children | 401.921 ns | 80.543 ns | 107.265 ns | **5.0x faster** | **1.3x faster** |
| complex_number | 125.218 us | 11.224 us | - | **11x faster** |    |
| complex_number_extraction | - | - | 139.007 us |    |    |
| datetime_quantifiers | 128.595 us | 53.781 us | 91.245 us | **2.4x faster** | **1.7x faster** |
| deep_nested_groups_depth4 | 221.404 ns | 10.351 ns | 42.075 ns | **21x faster** | **4.1x faster** |
| dense_quantifiers | 276.547 us | 10.753 us | 22.911 us | **26x faster** | **2.1x faster** |
| dfa_digits_only | 1.376 ms | 155.784 us | 71.988 us | **8.8x faster** | 2.2x slower |
| dfa_dot_phone | 1.298 ms | 64.011 us | 67.797 us | **20x faster** | **1.1x faster** |
| dfa_paren_phone | 70.818 us | 6.550 us | 23.280 us | **11x faster** | **3.6x faster** |
| dfa_simple_phone | 1.574 ms | 33.403 us | 86.957 us | **47x faster** | **2.6x faster** |
| dual_quantifiers | 216.160 us | 40.848 us | 22.736 us | **5.3x faster** | 1.8x slower |
| flexible_datetime | 180.503 us | 17.899 us | 71.304 us | **10x faster** | **4.0x faster** |
| flexible_phone | 2.882 ms | 90.297 us | 248.750 us | **32x faster** | **2.8x faster** |
| group_alternation | 221.840 ns | 7.872 ns | 84.653 ns | **28x faster** | **11x faster** |
| group_quantified | - | - | 74.030 us |    |    |
| grouped_quantifiers | 160.509 us | 7.049 us | 17.364 us | **23x faster** | **2.5x faster** |
| is_match_alphanumeric | 23.260 us | 2.062 ns | 19.086 ns | **11,283x faster** | **9.3x faster** |
| is_match_digits | 17.992 us | 2.164 ns | 38.830 ns | **8,316x faster** | **18x faster** |
| is_match_lowercase | 18.398 us | 3.156 ns | 25.678 ns | **5,829x faster** | **8.1x faster** |
| is_match_predefined_digits | 45.671 us | 2.106 ns | 24.395 ns | **21,689x faster** | **12x faster** |
| is_match_predefined_word | 48.920 us | 3.057 ns | 22.635 ns | **16,003x faster** | **7.4x faster** |
| large_8_alternations | 602.047 ns | 83.467 ns | 103.621 ns | **7.2x faster** | **1.2x faster** |
| literal_heavy_alternation | 713.112 ns | 86.818 ns | 99.742 ns | **8.2x faster** | **1.1x faster** |
| literal_match_long | 12.147 us | 10.373 us | 5.674 us | **1.2x faster** | 1.8x slower |
| literal_match_short | 1.489 us | 742.691 ns | 639.523 ns | **2.0x faster** | 1.2x slower |
| literal_prefix_long | 37.577 us | 3.281 us | 48.944 us | **11x faster** | **15x faster** |
| literal_prefix_medium | - | - | 3.596 us |    |    |
| literal_prefix_short | 323.820 ns | 163.112 ns | 356.285 ns | **2.0x faster** | **2.2x faster** |
| match_all_digits | 1.402 ms | 7.701 us | - | **182x faster** |    |
| match_all_pattern | - | - | 78.393 us |    |    |
| match_all_simple | 29.522 us | 8.201 us | 10.193 us | **3.6x faster** | **1.2x faster** |
| mixed_range_quantifiers | 138.298 us | 8.492 us | 5.969 us | **16x faster** | 1.4x slower |
| multi_format_phone | 6.331 ms | 150.229 us | 369.736 us | **42x faster** | **2.5x faster** |
| nanpa_findall | 37.791 us | 8.390 us | 13.984 us | **4.5x faster** | **1.7x faster** |
| nanpa_match_first | 260.117 ns | 23.974 ns | 95.193 ns | **11x faster** | **4.0x faster** |
| nanpa_search | 414.230 ns | 33.640 ns | 84.607 ns | **12x faster** | **2.5x faster** |
| national_phone_validation | 789.663 us | 47.730 us | 68.774 us | **17x faster** | **1.4x faster** |
| no_literal_baseline | 239.498 ns | 10.180 ns | 8.327 us | **24x faster** | **818x faster** |
| optimize_extreme_quantifiers | 15.323 us | 2.697 us | 350.136 ns | **5.7x faster** | 7.7x slower |
| optimize_large_quantifiers | 10.100 us | 4.743 us | 14.549 us | **2.1x faster** | **3.1x faster** |
| optimize_multiple_quantifiers | 323.469 us | 20.902 us | 29.334 us | **15x faster** | **1.4x faster** |
| optimize_phone_quantifiers | 214.129 us | 36.075 us | 61.391 us | **5.9x faster** | **1.7x faster** |
| optimize_range_quantifier | 174.210 us | 17.416 us | 50.976 us | **10x faster** | **2.9x faster** |
| phone_validation | 412.038 ns | 315.419 ns | 31.907 ns | **1.3x faster** | 9.9x slower |
| predefined_digits | 213.673 us | 873.464 ns | 68.962 ns | **245x faster** | 12.7x slower |
| predefined_word | 48.996 us | 22.492 us | 83.677 us | **2.2x faster** | **3.7x faster** |
| pure_dfa_dash | - | 1.505 us | - |    |    |
| pure_dfa_dot | - | 214.916 ns | - |    |    |
| pure_dfa_paren | - | 362.454 ns | - |    |    |
| quad_quantifiers | 164.902 us | 5.735 us | 20.969 us | **29x faster** | **3.7x faster** |
| quantifier_one_or_more | 258.630 ns | 5.229 ns | 94.792 ns | **49x faster** | **18x faster** |
| quantifier_zero_or_more | 250.981 ns | 5.204 ns | 69.611 ns | **48x faster** | **13x faster** |
| quantifier_zero_or_one | 263.979 ns | 7.612 ns | 86.915 ns | **35x faster** | **11x faster** |
| range_alphanumeric | 19.410 us | 631.817 ns | 85.043 us | **31x faster** | **135x faster** |
| range_digits | 181.070 us | 596.310 ns | 81.049 ns | **304x faster** | 7.4x slower |
| range_lowercase | 17.352 us | 368.021 ns | 84.313 ns | **47x faster** | 4.4x slower |
| range_quantifiers | 162.222 us | 28.179 us | 51.449 us | **5.8x faster** | **1.8x faster** |
| required_literal_long | - | - | 1.445 us |    |    |
| required_literal_short | 3.548 us | 266.851 ns | 450.399 ns | **13x faster** | **1.7x faster** |
| simd_alphanumeric_large | - | - | 92.311 ns |    |    |
| simd_alphanumeric_xlarge | - | - | 83.095 ns |    |    |
| simd_multi_char_class | - | - | 101.532 ns |    |    |
| simd_negated_alphanumeric | - | - | 84.284 ns |    |    |
| simple_phone | 1.839 ms | 34.965 us | 238.230 us | **53x faster** | **6.8x faster** |
| single_quantifier_alpha | 159.466 us | 16.839 us | 57.365 us | **9.5x faster** | **3.4x faster** |
| single_quantifier_digits | 146.672 us | 24.138 us | 27.762 us | **6.1x faster** | **1.2x faster** |
| smart_phone_primary | - | 33.384 us | - |    |    |
| sparse_email_findall | 397.052 us | 1.331 us | 2.306 us | **298x faster** | **1.7x faster** |
| sparse_flex_phone_findall | 819.068 us | 2.813 us | 58.359 us | **291x faster** | **21x faster** |
| sparse_phone_findall | 710.015 us | 2.401 us | 2.866 us | **296x faster** | **1.2x faster** |
| sparse_phone_search | 53.727 us | 6.044 us | 2.198 us | **8.9x faster** | 2.7x slower |
| sub_char_class | 1.692 ms | 147.189 us | 433.766 us | **11x faster** | **2.9x faster** |
| sub_digits | 1.918 ms | 122.019 us | 186.000 us | **16x faster** | **1.5x faster** |
| sub_group_date_fmt | 95.022 us | 17.179 us | 62.268 us | **5.5x faster** | **3.6x faster** |
| sub_group_phone_fmt | 166.928 us | 22.811 us | 58.261 us | **7.3x faster** | **2.6x faster** |
| sub_group_word_swap | 90.370 us | 115.922 us | 59.016 us | 1.3x slower | 2.0x slower |
| sub_limited_count | 28.171 us | 16.199 us | 8.259 us | **1.7x faster** | 2.0x slower |
| sub_literal | 7.092 us | 3.487 us | 1.905 us | **2.0x faster** | 1.8x slower |
| sub_whitespace | 139.113 us | 29.452 us | 54.358 us | **4.7x faster** | **1.8x faster** |
| toll_free_complex | 44.849 us | 17.490 us | - | **2.6x faster** |    |
| toll_free_simple | 117.023 us | 16.794 us | - | **7.0x faster** |    |
| triple_quantifiers | 116.495 us | 7.438 us | 16.147 us | **16x faster** | **2.2x faster** |
| ultra_dense_quantifiers | 406.660 us | 15.137 us | 69.478 us | **27x faster** | **4.6x faster** |
| wildcard_match_any | 5.263 us | 1.275 ns | 89.212 us | **4,128x faster** | **69,974x faster** |

## Summary

**Mojo vs Python:** 75 wins, 1 losses out of 76 benchmarks (99% win rate)
  - Geometric mean speedup: **21.72x**

**Mojo vs Rust:** 57 wins, 14 losses out of 71 common benchmarks (80% win rate)
  - Geometric mean speedup: **2.93x**
