| Benchmark | Mojo (ms) | Python (ms) | Rust (ms) | vs Python | vs Rust |
|-----------|-----------|-------------|-----------|-----------|---------|
| alternation_common_prefix           | 0.000007 |    0.000547 |    0.001854 |     75.5x |  255.9x |
| alternation_quantifiers             | 0.035321 |    0.489585 |    0.069565 |     13.9x |    2.0x |
| alternation_simple                  | 0.000003 |    0.000301 |    0.000020 |     93.7x |    6.2x |
| anchor_start                        | 0.000005 |    0.000339 |    0.000031 |     72.3x |    6.7x |
| complex_email                       | 0.003731 |    0.037064 |           - |      9.9x |         |
| complex_group_5_children            | 0.000041 |    0.000883 |    0.000063 |     21.4x |    1.5x |
| complex_number                      | 0.009512 |    0.159805 |           - |     16.8x |         |
| datetime_quantifiers                | 0.031873 |    0.109464 |    0.065831 |      3.4x |    2.1x |
| deep_nested_groups_depth4           | 0.000014 |    0.000379 |    0.000028 |     26.2x |    1.9x |
| dense_quantifiers                   | 0.032941 |    0.256674 |    0.021631 |      7.8x |    0.7x |
| dfa_digits_only                     | 0.096780 |    1.475895 |    0.054834 |     15.3x |    0.6x |
| dfa_dot_phone                       | 0.096010 |    1.436735 |    0.046611 |     15.0x |    0.5x |
| dfa_paren_phone                     | 0.010724 |    0.080414 |    0.012085 |      7.5x |    1.1x |
| dfa_simple_phone                    | 0.087436 |    1.490457 |    0.061031 |     17.0x |    0.7x |
| dual_quantifiers                    | 0.018034 |    0.141045 |    0.016627 |      7.8x |    0.9x |
| flexible_datetime                   | 0.051562 |    0.112842 |    0.033228 |      2.2x |    0.6x |
| flexible_phone                      | 0.062644 |    3.413087 |    0.205540 |     54.5x |    3.3x |
| group_alternation                   | 0.000003 |    0.000384 |    0.000050 |    123.7x |   16.0x |
| grouped_quantifiers                 | 0.026095 |    0.145508 |    0.010661 |      5.6x |    0.4x |
| is_match_alphanumeric               | 0.000001 |    0.022264 |    0.000013 |  18288.1x |   10.7x |
| is_match_digits                     | 0.000002 |    0.011394 |    0.000033 |   6311.9x |   18.5x |
| is_match_lowercase                  | 0.000001 |    0.014647 |    0.000014 |  11678.8x |   10.9x |
| is_match_predefined_digits          | 0.000001 |    0.031321 |    0.000016 |  24155.8x |   12.6x |
| is_match_predefined_word            | 0.000001 |    0.034199 |    0.000015 |  27221.9x |   11.7x |
| large_8_alternations                | 0.000054 |    0.000691 |    0.000088 |     12.8x |    1.6x |
| literal_heavy_alternation           | 0.000075 |    0.001196 |    0.000084 |     15.9x |    1.1x |
| literal_match_long                  | 0.004576 |    0.013881 |    0.003485 |      3.0x |    0.8x |
| literal_match_short                 | 0.000469 |    0.001096 |    0.000392 |      2.3x |    0.8x |
| literal_prefix_long                 | 0.001376 |    0.066937 |    0.024374 |     48.6x |   17.7x |
| literal_prefix_short                | 0.000129 |    0.000722 |    0.000225 |      5.6x |    1.7x |
| match_all_digits                    | 0.003773 |    2.464576 |           - |    653.2x |         |
| match_all_simple                    | 0.004602 |    0.048548 |    0.008049 |     10.5x |    1.7x |
| mixed_range_quantifiers             | 0.018002 |    0.126202 |    0.005266 |      7.0x |    0.3x |
| multi_format_phone                  | 0.067873 |    7.384705 |    0.162659 |    108.8x |    2.4x |
| nanpa_findall                       | 0.008329 |    0.030105 |    0.011408 |      3.6x |    1.4x |
| nanpa_match_first                   | 0.000019 |    0.000257 |    0.000075 |     13.5x |    3.9x |
| nanpa_search                        | 0.000250 |    0.000368 |    0.000049 |      1.5x |    0.2x |
| national_phone_validation           | 0.033063 |    0.758234 |    0.065229 |     22.9x |    2.0x |
| no_literal_baseline                 | 0.000006 |    0.000500 |    0.006798 |     78.0x | 1060.0x |
| optimize_extreme_quantifiers        | 0.002007 |    0.010219 |    0.000228 |      5.1x |    0.1x |
| optimize_large_quantifiers          | 0.002858 |    0.007304 |    0.009638 |      2.6x |    3.4x |
| optimize_multiple_quantifiers       | 0.050998 |    0.317536 |    0.020859 |      6.2x |    0.4x |
| optimize_phone_quantifiers          | 0.033437 |    0.160340 |    0.040922 |      4.8x |    1.2x |
| optimize_range_quantifier           | 0.011402 |    0.121677 |    0.029285 |     10.7x |    2.6x |
| phone_validation                    | 0.000997 |    0.000605 |    0.000025 |      0.6x |    0.0x |
| predefined_digits                   | 0.000324 |    0.381956 |    0.000058 |   1177.6x |    0.2x |
| predefined_word                     | 0.014372 |    0.070110 |    0.050321 |      4.9x |    3.5x |
| pure_dfa_dash                       | 0.000995 |           - |           - |           |         |
| pure_dfa_dot                        | 0.000106 |           - |           - |           |         |
| pure_dfa_paren                      | 0.000196 |           - |           - |           |         |
| quad_quantifiers                    | 0.023139 |    0.112981 |    0.011142 |      4.9x |    0.5x |
| quantifier_one_or_more              | 0.000003 |    0.000176 |    0.000054 |     54.5x |   16.6x |
| quantifier_zero_or_more             | 0.000003 |    0.000182 |    0.000049 |     54.4x |   14.7x |
| quantifier_zero_or_one              | 0.000003 |    0.000260 |    0.000049 |     78.8x |   15.0x |
| range_alphanumeric                  | 0.002077 |    0.032487 |    0.052020 |     15.6x |   25.0x |
| range_digits                        | 0.000288 |    0.100344 |    0.000063 |    348.7x |    0.2x |
| range_lowercase                     | 0.001657 |    0.015387 |    0.000054 |      9.3x |    0.0x |
| range_quantifiers                   | 0.018053 |    0.147700 |    0.043307 |      8.2x |    2.4x |
| required_literal_short              | 0.000171 |    0.004958 |    0.000375 |     29.0x |    2.2x |
| simple_phone                        | 0.087369 |    1.610087 |    0.169202 |     18.4x |    1.9x |
| single_quantifier_alpha             | 0.011083 |    0.141457 |    0.041816 |     12.8x |    3.8x |
| single_quantifier_digits            | 0.014850 |    0.110362 |    0.015880 |      7.4x |    1.1x |
| smart_phone_primary                 | 0.086531 |           - |           - |           |         |
| sparse_email_findall                | 0.157667 |    0.343117 |    0.001813 |      2.2x |    0.0x |
| sparse_flex_phone_findall           | 0.001225 |    0.475264 |    0.031423 |    387.9x |   25.6x |
| sparse_phone_findall                | 0.003690 |    0.457766 |    0.002141 |    124.1x |    0.6x |
| sparse_phone_search                 | 0.002770 |    0.048210 |    0.001285 |     17.4x |    0.5x |
| sub_char_class                      | 0.137799 |    1.384432 |    0.294229 |     10.0x |    2.1x |
| sub_digits                          | 0.082827 |    2.304235 |    0.107894 |     27.8x |    1.3x |
| sub_group_date_fmt                  | 0.014180 |    0.084292 |    0.043515 |      5.9x |    3.1x |
| sub_group_phone_fmt                 | 0.017437 |    0.150427 |    0.039236 |      8.6x |    2.3x |
| sub_group_word_swap                 | 0.049490 |    0.057045 |    0.030552 |      1.2x |    0.6x |
| sub_limited_count                   | 0.017480 |    0.020367 |    0.008527 |      1.2x |    0.5x |
| sub_literal                         | 0.003747 |    0.004935 |    0.001769 |      1.3x |    0.5x |
| sub_whitespace                      | 0.015286 |    0.097564 |    0.029016 |      6.4x |    1.9x |
| toll_free_complex                   | 0.008293 |    0.046846 |           - |      5.6x |         |
| toll_free_simple                    | 0.013388 |    0.102655 |           - |      7.7x |         |
| triple_quantifiers                  | 0.019100 |    0.115594 |    0.010795 |      6.1x |    0.6x |
| ultra_dense_quantifiers             | 0.036103 |    0.344414 |    0.043424 |      9.5x |    1.2x |
| wildcard_match_any                  | 0.000001 |    0.005006 |    0.057507 |   8226.8x | 94502.9x |

**vs Python: 75/76 wins (98%)**
**vs Rust: 46/71 wins (64%)**
