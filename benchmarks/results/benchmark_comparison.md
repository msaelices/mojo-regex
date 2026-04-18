| Benchmark | Mojo (ms) | Python (ms) | Rust (ms) | vs Python | vs Rust |
|-----------|-----------|-------------|-----------|-----------|---------|
| alternation_common_prefix           | 0.000012 | 0.000264 | 0.003953 |    21.5x |   320.7x |
| alternation_quantifiers             | 0.049491 | 0.556531 | 0.107863 |    11.2x |     2.2x |
| alternation_simple                  | 0.000005 | 0.000286 | 0.000026 |    53.1x |     4.8x |
| alternation_words                   |        - |        - | 0.000042 |          |          |
| anchor_end                          |        - |        - | 0.000042 |          |          |
| anchor_start                        | 0.000008 | 0.000213 | 0.000057 |    26.3x |     7.1x |
| complex_email                       | 0.008191 | 0.016640 |        - |     2.0x |          |
| complex_email_extraction            |        - |        - | 0.000606 |          |          |
| complex_group_5_children            | 0.000081 | 0.000402 | 0.000107 |     5.0x |     1.3x |
| complex_number                      | 0.011224 | 0.125218 |        - |    11.2x |          |
| complex_number_extraction           |        - |        - | 0.139007 |          |          |
| datetime_quantifiers                | 0.053781 | 0.128595 | 0.091245 |     2.4x |     1.7x |
| deep_nested_groups_depth4           | 0.000010 | 0.000221 | 0.000042 |    21.4x |     4.1x |
| dense_quantifiers                   | 0.010753 | 0.276547 | 0.022911 |    25.7x |     2.1x |
| dfa_digits_only                     | 0.155784 | 1.375611 | 0.071988 |     8.8x |     0.5x |
| dfa_dot_phone                       | 0.064011 | 1.298394 | 0.067797 |    20.3x |     1.1x |
| dfa_paren_phone                     | 0.006550 | 0.070818 | 0.023280 |    10.8x |     3.6x |
| dfa_simple_phone                    | 0.033403 | 1.573652 | 0.086957 |    47.1x |     2.6x |
| dual_quantifiers                    | 0.040848 | 0.216160 | 0.022736 |     5.3x |     0.6x |
| flexible_datetime                   | 0.017899 | 0.180503 | 0.071304 |    10.1x |     4.0x |
| flexible_phone                      | 0.090297 | 2.882232 | 0.248750 |    31.9x |     2.8x |
| group_alternation                   | 0.000008 | 0.000222 | 0.000085 |    28.2x |    10.8x |
| group_quantified                    |        - |        - | 0.074030 |          |          |
| grouped_quantifiers                 | 0.007049 | 0.160509 | 0.017364 |    22.8x |     2.5x |
| is_match_alphanumeric               | 0.000002 | 0.023260 | 0.000019 | 11283.0x |     9.3x |
| is_match_digits                     | 0.000002 | 0.017992 | 0.000039 |  8315.8x |    17.9x |
| is_match_lowercase                  | 0.000003 | 0.018398 | 0.000026 |  5828.7x |     8.1x |
| is_match_predefined_digits          | 0.000002 | 0.045671 | 0.000024 | 21689.0x |    11.6x |
| is_match_predefined_word            | 0.000003 | 0.048920 | 0.000023 | 16002.7x |     7.4x |
| large_8_alternations                | 0.000083 | 0.000602 | 0.000104 |     7.2x |     1.2x |
| literal_heavy_alternation           | 0.000087 | 0.000713 | 0.000100 |     8.2x |     1.1x |
| literal_match_long                  | 0.010373 | 0.012147 | 0.005674 |     1.2x |     0.5x |
| literal_match_short                 | 0.000743 | 0.001489 | 0.000640 |     2.0x |     0.9x |
| literal_prefix_long                 | 0.003281 | 0.037577 | 0.048944 |    11.5x |    14.9x |
| literal_prefix_medium               |        - |        - | 0.003596 |          |          |
| literal_prefix_short                | 0.000163 | 0.000324 | 0.000356 |     2.0x |     2.2x |
| match_all_digits                    | 0.007701 | 1.401607 |        - |   182.0x |          |
| match_all_pattern                   |        - |        - | 0.078393 |          |          |
| match_all_simple                    | 0.008201 | 0.029522 | 0.010193 |     3.6x |     1.2x |
| mixed_range_quantifiers             | 0.008492 | 0.138298 | 0.005969 |    16.3x |     0.7x |
| multi_format_phone                  | 0.150229 | 6.330939 | 0.369736 |    42.1x |     2.5x |
| nanpa_findall                       | 0.008390 | 0.037791 | 0.013984 |     4.5x |     1.7x |
| nanpa_match_first                   | 0.000024 | 0.000260 | 0.000095 |    10.8x |     4.0x |
| nanpa_search                        | 0.000034 | 0.000414 | 0.000085 |    12.3x |     2.5x |
| national_phone_validation           | 0.047730 | 0.789663 | 0.068774 |    16.5x |     1.4x |
| no_literal_baseline                 | 0.000010 | 0.000239 | 0.008327 |    23.5x |   818.0x |
| optimize_extreme_quantifiers        | 0.002697 | 0.015323 | 0.000350 |     5.7x |     0.1x |
| optimize_large_quantifiers          | 0.004743 | 0.010100 | 0.014549 |     2.1x |     3.1x |
| optimize_multiple_quantifiers       | 0.020902 | 0.323469 | 0.029334 |    15.5x |     1.4x |
| optimize_phone_quantifiers          | 0.036075 | 0.214129 | 0.061391 |     5.9x |     1.7x |
| optimize_range_quantifier           | 0.017416 | 0.174210 | 0.050976 |    10.0x |     2.9x |
| phone_validation                    | 0.000315 | 0.000412 | 0.000032 |     1.3x |     0.1x |
| predefined_digits                   | 0.000873 | 0.213673 | 0.000069 |   244.6x |     0.1x |
| predefined_word                     | 0.022492 | 0.048996 | 0.083677 |     2.2x |     3.7x |
| pure_dfa_dash                       | 0.001505 |        - |        - |          |          |
| pure_dfa_dot                        | 0.000215 |        - |        - |          |          |
| pure_dfa_paren                      | 0.000362 |        - |        - |          |          |
| quad_quantifiers                    | 0.005735 | 0.164902 | 0.020969 |    28.8x |     3.7x |
| quantifier_one_or_more              | 0.000005 | 0.000259 | 0.000095 |    49.5x |    18.1x |
| quantifier_zero_or_more             | 0.000005 | 0.000251 | 0.000070 |    48.2x |    13.4x |
| quantifier_zero_or_one              | 0.000008 | 0.000264 | 0.000087 |    34.7x |    11.4x |
| range_alphanumeric                  | 0.000632 | 0.019410 | 0.085043 |    30.7x |   134.6x |
| range_digits                        | 0.000596 | 0.181070 | 0.000081 |   303.7x |     0.1x |
| range_lowercase                     | 0.000368 | 0.017352 | 0.000084 |    47.1x |     0.2x |
| range_quantifiers                   | 0.028179 | 0.162222 | 0.051449 |     5.8x |     1.8x |
| required_literal_long               |        - |        - | 0.001445 |          |          |
| required_literal_short              | 0.000267 | 0.003548 | 0.000450 |    13.3x |     1.7x |
| simd_alphanumeric_large             |        - |        - | 0.000092 |          |          |
| simd_alphanumeric_xlarge            |        - |        - | 0.000083 |          |          |
| simd_multi_char_class               |        - |        - | 0.000102 |          |          |
| simd_negated_alphanumeric           |        - |        - | 0.000084 |          |          |
| simple_phone                        | 0.034965 | 1.838891 | 0.238230 |    52.6x |     6.8x |
| single_quantifier_alpha             | 0.016839 | 0.159466 | 0.057365 |     9.5x |     3.4x |
| single_quantifier_digits            | 0.024138 | 0.146672 | 0.027762 |     6.1x |     1.2x |
| smart_phone_primary                 | 0.033384 |        - |        - |          |          |
| sparse_email_findall                | 0.001331 | 0.397052 | 0.002306 |   298.4x |     1.7x |
| sparse_flex_phone_findall           | 0.002813 | 0.819068 | 0.058359 |   291.2x |    20.7x |
| sparse_phone_findall                | 0.002401 | 0.710015 | 0.002866 |   295.7x |     1.2x |
| sparse_phone_search                 | 0.006044 | 0.053727 | 0.002198 |     8.9x |     0.4x |
| sub_char_class                      | 0.147189 | 1.691695 | 0.433766 |    11.5x |     2.9x |
| sub_digits                          | 0.122019 | 1.917956 | 0.186000 |    15.7x |     1.5x |
| sub_group_date_fmt                  | 0.017179 | 0.095022 | 0.062268 |     5.5x |     3.6x |
| sub_group_phone_fmt                 | 0.022811 | 0.166928 | 0.058261 |     7.3x |     2.6x |
| sub_group_word_swap                 | 0.115922 | 0.090370 | 0.059016 |     0.8x |     0.5x |
| sub_limited_count                   | 0.016199 | 0.028171 | 0.008259 |     1.7x |     0.5x |
| sub_literal                         | 0.003487 | 0.007092 | 0.001905 |     2.0x |     0.5x |
| sub_whitespace                      | 0.029452 | 0.139113 | 0.054358 |     4.7x |     1.8x |
| toll_free_complex                   | 0.017490 | 0.044849 |        - |     2.6x |          |
| toll_free_simple                    | 0.016794 | 0.117023 |        - |     7.0x |          |
| triple_quantifiers                  | 0.007438 | 0.116495 | 0.016147 |    15.7x |     2.2x |
| ultra_dense_quantifiers             | 0.015137 | 0.406660 | 0.069478 |    26.9x |     4.6x |
| wildcard_match_any                  | 0.000001 | 0.005263 | 0.089212 |  4128.4x | 69973.8x |
