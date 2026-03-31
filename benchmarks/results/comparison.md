# Benchmark Results

Comparison of mojo-regex v0.8.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000340 | 0.000032 | 0.004313 | 10.8x faster | 136.6x faster |
| alternation_quantifiers | 0.836904 | 3.154854 | 0.074091 | 3.8x slower | 42.6x slower |
| alternation_simple | 0.000824 | 0.000012 | 0.000022 | 69.9x faster | 1.9x faster |
| anchor_start | 0.000891 | 0.000016 | 0.000037 | 57.0x faster | 2.3x faster |
| complex_email | 0.036359 | 0.012515 | - | 2.9x faster | - |
| complex_group_5_children | 0.000848 | 0.003939 | 0.000083 | 4.6x slower | 47.4x slower |
| complex_number | 0.276856 | 0.022084 | - | 12.5x faster | - |
| datetime_quantifiers | 0.147968 | 0.078569 | 0.055201 | 1.9x faster | 1.4x slower |
| deep_nested_groups_depth4 | 0.000574 | 0.002113 | 0.000028 | 3.7x slower | 75.5x slower |
| dense_quantifiers | 0.346685 | 0.123491 | 0.017991 | 2.8x faster | 6.9x slower |
| dfa_digits_only | 2.318826 | 0.367005 | 0.074023 | 6.3x faster | 5.0x slower |
| dfa_dot_phone | 1.627333 | 0.321340 | 0.046718 | 5.1x faster | 6.9x slower |
| dfa_paren_phone | 0.084361 | 0.176939 | 0.015125 | 2.1x slower | 11.7x slower |
| dfa_simple_phone | 1.591163 | 0.321000 | 0.103935 | 5.0x faster | 3.1x slower |
| dual_quantifiers | 0.320311 | 0.039573 | 0.025613 | 8.1x faster | 1.5x slower |
| flexible_datetime | 0.157019 | 0.167457 | 0.037951 | ~same | 4.4x slower |
| flexible_phone | 5.978221 | 6.651533 | 0.225382 | ~same | 29.5x slower |
| group_alternation | 0.000585 | 0.000012 | 0.000061 | 50.3x faster | 5.2x faster |
| grouped_quantifiers | 0.159450 | 0.059039 | 0.015469 | 2.7x faster | 3.8x slower |
| is_match_alphanumeric | 0.020428 | 0.000008 | 0.000020 | 2629.4x faster | 2.5x faster |
| is_match_digits | 0.019850 | 0.000006 | 0.000029 | 3124.4x faster | 4.6x faster |
| is_match_lowercase | 0.020645 | 0.000008 | 0.000012 | 2556.4x faster | 1.5x faster |
| is_match_predefined_digits | 0.054130 | 0.000009 | 0.000025 | 5814.4x faster | 2.7x faster |
| is_match_predefined_word | 0.054919 | 0.000009 | 0.000013 | 6362.2x faster | 1.5x faster |
| large_8_alternations | 0.001079 | 0.000177 | 0.000088 | 6.1x faster | 2.0x slower |
| literal_heavy_alternation | 0.000921 | 0.000259 | 0.000074 | 3.6x faster | 3.5x slower |
| literal_match_long | 0.019510 | 0.024360 | 0.008066 | 1.2x slower | 3.0x slower |
| literal_match_short | 0.002393 | 0.002754 | 0.000643 | 1.2x slower | 4.3x slower |
| literal_prefix_long | 0.051304 | 0.175764 | 0.039019 | 3.4x slower | 4.5x slower |
| literal_prefix_short | 0.000360 | 0.001279 | 0.000502 | 3.6x slower | 2.5x slower |
| match_all_digits | 2.432286 | 0.008131 | - | 299.1x faster | - |
| match_all_simple | 0.032778 | 0.011106 | 0.007179 | 3.0x faster | 1.5x slower |
| mixed_range_quantifiers | 0.137430 | 0.034405 | 0.006462 | 4.0x faster | 5.3x slower |
| multi_format_phone | 8.799562 | 17.845010 | 0.205740 | 2.0x slower | 86.7x slower |
| national_phone_validation | 2.155988 | 0.104847 | 0.092215 | 20.6x faster | ~same |
| no_literal_baseline | 0.000397 | 0.000013 | 0.013719 | 30.2x faster | 1042.1x faster |
| optimize_extreme_quantifiers | 0.015469 | 0.004100 | 0.000220 | 3.8x faster | 18.6x slower |
| optimize_large_quantifiers | 0.008903 | 0.007080 | 0.013844 | 1.3x faster | 2.0x faster |
| optimize_multiple_quantifiers | 0.338077 | 0.159672 | 0.019305 | 2.1x faster | 8.3x slower |
| optimize_phone_quantifiers | 0.192372 | 0.060754 | 0.062450 | 3.2x faster | ~same |
| optimize_range_quantifier | 0.178032 | 0.501264 | 0.043696 | 2.8x slower | 11.5x slower |
| phone_validation | 0.000594 | 0.001383 | 0.000038 | 2.3x slower | 36.7x slower |
| predefined_digits | 0.526099 | 0.000648 | 0.000093 | 811.6x faster | 7.0x slower |
| predefined_word | 0.163169 | 0.000792 | 0.061708 | 205.9x faster | 77.9x faster |
| quad_quantifiers | 0.284823 | 0.078827 | 0.019250 | 3.6x faster | 4.1x slower |
| quantifier_one_or_more | 0.000397 | 0.000012 | 0.000073 | 33.8x faster | 6.2x faster |
| quantifier_zero_or_more | 0.000401 | 0.000011 | 0.000071 | 36.5x faster | 6.5x faster |
| quantifier_zero_or_one | 0.000431 | 0.000010 | 0.000062 | 43.5x faster | 6.3x faster |
| range_alphanumeric | 0.043532 | 0.081697 | 0.076019 | 1.9x slower | ~same |
| range_digits | 0.267342 | 0.000903 | 0.000074 | 296.0x faster | 12.2x slower |
| range_lowercase | 0.028297 | 0.000968 | 0.000078 | 29.2x faster | 12.4x slower |
| range_quantifiers | 0.183795 | 0.045495 | 0.042499 | 4.0x faster | ~same |
| required_literal_short | 0.003745 | 0.158014 | 0.000413 | 42.2x slower | 383.0x slower |
| simple_phone | 3.720227 | 0.363603 | 0.205384 | 10.2x faster | 1.8x slower |
| single_quantifier_alpha | 0.398383 | 0.027814 | 0.041471 | 14.3x faster | 1.5x faster |
| single_quantifier_digits | 0.373708 | 0.043086 | 0.019129 | 8.7x faster | 2.3x slower |
| toll_free_complex | 0.119715 | 0.022289 | - | 5.4x faster | - |
| toll_free_simple | 0.285355 | 0.029087 | - | 9.8x faster | - |
| triple_quantifiers | 0.217553 | 0.036767 | 0.018995 | 5.9x faster | 1.9x slower |
| ultra_dense_quantifiers | 0.495257 | 0.095936 | 0.064204 | 5.2x faster | 1.5x slower |
| wildcard_match_any | 0.011445 | 0.000002 | 0.047496 | 6798.6x faster | 28213.6x faster |

## Summary

**Mojo vs Python:** 46 wins, 15 losses out of 61 benchmarks (75% win rate)

**Mojo vs Rust:** 18 wins, 38 losses out of 56 common benchmarks (32% win rate)

### Where Mojo excels

- **is_match (bool-only):** 2000-6000x faster than Python, 2-6x faster than Rust.
  O(1) single character check via SIMD lookup table.
- **Simple quantifiers** (`a*`, `a+`, `a?`): 17-41x faster than Python, 5-8x faster
  than Rust. Lightweight DFA with inlined dispatch.
- **Character class search/findall** (`[a-z]+`, `\w+`, `\d+`): 29-350x faster than
  Python using nibble-based SIMD matching (two native `pshufb` ops per 32 chars)
  across match_first, match_next, and match_all paths.
- **Wildcard** (`.*`): 4000+x faster than Python. Constant-time fast path.
- **DFA findall** (phone numbers, quantifier patterns): 2-8x faster than Python.
  Capturing groups are flattened into DFA sequences for non-capture operations.
- **Toll-free complex** (`8(?:00|33|...)[2-9]\d{6}`): 1.4x faster than Python.
  DFA compiler handles non-capturing alternation groups (PR #79).

### Where Mojo needs improvement

- **NFA backtracking patterns** (`flexible_phone`, `multi_format_phone`,
  `grouped_quantifiers`): 2-4x slower than Python, 19-83x slower than Rust.
  Rust uses a lazy DFA that avoids backtracking entirely.
- **Complex NFA patterns** (`deep_nested_groups_depth4`, `complex_group_5_children`):
  5-7x slower than Python due to recursive matching overhead.
- **`dfa_paren_phone`:** 4x slower than Python. DFA findall for multi-element
  patterns with literals between quantified ranges still has overhead.
- **`required_literal_short`:** 20+x slower than Python. The `.*` prefix forces
  full-text scanning in the NFA engine.

### Notes

- Rust's `regex` crate is a highly optimized production library using Thompson NFA
  simulation, lazy DFA, and Aho-Corasick multi-pattern matching. It represents the
  state-of-the-art in regex performance.
- Python's `re` module is implemented in C and handles backtracking-heavy patterns
  efficiently through its bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA architecture with SIMD-optimized character class
  matching using nibble-based `pshufb` lookups. It excels on DFA-friendly patterns
  and character class operations. The DFA compiler handles non-capturing alternation
  groups and flattens capturing groups for non-capture operations.
- Benchmarks run with pre-compiled regex, 500ms target runtime, median timing, and
  auto-calibration to reduce noise.
