# Benchmark Results

Comparison of mojo-regex 0.13.0 (post PRs #140/#143/#144/#145/#146/#147/#148), Python `re`, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, default optimization
- **Python**: CPython 3.12, `re` module (C implementation)
- **Rust**: `regex` crate, `--release` with `-C target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing

## Full comparison

| Benchmark | Python | Mojo | Rust | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 130.921 ns | 10.588 ns | 1.883 us | **12.4x faster** | **177.9x faster** |
| alternation_quantifiers | 408.447 us | 29.521 us | 55.781 us | **13.8x faster** | **1.9x faster** |
| alternation_simple | 123.908 ns | 3.223 ns | 15.495 ns | **38.4x faster** | **4.8x faster** |
| alternation_words | - | - | 21.998 ns |  |  |
| anchor_end | - | - | 21.371 ns |  |  |
| anchor_start | 129.855 ns | 4.845 ns | 28.636 ns | **26.8x faster** | **5.9x faster** |
| complex_email | 10.270 us | 3.074 us | - | **3.3x faster** |  |
| complex_email_extraction | - | - | 342.703 ns |  |  |
| complex_group_5_children | 202.591 ns | 33.036 ns | 63.862 ns | **6.1x faster** | **1.9x faster** |
| complex_number | 77.827 us | 6.213 us | - | **12.5x faster** |  |
| complex_number_extraction | - | - | 57.744 us |  |  |
| datetime_quantifiers | 58.372 us | 36.068 us | 45.130 us | **1.6x faster** | **1.3x faster** |
| deep_nested_groups_depth4 | 184.619 ns | 6.371 ns | 31.873 ns | **29.0x faster** | **5.0x faster** |
| dense_quantifiers | 122.684 us | 6.375 us | 17.458 us | **19.2x faster** | **2.7x faster** |
| dfa_digits_only | 632.848 us | 85.944 us | 49.814 us | **7.4x faster** | 1.7x slower |
| dfa_dot_phone | 625.342 us | 25.397 us | 41.064 us | **24.6x faster** | **1.6x faster** |
| dfa_paren_phone | 37.601 us | 3.983 us | 10.018 us | **9.4x faster** | **2.5x faster** |
| dfa_simple_phone | 674.530 us | 19.990 us | 56.233 us | **33.7x faster** | **2.8x faster** |
| dual_quantifiers | 70.641 us | 16.868 us | 16.274 us | **4.2x faster** | ~equal |
| flexible_datetime | 77.442 us | 11.569 us | 31.949 us | **6.7x faster** | **2.8x faster** |
| flexible_phone | 1.368 ms | 51.657 us | 143.550 us | **26.5x faster** | **2.8x faster** |
| group_alternation | 124.508 ns | 3.034 ns | 46.907 ns | **41.0x faster** | **15.5x faster** |
| group_quantified | - | - | 36.927 us |  |  |
| grouped_quantifiers | 73.842 us | 3.357 us | 8.366 us | **22.0x faster** | **2.5x faster** |
| is_match_alphanumeric | 11.009 us | 1.235 ns | 11.731 ns | **8912.3x faster** | **9.5x faster** |
| is_match_digits | 9.300 us | 1.223 ns | 23.553 ns | **7607.3x faster** | **19.3x faster** |
| is_match_lowercase | 8.765 us | 1.179 ns | 11.561 ns | **7434.2x faster** | **9.8x faster** |
| is_match_predefined_digits | 23.895 us | 1.614 ns | 12.395 ns | **14802.4x faster** | **7.7x faster** |
| is_match_predefined_word | 21.190 us | 1.176 ns | 16.287 ns | **18013.0x faster** | **13.8x faster** |
| large_8_alternations | 271.383 ns | 54.554 ns | 50.212 ns | **5.0x faster** | 1.1x slower |
| literal_heavy_alternation | 303.619 ns | 64.758 ns | 56.122 ns | **4.7x faster** | 1.2x slower |
| literal_match_long | 6.044 us | 387.406 ns | 2.811 us | **15.6x faster** | **7.3x faster** |
| literal_match_short | 720.878 ns | 69.085 ns | 280.957 ns | **10.4x faster** | **4.1x faster** |
| literal_prefix_long | 16.886 us | 1.103 us | 22.859 us | **15.3x faster** | **20.7x faster** |
| literal_prefix_medium | - | - | 2.922 us |  |  |
| literal_prefix_short | 145.387 ns | 86.372 ns | 214.475 ns | **1.7x faster** | **2.5x faster** |
| match_all_digits | 767.612 us | 2.568 us | - | **298.9x faster** |  |
| match_all_pattern | - | - | 41.034 us |  |  |
| match_all_simple | 12.206 us | 4.399 us | 4.903 us | **2.8x faster** | **1.1x faster** |
| mixed_range_quantifiers | 62.236 us | 3.369 us | 3.955 us | **18.5x faster** | **1.2x faster** |
| multi_format_phone | 3.355 ms | 56.674 us | 148.654 us | **59.2x faster** | **2.6x faster** |
| nanpa_findall | 22.552 us | 5.139 us | 9.053 us | **4.4x faster** | **1.8x faster** |
| nanpa_match_first | 252.181 ns | 13.860 ns | 40.279 ns | **18.2x faster** | **2.9x faster** |
| nanpa_search | 212.889 ns | 19.280 ns | 46.527 ns | **11.0x faster** | **2.4x faster** |
| national_phone_validation | 457.786 us | 27.319 us | 43.108 us | **16.8x faster** | **1.6x faster** |
| no_literal_baseline | 139.892 ns | 6.001 ns | 5.069 us | **23.3x faster** | **844.7x faster** |
| optimize_extreme_quantifiers | 7.833 us | 57.580 ns | 158.951 ns | **136.0x faster** | **2.8x faster** |
| optimize_large_quantifiers | 4.281 us | 2.683 us | 8.776 us | **1.6x faster** | **3.3x faster** |
| optimize_multiple_quantifiers | 184.556 us | 8.556 us | 13.220 us | **21.6x faster** | **1.5x faster** |
| optimize_phone_quantifiers | 114.648 us | 20.993 us | 38.549 us | **5.5x faster** | **1.8x faster** |
| optimize_range_quantifier | 90.078 us | 10.442 us | 27.687 us | **8.6x faster** | **2.7x faster** |
| phone_validation | 246.764 ns | 14.362 ns | 17.357 ns | **17.2x faster** | **1.2x faster** |
| predefined_digits | 114.919 us | 201.038 ns | 56.446 ns | **571.6x faster** | 3.6x slower |
| predefined_word | 20.381 us | 19.756 us | 43.442 us | ~equal | **2.2x faster** |
| pure_dfa_dash | - | 74.068 ns | - |  |  |
| pure_dfa_dot | - | 82.826 ns | - |  |  |
| pure_dfa_paren | - | 76.881 ns | - |  |  |
| quad_quantifiers | 77.705 us | 3.357 us | 10.165 us | **23.1x faster** | **3.0x faster** |
| quantifier_one_or_more | 132.994 ns | 3.158 ns | 42.459 ns | **42.1x faster** | **13.4x faster** |
| quantifier_zero_or_more | 161.218 ns | 3.017 ns | 42.008 ns | **53.4x faster** | **13.9x faster** |
| quantifier_zero_or_one | 132.249 ns | 3.013 ns | 43.298 ns | **43.9x faster** | **14.4x faster** |
| range_alphanumeric | 10.993 us | 400.240 ns | 39.385 us | **27.5x faster** | **98.4x faster** |
| range_digits | 83.693 us | 201.643 ns | 65.279 ns | **415.1x faster** | 3.1x slower |
| range_lowercase | 9.625 us | 170.975 ns | 45.214 ns | **56.3x faster** | 3.8x slower |
| range_quantifiers | 74.485 us | 16.049 us | 30.637 us | **4.6x faster** | **1.9x faster** |
| required_literal_long | - | - | 781.430 ns |  |  |
| required_literal_short | 1.391 us | 156.753 ns | 201.375 ns | **8.9x faster** | **1.3x faster** |
| simd_alphanumeric_large | - | - | 51.990 ns |  |  |
| simd_alphanumeric_xlarge | - | - | 51.850 ns |  |  |
| simd_multi_char_class | - | - | 43.088 ns |  |  |
| simd_negated_alphanumeric | - | - | 39.201 ns |  |  |
| simple_phone | 802.904 us | 19.980 us | 106.452 us | **40.2x faster** | **5.3x faster** |
| single_quantifier_alpha | 83.255 us | 8.752 us | 28.365 us | **9.5x faster** | **3.2x faster** |
| single_quantifier_digits | 92.499 us | 13.455 us | 15.104 us | **6.9x faster** | **1.1x faster** |
| smart_phone_primary | - | 20.352 us | - |  |  |
| sparse_email_findall | 255.481 us | 1.102 us | 981.520 ns | **231.8x faster** | 1.1x slower |
| sparse_flex_phone_findall | 345.756 us | 1.228 us | 43.520 us | **281.5x faster** | **35.4x faster** |
| sparse_phone_findall | 366.213 us | 1.479 us | 1.741 us | **247.6x faster** | **1.2x faster** |
| sparse_phone_search | 25.257 us | 1.934 us | 1.201 us | **13.1x faster** | 1.6x slower |
| sub_char_class | 1.346 ms | 88.489 us | 186.327 us | **15.2x faster** | **2.1x faster** |
| sub_digits | 955.194 us | 67.036 us | 111.132 us | **14.2x faster** | **1.7x faster** |
| sub_group_date_fmt | 60.867 us | 10.671 us | 26.757 us | **5.7x faster** | **2.5x faster** |
| sub_group_phone_fmt | 82.271 us | 13.686 us | 34.672 us | **6.0x faster** | **2.5x faster** |
| sub_group_word_swap | 39.936 us | 47.943 us | 25.547 us | 1.2x slower | 1.9x slower |
| sub_limited_count | 15.460 us | 9.924 us | 5.422 us | **1.6x faster** | 1.8x slower |
| sub_literal | 3.765 us | 2.099 us | 1.345 us | **1.8x faster** | 1.6x slower |
| sub_whitespace | 70.868 us | 11.418 us | 23.963 us | **6.2x faster** | **2.1x faster** |
| toll_free_complex | 26.430 us | 6.736 us | - | **3.9x faster** |  |
| toll_free_simple | 49.527 us | 7.920 us | - | **6.3x faster** |  |
| triple_quantifiers | 62.760 us | 3.366 us | 7.931 us | **18.6x faster** | **2.4x faster** |
| ultra_dense_quantifiers | 207.470 us | 6.307 us | 52.397 us | **32.9x faster** | **8.3x faster** |
| wildcard_match_any | 4.571 us | 0.838 ns | 38.319 us | **5454.2x faster** | **45718.5x faster** |

## Aggregate

- **Mojo vs Python** (76 shared benches): geomean **24.54x**, Mojo wins 74, Python wins 1.
- **Mojo vs Rust** (71 shared benches): geomean **3.47x**, Mojo wins 59, Rust wins 11.
