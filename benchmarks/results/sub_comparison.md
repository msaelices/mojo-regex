# re.sub() Benchmark Comparison (2026-04-12)

First baseline run after implementing `sub()` in mojo-regex.

## Results

| Benchmark | Mojo (ms) | Python (ms) | Rust (ms) | vs Python | vs Rust |
|-----------|----------|------------|----------|-----------|---------|
| `sub_literal` | 0.00307 | 0.00379 | 0.00127 | **1.2x faster** | 2.4x slower |
| `sub_digits` | 0.126 | 0.941 | 0.102 | **7.5x faster** | 1.2x slower |
| `sub_char_class` | 0.137 | 1.151 | 0.181 | **8.4x faster** | **1.3x faster** |
| `sub_whitespace` | 0.018 | 0.064 | 0.028 | **3.5x faster** | **1.5x faster** |
| `sub_limited_count` | 0.014 | 0.017 | 0.007 | **1.2x faster** | 2.1x slower |

## Summary

- **vs Python: 5/5 wins** (1.2x-8.4x faster)
- **vs Rust: 2 wins, 3 losses**

## Analysis

Mojo wins decisively against Python on all patterns. Against Rust:

- **Mojo wins** on `sub_char_class` and `sub_whitespace` where the regex
  engine (DFA/lazy DFA) drives the match cost and Mojo's SIMD character
  class matchers pay off.
- **Rust wins** on `sub_literal` (2.4x) and `sub_limited_count` (2.1x)
  where Rust's `replace_all` has a dedicated literal fast path that
  bypasses the full regex machinery. Also wins on `sub_digits` (1.2x).

## Optimization targets

1. **`sub_literal`**: Mojo's `sub()` still runs the full regex match_next
   loop for pure literals. A fast path detecting `is_exact_literal` and
   using `String.replace()` or SIMD literal scan would close the 2.4x gap.
2. **`sub_limited_count`**: Same literal overhead on larger text. The
   `count` parameter is not yet wired to limit early (it replaces all,
   then the benchmark name is misleading - should use count=5).
3. **`sub_digits`**: Close to Rust (1.2x). The DFA match_next + string
   building overhead accounts for the gap. Pre-sizing the result string
   more aggressively could help.
4. **String building**: `result += slice` in a loop reallocates. A
   two-pass approach (count total output size, then fill) would eliminate
   reallocs entirely.
