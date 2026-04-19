# Changelog

## v0.11.0 (2026-04-17)

### Perf deep-dive: range-path find_first + precomputed OnePass end-anchor (PR #145)

- Two independent hot-path wins from a profiling pass.
- **Range fast path in `CharacterClassSIMD.find_first_nibble_match`**: for 1/2/3-range character classes (`[0-9]`, `[a-z]`, `[a-zA-Z]`, `[a-zA-Z0-9]`, `\d`, `\w`, ...), the previous code always went through the nibble-table `pshufb` scan (2x `_dynamic_shuffle` + AND + cmp per 32-byte chunk). Contiguous byte ranges can use one unsigned subtract + one range compare per chunk — ~2x fewer SIMD instructions. Mirrors the existing specialization in `count_consecutive_matches`.
- **Precompute OnePass end-anchor fixup per state**: `OnePassNFA.match_first` previously ran `_fire_end_anchor(nfa_set, text_len)` for every `$`-anchored match — and the method took `nfa_set` (SIMD[uint8, 512] = 512 bytes) **by value**, copying the whole state set to the stack per call on top of doing a DFS closure walk. The answer is fully determined by the state's `nfa_set` and the program graph, so precompute it at `compile_onepass` time and store a `Bool is_end_match` on `OnePassState`. Match-time fixup is now a single byte load.
- Measurements (best-of-3 vs v0.11.0 baseline): `phone_validation` **315 → 28 ns (11.2x, now faster than Rust's `regex`)**, `predefined_digits` 874 → 421 ns (2.08x), `sparse_phone_search` 6044 → 3238 ns (1.87x), `range_digits` 596 → 342 ns (1.74x), `multi_format_phone` 150 → 95 μs (1.58x), `complex_email` 8.2 → 5.5 μs (1.50x), `range_lowercase` 368 → 266 ns (1.38x). Full-bench geo vs Rust lifted from 2.93x to ~3.16x; vs Python from 21.7x to ~23.8x.

### Pattern + repl identity cache for module-level `sub()` (PR #144)

- Closes the remainder of issue #142. Module-level `sub(pattern, repl, text)` re-did `hash(pattern)`, `_has_group_refs(repl)`, and `_parse_repl_template(repl)` on every call even when the caller passed the same `StaticString` pointers each time. Adds a one-slot `_LastSubCache` keyed on pointer-identity `(address, byte_length)` of pattern and repl: on hit, reuse the cached `hash(pattern)` and the parsed `_ReplSegment` template. `_sub_impl` split into a wrapper + `_sub_impl_with_repl` so the module-level `sub()` can feed in the cached template without recomputing per call.
- Microbench (best of 5, module-level `sub()`, whole-text match): ES `(\d{3})(\d{2})(\d{2})(\d{2})` **559 → 192 ns (2.9x)**, US `(\d{3})(\d{3})(\d{4})` **535 → 166 ns (3.2x)**. Module-level path now nearly ties method-level `compiled.sub()` (180 ns) for the smith-phonenums `StaticString` usage.

### Precompute fixed-width `sub()` metadata; short-circuit whole-text matches (PR #143)

- Closes half of issue #142 (smith-phonenums `format_number` bottleneck). For `sub()` on patterns that are concatenated fixed-width `(\d{N})` capture groups, `CompiledRegex` now precomputes per-match offsets/widths at construction time and `_sub_impl` short-circuits whole-text matches without invoking the regex engine.
- Three fixes in one: (1) pattern parsing + offset/width computation moved from per-`sub()`-call to once-at-compile-time; (2) short-circuit condition `text_len == total_width and count != 1 or count == 0` (parses as `(text_len == total_width and count != 1) or count == 0`) didn't fire for the target `count=1` case — fixed to fire whenever `text_len == total_width`; (3) the old fast path produced garbage output on non-matching text of the right length (latent correctness bug) — now validates digit-ness and returns text unchanged when it doesn't match.
- Microbench (best of 5): ES `(\d{3})(\d{2})(\d{2})(\d{2})` **559 → 180 ns (3.1x)**, US `(\d{3})(\d{3})(\d{4})` **535 → 150 ns (3.6x)**. Full `bench_engine` symmetric best-of-4 vs main: geo 1.042x, W/L/S 17/0/63; `sub_char_class` 1.18x, `sub_group_word_swap` 1.14x, `sub_digits` 1.10x.

### Hoist redundant `ast.get_value()` call in NFA `_match_range` (b0179a0)

- `RANGE_KIND_COMPLEX_ALNUM` and `RANGE_KIND_OTHER` paths called `ast.get_value()` twice per character in the backtracking-NFA inner loop: once in the `elif` condition (coerced to Bool), once inside the branch to unwrap. `get_value` itself is not trivial (double pointer indirection + `Span`/`StringSlice`/`Optional` construction), and LLVM can't dedup through the `self.regex_ptr[]` indirection. Rewrote as `var opt = ast.get_value(); if opt: ...` to bind the first call's result and reuse it. Micro-cleanup; only affects patterns routing to backtracking NFA with custom bracket classes.

### OnePass NFA engine for `$`-anchored patterns (PR #140)

- Adds a OnePass NFA in `src/regex/onepass.mojo` for patterns where at every state, for every input byte, at most one forward transition fires. Such patterns run in O(n) per byte with no backtracking, no state-set tracking, and no per-call setup. Unlike LazyDFA it compiles all transitions ahead of time and correctly handles `$` (keeps `OP_END_ANCHOR` in the set, fires it only at `pos == text_len`), so it fills the niche LazyDFA declines. `NFAMatcher` dispatches to OnePass whenever the pattern has `$` and the program is one-pass; LazyDFA stays preferred for `$`-free patterns where its first-byte SIMD prefilter wins.
- `phone_validation` `^\+?1?[\s.-]?\(?([2-9]\d{2})\)?[\s.-]?([2-9]\d{2})[\s.-]?(\d{4})$` (5x median): backtracking NFA 1.76 us → OnePass 0.25 us (**6.92x faster**). Full `bench_engine` geom mean **1.09x** across 80 benchmarks (44 wins / 28 losses / 8 similar). Compile-time hash in `_hash_set` also rewritten from a 64-deep serial FNV-1a chain to a SIMD XOR-reduction over uint64 lanes (58 ns → 8 ns on the hash itself).

### Single-byte required-literal memchr prefilter for findall (PR #139)

- Patterns like `[a-zA-Z0-9._%+-]+@[...]\.[...]` (email) or `\d{3}-\d{3}-\d{4}` (phone) have a rare required byte (`@` or `-`) outside the first-element character class. Rust's prefilter memchr-scans for it; Mojo did not. Adds `simd_find_byte` (memchr-style SIMD scan), `_find_rare_required_byte` (top-level AST walker), and a `_match_all_required_byte` fast path on `HybridMatcher` that does memchr → backward-scan to candidate match start → `dfa.match_first`.
- Measurements (3x median): `sparse_email_findall` **~160x faster** (199 us → 1.25 us; previously 167x slower than Rust, now within ~5%); `simple_phone` **4.4x faster** (155 us → 35 us). Full bench geom mean vs main: **1.32x** across 80 benchmarks, with broad wins on phone and quantifier patterns that have rare separator bytes.

### Two-way unroll of count_consecutive_matches SIMD loops (PR #138)

- The SIMD loops in `CharacterClassSIMD.count_consecutive_matches` for contiguous-range character classes had a tight dependency chain per iteration (load → sub → min → eq → reduce_and). Unrolling two chunks per iteration lets LLVM schedule the two chains in parallel, doubling effective throughput on long all-matching runs. Applied to the single-range (`[a-z]+`, `[0-9]+`), 2-range (`[a-zA-Z]+`), and 3-range (`[a-zA-Z0-9]+`) paths, all deduped behind `@always_inline` helpers (`_in_range_1/2/3`, `_first_false`, `_first_false_in_two`).
- Measurements (3x median): `range_lowercase` `[a-z]+` **7.77x faster** (1.65us → 0.21us), `range_alphanumeric` `[a-zA-Z0-9]+` **3.1x faster** (2.08us → 0.67us), `range_digits` `[0-9]+` 1.4x faster. `range_lowercase` was ~33x slower than Rust before this change; after, ~5x.

### `--dev` and `--filter` flags for bench_engine (PR #137)

- Added two CLI flags to `bench_engine.mojo` for fast dev iteration. `--dev` switches sample budget from 10ms to 1ms and per-bench target from 500ms to 50ms (noisier, for directional signal only). `--filter=<substr>` runs only benchmarks whose name contains the substring. Flags compose: `--dev --filter=sub_` runs the sub() subset in ~8 s vs ~4 min for a full stable run. Added `CLAUDE.md` at project root and expanded `benchmarks/BENCHMARKING_GUIDE.md` to document the iteration workflow.

### Inline match_next dispatchers and pre-allocate MatchList in findall (PR #136)

- Added `@always_inline` to `DFAEngine.match_next`, `NFAEngine.match_next`, and `PikeVM.match_next` so the dispatch chain from `HybridMatcher` (already inlined) collapses end-to-end.
- Pre-allocated `MatchList` capacity in all 6 `match_all` entry points based on text length (`text_len >> 7` when `text_len >= 1024`, else lazy default), avoiding 5-7 reallocations on long-text findall.
- Vs baseline: 39 wins / 24 losses / 17 similar over 80 benchmarks, geom mean **1.060x**. sub() operations: clean 8/0 win, geom **1.28x**. Top wins: `deep_nested_groups_depth4` **2.95x**, `complex_group_5_children` 1.70x, `sub_group_phone_fmt` 1.62x, `simple_phone` 1.60x, `dfa_simple_phone` 1.56x, `sub_group_word_swap` 1.53x, `sub_digits` 1.49x, `multi_format_phone` 1.49x, `dfa_dot_phone` 1.48x, `complex_email` 1.46x.
- A Dict-keyed LazyDFA state lookup was also implemented and benchmarked, but reverted: net-neutral overall and slightly negative on the NFA path, reproducing PR #123's original conclusion.

### Precompute pattern properties, eliminate string ops from match paths (PR #135)

- Replaced runtime `endswith`, `startswith`, `len` calls on `self.pattern` with precomputed Bool/Int fields set once at construction. `nanpa_search` **17.9x faster**, `sub_whitespace` **1.49x**, `nanpa_findall` **1.42x**, `sparse_phone_search` **1.36x**, `multi_format_phone` **1.33x**. Also increased benchmark `MIN_SAMPLE_NS` from 1ms to 10ms for more stable sub-microsecond measurements.

### Use ref instead of copy for ASTNode in NFA match methods (PR #133)

- Replaced ~550-byte `ASTNode` copies with `ref` bindings in all 4 public NFA match methods (`match_all`, `match_first`, `match_next`, `match_next_with_groups`). Inlined `Match` temporaries directly into list appends. `findall` **2.6-2.9x faster**, free functions (`search`, `findall`, `match_first`) **1.6x faster**.

### Skip lazy DFA for $ anchor patterns, apply cache pointer to all free functions (PR #132)

- The lazy DFA's cached `is_match` flag is position-dependent for `$` anchor patterns, causing incorrect matches when the cache is shared. Fix: detect `OP_END_ANCHOR` at `LazyDFA` construction and skip lazy DFA for those patterns. With this fix, `_compile_and_cache` pointer applied to `match_first`, `search`, and `findall` — eliminating `CompiledRegex` copy from Dict cache on every call. `phone_validation` regresses (59x, falls to NFA) but 9 other benchmarks gain 1.1-1.2x.

### Eliminate CompiledRegex copy in sub() via cache pointer lookup (PR #127)

- `sub()` copied the entire `CompiledRegex` out of the Dict cache on every call (2.5µs copy overhead). Now uses `_compile_and_cache()` returning an `UnsafePointer` into the cache. `sub()` per call: 36,632ns -> 1,125ns (**33x faster**), now within 1.4x of `compiled.sub()`.

### Multi-range SIMD scan for [a-zA-Z0-9]+ and similar patterns (PR #126)

- Added multi-range SIMD path to `count_consecutive_matches` for character classes with 2-3 contiguous sub-ranges. Uses SIMD unsigned subtraction + OR across all ranges instead of scalar lookup. `range_alphanumeric` **9x faster** (0.025ms -> 0.003ms), flipped from 1.4x slower than Python to ~4.7x faster. Zero regressions on single-range benchmarks. Python win rate: 96% -> 97%.

### Increase PikeVM MAX_STATES to 512: enable lazy DFA for NANPA patterns (PR #124)

- The US NANPA area code pattern (290 PikeVM instructions) exceeded `MAX_STATES=128` and fell back to the backtracking NFA, 28x slower than Python. Bumping to 512 enables the lazy DFA which produces only 11 cached states. `nanpa_match_first` **94,579x faster** (3.594ms -> 0.000038ms), now **6.1x faster than Python** and **1.3x faster than Rust**. `nanpa_findall` **273x faster**, now 8x faster than Python. Added NANPA benchmarks to all 3 engines.

### Cache DFA dispatch condition and inline LazyDFA helpers (PR #122)

- M5: Replaced 6 occurrences of `self.dfa_matcher and self.complexity.value == PatternComplexity.SIMPLE` with a cached `_use_dfa` Bool field. `DFAMatcher` now conforms to `Boolable`.
- M6: Added `@always_inline` to 4 LazyDFA helpers (`_compute_transition`, `_get_or_create_state_for_pos`, `_find_or_create_state`, `_has_match_in_set`). `_add_state` is recursive and cannot be inlined.
- **64/77 benchmarks show >10% speedup.** Lazy DFA patterns (`flexible_phone` 2.2x, `multi_format_phone` 1.7x, `alternation_quantifiers` 1.9x, `simple_phone` 2.4x, `match_all_digits` 2.4x). LLVM was NOT inlining the LazyDFA helpers before.

### Fix large alternation (7+ branches) failing to match full pattern (PR #121)

- Root cause: `UInt8` overflow in `ASTNode.children_indexes`. Patterns with > 255 AST nodes (like the US NANPA area code pattern with 303 nodes) silently corrupted child indices, producing a 1-byte match instead of the full pattern. Fix: widened indices from `UInt8` to `UInt16` (`SIMD[uint16, 256]`), supporting up to 65535 AST nodes. Added `_has_nested_alternation` defense-in-depth in the optimizer.

### Skip per-character _create_range_matcher indirection (PR #119)

- For `RANGE_KIND_OTHER` patterns, `_match_range` called `_match_with_simd_or_fallback` -> `_create_range_matcher` per character, but `_create_range_matcher` returns `None` for all bracket patterns. Now goes directly to `ast._is_char_in_range_by_code`. Removed dead `_match_with_simd_or_fallback`.

## v0.10.0 (2026-04-11)

Performance tuning release. Mojo vs Rust win rate improved from 57% to 64%.

### Fix 3+ way alternation with character classes failing to match (PR #118)

- Fixed bug where patterns like `3[02]|40|[68]9` failed to match. The prefilter extracted a literal from one alternation branch (`"40"`) and rejected matches from other branches (`"30"` matching `3[02]`). Fix: skip prefilter creation when the pattern contains alternation (`|`).

### Inline match_next dispatch chain and _apply_quantifier_simd (PR #117)

- Added `@always_inline` to `HybridMatcher.match_next` and `CompiledRegex.match_next` (the most-used dispatch path for `search`, `sub`, `test`). Added `@always_inline` to `_apply_quantifier_simd`. The other 6 NFA recursive dispatch functions cannot be inlined due to mutual recursion with `_match_node`.

### Extract shared nibble table builder and SIMD scan (PR #116)

- `build_nibble_tables()` and `find_first_in_nibble_tables()` extracted into `simd_ops.mojo` as shared free functions. Both `CharacterClassSIMD` and `LazyDFA` now delegate to them, removing ~50 lines of duplicated nibble table logic. Removed redundant `SIMD_WIDTH` from `pikevm.mojo`.

### SIMD nibble scan for LazyDFA first-byte prefilter (PR #115)

- LazyDFA first-byte filter previously checked `first_byte_filter[text_ptr[pos]]` one byte at a time. Now builds nibble lookup tables at construction and uses SIMD `_dynamic_shuffle` to scan 16/32 bytes per iteration via `_find_first_candidate()`. Added 4 sparse-match benchmarks (~1 match per 2KB). `sparse_flex_phone_findall` (lazy DFA path): 330x faster than Python, 18x faster than Rust.

### Deep sub() optimization: CompiledRegex.sub, pre-parsed template, match bypass (PR #113)

- Added `CompiledRegex.sub()` method to bypass the regex cache lookup for callers with an already-compiled regex. `sub()` refactored into `_sub_impl(compiled, repl, text, count)`.
- Pre-parsed replacement template: `_parse_repl_template()` runs once per `sub()` call producing `List[_ReplSegment]`. Per-match interpolation walks the template via `unsafe_ptr()` without re-scanning repl.
- Full-string match bypass: when `len(text) == total_match_width` for fixed-width `\d{N}` patterns, skip DFA execution entirely. `sub_group_phone_fmt` 20% faster, `sub_group_date_fmt` 24% faster vs baseline.

### Optimize sub() internals (PR #112)

- Replaced all runtime `ord()` calls in sub-related functions with comptime `CHAR_*` constants. Added `@always_inline` to `_has_group_refs`, `_detect_fixed_width_groups`, `_interpolate_groups`. Batched literal runs in interpolation instead of one-byte appends. Hoisted group offset computation out of the per-match loop. `sub_literal` 23% faster, `sub_group_date_fmt` 7% faster.

### DFA fast path for sub() on fixed-width capture groups (PR #110)

- When all capture groups are fixed-width `\d{N}` segments, `sub()` now skips the NFA entirely and computes group boundaries via pointer arithmetic. Uses `_detect_fixed_width_groups()` to analyze pattern structure at call time, then `compiled.match_next()` (DFA/lazy-DFA) for position finding + `_interpolate_fixed_groups()` for substitution.
- Added 3 group-reference benchmarks (`sub_group_phone_fmt`, `sub_group_date_fmt`, `sub_group_word_swap`). Fixed-width path beats Python 2.8-3.2x and Rust 1.5-1.9x on phone number formatting.

### Capture group extraction and group-reference interpolation in sub() (PR #108)

- `sub()` now supports `\1`..\`\9` backreferences in replacement strings, matching Python's `re.sub` behavior. Parser assigns 1-based `group_id` to capturing groups. NFA `_match_group` tags `Match` objects with group IDs. New `match_next_with_groups()` returns group captures. `_interpolate_groups()` uses `InlineArray` indexed lookup for O(1) per backreference.
- Optimized `sub()`: split into two loop paths (group-aware vs fast) to avoid group machinery when no backreferences are used. `match_next_with_groups` uses literal prefiltering. Early return for empty text.

### sub() comparison benchmarks and pre-allocation fix (PR #106)

- Added 5 `sub()` benchmarks with equivalent logic across Mojo, Python, and Rust (`sub_literal`, `sub_digits`, `sub_char_class`, `sub_whitespace`, `sub_limited_count`). vs Python: 5/5 wins (1.2x-8.4x faster). vs Rust: 2 wins, 3 losses.
- Pre-allocated result `String` in `sub()` with `capacity=text_len + 64` to reduce reallocations on replacement-heavy patterns.

### Eliminate per-match String copies in DFA/NFA hot paths (PR #105)

- DFA `_try_match_at_position` called `get_pattern()` on every literal match attempt, copying `self.literal_pattern` (heap allocation). Now accesses the field directly.
- NFA `match_all`/`match_next` called `get_pattern().as_bytes()` in the literal prefilter loop. Added `_get_search_literal_bytes()` returning a zero-copy `Span[Byte]` view.

### Precompute range classification tag on ASTNode (PR #104)

- Added `range_kind: Int` field to `ASTNode` with 8 classification constants, computed once at AST build time by `classify_range_kind()`. Replaces per-character string comparison chains in `_match_range` and `_apply_quantifier_simd` (up to 5 equality checks + `startswith`/`endswith`/`in` per char) with a single integer switch. Extracted `_quantifier_negated_loop` and `_quantifier_range_loop` helpers (net -14% code in nfa.mojo). Moved `COMPLEX_CHAR_CLASS_THRESHOLD` to ast.mojo as shared constant.

### `re.sub()` pattern substitution (PR #103)

- Added `sub(pattern, repl, text, count=0)` function equivalent to Python's `re.sub()`. Replaces all non-overlapping matches of `pattern` in `text` with `repl`. Optional `count` parameter limits the number of replacements. Handles zero-length matches by advancing one byte to avoid infinite loops.

### Inline NFA per-character range checks (PR #102)

- Replaced per-character `get_digit_matcher()`/`get_word_matcher()`/`get_whitespace_matcher()`/`get_alnum_matcher()`/`get_alpha_matcher()` Dict lookups in `_match_digit`, `_match_word`, `_match_space`, and `_match_range` with direct O(1) comptime `CHAR_*` constant comparisons, matching the pattern already used by `ast.is_match_char`.

### `StringSlice` pattern in the public API (PR #99)

- `compile_regex`, `match_first`, `search`, `findall` now take `pattern: ImmSlice`, matching the `text: ImmSlice` signatures from PR #95.
- Regex cache rekeyed from `Dict[String, CompiledRegex]` to `Dict[UInt64, CompiledRegex]` on `hash(pattern)`. Cache hits allocate zero Strings (hash + probe + byte-compare against `cached.pattern`). On the astronomically rare 64-bit hash collision we fall through to a fresh compile.

### `NFAMatcher` lazy DFA initialization fix (PR #98)

- `NFAMatcher.__init__`/`__copyinit__` now use `init_pointee_move` instead of `self._lazy_dfa_ptr[] = LazyDFA(...)`, which was move-assigning into uninitialized `alloc` storage and crashing nondeterministically at process exit. Collapsed the `(ptr, _has_lazy_dfa: Bool)` pair into a single nullable `_lazy_dfa_ptr`.
- `@always_inline` on the `is_match` trampoline (`CompiledRegex` -> `HybridMatcher` -> `DFAMatcher` -> `DFAEngine`), so a 16-byte `ImmSlice` through four call levels folds into the one-byte fast path.
- `pixi run test` switched from `mojo run` to `mojo build -debug-level=line-tables` + execute for symbolicated stack traces on CI crashes.

### `StringSlice` text parameter in the matcher chain (PR #95)

- The whole matcher chain (`match_first`/`search`/`findall`, `CompiledRegex`, `HybridMatcher`, `DFAMatcher`/`NFAMatcher`, `DFAEngine`/`NFAEngine`/`PikeVMEngine`/`LazyDFA`, and shared SIMD helpers) now takes `text: ImmSlice` instead of `String`. Callers no longer allocate to hand over a literal or slice.
- `Match` stores a single byte pointer instead of `UnsafePointer[String]`, keeping the struct at 32 bytes so `MatchList` iteration stays cache-friendly.
- `is_match` is `@always_inline` end-to-end through the four-level trampoline, so the 16-byte slice folds into the one-byte-read fast path.
- Removed redundant `__str__`/`__repr__` on `Regex`, `ASTNode`, `PatternComplexity` (covered by `Writable`).
- Results (best-of-3, 65 engine benchmarks, 39 faster >5%, 4 slower >5%, average **-11.49%**): `is_match_*` -65%/-68% (~4 µs -> ~1.3 µs), `quad_quantifiers` -38%, `range_quantifiers` -24%, `dfa_dot_phone` -22%, `flexible_datetime` -21%, `ultra_dense_quantifiers` -20%.

### DFA inner loop optimization (PR #94)

- **Unsafe state access**: Use `unsafe_ptr()` for direct state array access in
  `_try_match_at_position` hot loop, bypassing List bounds checking.
- **Removed redundant bounds checks**: `get_transition` no longer checks
  `char_code >= 0 && < 256` (always true for uint8 input). Removed repeated
  `current_state < len(self.states)` checks inside the loop (was 3x per iteration).
- Key results: DFA findall benchmarks 1.3-1.8x faster.
  - `ultra_dense_quantifiers`: **1.8x faster**
  - `grouped_quantifiers`: **1.6x faster**
  - `dense_quantifiers`: **1.5x faster**
  - Mojo vs Rust: 57% -> **64% win rate** (36/20).

### SIMD range comparison for character classes (PR #93)

- **Contiguous range fast path**: `count_consecutive_matches` now uses SIMD unsigned
  subtraction + `min` + `eq` to check SIMD_WIDTH (32) bytes per iteration for
  contiguous byte ranges (e.g., `[a-z]`, `[0-9]`, `[A-Z]`).
- **`range_start`/`range_end` fields**: `CharacterClassSIMD` tracks whether the
  character class is a contiguous range, enabling the SIMD fast path at construction.
- Non-contiguous classes keep the scalar 4-way unrolled lookup table path.
- Key results:
  - `range_lowercase`: was 2x slower than Python, now **9.4x faster** (8x absolute speedup).
  - Overall vs Python: 97% -> **100% win rate** (61/0).

## v0.9.0 (2026-04-02)

PikeVM and lazy DFA release. Mojo vs Python win rate improved from 85% to 97%
(59 wins, 2 losses out of 61 benchmarks). Mojo vs Rust improved from 41% to 57%.

### PikeVM engine (PRs #86, #88, #89)

- **Thompson NFA simulation**: New PikeVM engine tracks all NFA states simultaneously
  instead of backtracking. Compiles AST to flat bytecode (BYTE, CLASS, SPLIT, JUMP,
  MATCH, etc.) and simulates using fixed-size `InlineArray[Int, 128]` state lists
  and `SIMD[DType.uint8, 128]` dedup vectors. Zero per-step heap allocations.
- **First-byte prefilter**: Extracts which bytes can start a match from the epsilon
  closure of state 0. Skips ~95% of positions for patterns like `\(?\d{3}\)?`.
- **Integration**: `NFAMatcher` routes `match_first` through PikeVM when available
  (programs <= 128 instructions). Search/findall use PikeVM with prefilter when
  NFA has no literal optimization or `.*` fast paths.
- **`\s`/`\d`/`\w` in bracket ranges**: PikeVM correctly expands escape sequences
  inside `[...]` (e.g., `[\s.-]`), which `_expand_character_range` doesn't handle.

### Lazy DFA (PR #91)

- **Cached state transitions**: Builds DFA states on-the-fly from PikeVM bytecode.
  Each unique NFA state set becomes a cached DFA state with a 256-entry transition
  table. After warmup (~20 bytes), most transitions hit cache for O(1) per byte.
- **Interior mutability**: Uses `UnsafePointer[LazyDFA]` for cache mutation through
  non-mut `self` (required by `RegexMatcher` trait). Proper `__del__` for cleanup.
- **No eviction**: State list grows freely (typically 10-50 states, ~2KB each).
  Avoids unsafe mid-match eviction that could invalidate live state IDs.
- Key results:
  - `flexible_phone`: **22.5x faster** than Python, **0.6x vs Rust**
  - `multi_format_phone`: **76.4x faster** than Python, **0.6x vs Rust**
  - `phone_validation`: **14.6x faster** than Python

### Lazy DFA hot path inlining (PR #92)

- **`@always_inline` on hot path**: Added `@always_inline` to `LazyDFA.match_first`,
  `match_next`, `match_all`, and `_run_lazy`. Eliminates function call overhead
  that dominated short-input benchmarks.
- **Unchecked state access**: Use `unsafe_ptr()` for direct state array access in
  `_run_lazy` inner loop, bypassing List bounds checking.
- Key results:
  - `phone_validation`: was 1.2x slower than Python, now **14.3x faster**. Now **1.2x faster than Rust**.
  - `flexible_phone` vs Rust: was 4.4x slower, now **1.7x faster**.
  - `multi_format_phone` vs Rust: was 8.1x slower, now **1.4x faster**.
  - Overall vs Python: 91% -> **97% win rate**. vs Rust: 41% -> **57% win rate**.
- **Benchmark parser fix**: `parse_mojo_output.py` regex now handles scientific
  notation (e.g., `3.97e-05`), previously silently dropping sub-microsecond results.

### `.*` last-literal optimization (PR #90)

- **`rfind` for last-literal search**: `_find_last_literal` used repeated forward
  `twoway_search` (O(N * occurrences)). Replaced with `String.rfind` for single-pass
  O(n) reverse scan.
- `required_literal_short` (`.*@example\.com`): **39x faster**, now 10.7x faster
  than Python (was the last consistent loss).

### Code quality

- `Instruction` marked `TrivialRegisterPassable` for zero-overhead access.
- Pre-allocated `List` capacity for instructions (128) and class tables (8).
- Class table deduplication via SIMD `eq()` check.
- Extracted `_use_pikevm_for_search` helper to deduplicate routing condition.
- Early return in `_build_first_byte_filter` for OP_ANY/OP_MATCH.
- Suppressed unused `emit()` return warnings.
- Reused `_expand_character_range` for DIGIT/WORD/SPACE in PikeVM compiler.

## v0.8.0 (2026-03-31)

Major performance release. Mojo vs Python win rate improved from 53% to 85% (52 wins, 9 losses out of 61 benchmarks).

### Performance improvements

#### DFA character class matching (PRs #74, #75)
- **Nibble-based SIMD scan**: Replaced slow `_dynamic_shuffle` on 256-byte lookup table with two 16-byte nibble tables using native `pshufb`. Matches 32 chars in 3 SIMD instructions.
- **`is_match` fast path**: O(1) single character check via SIMD lookup table, 2000-19000x faster than Python.
- **`@always_inline` on dispatch chain**: Inlined `CompiledRegex` -> `HybridMatcher` -> `DFAMatcher` -> `DFAEngine` -> `_try_match_simd` -> `count_consecutive_matches`.
- **SIMD scan bypass fix**: `_try_match_simd` was incorrectly classifying `[a-z]+` as a bounded quantifier. Added `_simd_scan_eligible` flag computed at compile time.
- Key result: `range_lowercase` **361x faster**, `predefined_word` **230x faster**.

#### NFA optimization (PR #76)
- **Inline dispatch**: Added `@always_inline` to NFAMatcher dispatch chain.
- **Backward search fix**: Reduced from 100 positions to pattern length.
- Key result: `literal_prefix_short` **3x faster**, `toll_free_complex` **1.5x faster**.

#### Parser and DFA compiler bug fixes (PR #77)
- **Escaped characters**: `\(`, `\)`, `\.`, `\+` now correctly stored as target character instead of backslash.
- **Dash outside brackets**: Literal `-` between pattern elements no longer silently dropped.
- **DFA start state**: Fixed missing start state for `min_matches > 1` sequences.
- Many benchmarks (`dfa_paren_phone`, `pure_dfa_dot`, `complex_email`) were silently returning zero matches before these fixes.

#### SIMD nibble scan for search/findall (PR #78)
- Applied nibble-based `count_consecutive_matches` and `find_first_nibble_match` to `_optimized_simd_search` and `match_all` paths.
- Key result: `predefined_digits` search **169x faster**, `match_all_digits` findall **90x faster**. vs-Rust gap for `\d+` search went from 1166x to 7x.

#### DFA non-capturing alternation groups (PR #79)
- Extended DFA compiler to handle `(?:00|33|44|...)` alternation within sequences.
- Key result: `toll_free_complex` **8.6x faster**, now 1.4x faster than Python.

#### Capturing group flattening
- Patterns with `(...)` capturing groups containing only char classes are flattened into DFA sequences since current API doesn't return sub-group captures.
- Key result: `grouped_quantifiers` **24x faster**, now 5x faster than Python.

#### First-element SIMD prefilter
- Multi-element DFA sequences use the first element's character class as a SIMD prefilter to skip positions in `match_all` and `match_next`.
- Key result: `grouped_quantifiers` **24x faster** (combined with flattening).

#### Nibble table overflow fix (PR #81)
- Fixed `UInt8` overflow for characters with nibble >= 8 (e.g., `8`, `9`, `(`). Changed to bucket-based encoding.
- Applied nibble SIMD skip to general DFA `match_all` and `_optimized_simd_search` paths.
- Key result: `dfa_paren_phone` now 2x faster than Python (was 4x slower).

#### `.*` prefix/suffix fast paths (PRs #82, #83)
- `.*LITERAL` patterns: Find last occurrence of literal suffix, skip NFA backtracking entirely.
- `LITERAL.*` patterns: Find first literal, match extends to end of text.
- Key result: `literal_prefix_long` **91x faster**, now 19.5x faster than Python. `required_literal_short` reduced from 42x to ~3x slower.

#### Variable-length alternation branches (PR #84)
- Removed equal-length constraint from `_is_literal_alternation_group`.
- Key result: `complex_group_5_children` **86x faster**, now 5.9x faster than Python (was 14.7x slower).

#### Deeply nested alternation groups (PR #85)
- DFA compiler now unwraps nested GROUP wrappers to detect and compile deeply nested alternations.
- Key result: `deep_nested_groups_depth4` **52x faster**, now 6.3x faster than Python (was 8.2x slower).

#### NFA literal prefiltering
- Enabled literal extraction for all complexity levels (not just MEDIUM/COMPLEX).
- Lowered prefix literal threshold from 3 to 1 character.
- Required prefix literals to also be `is_required=True` to avoid incorrect skipping for alternation patterns.

#### SIMD quantifier threshold (PR #72)
- Enabled SIMD quantifier path for `\d+`, `\w+`, `\s+` patterns by lowering threshold for predefined types.

#### StringSlice API changes (PRs #70, #71)
- `CharacterClassSIMD.__init__`, `get_character_class_matcher`, `simd_count_char` now take `StringSlice` instead of `String`.
- `PrefilterMatcher` trait methods take `StringSlice` instead of `String`.

### Benchmark infrastructure (PR #73)
- Pre-compile regex outside timing loop (was unfairly penalizing Mojo).
- Report median instead of mean for robustness to OS scheduling outliers.
- Auto-calibrate iterations so each sample takes >= 1ms.
- Increased target runtime from 100ms to 500ms, warmup from 3 to 10 iterations.
- Applied same methodology to Python and Rust harnesses for fair comparison.
- Added `is_match` benchmarks across all three engines.

### Code quality
- Extracted `_element_to_char_class` helper to deduplicate char class extraction.
- Extracted `find_first_nibble_match` and `_find_last_literal` helpers.
- Used existing `CHAR_A`/`CHAR_Z`/etc. constants instead of `ord()` calls.
- Pre-allocated lists with capacity hints in alternation branch collection.

## v0.7.0

Previous release. See git history for details.
