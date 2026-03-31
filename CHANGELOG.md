# Changelog

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
