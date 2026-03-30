# mojo-regex Optimization Opportunities

Analysis based on patterns identified in the Mojo stdlib improvement documents
and deep inspection of the mojo-regex codebase.

## ~~Critical: DFA State Transition Table Layout~~ (Investigated, no win)

**Files:** `src/regex/dfa.mojo` lines 209-226

Each `DFAState` uses a fixed `SIMD[DType.int32, 256]` transition table (1024 bytes
per state). For a 100-state DFA, this is 100KB of transition data. A CPU L1 cache
is ~32KB, so a single state lookup causes multiple cache misses.

**Investigated:** Separated transitions into a flat `UnsafePointer[Int32]` table
on `DFAEngine` indexed by `state_id * 256 + char_code`, reducing `DFAState` to
16 bytes. Result: compilation-time benchmarks improved (1.2-1.5x) but the core
matching loop regressed (1.7-2.4x slower) because the original `SIMD[DType.int32, 256]`
in a `RegisterPassable` struct allows the compiler to optimize the indexed access
extremely well. The flat pointer approach introduces an indirection that the
compiler cannot optimize as effectively.

**Conclusion:** The current SIMD-based transition table is already well-optimized
by the Mojo compiler. Alternative representations (sparse, CSR, flat array) add
indirection overhead that outweighs the cache locality benefit.

## ~~High: String Concatenation in Loops~~ (Fixed, PR #61)

**PR:** https://github.com/msaelices/mojo-regex/pull/61

**Pattern from stdlib docs:** `String.replace()` and `String._split()` had
similar allocation overhead. The fix is pre-allocation.

Pre-allocated `String(capacity=...)` before range expansion loops in
`parser.mojo` and `dfa.mojo`. Key benchmark improvements:
- `grouped_quantifiers`: 1.8x faster
- `dfa_digits_only`: 1.8x faster
- `literal_heavy_alternation`: 1.8x faster
- `single_quantifier_alpha`: 2.0x faster
- `match_all_digits`: 1.4x faster

### Remaining: Branch text extraction (dfa.mojo:2814-2819, prefilter.mojo:203-211)
String concatenation in loops extracting literals from AST children.
Fix: Two-pass (count length, then allocate+fill).

## ~~High: Negated Character Class Inefficiency~~ (Fixed)

**File:** `src/regex/dfa.mojo` lines 1702-1713

The negated character class now sets all transitions to `to_state` in bulk via
SIMD assignment (`state.transitions = SIMD[...](to_state)`), then removes only
the excluded characters. For `[^a]`, this is 1 removal instead of 255 additions.

## ~~High: SIMD character class matcher silently disabled~~ (Fixed, PR #62)

**PR:** https://github.com/msaelices/mojo-regex/pull/62

The `range_digits` and `predefined_digits` regressions were caused by a Mojo
0.26.2 compiler bug where `Optional[T]` silently fails for structs containing
`SIMD` fields wider than 64 bytes (https://github.com/modular/modular/issues/6253).
This disabled the SIMD character class matcher for ALL character class patterns.

Workaround: replaced `Optional[CharacterClassSIMD]` with a plain field + Bool flag.

- range_digits: 0.105ms -> 0.040ms (2.6x faster)
- predefined_digits: 0.147ms -> 0.038ms (3.9x faster)

## ~~High: Grouped literal alternations misrouted to NFA~~ (Fixed, PR #64)

**PR:** https://github.com/msaelices/mojo-regex/pull/64

Patterns like `(apple|banana|cherry|date|elderberry|fig|grape|honey)` were
classified as COMPLEX due to nested GROUP wrappers exceeding the optimizer's
depth threshold, routing them to the slow NFA+Prefilter engine instead of
the O(n) DFA engine.

Two fixes: the optimizer now recognizes pure literal alternation trees
regardless of GROUP nesting depth, and the DFA compiler unwraps nested
GROUP wrappers when checking for alternation patterns.

- large_8_alternations: 0.025ms -> 0.0003ms (80x faster, now 3.7x faster than Python)
- literal_heavy_alternation: 0.060ms -> 0.0004ms (167x faster)

## Medium: SIMD First-Match Scalar Fallback

**File:** `src/regex/simd_ops.mojo` lines 150-160

After finding a SIMD chunk with matches, the code uses a scalar loop to find the
first set bit:

```mojo
if matches.reduce_or():
    for i in range(SIMD_WIDTH):  # Scalar scan
        if matches[i]:
            return pos + i
```

Could use `countl_zero` or equivalent to find the first true in the SIMD mask
without looping.

## Medium: SIMD Width Gaps

**File:** `src/regex/simd_ops.mojo` lines 51-53

```mojo
alias USE_SHUFFLE = SIMD_WIDTH == 16 or SIMD_WIDTH == 32
```

AVX-512 systems (SIMD_WIDTH=64) fall back to scalar paths. ARM NEON has
SIMD_WIDTH=16 but different shuffle semantics. Worth adding explicit AVX-512
support and verifying ARM paths.

## Medium: NFA Prefilter Thresholds

**File:** `src/regex/nfa.mojo` lines 40-42

```mojo
alias MIN_PREFIX_LITERAL_LENGTH = 3
alias MIN_REQUIRED_LITERAL_LENGTH = 4
```

These thresholds determine when literal prefiltering kicks in. Patterns with
2-character literals (like `\d{3}-\d{3}` where `-` is literal) miss the
optimization. Lowering to 2/3 would enable prefiltering for more patterns.

## ~~Medium: DFA match_all scanning every position~~ (Fixed, PR #65)

**PR:** https://github.com/msaelices/mojo-regex/pull/65

The DFA `match_all` loop was calling `_try_match_at_position` at every text
position. Now uses the SIMD character class matcher to skip non-matching
positions, only running the full DFA when a candidate is found.

- match_all_digits: 16x faster (1.94ms -> 0.12ms, now 9x faster than Python)
- dfa_digits_only: 8.4x faster (2.85ms -> 0.34ms, now 2.9x faster than Python)
- single_quantifier_digits: 4.5x faster (now 1.7x faster than Python)

## Medium: find_all_matches Append in Closure

**File:** `src/regex/simd_ops.mojo` lines 178-190

The vectorize closure calls `matches.append()` which may trigger reallocation
inside the SIMD loop. A two-pass approach (count matches, pre-allocate, fill)
would eliminate this.

## ~~Medium: NFA Fixed Quantifier Backtracking~~ (Fixed, PR #68)

**PR:** https://github.com/msaelices/mojo-regex/pull/68

For fixed quantifiers like `{3}` where min == max, the backtracking loop
tried counts 3, 2, 1, 0 when only count=3 is valid. Added a fast path that
skips the loop and tries exactly once.

- grouped_quantifiers: 1.75ms -> 0.84ms (2.1x faster)

## ~~Medium: NFA Heap Allocations in Range Matching~~ (Fixed, PR #69)

**PR:** https://github.com/msaelices/mojo-regex/pull/69

Three allocation sources eliminated from NFA hot paths:

1. `chr(ch_code)` + `ch in inner` per character for unrecognized range patterns.
   Replaced with `_byte_in_string()` zero-allocation byte pointer scan.
2. `String(ast.get_value().value())` per RANGE match in `_apply_quantifier_simd`.
   Changed to `StringSlice` ref to avoid heap copy.
3. `text[byte=start:end]` per NFA match candidate in `_match_contains_literal`.
   Replaced with direct byte-level substring search.

- alternation_quantifiers: 1.61ms -> 0.96ms (1.7x faster)
- toll_free_complex: 0.62ms -> 0.34ms (1.8x faster)
- flexible_phone: 4.56ms -> 4.05ms (1.13x faster)

## ~~Low: NFA String Allocations in is_match~~ (Fixed, PR #63)

**PR:** https://github.com/msaelices/mojo-regex/pull/63

Added `is_match_char(ch_code: Int)` to ASTNode for zero-allocation character
matching. The NFA hot loops now use `ast.is_match_char(Int(str_ptr[pos]), ...)`
instead of `ast.is_match(String(str[byte=pos]), ...)`.

- literal_prefix_long: 14.5x faster
- alternation_quantifiers: 4.5x faster
- flexible_phone: 1.5x faster

## Low: MatchList Capacity Tuning

**File:** `src/regex/matching.mojo` line 44

`DEFAULT_RESERVE_SIZE = 8` for initial match list capacity. For `findall` on long
text, this causes multiple doublings. Could estimate based on text length and
pattern type.

## ~~Medium: String-to-StringSlice in SIMD Character Class APIs~~ (Fixed, PR #70)

**PR:** https://github.com/msaelices/mojo-regex/pull/70

`CharacterClassSIMD.__init__`, `get_character_class_matcher`, and `simd_count_char`
all took `String` parameters but only read from them via `unsafe_ptr()` or `ord()`.
Changed to `StringSlice` to avoid heap allocations at API boundaries. Also changed
the range constructor from `(start_char: String, end_char: String)` to
`(start_code: Int, end_code: Int)` eliminating two allocations per range matcher
creation. NFA `_create_range_matcher` no longer wraps `StringSlice` in `String`
just to pass it to `get_character_class_matcher`.

### Remaining: String-to-StringSlice opportunities in other modules

#### High: Prefilter text parameters (matching hot path)

**File:** `src/regex/prefilter.mojo` lines 347-477

The `PrefilterMatcher` trait methods `find_candidates(text: String)` and
`find_first_candidate(text: String)` and their implementations in `MemchrPrefilter`
and `ExactLiteralMatcher` take `String` but only call `.find()` and `len()`.
These are in the matching hot path. Changing to `StringSlice` would avoid
forcing callers to allocate.

#### Medium: Prefilter literal extraction allocations (compilation path)

**File:** `src/regex/prefilter.mojo` lines 186-213

`_extract_from_node()` creates `String(char_value.value())` per single character
(line 186). `_extract_literal_sequence()` returns `String` built by repeated
concatenation (line 210: `result += child_literal`). Could use `StringSlice` for
single-char returns and pre-allocate capacity for sequence building.

#### Medium: DFA _expand_character_range returns String (compilation path)

**File:** `src/regex/dfa.mojo` lines 69-165

Takes `StringSlice` input but returns `String`. Lines 92, 129, 135, 141 create
`String` from slices of comptime constants (`LOWERCASE_LETTERS`, `DIGITS`, etc.)
that already live in static memory. Could return `StringSlice` for those fast
paths if `compile_character_class_with_logic()` accepted `StringSlice`.

#### Low: Public matcher API text parameters (breaking change)

**Files:** `src/regex/matcher.mojo` lines 99-120, 453-580, 796-826

`match_first`, `match_next`, `match_all`, `search`, `findall` all take
`text: String` but only read from it. Changing to `StringSlice` would avoid
caller allocations but is a breaking API change.

## Medium: Dict Lookup per Character for SIMD Matchers

**File:** `src/regex/simd_matchers.mojo` lines 447-513, `src/regex/nfa.mojo` lines 632-720

Every call to `get_digit_matcher()`, `get_word_matcher()`, or `get_whitespace_matcher()`
goes through `_get_range_matchers()` which calls `_RANGE_MATCHERS_GLOBAL.get_or_create_ptr()`
and then does a `Dict` lookup with a `try/except`. This happens on every character in
patterns like `\d{4}`, `\w+`, etc.

**Fix:** Hoist matcher lookups out of per-character loops, or inline the range
checks directly (e.g., `ch >= ord('0') and ch <= ord('9')` for digits, as
`is_match_char` already does in ast.mojo).

## Medium: SIMD Quantifier Threshold Too Conservative

**File:** `src/regex/ast.mojo` lines 374-388

```mojo
if max_matches == -1:  # Unlimited quantifiers like *, +
    return min_matches > 3  # Skips SIMD for \d+, [0-9]+, \w+
```

Patterns like `[0-9]+` (min=1), `\d+`, `\w+` all skip the SIMD quantifier
path and fall back to the scalar loop. Lowering to `min_matches >= 1` for
predefined types (DIGIT, WORD, SPACE) would enable SIMD for these patterns.

## Medium: Prefilter Disabled in match_all

**File:** `src/regex/matcher.mojo` lines 568-571

```mojo
if self.prefilter and not self.literal_info.has_anchors:
    # Disabled for now to isolate performance issue
    pass
```

The prefilter path that skips text positions in `match_all` (used by `findall`)
is completely disabled. Re-enabling would avoid NFA evaluation at every text
position for patterns with required literals.

## ~~High: DFA Character Class Matching Orders of Magnitude Slower Than Rust~~ (Fixed, PR #74, #75)

**PRs:** https://github.com/msaelices/mojo-regex/pull/74, https://github.com/msaelices/mojo-regex/pull/75

Four fixes applied:

1. **`is_match` fast path (O(1), PR #74):** Added `DFAEngine.is_match()` that
   checks if the first character matches the SIMD character class without
   scanning for match boundaries. Mojo `is_match` is competitive with Rust
   (0.2-0.4x).

2. **Nibble-based SIMD scan (PR #75):** Replaced `_dynamic_shuffle` on
   256-byte table (~167ns/chunk) with two 16-byte nibble tables using native
   `pshufb`. Matches 32 chars in 3 SIMD instructions.

3. **Fixed SIMD scan bypass bug (PR #75):** `_try_match_simd` was incorrectly
   classifying `[a-z]+` as a bounded quantifier. Added `_simd_scan_eligible`
   flag computed at compile time.

4. **`@always_inline` on dispatch chain (PR #75):** Inlined
   `CompiledRegex.match_first` -> `HybridMatcher` -> `DFAMatcher` ->
   `DFAEngine` -> `_try_match_simd` -> `count_consecutive_matches`.

   | Benchmark | Before (ms) | After (ms) | Speedup |
   |-----------|------------|-----------|---------|
   | `range_lowercase` (`[a-z]+`) | 0.136 | 0.000375 | 361x |
   | `predefined_word` (`\w+`) | 0.107 | 0.000465 | 230x |
   | `dfa_simple_phone` | 1.838 | 0.459 | 4.0x |
   | `dfa_digits_only` | 0.769 | 0.257 | 3.0x |

   vs-Rust gap for `[a-z]+` went from 8037x to ~22x.

## High: NFA Complex Pattern Backtracking Much Slower Than Rust

**Benchmarked 2026-03-29** (pre-compiled, median timing)

Complex NFA patterns with backtracking are 40-200x slower than Rust:

| Benchmark | Mojo (ms) | Python (ms) | Rust (ms) | Mojo/Rust |
|-----------|----------|------------|----------|-----------|
| `flexible_phone` | 9.01 | 3.06 | 0.224 | 40x |
| `multi_format_phone` | 22.38 | 7.27 | 0.232 | 97x |
| `grouped_quantifiers` | 0.70 | 0.27 | 0.009 | 77x |
| `dfa_paren_phone` | 1.66 | 0.14 | 0.013 | 133x |
| `phone_validation` | 0.0018 | 0.0005 | 0.000025 | 72x |
| `optimize_extreme_quantifiers` | 0.039 | 0.014 | 0.000189 | 209x |

**Root cause:** Rust's `regex` crate uses a lazy DFA (Thompson NFA -> DFA cache)
that avoids backtracking entirely. Mojo's NFA engine uses explicit backtracking
which is exponential in the worst case. Additionally, `dfa_paren_phone` being
0.1x vs Python suggests a possible bug in the DFA compilation for escaped
parenthesis patterns.

**Fix directions:**
- Investigate `dfa_paren_phone` regression vs Python (possible DFA compilation
  bug with `\(` patterns).
- Consider implementing a Thompson NFA or lazy DFA to avoid backtracking.
- Short term: improve NFA backtracking pruning and memoization.

## Patterns from Stdlib Docs Applicable Here

| Stdlib Pattern | mojo-regex Equivalent |
|---|---|
| `String.count()` O(n*m) from repeated find() | DFA literal search already uses SIMD |
| `String._split()` missing pre-allocation | Range expansion missing pre-allocation |
| `List.contains()` scalar vs SIMD | Character class matching already uses SIMD |
| `Set.__eq__()` redundant hash recomputation | Not applicable (no Set usage in hot paths) |
| Missing `@always_inline` | Most hot paths already inlined |
| `normalize_index()` complex dispatch | Avoided by using `unsafe_ptr()` |
| `debug_assert[assert_mode="safe"]` overhead | Avoided by using `unsafe_ptr()` |
