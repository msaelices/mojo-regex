# re.sub() Benchmark Comparison (2026-04-12)

Updated after capture group support (PR #108) and optimization pass.

## Results

| Benchmark | Mojo (ms) | Python (ms) | Rust (ms) | vs Python | vs Rust |
|-----------|----------|------------|----------|-----------|---------|
| `sub_literal` | 0.00404 | 0.00467 | 0.00130 | **1.2x faster** | 3.1x slower |
| `sub_digits` | 0.0909 | 0.816 | 0.103 | **9.0x faster** | 1.1x slower |
| `sub_char_class` | 0.138 | 0.932 | 0.178 | **6.8x faster** | **1.3x faster** |
| `sub_whitespace` | 0.0186 | 0.0934 | 0.0235 | **5.0x faster** | **1.3x faster** |
| `sub_limited_count` | 0.0138 | 0.0164 | 0.00746 | **1.2x faster** | 1.8x slower |

## Summary

- **vs Python: 5/5 wins** (1.2x-9.0x faster)
- **vs Rust: 2 wins, 3 losses**

## Changes from previous run

- `sub_digits`: 7.5x -> **9.0x** faster than Python (improved by optimization pass)
- `sub_whitespace`: 3.5x -> **5.0x** faster than Python

## Optimization targets

1. **`sub_literal`**: Mojo's `sub()` still runs match_next for pure literals.
   A fast path detecting `is_exact_literal` and using `String.replace()` or
   SIMD literal scan would close the 3.1x gap vs Rust.
2. **`sub_limited_count`**: Same literal overhead on larger text.
3. **`sub_digits`**: Close to Rust (1.1x). The DFA match_next + string
   building overhead accounts for the gap.
4. **String building**: Pre-allocation helps but a two-pass approach (count
   total output size, then fill) would eliminate all reallocs.
