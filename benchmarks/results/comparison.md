# Benchmark Results

Comparison of mojo-regex 0.12.0 (post PRs #140/#143/#144/#145/#146), Python `re`, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, default optimization
- **Python**: CPython 3.12, `re` module (C implementation)
- **Rust**: `regex` crate, `--release` with `-C target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing

## Full comparison

| Benchmark | Python | Mojo | Rust | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 141.607 ns | 7.910 ns | 2.452 us | **17.9x faster** | **310x faster** |
| alternation_quantifiers | 388.322 us | 30.876 us | 81.697 us | **12.6x faster** | **2.6x faster** |
| alternation_simple | 131.952 ns | 3.703 ns | 23.050 ns | **35.6x faster** | **6.2x faster** |
| alternation_words | - | - | 28.549 ns |  |  |
| anchor_end | - | - | 36.326 ns |  |  |
| anchor_start | 130.307 ns | 5.163 ns | 41.497 ns | **25.2x faster** | **8.0x faster** |
| complex_email | 15.866 us | 6.060 us | - | **2.6x faster** |  |
| complex_email_extraction | - | - | 491.795 ns |  |  |
| complex_group_5_children | 213.043 ns | 56.548 ns | 76.551 ns | **3.8x faster** | **1.4x faster** |
| complex_number | 108.116 us | 9.355 us | - | **11.6x faster** |  |
| complex_number_extraction | - | - | 80.777 us |  |  |
| datetime_quantifiers | 80.287 us | 42.265 us | 60.372 us | **1.9x faster** | **1.4x faster** |
| deep_nested_groups_depth4 | 146.072 ns | 7.148 ns | 26.063 ns | **20.4x faster** | **3.6x faster** |
| dense_quantifiers | 140.921 us | 7.556 us | 20.235 us | **18.7x faster** | **2.7x faster** |
| dfa_digits_only | 948.011 us | 100.410 us | 72.658 us | **9.4x faster** | 1.4x slower |
| dfa_dot_phone | 669.665 us | 32.970 us | 37.917 us | **20.3x faster** | **1.2x faster** |
| dfa_paren_phone | 40.165 us | 4.711 us | 15.148 us | **8.5x faster** | **3.2x faster** |
| dfa_simple_phone | 1.109 ms | 24.268 us | 106.130 us | **45.7x faster** | **4.4x faster** |
| dual_quantifiers | 69.760 us | 32.991 us | 27.726 us | **2.1x faster** | 1.2x slower |
| flexible_datetime | 117.598 us | 12.298 us | 40.839 us | **9.6x faster** | **3.3x faster** |
| flexible_phone | 2.307 ms | 52.456 us | 220.234 us | **44.0x faster** | **4.2x faster** |
| group_alternation | 140.620 ns | 6.827 ns | 60.780 ns | **20.6x faster** | **8.9x faster** |
| group_quantified | - | - | 85.469 us |  |  |
| grouped_quantifiers | 138.428 us | 6.582 us | 10.379 us | **21.0x faster** | **1.6x faster** |
| is_match_alphanumeric | 12.373 us | 1.268 ns | 25.841 ns | **9,756x faster** | **20.4x faster** |
| is_match_digits | 16.222 us | 1.350 ns | 30.914 ns | **12,013x faster** | **22.9x faster** |
| is_match_lowercase | 9.395 us | 2.229 ns | 16.365 ns | **4,214x faster** | **7.3x faster** |
| is_match_predefined_digits | 24.571 us | 1.405 ns | 14.469 ns | **17,490x faster** | **10.3x faster** |
| is_match_predefined_word | 21.982 us | 2.156 ns | 19.207 ns | **10,194x faster** | **8.9x faster** |
| large_8_alternations | 633.771 ns | 48.199 ns | 70.193 ns | **13.1x faster** | **1.5x faster** |
| literal_heavy_alternation | 316.284 ns | 59.406 ns | 104.157 ns | **5.3x faster** | **1.8x faster** |
| literal_match_long | 6.518 us | 8.204 us | 5.047 us | 1.3x slower | 1.6x slower |
| literal_match_short | 763.707 ns | 707.674 ns | 484.959 ns | **1.1x faster** | 1.5x slower |
| literal_prefix_long | 31.617 us | 2.420 us | 28.775 us | **13.1x faster** | **11.9x faster** |
| literal_prefix_medium | - | - | 3.951 us |  |  |
| literal_prefix_short | 154.112 ns | 107.434 ns | 375.663 ns | **1.4x faster** | **3.5x faster** |
| match_all_digits | 799.237 us | 2.978 us | - | **268x faster** |  |
| match_all_pattern | - | - | 64.231 us |  |  |
| match_all_simple | 16.815 us | 4.988 us | 6.944 us | **3.4x faster** | **1.4x faster** |
| mixed_range_quantifiers | 61.606 us | 5.629 us | 7.422 us | **10.9x faster** | **1.3x faster** |
| multi_format_phone | 4.219 ms | 118.313 us | 268.633 us | **35.7x faster** | **2.3x faster** |
| nanpa_findall | 38.161 us | 5.765 us | 18.086 us | **6.6x faster** | **3.1x faster** |
| nanpa_match_first | 195.508 ns | 20.099 ns | 52.807 ns | **9.7x faster** | **2.6x faster** |
| nanpa_search | 311.330 ns | 46.644 ns | 81.090 ns | **6.7x faster** | **1.7x faster** |
| national_phone_validation | 902.455 us | 41.264 us | 75.092 us | **21.9x faster** | **1.8x faster** |
| no_literal_baseline | 149.224 ns | 6.969 ns | 8.313 us | **21.4x faster** | **1,193x faster** |
| optimize_extreme_quantifiers | 6.734 us | 2.267 us | 194.165 ns | **3.0x faster** | 11.7x slower |
| optimize_large_quantifiers | 5.026 us | 2.941 us | 19.393 us | **1.7x faster** | **6.6x faster** |
| optimize_multiple_quantifiers | 210.860 us | 15.637 us | 16.895 us | **13.5x faster** | **1.1x faster** |
| optimize_phone_quantifiers | 168.898 us | 38.102 us | 69.463 us | **4.4x faster** | **1.8x faster** |
| optimize_range_quantifier | 85.662 us | 12.093 us | 47.419 us | **7.1x faster** | **3.9x faster** |
| phone_validation | 285.112 ns | 24.355 ns | 29.576 ns | **11.7x faster** | **1.2x faster** |
| predefined_digits | 115.104 us | 360.921 ns | 52.672 ns | **319x faster** | 6.9x slower |
| predefined_word | 36.971 us | 14.644 us | 52.975 us | **2.5x faster** | **3.6x faster** |
| pure_dfa_dash | - | 1.027 us | - |  |  |
| pure_dfa_dot | - | 110.287 ns | - |  |  |
| pure_dfa_paren | - | 318.067 ns | - |  |  |
| quad_quantifiers | 121.762 us | 3.703 us | 13.876 us | **32.9x faster** | **3.7x faster** |
| quantifier_one_or_more | 143.633 ns | 3.893 ns | 63.021 ns | **36.9x faster** | **16.2x faster** |
| quantifier_zero_or_more | 234.324 ns | 3.340 ns | 86.781 ns | **70.1x faster** | **26.0x faster** |
| quantifier_zero_or_one | 140.537 ns | 5.331 ns | 63.928 ns | **26.4x faster** | **12.0x faster** |
| range_alphanumeric | 11.647 us | 514.655 ns | 43.190 us | **22.6x faster** | **83.9x faster** |
| range_digits | 94.436 us | 220.238 ns | 102.455 ns | **429x faster** | 2.1x slower |
| range_lowercase | 10.900 us | 204.236 ns | 66.930 ns | **53.4x faster** | 3.1x slower |
| range_quantifiers | 80.653 us | 17.422 us | 58.783 us | **4.6x faster** | **3.4x faster** |
| required_literal_long | - | - | 1.609 us |  |  |
| required_literal_short | 1.316 us | 169.119 ns | 270.189 ns | **7.8x faster** | **1.6x faster** |
| simd_alphanumeric_large | - | - | 82.468 ns |  |  |
| simd_alphanumeric_xlarge | - | - | 104.664 ns |  |  |
| simd_multi_char_class | - | - | 57.423 ns |  |  |
| simd_negated_alphanumeric | - | - | 62.537 ns |  |  |
| simple_phone | 937.490 us | 23.488 us | 139.468 us | **39.9x faster** | **5.9x faster** |
| single_quantifier_alpha | 85.786 us | 9.676 us | 43.545 us | **8.9x faster** | **4.5x faster** |
| single_quantifier_digits | 111.419 us | 15.514 us | 17.950 us | **7.2x faster** | **1.2x faster** |
| smart_phone_primary | - | 26.283 us | - |  |  |
| sparse_email_findall | 256.812 us | 910.034 ns | 1.291 us | **282x faster** | **1.4x faster** |
| sparse_flex_phone_findall | 373.358 us | 2.038 us | 40.501 us | **183x faster** | **19.9x faster** |
| sparse_phone_findall | 548.155 us | 1.572 us | 3.049 us | **349x faster** | **1.9x faster** |
| sparse_phone_search | 26.081 us | 2.707 us | 2.226 us | **9.6x faster** | 1.2x slower |
| sub_char_class | 1.012 ms | 119.287 us | 233.859 us | **8.5x faster** | **2.0x faster** |
| sub_digits | 1.014 ms | 96.749 us | 243.053 us | **10.5x faster** | **2.5x faster** |
| sub_group_date_fmt | 60.500 us | 12.326 us | 36.126 us | **4.9x faster** | **2.9x faster** |
| sub_group_phone_fmt | 87.112 us | 17.291 us | 79.305 us | **5.0x faster** | **4.6x faster** |
| sub_group_word_swap | 41.930 us | 89.350 us | 33.119 us | 2.1x slower | 2.7x slower |
| sub_limited_count | 28.407 us | 11.306 us | 8.351 us | **2.5x faster** | 1.4x slower |
| sub_literal | 8.043 us | 4.007 us | 1.506 us | **2.0x faster** | 2.7x slower |
| sub_whitespace | 90.957 us | 21.104 us | 32.046 us | **4.3x faster** | **1.5x faster** |
| toll_free_complex | 36.364 us | 6.865 us | - | **5.3x faster** |  |
| toll_free_simple | 65.116 us | 15.710 us | - | **4.1x faster** |  |
| triple_quantifiers | 75.171 us | 3.919 us | 12.360 us | **19.2x faster** | **3.2x faster** |
| ultra_dense_quantifiers | 203.649 us | 14.094 us | 69.536 us | **14.4x faster** | **4.9x faster** |
| wildcard_match_any | 4.789 us | 0.931 ns | 55.904 us | **5,143x faster** | **60,040x faster** |

## Aggregate

- **Mojo vs Python** (76 shared benches): geomean **20.04x**, Mojo wins 74, Python wins 2.
- **Mojo vs Rust** (71 shared benches): geomean **3.44x**, Mojo wins 59, Rust wins 12.
