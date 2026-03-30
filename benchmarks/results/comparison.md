# Benchmark Results

Comparison of mojo-regex v0.8.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000373 | 0.000029 | 0.003046 | 12.7x faster | 104.1x faster |
| alternation_quantifiers | 0.605675 | 1.863843 | 0.079183 | 3.1x slower | 23.5x slower |
| alternation_simple | 0.000287 | 0.000007 | 0.000029 | 42.3x faster | 4.3x faster |
| anchor_start | 0.000289 | 0.000012 | 0.000057 | 23.3x faster | 4.6x faster |
| complex_email | 0.025541 | 0.013513 | - | 1.9x faster | - |
| complex_group_5_children | 0.000722 | 0.004517 | 0.000086 | 6.3x slower | 52.8x slower |
| complex_number | 0.144333 | 0.039171 | - | 3.7x faster | - |
| datetime_quantifiers | 0.148295 | 0.118489 | 0.054140 | 1.3x faster | 2.2x slower |
| deep_nested_groups_depth4 | 0.000287 | 0.003227 | 0.000030 | 11.3x slower | 109.3x slower |
| dense_quantifiers | 0.298820 | 0.108906 | 0.019524 | 2.7x faster | 5.6x slower |
| dfa_digits_only | 1.754141 | 0.276451 | 0.086510 | 6.3x faster | 3.2x slower |
| dfa_dot_phone | 1.782412 | 0.411637 | 0.044693 | 4.3x faster | 9.2x slower |
| dfa_paren_phone | 0.110849 | 0.580905 | 0.014837 | 5.2x slower | 39.2x slower |
| dfa_simple_phone | 1.699213 | 0.624446 | 0.080248 | 2.7x faster | 7.8x slower |
| dual_quantifiers | 0.220794 | 0.037697 | 0.021629 | 5.9x faster | 1.7x slower |
| flexible_datetime | 0.152551 | 0.147895 | 0.032884 | ~same | 4.5x slower |
| flexible_phone | 3.016897 | 5.333776 | 0.216443 | 1.8x slower | 24.6x slower |
| group_alternation | 0.000262 | 0.000015 | 0.000068 | 17.3x faster | 4.5x faster |
| grouped_quantifiers | 0.194464 | 0.667218 | 0.010367 | 3.4x slower | 64.4x slower |
| is_match_alphanumeric | 0.049896 | 0.000005 | 0.000016 | 9705x faster | 3.2x faster |
| is_match_digits | 0.024520 | 0.000007 | 0.000035 | 3687x faster | 5.3x faster |
| is_match_lowercase | 0.021923 | 0.000005 | 0.000019 | 4356x faster | 3.7x faster |
| is_match_predefined_digits | 0.093488 | 0.000008 | 0.000019 | 11608x faster | 2.3x faster |
| is_match_predefined_word | 0.091435 | 0.000005 | 0.000017 | 18929x faster | 3.5x faster |
| large_8_alternations | 0.000674 | 0.000218 | 0.000084 | 3.1x faster | 2.6x slower |
| literal_heavy_alternation | 0.000745 | 0.000260 | 0.000076 | 2.9x faster | 3.4x slower |
| literal_match_long | 0.019179 | 0.011374 | 0.006251 | 1.7x faster | 1.8x slower |
| literal_match_short | 0.001829 | 0.001061 | 0.000393 | 1.7x faster | 2.7x slower |
| literal_prefix_long | 0.054446 | 0.078406 | 0.026760 | 1.4x slower | 2.9x slower |
| literal_prefix_short | 0.000508 | 0.000585 | 0.000504 | ~same | ~same |
| match_all_digits | 2.520608 | 0.007211 | - | 349.5x faster | - |
| match_all_simple | 0.046282 | 0.013242 | 0.009059 | 3.5x faster | 1.5x slower |
| mixed_range_quantifiers | 0.137471 | 0.033543 | 0.009674 | 4.1x faster | 3.5x slower |
| multi_format_phone | 8.057623 | 16.175393 | 0.204055 | 2.0x slower | 79.3x slower |
| national_phone_validation | 2.103211 | 0.103368 | 0.070097 | 20.3x faster | 1.5x slower |
| no_literal_baseline | 0.000580 | 0.000009 | 0.007675 | 63.3x faster | 838.0x faster |
| optimize_extreme_quantifiers | 0.016449 | 0.042272 | 0.000262 | 2.6x slower | 161.3x slower |
| optimize_large_quantifiers | 0.014008 | 0.008339 | 0.013157 | 1.7x faster | 1.6x faster |
| optimize_multiple_quantifiers | 0.494765 | 0.127121 | 0.018563 | 3.9x faster | 6.8x slower |
| optimize_phone_quantifiers | 0.304395 | 0.099825 | 0.053232 | 3.0x faster | 1.9x slower |
| optimize_range_quantifier | 0.171686 | 0.516406 | 0.035835 | 3.0x slower | 14.4x slower |
| phone_validation | 0.000584 | 0.001708 | 0.000024 | 2.9x slower | 70.1x slower |
| predefined_digits | 0.301450 | 0.001087 | 0.000061 | 277.3x faster | 17.8x slower |
| predefined_word | 0.055927 | 0.000872 | 0.123180 | 64.1x faster | 141.2x faster |
| quad_quantifiers | 0.177353 | 0.054496 | 0.014865 | 3.3x faster | 3.7x slower |
| quantifier_one_or_more | 0.000507 | 0.000008 | 0.000087 | 67.4x faster | 11.5x faster |
| quantifier_zero_or_more | 0.000773 | 0.000009 | 0.000056 | 81.5x faster | 5.9x faster |
| quantifier_zero_or_one | 0.000357 | 0.000009 | 0.000062 | 41.3x faster | 7.1x faster |
| range_alphanumeric | 0.024512 | 0.087686 | 0.080782 | 3.6x slower | ~same |
| range_digits | 0.179738 | 0.000559 | 0.000085 | 321.5x faster | 6.6x slower |
| range_lowercase | 0.022813 | 0.000578 | 0.000073 | 39.4x faster | 7.9x slower |
| range_quantifiers | 0.173386 | 0.035612 | 0.062733 | 4.9x faster | 1.8x faster |
| required_literal_short | 0.006223 | 0.128626 | 0.000324 | 20.7x slower | 397.3x slower |
| simple_phone | 2.260044 | 0.683835 | 0.137201 | 3.3x faster | 5.0x slower |
| single_quantifier_alpha | 0.473663 | 0.018997 | 0.045664 | 24.9x faster | 2.4x faster |
| single_quantifier_digits | 0.251316 | 0.027128 | 0.017446 | 9.3x faster | 1.6x slower |
| toll_free_complex | 0.108215 | 0.594234 | - | 5.5x slower | - |
| toll_free_simple | 0.188793 | 0.035842 | - | 5.3x faster | - |
| triple_quantifiers | 0.170254 | 0.074848 | 0.010785 | 2.3x faster | 6.9x slower |
| ultra_dense_quantifiers | 0.379684 | 0.084153 | 0.046692 | 4.5x faster | 1.8x slower |
| wildcard_match_any | 0.011350 | 0.000001 | 0.123159 | 11216x faster | 121701x faster |

## Summary

**Mojo vs Python:** 46 wins, 15 losses out of 61 benchmarks (75% win rate)

**Mojo vs Rust:** 18 wins, 38 losses out of 56 common benchmarks (32% win rate)

### Where Mojo excels

- **is_match (bool-only):** 3687-18929x faster than Python, 2-5x faster than Rust.
  O(1) single character check via SIMD lookup table.
- **Simple quantifiers** (`a*`, `a+`, `a?`): 41-82x faster than Python, 5-12x faster
  than Rust. Lightweight DFA with inlined dispatch.
- **Character class search/findall** (`[a-z]+`, `\w+`, `\d+`): 39-350x faster than
  Python using nibble-based SIMD matching (two native `pshufb` ops per 32 chars)
  across match_first, match_next, and match_all paths.
- **Wildcard** (`.*`): 11216x faster than Python. Constant-time fast path.
- **DFA findall** (phone numbers, quantifier patterns): 2-6x faster than Python.

### Where Mojo needs improvement

- **NFA backtracking patterns** (`flexible_phone`, `multi_format_phone`,
  `grouped_quantifiers`): 2-3x slower than Python, 25-79x slower than Rust.
  Rust uses a lazy DFA that avoids backtracking entirely.
- **Complex NFA patterns** (`deep_nested_groups_depth4`, `complex_group_5_children`):
  6-11x slower than Python due to recursive matching overhead.
- **`dfa_paren_phone`:** 5x slower than Python. The escaped parenthesis parser bug
  is fixed (PR #77) but the DFA findall path for this multi-element pattern with
  literals between quantified ranges is still slower than Python's C engine.
- **`required_literal_short`:** 21x slower than Python. The NFA prefilter literal
  search has overhead that exceeds Python's optimized C implementation for short texts.

### Notes

- Rust's `regex` crate is a highly optimized production library using Thompson NFA
  simulation, lazy DFA, and Aho-Corasick multi-pattern matching. It represents the
  state-of-the-art in regex performance.
- Python's `re` module is implemented in C and handles backtracking-heavy patterns
  efficiently through its bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA architecture with SIMD-optimized character class
  matching using nibble-based `pshufb` lookups. It excels on DFA-friendly patterns
  and character class operations.
- Benchmarks run with pre-compiled regex, 500ms target runtime, median timing, and
  auto-calibration to reduce noise.
