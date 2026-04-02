# Benchmark Results

Comparison of mojo-regex v0.9.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000205 | 0.000019 | 0.002763 | 10.9x faster | 147.1x faster |
| alternation_quantifiers | 0.548116 | 0.033851 | 0.077938 | 16.2x faster | 2.3x faster |
| alternation_simple | 0.000216 | 0.000006 | 0.000022 | 37.1x faster | 3.7x faster |
| anchor_start | 0.000239 | 0.000010 | 0.000048 | 23.7x faster | 4.8x faster |
| complex_email | 0.015001 | 0.005766 | - | 2.6x faster | - |
| complex_group_5_children | 0.000535 | 0.000094 | 0.000080 | 5.7x faster | 1.2x slower |
| complex_number | 0.096042 | 0.014874 | - | 6.5x faster | - |
| datetime_quantifiers | 0.149279 | 0.041595 | 0.063636 | 3.6x faster | 1.5x faster |
| deep_nested_groups_depth4 | 0.000269 | 0.000047 | 0.000022 | 5.7x faster | 2.2x slower |
| dense_quantifiers | 0.277012 | 0.049089 | 0.020186 | 5.6x faster | 2.4x slower |
| dfa_digits_only | 1.366024 | 0.141156 | 0.065954 | 9.7x faster | 2.1x slower |
| dfa_dot_phone | 1.028099 | 0.134110 | 0.038332 | 7.7x faster | 3.5x slower |
| dfa_paren_phone | 0.054192 | 0.017243 | 0.012261 | 3.1x faster | 1.4x slower |
| dfa_simple_phone | 1.397189 | 0.111576 | 0.062035 | 12.5x faster | 1.8x slower |
| dual_quantifiers | 0.153833 | 0.034622 | 0.018107 | 4.4x faster | 1.9x slower |
| flexible_datetime | 0.125663 | 0.072618 | 0.034419 | 1.7x faster | 2.1x slower |
| flexible_phone | 2.587829 | 0.085225 | 0.165093 | 30.4x faster | 1.9x faster |
| group_alternation | 0.000240 | 0.000006 | 0.000062 | 40.0x faster | 10.3x faster |
| grouped_quantifiers | 0.177344 | 0.038188 | 0.016153 | 4.6x faster | 2.4x slower |
| is_match_alphanumeric | 0.022975 | 0.000004 | 0.000013 | 5529.8x faster | 3.1x faster |
| is_match_digits | 0.018364 | 0.000004 | 0.000028 | 4437.4x faster | 6.7x faster |
| is_match_lowercase | 0.023235 | 0.000006 | 0.000016 | 3658.7x faster | 2.5x faster |
| is_match_predefined_digits | 0.039575 | 0.000004 | 0.000014 | 9542.6x faster | 3.4x faster |
| is_match_predefined_word | 0.041491 | 0.000007 | 0.000018 | 6366.3x faster | 2.8x faster |
| large_8_alternations | 0.000452 | 0.000138 | 0.000060 | 3.3x faster | 2.3x slower |
| literal_heavy_alternation | 0.000539 | 0.000131 | 0.000069 | 4.1x faster | 1.9x slower |
| literal_match_long | 0.009688 | 0.008765 | 0.003100 | 1.1x faster | 2.8x slower |
| literal_match_short | 0.001917 | 0.000611 | 0.000309 | 3.1x faster | 2.0x slower |
| literal_prefix_long | 0.028644 | 0.001355 | 0.032224 | 21.1x faster | 23.8x faster |
| literal_prefix_short | 0.000365 | 0.000162 | 0.000248 | 2.3x faster | 1.5x faster |
| match_all_digits | 1.156175 | 0.003261 | - | 354.5x faster | - |
| match_all_simple | 0.028153 | 0.006819 | 0.006090 | 4.1x faster | 1.1x slower |
| mixed_range_quantifiers | 0.083792 | 0.031456 | 0.004234 | 2.7x faster | 7.4x slower |
| multi_format_phone | 6.741780 | 0.072897 | 0.304144 | 92.5x faster | 4.2x faster |
| national_phone_validation | 0.705109 | 0.045283 | 0.067209 | 15.6x faster | 1.5x faster |
| no_literal_baseline | 0.000199 | 0.000007 | 0.007527 | 28.2x faster | 1065.0x faster |
| optimize_extreme_quantifiers | 0.011433 | 0.001857 | 0.000187 | 6.2x faster | 9.9x slower |
| optimize_large_quantifiers | 0.008836 | 0.004483 | 0.008854 | 2.0x faster | 2.0x faster |
| optimize_multiple_quantifiers | 0.537967 | 0.094062 | 0.018045 | 5.7x faster | 5.2x slower |
| optimize_phone_quantifiers | 0.194558 | 0.033955 | 0.045880 | 5.7x faster | 1.4x faster |
| optimize_range_quantifier | 0.186627 | 0.010034 | 0.027581 | 18.6x faster | 2.7x faster |
| phone_validation | 0.000377 | 0.000019 | 0.000024 | 20.1x faster | 1.3x faster |
| predefined_digits | 0.199526 | 0.000329 | 0.000047 | 606.5x faster | 7.0x slower |
| predefined_word | 0.037938 | 0.015731 | 0.046293 | 2.4x faster | 2.9x faster |
| quad_quantifiers | 0.096664 | 0.032846 | 0.010804 | 2.9x faster | 3.0x slower |
| quantifier_one_or_more | 0.000388 | 0.000006 | 0.000050 | 69.4x faster | 9.0x faster |
| quantifier_zero_or_more | 0.000204 | 0.000007 | 0.000047 | 30.4x faster | 7.1x faster |
| quantifier_zero_or_one | 0.000390 | 0.000007 | 0.000047 | 52.4x faster | 6.4x faster |
| range_alphanumeric | 0.017999 | 0.015931 | 0.047641 | 1.1x faster | 3.0x faster |
| range_digits | 0.124570 | 0.000350 | 0.000057 | 356.0x faster | 6.1x slower |
| range_lowercase | 0.017171 | 0.001836 | 0.000050 | 9.4x faster | 37.1x slower |
| range_quantifiers | 0.178140 | 0.023613 | 0.036654 | 7.5x faster | 1.6x faster |
| required_literal_short | 0.002636 | 0.000190 | 0.000227 | 13.9x faster | 1.2x faster |
| simple_phone | 1.967730 | 0.152060 | 0.160663 | 12.9x faster | ~same |
| single_quantifier_alpha | 0.150912 | 0.015334 | 0.037164 | 9.8x faster | 2.4x faster |
| single_quantifier_digits | 0.114151 | 0.019651 | 0.021230 | 5.8x faster | ~same |
| toll_free_complex | 0.037972 | 0.013105 | - | 2.9x faster | - |
| toll_free_simple | 0.110093 | 0.033758 | - | 3.3x faster | - |
| triple_quantifiers | 0.193418 | 0.028606 | 0.008678 | 6.8x faster | 3.3x slower |
| ultra_dense_quantifiers | 0.318297 | 0.093721 | 0.040502 | 3.4x faster | 2.3x slower |
| wildcard_match_any | 0.006336 | 0.000001 | 0.051336 | 5906.2x faster | 47856.1x faster |

## Summary

**Mojo vs Python:** 61 wins, 0 losses out of 61 benchmarks (100% win rate)

**Mojo vs Rust:** 32 wins, 24 losses out of 56 common benchmarks (57% win rate)

### Where Mojo excels (vs Python)

- **is_match (bool-only):** 3600-9500x faster. O(1) SIMD lookup table check.
- **Simple quantifiers** (`a*`, `a+`, `a?`): 30-69x faster. Inlined DFA dispatch.
- **Character class search/findall** (`[a-z]+`, `\w+`, `\d+`): 9-606x faster.
  SIMD range comparison for contiguous ranges, nibble-based matching for others.
- **Wildcard** (`.*`): 5900+x faster. Constant-time fast path.
- **`.*` prefix/suffix patterns**: `rfind` for last-literal, skip NFA entirely.
- **DFA findall** (phone numbers, quantifiers): 3-13x faster.
- **NFA/LazyDFA patterns** (`flexible_phone`, `multi_format_phone`, `phone_validation`):
  Inlined lazy DFA with unchecked state access, 20-93x faster than Python.

### Remaining gaps (vs Rust)

- DFA findall patterns (dense quantifiers, grouped quantifiers): 2-5x slower.
  Rust's lazy DFA and Aho-Corasick are more efficient for bulk scanning.
- `range_lowercase` (`[a-z]+` match_first on 10K chars): 37x slower. Rust uses
  highly optimized SIMD scanning; Mojo's SIMD range comparison is fast but not
  on par with Rust's mature implementation.
- `optimize_extreme_quantifiers`, `mixed_range_quantifiers`: 7-10x slower.

### Notes

- Rust's `regex` crate is a highly optimized production library using Thompson NFA
  simulation, lazy DFA, and Aho-Corasick multi-pattern matching.
- Python's `re` module is implemented in C with a bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA/PikeVM/LazyDFA architecture with SIMD-optimized
  character class matching. The DFA compiler handles alternation groups, variable-length
  branches, nested groups, and capturing group flattening. The PikeVM provides O(n*m)
  guaranteed matching with first-byte prefiltering. The lazy DFA caches PikeVM state-set
  transitions for O(1) per-byte matching after warmup. SIMD range comparison for
  contiguous byte ranges. Fast paths for `.*` prefix/suffix.
- Benchmarks run with pre-compiled regex, 500ms target runtime, median timing, and
  auto-calibration to reduce noise.
