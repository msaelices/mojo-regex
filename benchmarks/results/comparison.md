# Benchmark Results

Comparison of mojo-regex v0.11.0-dev, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000116 | 0.000007 | 0.001884 | **17.7x faster** | **288.7x faster** |
| alternation_quantifiers | 0.347985 | 0.029993 | 0.054475 | **11.6x faster** | **1.8x faster** |
| alternation_simple | 0.000192 | 0.000004 | 0.000017 | **46.7x faster** | **4.2x faster** |
| anchor_start | 0.000130 | 0.000004 | 0.000030 | **29.4x faster** | **6.8x faster** |
| complex_email | 0.013036 | 0.004533 | - | **2.9x faster** |  |
| complex_group_5_children | 0.000431 | 0.000040 | 0.000064 | **10.9x faster** | **1.6x faster** |
| complex_number | 0.068165 | 0.008112 | - | **8.4x faster** |  |
| datetime_quantifiers | 0.064100 | 0.026431 | 0.043839 | **2.4x faster** | **1.7x faster** |
| deep_nested_groups_depth4 | 0.000137 | 0.000014 | 0.000021 | **9.8x faster** | **1.5x faster** |
| dense_quantifiers | 0.127259 | 0.032913 | 0.017819 | **3.9x faster** | 1.8x slower |
| dfa_digits_only | 0.640491 | 0.083582 | 0.101473 | **7.7x faster** | **1.2x faster** |
| dfa_dot_phone | 0.849646 | 0.098685 | 0.029617 | **8.6x faster** | 3.3x slower |
| dfa_paren_phone | 0.038749 | 0.009767 | 0.013293 | **4.0x faster** | **1.4x faster** |
| dfa_simple_phone | 0.883736 | 0.088589 | 0.056370 | **10.0x faster** | 1.6x slower |
| dual_quantifiers | 0.077237 | 0.017446 | 0.014820 | **4.4x faster** | 1.2x slower |
| flexible_datetime | 0.092466 | 0.048583 | 0.031029 | **1.9x faster** | 1.6x slower |
| flexible_phone | 1.708414 | 0.051821 | 0.144388 | **33.0x faster** | **2.8x faster** |
| group_alternation | 0.000135 | 0.000003 | 0.000048 | **44.8x faster** | **15.9x faster** |
| grouped_quantifiers | 0.075564 | 0.017876 | 0.009725 | **4.2x faster** | 1.8x slower |
| is_match_alphanumeric | 0.011302 | 0.000001 | 0.000014 | **9087.7x faster** | **11.0x faster** |
| is_match_digits | 0.010749 | 0.000001 | 0.000023 | **8816.1x faster** | **18.6x faster** |
| is_match_lowercase | 0.008909 | 0.000001 | 0.000013 | **7086.2x faster** | **10.2x faster** |
| is_match_predefined_digits | 0.031869 | 0.000001 | 0.000012 | **25986.8x faster** | **9.5x faster** |
| is_match_predefined_word | 0.020659 | 0.000001 | 0.000014 | **16944.3x faster** | **11.8x faster** |
| large_8_alternations | 0.000427 | 0.000071 | 0.000048 | **6.0x faster** | 1.5x slower |
| literal_heavy_alternation | 0.000527 | 0.000090 | 0.000056 | **5.9x faster** | 1.6x slower |
| literal_match_long | 0.013041 | 0.004577 | 0.002841 | **2.8x faster** | 1.6x slower |
| literal_match_short | 0.000768 | 0.000486 | 0.000379 | **1.6x faster** | 1.3x slower |
| literal_prefix_long | 0.019329 | 0.001195 | 0.021574 | **16.2x faster** | **18.1x faster** |
| literal_prefix_short | 0.000156 | 0.000161 | 0.000227 | ~same | **1.4x faster** |
| match_all_digits | 0.858963 | 0.002866 | - | **299.7x faster** |  |
| match_all_simple | 0.030502 | 0.006473 | 0.004930 | **4.7x faster** | 1.3x slower |
| mixed_range_quantifiers | 0.083231 | 0.017357 | 0.004170 | **4.8x faster** | 4.2x slower |
| multi_format_phone | 3.147873 | 0.074513 | 0.148533 | **42.2x faster** | **2.0x faster** |
| nanpa_findall | 0.028363 | 0.005271 | 0.008546 | **5.4x faster** | **1.6x faster** |
| nanpa_match_first | 0.000235 | 0.000014 | 0.000040 | **16.5x faster** | **2.8x faster** |
| nanpa_search | 0.000222 | 0.000241 | 0.000048 | 1.1x slower | 5.0x slower |
| national_phone_validation | 0.485502 | 0.031191 | 0.041504 | **15.6x faster** | **1.3x faster** |
| no_literal_baseline | 0.000143 | 0.000006 | 0.005116 | **22.3x faster** | **794.9x faster** |
| optimize_extreme_quantifiers | 0.013082 | 0.002006 | 0.000146 | **6.5x faster** | 13.7x slower |
| optimize_large_quantifiers | 0.004487 | 0.002579 | 0.009355 | **1.7x faster** | **3.6x faster** |
| optimize_multiple_quantifiers | 0.190075 | 0.046401 | 0.016930 | **4.1x faster** | 2.7x slower |
| optimize_phone_quantifiers | 0.103934 | 0.023312 | 0.037681 | **4.5x faster** | **1.6x faster** |
| optimize_range_quantifier | 0.078941 | 0.010527 | 0.027134 | **7.5x faster** | **2.6x faster** |
| phone_validation | 0.000301 | 0.000016 | 0.000017 | **18.3x faster** | **1.1x faster** |
| predefined_digits | 0.109818 | 0.000274 | 0.000042 | **400.8x faster** | 6.6x slower |
| predefined_word | 0.037925 | 0.017449 | 0.039410 | **2.2x faster** | **2.3x faster** |
| quad_quantifiers | 0.085120 | 0.019344 | 0.009606 | **4.4x faster** | 2.0x slower |
| quantifier_one_or_more | 0.000146 | 0.000003 | 0.000041 | **43.2x faster** | **12.2x faster** |
| quantifier_zero_or_more | 0.000212 | 0.000003 | 0.000051 | **70.3x faster** | **17.0x faster** |
| quantifier_zero_or_one | 0.000201 | 0.000003 | 0.000053 | **65.8x faster** | **17.4x faster** |
| range_alphanumeric | 0.013270 | 0.018844 | 0.048902 | 1.4x slower | **2.6x faster** |
| range_digits | 0.099223 | 0.000296 | 0.000064 | **334.7x faster** | 4.6x slower |
| range_lowercase | 0.009068 | 0.003152 | 0.000041 | **2.9x faster** | 77.0x slower |
| range_quantifiers | 0.070637 | 0.017902 | 0.030694 | **3.9x faster** | **1.7x faster** |
| required_literal_short | 0.001301 | 0.000216 | 0.000201 | **6.0x faster** | 1.1x slower |
| simple_phone | 1.093763 | 0.103793 | 0.134604 | **10.5x faster** | **1.3x faster** |
| single_quantifier_alpha | 0.085633 | 0.010959 | 0.031052 | **7.8x faster** | **2.8x faster** |
| single_quantifier_digits | 0.061720 | 0.014020 | 0.018005 | **4.4x faster** | **1.3x faster** |
| sparse_email_findall | 0.336140 | 0.125583 | 0.001013 | **2.7x faster** | 123.9x slower |
| sparse_flex_phone_findall | 0.356181 | 0.001251 | 0.029383 | **284.6x faster** | **23.5x faster** |
| sparse_phone_findall | 0.455701 | 0.002002 | 0.001785 | **227.6x faster** | 1.1x slower |
| sparse_phone_search | 0.027632 | 0.002716 | 0.001407 | **10.2x faster** | 1.9x slower |
| sub_char_class | 1.182288 | 0.126006 | 0.185061 | **9.4x faster** | **1.5x faster** |
| sub_digits | 0.828944 | 0.084176 | 0.118436 | **9.8x faster** | **1.4x faster** |
| sub_group_date_fmt | 0.084778 | 0.013028 | 0.026352 | **6.5x faster** | **2.0x faster** |
| sub_group_phone_fmt | 0.084759 | 0.017367 | 0.037743 | **4.9x faster** | **2.2x faster** |
| sub_group_word_swap | 0.040471 | 0.052647 | 0.027471 | 1.3x slower | 1.9x slower |
| sub_limited_count | 0.021292 | 0.012315 | 0.005317 | **1.7x faster** | 2.3x slower |
| sub_literal | 0.004623 | 0.002804 | 0.001212 | **1.6x faster** | 2.3x slower |
| sub_whitespace | 0.068162 | 0.017517 | 0.026306 | **3.9x faster** | **1.5x faster** |
| toll_free_complex | 0.028126 | 0.008250 | - | **3.4x faster** |  |
| toll_free_simple | 0.051274 | 0.012799 | - | **4.0x faster** |  |
| triple_quantifiers | 0.066789 | 0.018462 | 0.009555 | **3.6x faster** | 1.9x slower |
| ultra_dense_quantifiers | 0.278400 | 0.033418 | 0.034667 | **8.3x faster** | ~same |
| wildcard_match_any | 0.002918 | 0.000001 | 0.039112 | **4357.6x faster** | **58400.5x faster** |

## Summary

**Mojo vs Python:** 73 wins, 3 losses out of 76 benchmarks (96% win rate)

**Mojo vs Rust:** 44 wins, 27 losses out of 71 common benchmarks (61% win rate)
