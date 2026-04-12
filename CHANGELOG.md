# Changelog

## v0.10.0 (2026-04-11)

Performance tuning release. Mojo vs Rust win rate improved from 57% to 64%.

### Precompute range classification tag on ASTNode (PR #104)

- Added `range_kind: Int` field to `ASTNode` with 8 classification constants, computed once at AST build time by `classify_range_kind()`. Replaces per-character string comparison chains in `_match_range` and `_apply_quantifier_simd` (up to 5 equality checks + `startswith`/`endswith`/`in` per char) with a single integer switch. Extracted `_quantifier_negated_loop` and `_quantifier_range_loop` helpers (net -14% code in nfa.mojo). Moved `COMPLEX_CHAR_CLASS_THRESHOLD` to ast.mojo as shared constant.

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
