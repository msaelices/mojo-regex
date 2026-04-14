# Benchmark Results

Comparison of mojo-regex v0.11.0-dev, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000124 | 0.000009 | 0.001908 | **13.4x faster** | **206.2x faster** |
| alternation_quantifiers | 0.273589 | 0.033817 | 0.054233 | **8.1x faster** | **1.6x faster** |
| alternation_simple | 0.000127 | 0.000003 | 0.000025 | **38.6x faster** | **7.5x faster** |
| anchor_start | 0.000140 | 0.000005 | 0.000045 | **29.0x faster** | **9.4x faster** |
| complex_email | 0.009337 | 0.003392 | - | **2.8x faster** |  |
| complex_group_5_children | 0.000222 | 0.000040 | 0.000113 | **5.6x faster** | **2.9x faster** |
| complex_number | 0.068044 | 0.014967 | - | **4.5x faster** |  |
| datetime_quantifiers | 0.068094 | 0.025591 | 0.065426 | **2.7x faster** | **2.6x faster** |
| deep_nested_groups_depth4 | 0.000147 | 0.000014 | 0.000045 | **10.3x faster** | **3.1x faster** |
| dense_quantifiers | 0.133244 | 0.030628 | 0.019781 | **4.4x faster** | 1.5x slower |
| dfa_digits_only | 0.647129 | 0.111858 | 0.089880 | **5.8x faster** | 1.2x slower |
| dfa_dot_phone | 0.828119 | 0.087032 | 0.030818 | **9.5x faster** | 2.8x slower |
| dfa_paren_phone | 0.039437 | 0.014125 | 0.018509 | **2.8x faster** | **1.3x faster** |
| dfa_simple_phone | 0.714900 | 0.080135 | 0.058684 | **8.9x faster** | 1.4x slower |
| dual_quantifiers | 0.070080 | 0.018237 | 0.015491 | **3.8x faster** | 1.2x slower |
| flexible_datetime | 0.077629 | 0.054082 | 0.031093 | **1.4x faster** | 1.7x slower |
| flexible_phone | 1.410522 | 0.072119 | 0.158720 | **19.6x faster** | **2.2x faster** |
| group_alternation | 0.000131 | 0.000003 | 0.000066 | **40.3x faster** | **20.4x faster** |
| grouped_quantifiers | 0.077498 | 0.019181 | 0.011972 | **4.0x faster** | 1.6x slower |
| is_match_alphanumeric | 0.012416 | 0.000001 | 0.000012 | **9338.8x faster** | **9.0x faster** |
| is_match_digits | 0.008639 | 0.000001 | 0.000023 | **6691.6x faster** | **17.6x faster** |
| is_match_lowercase | 0.009655 | 0.000002 | 0.000012 | **4910.2x faster** | **6.2x faster** |
| is_match_predefined_digits | 0.023189 | 0.000001 | 0.000012 | **17451.7x faster** | **8.7x faster** |
| is_match_predefined_word | 0.021505 | 0.000001 | 0.000011 | **16114.6x faster** | **8.6x faster** |
| large_8_alternations | 0.000269 | 0.000057 | 0.000057 | **4.7x faster** | ~same |
| literal_heavy_alternation | 0.000322 | 0.000069 | 0.000061 | **4.7x faster** | 1.1x slower |
| literal_match_long | 0.007319 | 0.006666 | 0.003550 | **1.1x faster** | 1.9x slower |
| literal_match_short | 0.000814 | 0.000900 | 0.000590 | 1.1x slower | 1.5x slower |
| literal_prefix_long | 0.017142 | 0.001166 | 0.021669 | **14.7x faster** | **18.6x faster** |
| literal_prefix_short | 0.000145 | 0.000123 | 0.000215 | **1.2x faster** | **1.7x faster** |
| match_all_digits | 0.842092 | 0.003453 | - | **243.9x faster** |  |
| match_all_simple | 0.012556 | 0.005711 | 0.004855 | **2.2x faster** | 1.2x slower |
| mixed_range_quantifiers | 0.060380 | 0.024108 | 0.003818 | **2.5x faster** | 6.3x slower |
| multi_format_phone | 3.089563 | 0.057190 | 0.155617 | **54.0x faster** | **2.7x faster** |
| nanpa_findall | 0.024383 | 0.005167 | 0.009524 | **4.7x faster** | **1.8x faster** |
| nanpa_match_first | 0.000205 | 0.000014 | 0.000046 | **14.6x faster** | **3.3x faster** |
| nanpa_search | 0.000225 | 0.000247 | 0.000049 | 1.1x slower | 5.0x slower |
| national_phone_validation | 0.669799 | 0.028834 | 0.118369 | **23.2x faster** | **4.1x faster** |
| no_literal_baseline | 0.000143 | 0.000006 | 0.005191 | **22.9x faster** | **834.3x faster** |
| optimize_extreme_quantifiers | 0.006630 | 0.002114 | 0.000160 | **3.1x faster** | 13.2x slower |
| optimize_large_quantifiers | 0.005455 | 0.002833 | 0.008860 | **1.9x faster** | **3.1x faster** |
| optimize_multiple_quantifiers | 0.250735 | 0.047903 | 0.018615 | **5.2x faster** | 2.6x slower |
| optimize_phone_quantifiers | 0.099363 | 0.024414 | 0.040415 | **4.1x faster** | **1.7x faster** |
| optimize_range_quantifier | 0.079128 | 0.010111 | 0.029222 | **7.8x faster** | **2.9x faster** |
| phone_validation | 0.000426 | 0.000023 | 0.000020 | **18.6x faster** | 1.1x slower |
| predefined_digits | 0.136652 | 0.000270 | 0.000071 | **505.7x faster** | 3.8x slower |
| predefined_word | 0.023482 | 0.014363 | 0.042624 | **1.6x faster** | **3.0x faster** |
| quad_quantifiers | 0.072582 | 0.023313 | 0.010481 | **3.1x faster** | 2.2x slower |
| quantifier_one_or_more | 0.000151 | 0.000003 | 0.000089 | **46.9x faster** | **27.7x faster** |
| quantifier_zero_or_more | 0.000153 | 0.000003 | 0.000053 | **48.6x faster** | **16.9x faster** |
| quantifier_zero_or_one | 0.000191 | 0.000004 | 0.000053 | **51.8x faster** | **14.5x faster** |
| range_alphanumeric | 0.012820 | 0.002193 | 0.044315 | **5.8x faster** | **20.2x faster** |
| range_digits | 0.124218 | 0.000288 | 0.000055 | **432.0x faster** | 5.2x slower |
| range_lowercase | 0.010667 | 0.001741 | 0.000049 | **6.1x faster** | 35.7x slower |
| range_quantifiers | 0.085729 | 0.016318 | 0.040813 | **5.3x faster** | **2.5x faster** |
| required_literal_short | 0.001434 | 0.000176 | 0.000202 | **8.2x faster** | **1.2x faster** |
| simple_phone | 1.041964 | 0.086128 | 0.164892 | **12.1x faster** | **1.9x faster** |
| single_quantifier_alpha | 0.111869 | 0.010255 | 0.033315 | **10.9x faster** | **3.2x faster** |
| single_quantifier_digits | 0.064301 | 0.018470 | 0.019630 | **3.5x faster** | **1.1x faster** |
| sparse_email_findall | 0.360098 | 0.127997 | 0.001095 | **2.8x faster** | 116.9x slower |
| sparse_flex_phone_findall | 0.361866 | 0.001275 | 0.028929 | **283.8x faster** | **22.7x faster** |
| sparse_phone_findall | 0.383303 | 0.002149 | 0.001943 | **178.4x faster** | 1.1x slower |
| sparse_phone_search | 0.031518 | 0.002754 | 0.001292 | **11.4x faster** | 2.1x slower |
| sub_char_class | 0.882315 | 0.127005 | 0.186030 | **6.9x faster** | **1.5x faster** |
| sub_digits | 0.859977 | 0.106213 | 0.195322 | **8.1x faster** | **1.8x faster** |
| sub_group_date_fmt | 0.066916 | 0.013473 | 0.028620 | **5.0x faster** | **2.1x faster** |
| sub_group_phone_fmt | 0.091636 | 0.019127 | 0.034461 | **4.8x faster** | **1.8x faster** |
| sub_group_word_swap | 0.051766 | 0.052935 | 0.026181 | ~same | 2.0x slower |
| sub_limited_count | 0.018117 | 0.013632 | 0.005507 | **1.3x faster** | 2.5x slower |
| sub_literal | 0.003868 | 0.003013 | 0.001175 | **1.3x faster** | 2.6x slower |
| sub_whitespace | 0.077479 | 0.019172 | 0.024111 | **4.0x faster** | **1.3x faster** |
| toll_free_complex | 0.044535 | 0.007793 | - | **5.7x faster** |  |
| toll_free_simple | 0.051418 | 0.016507 | - | **3.1x faster** |  |
| triple_quantifiers | 0.076995 | 0.017396 | 0.008323 | **4.4x faster** | 2.1x slower |
| ultra_dense_quantifiers | 0.190196 | 0.038239 | 0.034770 | **5.0x faster** | 1.1x slower |
| wildcard_match_any | 0.003195 | 0.000001 | 0.045601 | **4775.3x faster** | **68149.9x faster** |

## Summary

**Mojo vs Python:** 74 wins, 2 losses out of 76 benchmarks (97% win rate)

**Mojo vs Rust:** 43 wins, 28 losses out of 71 common benchmarks (60% win rate)
