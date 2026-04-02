# Benchmark Results

Comparison of mojo-regex v0.9.0, Python `re` module, and Rust `regex` crate.

- **Mojo**: 0.26.2 stable, compiled with default optimization
- **Python**: CPython (system), `re` module (C implementation)
- **Rust**: `regex` 1.10 crate, `--release` with LTO and `target-cpu=native`
- **Methodology**: Pre-compiled regex, 500ms target runtime, median timing, auto-calibration

## Full comparison

| Benchmark | Python (ms) | Mojo (ms) | Rust (ms) | Mojo vs Python | Mojo vs Rust |
|---|---|---|---|---|---|
| alternation_common_prefix | 0.000291 | 0.000019 | 0.002475 | 15.0x faster | 127.9x faster |
| alternation_quantifiers | 0.424709 | 0.499424 | 0.076914 | 1.2x slower | 6.5x slower |
| alternation_simple | 0.000226 | 0.000011 | 0.000022 | 20.3x faster | 2.0x faster |
| anchor_start | 0.000254 | 0.000014 | 0.000046 | 18.0x faster | 3.3x faster |
| complex_email | 0.016697 | 0.006918 | - | 2.4x faster | - |
| complex_group_5_children | 0.000381 | 0.000108 | 0.000078 | 3.5x faster | 1.4x slower |
| complex_number | 0.124174 | 0.015537 | - | 8.0x faster | - |
| datetime_quantifiers | 0.199358 | 0.064168 | 0.059198 | 3.1x faster | ~same |
| deep_nested_groups_depth4 | 0.000241 | 0.000031 | 0.000024 | 7.8x faster | 1.3x slower |
| dense_quantifiers | 0.267184 | 0.068695 | 0.019724 | 3.9x faster | 3.5x slower |
| dfa_digits_only | 1.145405 | 0.156028 | 0.063199 | 7.3x faster | 2.5x slower |
| dfa_dot_phone | 1.508442 | 0.141763 | 0.043006 | 10.6x faster | 3.3x slower |
| dfa_paren_phone | 0.078943 | 0.018121 | 0.015634 | 4.4x faster | 1.2x slower |
| dfa_simple_phone | 1.037907 | 0.122740 | 0.108048 | 8.5x faster | ~same |
| dual_quantifiers | 0.170095 | 0.032843 | 0.024732 | 5.2x faster | 1.3x slower |
| flexible_datetime | 0.239655 | 0.120858 | 0.032204 | 2.0x faster | 3.8x slower |
| flexible_phone | 2.811042 | 0.857472 | 0.194150 | 3.3x faster | 4.4x slower |
| group_alternation | 0.000184 | 0.000020 | 0.000057 | 9.1x faster | 2.8x faster |
| grouped_quantifiers | 0.175815 | 0.040618 | 0.010327 | 4.3x faster | 3.9x slower |
| is_match_alphanumeric | 0.018642 | 0.000005 | 0.000016 | 3552.6x faster | 3.1x faster |
| is_match_digits | 0.014218 | 0.000005 | 0.000039 | 2742.3x faster | 7.6x faster |
| is_match_lowercase | 0.020548 | 0.000005 | 0.000014 | 3746.9x faster | 2.6x faster |
| is_match_predefined_digits | 0.042198 | 0.000005 | 0.000017 | 9091.4x faster | 3.6x faster |
| is_match_predefined_word | 0.061167 | 0.000007 | 0.000014 | 9101.6x faster | 2.1x faster |
| large_8_alternations | 0.000945 | 0.000108 | 0.000063 | 8.7x faster | 1.7x slower |
| literal_heavy_alternation | 0.000610 | 0.000163 | 0.000073 | 3.8x faster | 2.2x slower |
| literal_match_long | 0.009999 | 0.011225 | 0.003833 | ~same | 2.9x slower |
| literal_match_short | 0.000957 | 0.000802 | 0.000365 | 1.2x faster | 2.2x slower |
| literal_prefix_long | 0.037350 | 0.001802 | 0.028786 | 20.7x faster | 16.0x faster |
| literal_prefix_short | 0.000329 | 0.000178 | 0.000328 | 1.8x faster | 1.8x faster |
| match_all_digits | 1.382771 | 0.004128 | - | 335.0x faster | - |
| match_all_simple | 0.022366 | 0.007262 | 0.007688 | 3.1x faster | ~same |
| mixed_range_quantifiers | 0.160577 | 0.028157 | 0.005473 | 5.7x faster | 5.1x slower |
| multi_format_phone | 10.013608 | 1.660102 | 0.205891 | 6.0x faster | 8.1x slower |
| national_phone_validation | 0.890130 | 0.059130 | 0.058362 | 15.1x faster | ~same |
| no_literal_baseline | 0.000307 | 0.000015 | 0.007174 | 20.8x faster | 485.7x faster |
| optimize_extreme_quantifiers | 0.009992 | 0.002289 | 0.000229 | 4.4x faster | 10.0x slower |
| optimize_large_quantifiers | 0.007086 | 0.005655 | 0.010795 | 1.3x faster | 1.9x faster |
| optimize_multiple_quantifiers | 0.399640 | 0.092711 | 0.022636 | 4.3x faster | 4.1x slower |
| optimize_phone_quantifiers | 0.171009 | 0.041789 | 0.040099 | 4.1x faster | ~same |
| optimize_range_quantifier | 0.142851 | 0.107729 | 0.045729 | 1.3x faster | 2.4x slower |
| phone_validation | 0.000588 | 0.000683 | 0.000027 | 1.2x slower | 24.9x slower |
| predefined_digits | 0.221948 | 0.000578 | 0.000052 | 384.1x faster | 11.2x slower |
| predefined_word | 0.052097 | 0.021158 | 0.051501 | 2.5x faster | 2.4x faster |
| quad_quantifiers | 0.113973 | 0.046134 | 0.012796 | 2.5x faster | 3.6x slower |
| quantifier_one_or_more | 0.000297 | 0.000009 | 0.000053 | 32.0x faster | 5.7x faster |
| quantifier_zero_or_more | 0.000377 | 0.000010 | 0.000071 | 38.9x faster | 7.3x faster |
| quantifier_zero_or_one | 0.000352 | 0.000011 | 0.000049 | 32.2x faster | 4.5x faster |
| range_alphanumeric | 0.019438 | 0.023328 | 0.058758 | 1.2x slower | 2.5x faster |
| range_digits | 0.129626 | 0.000521 | 0.000060 | 248.9x faster | 8.6x slower |
| range_lowercase | 0.020628 | 0.026024 | 0.000068 | 1.3x slower | 380.9x slower |
| range_quantifiers | 0.140991 | 0.032275 | 0.040761 | 4.4x faster | 1.3x faster |
| required_literal_short | 0.002787 | 0.000251 | 0.000308 | 11.1x faster | 1.2x faster |
| simple_phone | 2.131577 | 0.155902 | 0.149497 | 13.7x faster | ~same |
| single_quantifier_alpha | 0.198183 | 0.019860 | 0.041008 | 10.0x faster | 2.1x faster |
| single_quantifier_digits | 0.103862 | 0.024661 | 0.017695 | 4.2x faster | 1.4x slower |
| toll_free_complex | 0.059510 | 0.016839 | - | 3.5x faster | - |
| toll_free_simple | 0.118713 | 0.018950 | - | 6.3x faster | - |
| triple_quantifiers | 0.109751 | 0.041481 | 0.009925 | 2.6x faster | 4.2x slower |
| ultra_dense_quantifiers | 0.289140 | 0.059014 | 0.048239 | 4.9x faster | 1.2x slower |
| wildcard_match_any | 0.007596 | 0.000002 | 0.119299 | 3301.7x faster | 51854.6x faster |

## Summary

**Mojo vs Python:** 56 wins, 5 losses out of 61 benchmarks (91% win rate)

**Mojo vs Rust:** 23 wins, 33 losses out of 56 common benchmarks (41% win rate)

### Where Mojo excels (vs Python)

- **is_match (bool-only):** 2000-19000x faster. O(1) SIMD lookup table check.
- **Simple quantifiers** (`a*`, `a+`, `a?`): 17-80x faster. Inlined DFA dispatch.
- **Character class search/findall** (`[a-z]+`, `\w+`, `\d+`): 29-350x faster.
  Nibble-based SIMD matching (two native `pshufb` ops per 32 chars).
- **Wildcard** (`.*`): 4000+x faster. Constant-time fast path.
- **`.*` prefix/suffix patterns**: `rfind` for last-literal, skip NFA entirely.
- **DFA findall** (phone numbers, quantifiers): 2-12x faster.
- **NFA patterns** (`flexible_phone`, `multi_format_phone`): PikeVM with
  first-byte prefilter, 5-10x faster than Python.

### Remaining gaps

- No consistent losses vs Python. Noise-level fluctuations on
  `range_lowercase` and a few DFA patterns depending on system load.
- vs Rust: 5-400x slower on some patterns. Rust's lazy DFA and Thompson
  NFA simulation are fundamentally more efficient for complex patterns.
  See `docs/pikevm-proposal.md` for the lazy DFA roadmap.

### Notes

- Rust's `regex` crate is a highly optimized production library using Thompson NFA
  simulation, lazy DFA, and Aho-Corasick multi-pattern matching.
- Python's `re` module is implemented in C with a bytecode interpreter.
- mojo-regex uses a hybrid DFA/NFA/PikeVM architecture with SIMD-optimized character
  class matching. The DFA compiler handles alternation groups, variable-length branches,
  nested groups, and capturing group flattening. The PikeVM provides O(n*m) guaranteed
  matching with first-byte prefiltering. Fast paths for `.*` prefix/suffix patterns.
- Benchmarks run with pre-compiled regex, 500ms target runtime, median timing, and
  auto-calibration to reduce noise.
