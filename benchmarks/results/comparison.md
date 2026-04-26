# Benchmark Results

Comparison of mojo-regex 0.12.0 (post PRs #140/#143/#144/#145/#146), Python `re`, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, default optimization
- **Python**: CPython 3.12, `re` module (C implementation)
- **Rust**: `regex` crate, `--release` with `-C target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing

## Full comparison

| Benchmark | Python | Mojo | Rust | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 143.093 ns | 8.739 ns | 2.623 us | **16.4x faster** | **300x faster** |
| alternation_quantifiers | 284.706 us | 37.372 us | 89.414 us | **7.6x faster** | **2.4x faster** |
| alternation_simple | 139.310 ns | 3.967 ns | 27.124 ns | **35.1x faster** | **6.8x faster** |
| alternation_words | - | - | 30.666 ns |  |  |
| anchor_end | - | - | 28.327 ns |  |  |
| anchor_start | 220.797 ns | 5.108 ns | 50.817 ns | **43.2x faster** | **9.9x faster** |
| complex_email | 12.023 us | 3.729 us | - | **3.2x faster** |  |
| complex_email_extraction | - | - | 488.003 ns |  |  |
| complex_group_5_children | 227.622 ns | 45.242 ns | 77.750 ns | **5.0x faster** | **1.7x faster** |
| complex_number | 94.695 us | 7.917 us | - | **12.0x faster** |  |
| complex_number_extraction | - | - | 142.553 us |  |  |
| datetime_quantifiers | 75.680 us | 34.069 us | 73.237 us | **2.2x faster** | **2.1x faster** |
| deep_nested_groups_depth4 | 293.432 ns | 7.784 ns | 47.604 ns | **37.7x faster** | **6.1x faster** |
| dense_quantifiers | 155.496 us | 8.570 us | 24.311 us | **18.1x faster** | **2.8x faster** |
| dfa_digits_only | 687.724 us | 214.123 us | 63.870 us | **3.2x faster** | 3.4x slower |
| dfa_dot_phone | 728.399 us | 27.647 us | 50.038 us | **26.3x faster** | **1.8x faster** |
| dfa_paren_phone | 46.525 us | 4.431 us | 27.188 us | **10.5x faster** | **6.1x faster** |
| dfa_simple_phone | 797.759 us | 21.889 us | 79.016 us | **36.4x faster** | **3.6x faster** |
| dual_quantifiers | 75.292 us | 18.029 us | 19.159 us | **4.2x faster** | **1.1x faster** |
| flexible_datetime | 78.170 us | 16.334 us | 60.012 us | **4.8x faster** | **3.7x faster** |
| flexible_phone | 1.763 ms | 59.977 us | 193.999 us | **29.4x faster** | **3.2x faster** |
| group_alternation | 125.485 ns | 4.450 ns | 70.046 ns | **28.2x faster** | **15.7x faster** |
| group_quantified | - | - | 50.728 us |  |  |
| grouped_quantifiers | 162.851 us | 4.335 us | 11.393 us | **37.6x faster** | **2.6x faster** |
| is_match_alphanumeric | 20.403 us | 1.678 ns | 20.164 ns | **12,160x faster** | **12.0x faster** |
| is_match_digits | 8.824 us | 1.979 ns | 50.568 ns | **4,459x faster** | **25.6x faster** |
| is_match_lowercase | 9.415 us | 1.798 ns | 20.133 ns | **5,235x faster** | **11.2x faster** |
| is_match_predefined_digits | 24.607 us | 1.446 ns | 25.839 ns | **17,020x faster** | **17.9x faster** |
| is_match_predefined_word | 22.916 us | 1.383 ns | 22.567 ns | **16,570x faster** | **16.3x faster** |
| large_8_alternations | 292.339 ns | 52.058 ns | 77.081 ns | **5.6x faster** | **1.5x faster** |
| literal_heavy_alternation | 377.308 ns | 65.967 ns | 128.205 ns | **5.7x faster** | **1.9x faster** |
| literal_match_long | 7.145 us | 9.564 us | 3.679 us | 1.3x slower | 2.6x slower |
| literal_match_short | 891.116 ns | 716.639 ns | 534.164 ns | **1.2x faster** | 1.3x slower |
| literal_prefix_long | 18.195 us | 2.135 us | 29.969 us | **8.5x faster** | **14.0x faster** |
| literal_prefix_medium | - | - | 4.172 us |  |  |
| literal_prefix_short | 151.064 ns | 97.948 ns | 379.098 ns | **1.5x faster** | **3.9x faster** |
| match_all_digits | 818.731 us | 3.030 us | - | **270x faster** |  |
| match_all_pattern | - | - | 65.129 us |  |  |
| match_all_simple | 13.214 us | 5.388 us | 7.588 us | **2.5x faster** | **1.4x faster** |
| mixed_range_quantifiers | 64.154 us | 3.792 us | 4.370 us | **16.9x faster** | **1.2x faster** |
| multi_format_phone | 3.417 ms | 59.361 us | 212.262 us | **57.6x faster** | **3.6x faster** |
| nanpa_findall | 28.841 us | 7.388 us | 23.211 us | **3.9x faster** | **3.1x faster** |
| nanpa_match_first | 291.699 ns | 16.006 ns | 77.845 ns | **18.2x faster** | **4.9x faster** |
| nanpa_search | 301.288 ns | 23.799 ns | 75.952 ns | **12.7x faster** | **3.2x faster** |
| national_phone_validation | 579.915 us | 29.285 us | 57.597 us | **19.8x faster** | **2.0x faster** |
| no_literal_baseline | 180.076 ns | 7.204 ns | 7.587 us | **25.0x faster** | **1,053x faster** |
| optimize_extreme_quantifiers | 7.091 us | 609.941 ns | 311.834 ns | **11.6x faster** | 2.0x slower |
| optimize_large_quantifiers | 7.809 us | 3.551 us | 13.190 us | **2.2x faster** | **3.7x faster** |
| optimize_multiple_quantifiers | 236.902 us | 9.567 us | 18.658 us | **24.8x faster** | **2.0x faster** |
| optimize_phone_quantifiers | 102.221 us | 28.518 us | 68.858 us | **3.6x faster** | **2.4x faster** |
| optimize_range_quantifier | 83.611 us | 12.731 us | 44.237 us | **6.6x faster** | **3.5x faster** |
| phone_validation | 272.242 ns | 23.013 ns | 31.958 ns | **11.8x faster** | **1.4x faster** |
| predefined_digits | 109.368 us | 370.572 ns | 80.868 ns | **295x faster** | 4.6x slower |
| predefined_word | 22.321 us | 14.878 us | 56.520 us | **1.5x faster** | **3.8x faster** |
| pure_dfa_dash | - | 204.479 ns | - |  |  |
| pure_dfa_dot | - | 100.129 ns | - |  |  |
| pure_dfa_paren | - | 61.914 ns | - |  |  |
| quad_quantifiers | 78.479 us | 6.935 us | 12.406 us | **11.3x faster** | **1.8x faster** |
| quantifier_one_or_more | 147.971 ns | 4.012 ns | 63.062 ns | **36.9x faster** | **15.7x faster** |
| quantifier_zero_or_more | 200.374 ns | 3.830 ns | 53.528 ns | **52.3x faster** | **14.0x faster** |
| quantifier_zero_or_one | 162.328 ns | 4.429 ns | 58.091 ns | **36.7x faster** | **13.1x faster** |
| range_alphanumeric | 11.955 us | 728.513 ns | 68.006 us | **16.4x faster** | **93.3x faster** |
| range_digits | 105.518 us | 262.909 ns | 65.296 ns | **401x faster** | 4.0x slower |
| range_lowercase | 9.028 us | 236.412 ns | 64.323 ns | **38.2x faster** | 3.7x slower |
| range_quantifiers | 81.893 us | 24.335 us | 44.866 us | **3.4x faster** | **1.8x faster** |
| required_literal_long | - | - | 1.379 us |  |  |
| required_literal_short | 1.568 us | 196.240 ns | 303.513 ns | **8.0x faster** | **1.5x faster** |
| simd_alphanumeric_large | - | - | 97.502 ns |  |  |
| simd_alphanumeric_xlarge | - | - | 82.638 ns |  |  |
| simd_multi_char_class | - | - | 61.445 ns |  |  |
| simd_negated_alphanumeric | - | - | 52.210 ns |  |  |
| simple_phone | 1.290 ms | 23.710 us | 202.575 us | **54.4x faster** | **8.5x faster** |
| single_quantifier_alpha | 86.708 us | 9.671 us | 47.438 us | **9.0x faster** | **4.9x faster** |
| single_quantifier_digits | 75.287 us | 27.576 us | 17.409 us | **2.7x faster** | 1.6x slower |
| smart_phone_primary | - | 41.675 us | - |  |  |
| sparse_email_findall | 273.446 us | 905.243 ns | 2.540 us | **302x faster** | **2.8x faster** |
| sparse_flex_phone_findall | 369.402 us | 1.226 us | 63.478 us | **301x faster** | **51.8x faster** |
| sparse_phone_findall | 512.715 us | 2.101 us | 3.929 us | **244x faster** | **1.9x faster** |
| sparse_phone_search | 30.307 us | 4.900 us | 2.902 us | **6.2x faster** | 1.7x slower |
| sub_char_class | 911.644 us | 108.858 us | 315.988 us | **8.4x faster** | **2.9x faster** |
| sub_digits | 1.812 ms | 95.665 us | 156.545 us | **18.9x faster** | **1.6x faster** |
| sub_group_date_fmt | 64.747 us | 11.729 us | 46.654 us | **5.5x faster** | **4.0x faster** |
| sub_group_phone_fmt | 162.322 us | 23.506 us | 48.232 us | **6.9x faster** | **2.1x faster** |
| sub_group_word_swap | 41.076 us | 60.397 us | 35.658 us | 1.5x slower | 1.7x slower |
| sub_limited_count | 16.752 us | 12.597 us | 10.405 us | **1.3x faster** | 1.2x slower |
| sub_literal | 5.354 us | 2.571 us | 1.542 us | **2.1x faster** | 1.7x slower |
| sub_whitespace | 72.653 us | 14.501 us | 34.937 us | **5.0x faster** | **2.4x faster** |
| toll_free_complex | 54.902 us | 7.308 us | - | **7.5x faster** |  |
| toll_free_simple | 63.613 us | 8.620 us | - | **7.4x faster** |  |
| triple_quantifiers | 86.005 us | 3.678 us | 14.493 us | **23.4x faster** | **3.9x faster** |
| ultra_dense_quantifiers | 199.011 us | 7.148 us | 56.857 us | **27.8x faster** | **8.0x faster** |
| wildcard_match_any | 4.776 us | 0.747 ns | 51.430 us | **6,391x faster** | **68,815x faster** |

## Aggregate

- **Mojo vs Python** (76 shared benches): geomean **20.70x**, Mojo wins 74, Python wins 2.
- **Mojo vs Rust** (71 shared benches): geomean **3.86x**, Mojo wins 59, Rust wins 12.
