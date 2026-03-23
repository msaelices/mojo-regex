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

## High: Negated Character Class Inefficiency

**File:** `src/regex/dfa.mojo` lines 1700-1706

For negated classes like `[^aeiou]`, the code creates a 256-byte bitmap, then
iterates through ALL 256 ASCII values:

```mojo
for char_code in range(DEFAULT_DFA_TRANSITIONS):  # Always 256 iterations
    if char_bitmap[char_code] == 0:
        state.add_transition(char_code, to_state)
```

For `[^a]` (exclude 1 char), this does 255 `add_transition` calls. Could instead
add all transitions then remove the excluded ones, or use a different state
representation.

## ~~High: SIMD character class matcher silently disabled~~ (Fixed, PR #62)

**PR:** https://github.com/msaelices/mojo-regex/pull/62

The `range_digits` and `predefined_digits` regressions were caused by a Mojo
0.26.2 compiler bug where `Optional[T]` silently fails for structs containing
`SIMD` fields wider than 64 bytes (https://github.com/modular/modular/issues/6253).
This disabled the SIMD character class matcher for ALL character class patterns.

Workaround: replaced `Optional[CharacterClassSIMD]` with a plain field + Bool flag.

- range_digits: 0.105ms -> 0.040ms (2.6x faster)
- predefined_digits: 0.147ms -> 0.038ms (3.9x faster)

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

## Medium: find_all_matches Append in Closure

**File:** `src/regex/simd_ops.mojo` lines 178-190

The vectorize closure calls `matches.append()` which may trigger reallocation
inside the SIMD loop. A two-pass approach (count matches, pre-allocate, fill)
would eliminate this.

## Low: NFA String Allocations in is_match

**File:** `src/regex/nfa.mojo` lines 1112, 1196

```mojo
if ast.is_match(String(str[byte=pos]), pos, len(str)):
```

The `is_match()` API takes `String`, forcing allocation per character during
backtracking. Changing the API to accept `StringSlice` or a byte value would
eliminate these allocations.

## Low: MatchList Capacity Tuning

**File:** `src/regex/matching.mojo` line 44

`DEFAULT_RESERVE_SIZE = 8` for initial match list capacity. For `findall` on long
text, this causes multiple doublings. Could estimate based on text length and
pattern type.

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
