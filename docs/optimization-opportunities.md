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

## ~~Medium: NFA Prefilter Thresholds~~ (Already lowered, commit e85442a; re-evaluation needed post-lazy-DFA)

**File:** `src/regex/nfa.mojo` lines 40-45

Current values:
```mojo
comptime MIN_PREFIX_LITERAL_LENGTH = 1
comptime MIN_REQUIRED_LITERAL_LENGTH = 3
```

Commit e85442a (2026-03-30, "Enable NFA literal prefiltering for all
complexity levels") already lowered `MIN_PREFIX_LITERAL_LENGTH` from 3 to 1
and `MIN_REQUIRED_LITERAL_LENGTH` from 4 to 3, and removed the complexity
gate on literal extraction. Further lowering is questionable:

**Post-lazy-DFA trade-off:** When `has_literal_optimization=False`,
`NFAMatcher.match_all` routes to the lazy DFA (`_use_lazy_dfa_for_search`
at `matcher.mojo:249`), which is very fast (see PRs #91/#92). When
`has_literal_optimization=True`, it routes to the backtracking `NFAEngine`
with its literal prefilter. For short, non-selective literals (1-2 chars)
the prefilter may not save enough to beat the lazy DFA's single-pass scan,
so lowering `MIN_REQUIRED_LITERAL_LENGTH` from 3 to 2 could actually be a
regression now. The landscape changed after the lazy DFA landed and these
thresholds may even need *raising* to route more patterns to the lazy DFA.
Needs measurement with a stable benchmark environment before touching.

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

## ~~Medium: Dict Lookup per Character for SIMD Matchers~~ (Fixed)

**File:** `src/regex/nfa.mojo` `_match_digit`, `_match_word`, `_match_space`, `_match_range`

Replaced per-character `get_digit_matcher()`/`get_word_matcher()`/
`get_whitespace_matcher()`/`get_alnum_matcher()`/`get_alpha_matcher()`
calls in `_match_digit` (line 739), `_match_word` (line 779),
`_match_space` (line 707), and `_match_range` (lines 819-870) with
inline range checks matching `ast.is_match_char` (ast.mojo:394-411).
Each call went through `_get_range_matchers()` ->
`_RANGE_MATCHERS_GLOBAL.get_or_create_ptr()` -> `Dict.__getitem__` ->
`try/except` on every character. Now uses direct comptime CHAR_*
constant comparisons.

Note: the `_apply_quantifier_simd` path (lines 1367-1525) still uses
`get_*_matcher()` but calls them once per quantifier evaluation (not per
character), so the Dict lookup is amortized. No change needed there.

## Medium: SIMD Quantifier Threshold Too Conservative

**File:** `src/regex/ast.mojo` lines 374-388

```mojo
if max_matches == -1:  # Unlimited quantifiers like *, +
    return min_matches > 3  # Skips SIMD for \d+, [0-9]+, \w+
```

Patterns like `[0-9]+` (min=1), `\d+`, `\w+` all skip the SIMD quantifier
path and fall back to the scalar loop. Lowering to `min_matches >= 1` for
predefined types (DIGIT, WORD, SPACE) would enable SIMD for these patterns.

## ~~Medium: Prefilter Disabled in match_all~~ (Investigated, no gap in practice)

**File:** `src/regex/matcher.mojo` lines 648-652

```mojo
if self.prefilter and not self.literal_info.has_anchors:
    # Disabled for now to isolate performance issue
    pass
```

**Investigated:** Added a gated re-enable that ran the prefilter scan only
for patterns that (a) are not SIMPLE (DFA `match_all` already has its own
nibble-based SIMD prefilter), and (b) where `NFAEngine.has_literal_optimization`
is false (the NFA's internal prefilter at `nfa.mojo:204-268` is *more*
sophisticated: it retries matching at positions *before* the literal within
a 10-char window, so it handles non-prefix required literals correctly
where a naive `engine.match_next(text, literal_pos)` call would miss them).
Instrumented the gate with a debug print and ran all 65 benchmarks: **zero
firings**.

The remaining gap is patterns with a required literal of length exactly
2 or a prefix literal of length 2. `HybridMatcher.create_prefilter`
accepts literals >= 2 chars; NFA's thresholds are `MIN_PREFIX_LITERAL_LENGTH=3`
and `MIN_REQUIRED_LITERAL_LENGTH=4`. No benchmark pattern has that shape.

**Conclusion:** The right way to widen literal-prefiltering coverage for
`findall` is to lower the NFA thresholds (see next item), which expands
NFA's smarter internal prefilter rather than bolting a dumber one on at
the HybridMatcher level. This item can be removed once the NFA threshold
change lands and the `pass` stub can simply be deleted, since the NFA
engine will handle the same cases end-to-end.

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

## ~~High: NFA Complex Pattern Backtracking Much Slower Than Rust~~ (Fixed, PRs #76, #77, #91, #92)

**PRs:** https://github.com/msaelices/mojo-regex/pull/76, https://github.com/msaelices/mojo-regex/pull/77, https://github.com/msaelices/mojo-regex/pull/91, https://github.com/msaelices/mojo-regex/pull/92

### Fixed issues:

1. **NFA dispatch inlining and backward search (PR #76):** Added `@always_inline`
   to NFAMatcher dispatch chain. Reduced backward search heuristic from 100
   positions to pattern length. Result: 1.4-3x faster on NFA patterns.

2. **Parser/DFA bugs causing silent match failures (PR #77):** Three bugs fixed:
   - Lexer: escaped chars (`\(`, `\.`) stored backslash instead of target char
   - Parser: `-` outside brackets silently dropped
   - DFA compiler: missing start state for `min_matches > 1` sequences

   Many benchmarks (`dfa_paren_phone`, `dfa_simple_phone`, `pure_dfa_dot`,
   `complex_email`) were returning zero matches before these fixes.

### Additional fixes (PRs #78, #79, direct commits):

3. **Nibble-based SIMD scan for search/findall (PR #78):** Applied the
   nibble-based `count_consecutive_matches` and `find_first_nibble_match`
   to `_optimized_simd_search` and `match_all` paths. Result: 90-169x
   faster on character class search/findall (`predefined_digits`, `range_digits`,
   `match_all_digits`).

4. **DFA non-capturing alternation groups (PR #79):** Extended the DFA compiler
   to handle `(?:00|33|44|...)` alternation within sequences. Patterns like
   `8(?:00|33|44|55|66|77|88)[2-9]\d{6}` now use DFA instead of NFA.
   Result: `toll_free_complex` 8.6x faster, now 1.4x faster than Python.

5. **Capturing group flattening:** Patterns with `(...)` capturing groups
   containing only char classes are flattened into DFA sequences since
   `match_first`/`match_next`/`match_all` don't return sub-group captures.
   Result: `grouped_quantifiers` 24x faster, now 5x faster than Python.

6. **First-element SIMD prefilter:** Multi-element DFA sequences now use
   the first element's character class as a SIMD prefilter to skip
   positions in `match_all` and `match_next`.

7. **NFA literal prefiltering for all patterns:** Removed complexity gate
   on literal extraction. Even single-char prefixes help skip positions.

### Additional fixes (PRs #91, #92):

8. **Lazy DFA caching PikeVM transitions (PR #91):** Added a lazy DFA that
   caches PikeVM NFA state-set transitions as DFA states, converging to
   full-DFA speed after ~20 bytes of warmup. Each unique NFA state set
   becomes a cached DFA state; transitions are cached per `(state_id, byte)`
   pair in a 256-entry `InlineArray`. On cache hit the lookup is O(1); on
   miss it runs one PikeVM step and caches the result. Evicts all states
   when the cache exceeds 256 entries. `NFAMatcher` uses
   `UnsafePointer[LazyDFA]` for interior mutability through the non-mut
   `self` required by the `RegexMatcher` trait. Used for `match_first`,
   `match_next`, and `match_all` when no fast paths apply. For
   `flexible_phone` only 13-15 unique DFA states are created, and after
   the first match all transitions are cached.

   - `multi_format_phone`: 1.660ms -> 0.114ms (14.5x faster)
   - `phone_validation`: 14.1x faster
   - `alternation_quantifiers`: 0.499ms -> 0.049ms (10.1x faster)
   - `flexible_phone`: 0.857ms -> 0.115ms (7.5x faster)
   - Mojo vs Rust win rate: 41% -> 50%

9. **Inline lazy DFA hot path (PR #92):** Added `@always_inline` to
   `LazyDFA.match_first`, `match_next`, `match_all`, and `_run_lazy`, and
   switched `_run_lazy` to `unsafe_ptr()` for direct state array access,
   bypassing bounds checks in the inner loop.

   | Benchmark | vs Rust (before) | vs Rust (after) |
   |-----------|------------------|-----------------|
   | `phone_validation` | 24.9x slower | **1.2x faster** |
   | `flexible_phone` | 4.4x slower | **1.7x faster** |
   | `multi_format_phone` | 8.1x slower | **1.4x faster** |
   | `alternation_quantifiers` | 6.5x slower | **2.7x faster** |

   Mojo vs Rust win rate: 41% -> 57%. Mojo vs Python: 97% win rate.

## ~~Medium: `dfa_paren_phone` Still Slower Than Python~~ (Fixed, PR #81)

**PR:** https://github.com/msaelices/mojo-regex/pull/81

Fixed nibble table overflow bug that prevented SIMD skip for `(` (lo nibble
= 8). Changed to bucket-based encoding. Also applied nibble SIMD skip to
the general DFA `match_all` and `_optimized_simd_search` paths.
Result: `dfa_paren_phone` now 2x faster than Python (was 4x slower).

## ~~Medium: `required_literal_short` 20x Slower Than Python~~ (Fixed, PR #82)

**PR:** https://github.com/msaelices/mojo-regex/pull/82

Added `.*` prefix fast path that finds the last occurrence of the literal
suffix via `twoway_search` instead of greedy `.*` backtracking. Skips the
NFA entirely for `.*LITERAL` patterns when text has no newlines.
Result: `match_next` 9x faster, `match_all` 6.4x faster.

## ~~Medium: `literal_prefix_short/long` Slower Than Python~~ (Fixed, PR #83)

**PR:** https://github.com/msaelices/mojo-regex/pull/83

Added `LITERAL.*` suffix fast path. For patterns like `hello.*`, find the
first occurrence of the literal prefix, then match extends to end of text.
Skips the NFA entirely when text has no newlines.
Result: `literal_prefix_long` 91x faster, now 19.5x faster than Python.

## ~~Medium: `complex_group_5_children` 14.7x Slower Than Python~~ (Fixed, PR #84)

**PR:** https://github.com/msaelices/mojo-regex/pull/84

`_is_literal_alternation_group` required all branches to have the same
length, rejecting `(hello|world|test|demo|sample)` (branches 4-6 chars).
Removed the constraint since the DFA compiler already handles variable-length
branches. This lets patterns like `(hello|world|test|demo|sample)[0-9]{3}[a-z]{2}`
route to DFA.
Result: `complex_group_5_children` 86x faster, now 5.9x faster than Python.

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
