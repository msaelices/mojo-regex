# Benchmark Results

Comparison of mojo-regex v0.10.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000826 | 0.000017 | 0.003816 | **47.4x faster** | **218.9x faster** |
| alternation_quantifiers | 0.558568 | 0.113244 | 0.088148 | **4.9x faster** | 1.3x slower |
| alternation_simple | 0.001097 | 0.000005 | 0.000051 | **206.2x faster** | **9.5x faster** |
| anchor_start | 0.000748 | 0.000014 | 0.000088 | **53.7x faster** | **6.3x faster** |
| complex_email | 0.070160 | 0.012547 | - | **5.6x faster** |  |
| complex_group_5_children | 0.001476 | 0.000148 | 0.000104 | **9.9x faster** | 1.4x slower |
| complex_number | 0.461907 | 0.024917 | - | **18.5x faster** |  |
| datetime_quantifiers | 0.455806 | 0.108931 | 0.070875 | **4.2x faster** | 1.5x slower |
| deep_nested_groups_depth4 | 0.000587 | 0.000060 | 0.000079 | **9.9x faster** | **1.3x faster** |
| dense_quantifiers | 0.359791 | 0.088194 | 0.024651 | **4.1x faster** | 3.6x slower |
| dfa_digits_only | 3.773143 | 0.347118 | 0.105233 | **10.9x faster** | 3.3x slower |
| dfa_dot_phone | 4.522031 | 0.206810 | 0.043691 | **21.9x faster** | 4.7x slower |
| dfa_paren_phone | 0.189192 | 0.030942 | 0.029768 | **6.1x faster** | ~same |
| dfa_simple_phone | 3.356700 | 0.218841 | 0.103409 | **15.3x faster** | 2.1x slower |
| dual_quantifiers | 0.424495 | 0.056702 | 0.045129 | **7.5x faster** | 1.3x slower |
| flexible_datetime | 0.596272 | 0.244471 | 0.053651 | **2.4x faster** | 4.6x slower |
| flexible_phone | 9.679496 | 0.200821 | 0.379183 | **48.2x faster** | **1.9x faster** |
| group_alternation | 0.000765 | 0.000007 | 0.000122 | **107.7x faster** | **17.2x faster** |
| grouped_quantifiers | 0.182999 | 0.041133 | 0.013317 | **4.4x faster** | 3.1x slower |
| is_match_alphanumeric | 0.030454 | 0.000006 | 0.000021 | **4984.0x faster** | **3.5x faster** |
| is_match_digits | 0.018994 | 0.000003 | 0.000055 | **6685.3x faster** | **19.3x faster** |
| is_match_lowercase | 0.025201 | 0.000005 | 0.000021 | **5542.7x faster** | **4.5x faster** |
| is_match_predefined_digits | 0.076034 | 0.000003 | 0.000041 | **23456.1x faster** | **12.5x faster** |
| is_match_predefined_word | 0.087704 | 0.000005 | 0.000027 | **17818.7x faster** | **5.4x faster** |
| large_8_alternations | 0.001484 | 0.000116 | 0.000350 | **12.7x faster** | **3.0x faster** |
| literal_heavy_alternation | 0.002165 | 0.000177 | 0.000146 | **12.3x faster** | 1.2x slower |
| literal_match_long | 0.033884 | 0.007668 | 0.008249 | **4.4x faster** | **1.1x faster** |
| literal_match_short | 0.006112 | 0.001561 | 0.000829 | **3.9x faster** | 1.9x slower |
| literal_prefix_long | 0.055659 | 0.003462 | 0.067002 | **16.1x faster** | **19.4x faster** |
| literal_prefix_short | 0.001019 | 0.000258 | 0.000571 | **3.9x faster** | **2.2x faster** |
| match_all_digits | 5.191154 | 0.009146 | - | **567.6x faster** |  |
| match_all_simple | 0.086683 | 0.010259 | 0.009634 | **8.4x faster** | 1.1x slower |
| mixed_range_quantifiers | 0.414676 | 0.131857 | 0.008486 | **3.1x faster** | 15.5x slower |
| multi_format_phone | 14.477114 | 0.326429 | 0.294373 | **44.3x faster** | 1.1x slower |
| national_phone_validation | 1.487162 | 0.080051 | 0.092973 | **18.6x faster** | **1.2x faster** |
| no_literal_baseline | 0.000958 | 0.000015 | 0.010672 | **63.7x faster** | **709.4x faster** |
| optimize_extreme_quantifiers | 0.015186 | 0.003233 | 0.000442 | **4.7x faster** | 7.3x slower |
| optimize_large_quantifiers | 0.007850 | 0.007659 | 0.014534 | ~same | **1.9x faster** |
| optimize_multiple_quantifiers | 0.376304 | 0.119244 | 0.035518 | **3.2x faster** | 3.4x slower |
| optimize_phone_quantifiers | 0.192039 | 0.046933 | 0.106254 | **4.1x faster** | **2.3x faster** |
| optimize_range_quantifier | 0.215721 | 0.022032 | 0.077929 | **9.8x faster** | **3.5x faster** |
| phone_validation | 0.000766 | 0.000052 | 0.000047 | **14.8x faster** | 1.1x slower |
| predefined_digits | 0.722623 | 0.000668 | 0.000127 | **1081.3x faster** | 5.2x slower |
| predefined_word | 0.147209 | 0.025197 | 0.074794 | **5.8x faster** | **3.0x faster** |
| quad_quantifiers | 0.486208 | 0.099670 | 0.025278 | **4.9x faster** | 3.9x slower |
| quantifier_one_or_more | 0.000835 | 0.000022 | 0.000144 | **38.7x faster** | **6.7x faster** |
| quantifier_zero_or_more | 0.000694 | 0.000008 | 0.000110 | **86.3x faster** | **13.7x faster** |
| quantifier_zero_or_one | 0.000675 | 0.000014 | 0.000088 | **49.8x faster** | **6.5x faster** |
| range_alphanumeric | 0.091014 | 0.035849 | 0.078458 | **2.5x faster** | **2.2x faster** |
| range_digits | 0.401415 | 0.002072 | 0.000111 | **193.7x faster** | 18.7x slower |
| range_lowercase | 0.064163 | 0.010008 | 0.000108 | **6.4x faster** | 92.9x slower |
| range_quantifiers | 0.491603 | 0.081977 | 0.050994 | **6.0x faster** | 1.6x slower |
| required_literal_short | 0.008950 | 0.000253 | 0.000529 | **35.3x faster** | **2.1x faster** |
| simple_phone | 5.812477 | 0.428273 | 0.280827 | **13.6x faster** | 1.5x slower |
| single_quantifier_alpha | 0.777377 | 0.023921 | 0.102319 | **32.5x faster** | **4.3x faster** |
| single_quantifier_digits | 0.506991 | 0.036168 | 0.034972 | **14.0x faster** | ~same |
| sparse_email_findall | 0.895117 | 0.223600 | 0.002552 | **4.0x faster** | 87.6x slower |
| sparse_flex_phone_findall | 1.077527 | 0.002449 | 0.081576 | **439.9x faster** | **33.3x faster** |
| sparse_phone_findall | 1.263343 | 0.004458 | 0.004078 | **283.4x faster** | 1.1x slower |
| sparse_phone_search | 0.078280 | 0.006860 | 0.002867 | **11.4x faster** | 2.4x slower |
| sub_char_class | 2.223741 | 0.463600 | 0.315234 | **4.8x faster** | 1.5x slower |
| sub_digits | 4.191351 | 0.615677 | 0.196898 | **6.8x faster** | 3.1x slower |
| sub_group_date_fmt | 0.220319 | 0.032673 | 0.046133 | **6.7x faster** | **1.4x faster** |
| sub_group_phone_fmt | 0.323632 | 0.057244 | 0.064509 | **5.7x faster** | **1.1x faster** |
| sub_group_word_swap | 0.174808 | 0.094988 | 0.050184 | **1.8x faster** | 1.9x slower |
| sub_limited_count | 0.052567 | 0.038343 | 0.009397 | **1.4x faster** | 4.1x slower |
| sub_literal | 0.011989 | 0.009165 | 0.002510 | **1.3x faster** | 3.7x slower |
| sub_whitespace | 0.209092 | 0.057552 | 0.046967 | **3.6x faster** | 1.2x slower |
| toll_free_complex | 0.142056 | 0.017126 | - | **8.3x faster** |  |
| toll_free_simple | 0.210704 | 0.032705 | - | **6.4x faster** |  |
| triple_quantifiers | 0.478265 | 0.044746 | 0.012623 | **10.7x faster** | 3.5x slower |
| ultra_dense_quantifiers | 0.533211 | 0.110316 | 0.067306 | **4.8x faster** | 1.6x slower |
| wildcard_match_any | 0.017084 | 0.000002 | 0.121582 | **11253.3x faster** | **80085.1x faster** |

## Summary

**Mojo vs Python:** 73 wins, 0 losses out of 73 benchmarks (100% win rate)

**Mojo vs Rust:** 33 wins, 35 losses out of 68 common benchmarks (48% win rate)
