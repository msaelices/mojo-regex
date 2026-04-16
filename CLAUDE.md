# Claude guidance for mojo-regex

This file briefs future Claude sessions on how to work in this repo.
Keep it terse — load-bearing facts only. Everything here overrides
generic priors.

## Project shape

A pure-Mojo regex library with four dispatch paths:

- **DFA** (`src/regex/dfa.mojo`) — fastest, used for simple patterns
  that compile to a deterministic automaton.
- **NFA** (`src/regex/nfa.mojo`) — backtracking engine with literal
  prefiltering. Used for complex patterns when lazy DFA isn't
  applicable (e.g. `$` anchors).
- **PikeVM + LazyDFA** (`src/regex/pikevm.mojo`) — Thompson NFA
  simulation. `LazyDFA` caches state-set transitions for near-full-DFA
  speed after warmup. `MAX_STATES = 512`.
- **HybridMatcher** (`src/regex/matcher.mojo`) — `CompiledRegex` entry
  point. Dispatches to the right engine based on pattern complexity.

Routing happens in `src/regex/optimizer.mojo`. Literal extraction for
prefilters is in `src/regex/literal_optimizer.mojo`. SIMD primitives
(nibble scans, character class matchers) live in `src/regex/simd_ops.mojo`.

## Commands

| Task | Command |
|---|---|
| Run tests | `pixi run test` |
| Format code | `pixi run format` |
| Full bench (stable, ~4 min) | `mojo run -I src benchmarks/bench_engine.mojo` |
| Fast dev bench (~8 s, noisier) | `mojo run -I src benchmarks/bench_engine.mojo -- --dev` |
| Filtered bench | `mojo run -I src benchmarks/bench_engine.mojo -- --filter=<substr>` |

Benchmarks compose the flags: `-- --dev --filter=sub_` runs the `sub_*`
subset in dev mode for rapid iteration. See
`benchmarks/BENCHMARKING_GUIDE.md` for the full workflow.

**Never publish numbers from `--dev`**; it's 10x faster but noisier
(1 ms samples instead of 10 ms). Always do a full stable run before
committing benchmark deltas or updating `benchmarks/results/`.

## Performance change workflow

1. Identify the hot path (see `docs/optimization-opportunities-v2.md` /
   `v3.md` for open items; `docs/optimization-opportunities.md` for the
   history of what's already been tried).
2. Edit, run `pixi run test` — must be green before benchmarking.
3. Get a directional signal: `-- --dev --filter=<relevant>`.
4. If the signal is positive, run the full stable bench and compare
   to a freshly-measured baseline on the pre-change commit. The
   committed `benchmarks/results/mojo_results.json` is a long-lived
   reference that may be stale after infrastructure tweaks
   (e.g. `MIN_SAMPLE_NS` changes), so always re-measure the baseline
   in the same run; don't compare against the stored JSON alone.
5. Watch out for single-run noise on sub-µs benchmarks: ±30 % is
   normal. If a regression is isolated to one benchmark and the
   affected code path wasn't touched, it's probably noise. Re-run or
   run a 3× median pass before acting on it.

## Optimization audits

The authoritative list of open performance work is in
`docs/optimization-opportunities-v3.md`. When asked to find new
opportunities, read v1/v2/v3 first to avoid duplicating analysis, then
scrutinize the code directly — several v1/v2 items have been fixed or
were re-evaluated as not worth pursuing. See the "Items re-evaluated"
sections at the bottom of each doc for what was tried and dropped.

Be skeptical of agent-reported findings: verify each claim by reading
the cited lines before writing anything down. Common false positives
already encountered:
- SIMD broadcasts "inside loops" that are actually hoisted.
- `@always_inline` candidates that are recursive (Mojo rejects).
- Trait virtual dispatch "overhead" on `Optional[ConcreteType]` —
  Mojo devirtualizes.

## Git conventions

- One commit per topic. Don't mix refactor + logic + tests.
- Don't amend; stack new commits.
- No Claude attribution on commits or PRs (no `Co-Authored-By`, no
  "Assisted by Claude"). Project-level global rule — see
  `~/.claude/CLAUDE.md` for the user-wide version.
- Don't use the `—` character in messages; use `.` instead.
- The pre-commit hook (`.pre-commit-config.yaml`) is installed locally
  and runs `pixi run format` on every commit touching `.mojo` files.
  If the hook reformats files, the commit fails; re-add and commit
  again. To save the round-trip, run `pixi run format` before
  `git commit` on any `.mojo` change. CI runs the same hook.

## Mojo syntax notes

See the `mojo-syntax` skill for the full set, but the ones that bite
most often in this repo:

- `comptime` replaces `alias` and `@parameter`.
- `def` does **not** imply `raises`; add it explicitly.
- `@always_inline` errors on recursive functions — the compiler
  rejects them outright, not silently.
- Mojo `Dict` `__getitem__` raises even after a `in` check; wrap the
  subscript in `try/except` or propagate `raises` up.
- `sys.argv()` returns `Span[StaticString, StaticConstantOrigin]`.
- SIMD bit-pattern reinterpretation uses the free function
  `bitcast[dtype, size](value)` from `std.memory`, not a method.
