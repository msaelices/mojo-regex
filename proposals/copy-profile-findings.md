# Copy profile: where do we copy, and is it costing us?

Date: 2026-05-05
Author: investigation prompted by "reach almost-zero-copy" question

## TL;DR

The hot match path is already almost-zero-copy. Every traced copy in a
full benchmark run happens during pattern *compile* setup, none during
match iteration. There is no copy-elimination opportunity that would
move benchmark numbers. The cache architecture (pointer-returning
`_compile_and_cache`) is already optimal.

## Methodology

Mojo 0.26.1 made `call_location()` a public API at
`std.reflection.location.call_location`. We added a `print` at the top
of every hand-written `__init__(out self, *, copy: Self)` across the
8 structs with non-trivial copy constructors:

| Struct | File | Notes |
|---|---|---|
| `MatchList` | `src/regex/matching.mojo` | already `@always_inline` |
| `LiteralInfo` (prefilter) | `src/regex/prefilter.mojo` | needs `@always_inline` for `call_location()` |
| `MemchrPrefilter` | `src/regex/prefilter.mojo` | needs `@always_inline` |
| `BestLiteralInfo` | `src/regex/matcher.mojo` | needs `@always_inline` |
| `DFAMatcher` | `src/regex/matcher.mojo` | needs `@always_inline` |
| `NFAMatcher` | `src/regex/matcher.mojo` | needs `@always_inline` |
| `HybridMatcher` | `src/regex/matcher.mojo` | needs `@always_inline` |
| `CompiledRegex` | `src/regex/matcher.mojo` | needs `@always_inline` |

`ASTNode` and `Regex` were skipped: `ASTNode` is `comptime
__copy_ctor_is_trivial = True` (Mojo memcpys it directly, bypassing
any user-defined copy ctor), and `Regex` is `ImplicitlyCopyable` with
the explicit ctor commented out + rotted (references stale fields).

Trace prefix `COPY_TRACE <TypeName>` so output greps cleanly.

### Re-running the profile

The instrumented code lives on the `copy-profile` branch. To rerun:

```bash
git checkout copy-profile
pixi run mojo run -I src benchmarks/bench_engine.mojo -- --dev > /tmp/trace.log 2>&1
grep '^COPY_TRACE' /tmp/trace.log | sort | uniq -c | sort -rn
```

Filter to a single workload with e.g. `-- --dev --filter=match_all`.

### `inline_count` caveat

`call_location[inline_count=N]()` walks N frames up the inline chain.
Default `N=1` resolves direct calls correctly (e.g. `dict[k] = v`
shows `matcher.mojo:1279:30`). Bumping to `N=2` makes calls through
trait dispatch (`x.copy()` on a `Copyable` type) resolve to the
user's source line — but it *fails to compile* on direct call sites
because the chain only has 1 inline frame. There is no single
`inline_count` that works across both. Stick with the default and use
static `grep .copy\(\)` to map `value.mojo:122:20` traces back to user
call sites.

## Headline numbers

Full `--dev` run, ~80 benchmarks, 386 trace lines total:

| Type | Copies | Where |
|---|---:|---|
| `CompiledRegex` | 56 | `compile_regex` cache miss (`matcher.mojo:1279`) |
| `CompiledRegex` | 17 | `compile_regex` cache hit (`matcher.mojo:1271`) |
| `CompiledRegex` | 4 | `_compile_and_cache_with_key` cache miss (`matcher.mojo:1245`) |
| `HybridMatcher` | 77 | cascade from each `CompiledRegex.__copy__` |
| `DFAMatcher` | 77 | cascade |
| `NFAMatcher` | 77 | cascade |
| `BestLiteralInfo` | 77 | cascade |
| `MemchrPrefilter` | 1 | only patterns with viable memchr prefilter |
| `MatchList` | **0** | per-match container moved cleanly |
| `PrefilterLiteralInfo` | 0 | does not fire in this workload |

77 = 56 + 17 + 4 ≈ # of benchmark functions. Each cluster of 5 traces
corresponds to one `compile_regex` call.

## Architecture observations

1. **The hot match loop is zero-copy for all 8 instrumented types.**
   Benchmarks pre-compile the regex outside the timing loop, so the
   inner `match_first(text)` / `match_all(text)` calls do not trigger
   any of these copy ctors. If they did, a `--dev` run with
   thousands of iterations per benchmark would show hundreds of
   thousands of trace lines, not 386.

2. **`match_all` returns a `MatchList` with zero copy.** Move
   semantics on the return path are working correctly, even though
   the container can hold many `Match` entries.

3. **The high-level public API is already optimal.** `search`,
   `findall`, `match_first`, and `sub` route through
   `_compile_and_cache` which returns an
   `UnsafePointer[CompiledRegex, MutAnyOrigin]` to the cache entry.
   Zero copy on cache hit. The pointer-vs-value split is documented
   at `matcher.mojo:1208-1216`.

4. **The convenience function `compile_regex` (value-returning) does
   1 deep-copy per call**, even on cache hit (`compiled =
   regex_cache_ptr[][key]`). This cascades through the 5-struct
   hierarchy. Benchmarks call it once per benchmark function outside
   the timing loop, so it is invisible in numbers. User code that
   calls it in a hot loop would benefit from a `ref`-returning API,
   but that is an anti-pattern (the high-level API already exists).

## Conclusion

For benchmark performance: nothing actionable. The 5-struct cascade
per `compile_regex` call is the only candidate, and it doesn't show
up in the timing loop.

## Where to look next

Areas the 8-type trace did *not* cover, where real per-match
allocations may hide:

- **Capture groups**: `Optional[List[Optional[(Int, Int)]]]` and
  similar structures live inside the NFA simulation and may be
  allocated per match.
- **NFA simulation buffers**: state-set lists in `match_next_with_groups`.
- **Replacement template segments**: `List[_ReplSegment]` in `sub()`
  is parsed once per call but the per-match interpolation may
  allocate `String` results.
- **NFA dispatch overhead**: from a prior session, ~76% of
  `sub_group_word_swap` time is in `match_next_with_groups` recursion
  (15-20 dispatches per match). This is structural Mojo compilation
  cost, not copy cost.

To extend the trace, instrument the same way on the additional types.
The pattern is: add `@always_inline` to the copy ctor (if missing),
import `call_location` from `std.reflection.location`, and add
`print("COPY_TRACE <Type>", call_location())` at the top of the body.
