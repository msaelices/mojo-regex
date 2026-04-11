# mojo-regex Optimization Opportunities (v2)

Fresh audit of the codebase after PRs #61-#102 and the lazy DFA landed.
Items are ordered by expected impact on **matching throughput** (the hot
path), not compilation time. Each item references specific file/line
locations and the optimization pattern it follows from the
mojo-optimizations guide.

---

## High: Per-Character String Comparisons in `_match_range`

**File:** `src/regex/nfa.mojo` lines 839-863

Every character matched against a RANGE node runs up to 5 string equality
checks (`range_pattern == "[a-z]"`, `"[A-Z]"`, `"[0-9]"`, `"[a-zA-Z0-9]"`,
`"[a-zA-Z]"`), plus `startswith("[")`, `endswith("]")`, and 3 `in` substring
searches (`"a-z" in inner`, `"A-Z" in inner`, `"0-9" in inner`) per
character. These fire on every recursive descent into `_match_range` during
backtracking NFA evaluation.

**Fix:** Precompute a classification tag (e.g., an `Int` enum:
`RANGE_LOWERCASE`, `RANGE_UPPERCASE`, `RANGE_DIGITS`, `RANGE_ALNUM`,
`RANGE_ALPHA`, `RANGE_COMPLEX_ALNUM`, `RANGE_OTHER`) at AST construction
time. Store it on the `ASTNode`. The per-character check becomes a single
integer switch instead of N string comparisons.

**Pattern:** Fast-path dispatch by input shape (classify once at
construction, dispatch cheaply at match time).

## High: Duplicate String Comparisons in `_apply_quantifier_simd`

**File:** `src/regex/nfa.mojo` lines 1386-1526

The same `range_pattern == "[a-zA-Z0-9]"` / `"[a-z]"` / `"[A-Z]"` /
`"[0-9]"` / `"[a-zA-Z]"` chain is repeated a second time when the
quantifier SIMD path fires. This duplicates the per-invocation string
comparison cost from `_match_range`.

**Fix:** Same precomputed tag. Once the ASTNode carries the classification,
both `_match_range` and `_apply_quantifier_simd` switch on the integer
instead of re-comparing strings.

**Pattern:** Same as above. The two items should be fixed together.

## High: `_create_range_matcher` Called Per Character

**File:** `src/regex/nfa.mojo` lines 882-887

For range patterns that don't match the hardcoded `[a-z]`/`[A-Z]`/etc.
strings, `_match_range` falls through to `_match_with_simd_or_fallback`
which calls `_create_range_matcher(range_pattern)`. This constructs a
`CharacterClassSIMD` or `RangeBasedMatcher` on every character.

**Fix:** Cache the matcher on the `ASTNode` at parse/compile time, or in a
`Dict[UInt64, CharacterClassSIMD]` keyed by range pattern hash. The matcher
is immutable once created.

**Pattern:** Lazy-initialized global cache / cache by hash.

## High: LazyDFA First-Byte Filter Is Scalar Per-Byte

**File:** `src/regex/pikevm.mojo` line 725

The `match_all` and `match_next` prefilter loop checks
`self.pikevm.first_byte_filter[Int(text_ptr[pos])]` one byte at a time to
skip positions where no match can start. This is a scalar lookup per text
byte.

**Fix:** Load 16/32 bytes at a time via SIMD, shuffle through a nibble LUT
built from the first-byte filter, and find the first set bit. This is the
same nibble-based scan technique already used in `DFAEngine.match_all` and
`CharacterClassSIMD.find_first_nibble_match`. Expected 10-20x skip speedup
on long non-matching spans.

**Pattern:** SIMD byte scanning with nibble-based lookup.

## High: `get_pattern()` Returns Owned String on Hot Path

**File:** `src/regex/dfa.mojo` lines 1780-1786, called at line 1894

`DFAEngine.get_pattern()` returns `self.literal_pattern` which copies the
`String`. It is called inside `_try_match_at_position` for literal pattern
matching on every match attempt.

**Fix:** Return `StringSlice` (view) instead of owned `String`. The
`literal_pattern` field outlives the call, so a view is safe.

**Pattern:** Pass views, not owned strings.

## High: LazyDFA `_find_or_create_state` Is O(N) Linear Scan

**File:** `src/regex/pikevm.mojo` lines 884-900

State lookup scans the entire `List[CachedState]` with a full SIMD
`.eq().reduce_and()` comparison per cached state. This is O(N) per cache
miss where N = number of DFA states.

**Fix:** Add a `Dict[UInt64, Int]` keyed by a hash of the `nfa_set` SIMD
vector for O(1) lookup. Keep the linear list for ownership, use the dict
for fast lookup. For typical patterns with 10-50 states this is marginal,
but complex patterns with 100+ reachable states would benefit.

**Pattern:** Cache by hash, not by linear scan.

---

## Medium: 7 NFA Recursive Functions Missing `@always_inline`

**File:** `src/regex/nfa.mojo` lines 932, 968, 1014, 1065, 1252, 1274, 1342

`_match_or`, `_match_group`, `_match_group_with_quantifier`,
`_match_sequence`, `_match_re`, `_apply_quantifier`, and
`_apply_quantifier_simd` all lack `@always_inline`. These are called on
every recursive descent through the AST. The leaf matchers (`_match_element`,
`_match_digit`, etc.) are all inlined, but the dispatch chain above them is
not. One missing link breaks LLVM's ability to fold the call chain.

Note: `_match_re` (line 1252) is a pure trampoline that just forwards to
`_match_node(ast.get_child(0), ...)`. Without inlining, every match pays a
function call frame for zero work.

**Fix:** Add `@always_inline` to all 7 functions. These are thin dispatchers
and recursive forwarders, not large function bodies.

**Pattern:** Inlining hot-path trampolines.

## Medium: `match_next` Missing `@always_inline`

**File:** `src/regex/matcher.mojo` lines 556, 759

`HybridMatcher.match_next` and `CompiledRegex.match_next` are the most-used
dispatch path (`search`, `sub`, `test` all call them). `match_first` and
`is_match` are already `@always_inline`, but `match_next` is not.

**Fix:** Add `@always_inline` to both.

**Pattern:** Inlining hot-path trampolines.

## Medium: `sub()` String Concatenation Without Pre-Allocation

**File:** `src/regex/matcher.mojo` line 963

`var result = String()` then `result += ...` in a loop on lines 978, 984,
993, 1006. No capacity hint. For a 10K text with 100 replacements, this
triggers ~14 reallocations (0->1->2->4->...->16384). The output size is
bounded by `text_len + replacements * len(repl)`.

**Fix:** `String(capacity=text_len + 64)` as a conservative pre-allocation.

**Pattern:** Pre-allocate collections.

## Medium: LazyDFA `CachedState` Is 2177 Bytes

**File:** `src/regex/pikevm.mojo` lines 645-660

Each `CachedState` contains a 128-byte `nfa_set` SIMD vector + 1-byte
`is_match` + 256 x 8-byte `transitions` InlineArray = ~2177 bytes. Iterating
states in `_find_or_create_state` thrashes L1 cache (64-byte lines).

**Fix:** Struct-of-arrays layout: separate `nfa_sets: List[SIMD]` and
`transitions: List[InlineArray]` arrays. The linear NFA-set comparison scan
then touches only the compact `nfa_sets` array.

**Pattern:** Struct layout for cache efficiency.

## Medium: Redundant DFA Dispatch Condition (4 Sites)

**File:** `src/regex/matcher.mojo` lines 524, 546, 591, 600

`self.dfa_matcher and self.complexity.value == PatternComplexity.SIMPLE` is
evaluated verbatim at 4 dispatch points. The two conditions are always
correlated (DFA is only compiled for SIMPLE patterns).

**Fix:** Cache as a single `Bool` field `_use_dfa` set in `__init__`.
Eliminates a pointer null-check + enum comparison on every match call.

**Pattern:** Fast-path dispatch by input shape.

## Medium: LazyDFA Missing `@always_inline` on Inner Helpers

**File:** `src/regex/pikevm.mojo` lines 585, 796, 884, 902

`_add_state` (epsilon closure helper), `_compute_transition`,
`_find_or_create_state`, and `_has_match_in_set` all lack `@always_inline`.
`_add_state` is called from both the PikeVM hot loop and
`_compute_transition`. Inlining it would let LLVM see through the epsilon
closure dispatch.

**Pattern:** Inlining hot-path trampolines.

---

## Low: DFA Compilation String Churn

**File:** `src/regex/dfa.mojo` lines 1066-1093, 1381-1386, 1442

`_compile_simple_quantifier` builds a `List[String]` of single-char parts
then concatenates. `_extract_all_prefix_branches` does `branch_text +=
String(char_value)` per char. `_find_common_prefix` does `prefix += ...` in
a loop (O(n^2)). All are compilation-path only.

**Fix:** Pre-size `String(capacity=N)` in each case.

**Pattern:** Pre-allocate collections.

## Low: PikeVM `_add_state` Is Recursive

**File:** `src/regex/pikevm.mojo` line 585

Recursive calls for OP_SPLIT and OP_JUMP epsilon chains. Each chain pays
function-call overhead proportional to depth.

**Fix:** Iterative worklist (stack-based loop with `InlineArray`).

**Pattern:** Unlikely-branch hoisting / avoid call overhead.

## Low: `from regex.ast import` Inside Function Bodies

**File:** `src/regex/nfa.mojo` lines 580, 1298, 1362

Imports inside `_match_node` and `_apply_quantifier` execute on every call.
While the Mojo compiler likely optimizes these away, moving to module level
eliminates any risk.

---

## Deferred (Blocked on Mojo Stdlib)

### SIMD First-Match Scalar Fallback

**File:** `src/regex/simd_ops.mojo` (4 call sites)

Scalar loop to find first set bit after `reduce_or()`. Requires `movemask`
(SIMD bool to scalar bitmask) + `countr_zero`, neither of which Mojo's
stdlib exposes. Bounded by SIMD_WIDTH (16/32), low impact even when
available.

### SIMD Width Gaps (AVX-512)

**File:** `src/regex/simd_ops.mojo` line 60

`USE_SHUFFLE` gate forces AVX-512 (SIMD_WIDTH=64) into scalar fallback
instead of using existing sub-chunk shuffle path. Fix is ~5 lines (remove
the guard). Niche platform, deferred.
