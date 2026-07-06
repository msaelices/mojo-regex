# Comptime regex: compile-time pattern specialization, revisited

Date: 2026-07-04
Status: steps 1-3 implemented (PRs #167, #168, #169;
`src/regex/comptime_regex.mojo`, paired `ct_*`/`rtapi_*` benchmarks in
`bench_engine.mojo`). Step 4 (re-probe the envelope on toolchain bumps)
is ongoing maintenance. Measured (stable, 3-run medians): short-input
matching 1.4-1.9x faster than the runtime API; long-input parity.
Supersedes: PR #54 (closed)

> Implementation note (post step 1): the probe cannot try/except its
> way through the char-class path. The `_Global` FFI call is a *hard*
> comptime-interpreter error, not a catchable exception, so step 1
> whitelisted AST node types before attempting the comptime DFA build.
>
> Post step 2: `compile_dfa_pattern[use_matcher_cache=False]` constructs
> SIMD matchers directly (no `_Global`), which removed the whitelist
> entirely: char classes, negated classes, shorthands, wildcards,
> bounded quantifiers and multi-class sequences all build at comptime,
> and every remaining DFA rejection is a catchable raise that falls
> back to the runtime engine. `is_compile_time()` exists in newer
> nightlies (`kgen.is_compile_time` is unregistered on this pin) and
> would let the cache branch internally; revisit on the next bump.

## TL;DR

Mojo's comptime interpreter can now run this library's *real* parser
and *real* DFA compiler at compile time, and `materialize[...]()` can
embed the resulting transition tables into the binary. This makes a
CTRE-style API possible:

```mojo
var m = regex.search[r"^hello (world|mojo)$"](text)
```

with zero runtime pattern compilation, zero per-call cache lookup
(no hash, no Dict probe), invalid patterns rejected at *compile time*,
and a compile-time fallback to the existing runtime engine for
patterns the DFA cannot handle.

Everything in this document was verified empirically on the pinned
toolchain (`1.0.0b3.dev2026062806`). The one blocker for character
classes is a library-level issue (the `_Global` SIMD-matcher cache),
not a language limitation.

## Background: what PR #54 was and why it was closed

PR #54 ("Compile-Time Pattern Specialization", 2025-09) introduced a
`CompileTimeMatcher` that, despite the name, performed *runtime*
metacharacter scanning plus `text.find()`. The parametric
`[pattern: StaticString]` functions in that diff were never wired into
the dispatch. Its measured wins came from bypassing the engine for
literal patterns, which main has since gained through the literal
prefilter and DFA work. The implementation was therefore superseded;
this proposal revives the *idea* with the machinery Mojo has today.

## Experiments

Three experiments, run on this repo with `mojo run -I src`. The
sources are reproduced inline so the results can be re-checked when
the toolchain moves.

### 1. Comptime heap code + materialization

The comptime interpreter executes ordinary heap-allocating Mojo
(`List`, `unsafe_ptr` reads), and the result can be materialized to
runtime:

```mojo
def _build_table(pattern: StringSlice) -> List[Int]:
    var n = pattern.byte_length()
    var table = List[Int]()
    for _ in range((n + 1) * 256):
        table.append(0)
    var ptr = pattern.unsafe_ptr()
    for state in range(n):
        table[state * 256 + Int(ptr[state])] = state + 1
    return table^

comptime PATTERN: StaticString = "hello"
comptime TABLE = _build_table(PATTERN)

def main() raises:
    var table = materialize[TABLE]()   # 1536-entry table, built at comptime
    ...
```

Result: works. Notes:

- `List[Int]` is not `ImplicitlyCopyable`, so materialization must be
  explicit: `materialize[TABLE]()`. The compiler error message
  suggests exactly this.
- Each `materialize` call is a runtime copy. Hot paths must hoist it
  (see Design).

### 2. The real parser runs at comptime

```mojo
from regex.parser import parse

def _count_ast_nodes(pattern: String) -> Int:
    try:
        var ast = parse(pattern)
        return Int(ast.get_children_len())
    except:
        return -999

comptime N_NODES = _count_ast_nodes("a[bc]+(x|y)$")   # evaluates: 1
```

Result: works. The interpreter handles the full parser, including the
self-referential `Regex` arena, `alloc`, `UnsafePointer` writes, and
destructors. Two constraints surfaced:

- **Raising functions cannot initialize a `comptime` value.** The
  parser is `raises`, so the comptime entry point must be a
  non-raising shim with `try`/`except`. In the real implementation the
  except arm feeds a `comptime assert`, which turns an invalid pattern
  into a compile error (a DX win no runtime engine can offer).

### 3. Full CTRE pipeline: comptime parse + comptime DFA + runtime match

```mojo
from regex.parser import parse
from regex.dfa import DFAState, compile_dfa_pattern

def _build_dfa_states(pattern: String) -> List[DFAState]:
    try:
        var ast = parse(pattern)
        var engine = compile_dfa_pattern(ast)
        return engine.states.copy()
    except:
        return List[DFAState]()

comptime PATTERN = "hello"
comptime STATES = _build_dfa_states(PATTERN)

def main() raises:
    var states = materialize[STATES]()
    # pure table-walk over states[...].transitions, no compilation
```

Result: works end to end. `parse` + `compile_dfa_pattern` produced a
6-state DFA at compile time; the runtime walk matched `"say hello
world"` correctly. `DFAState` materializes cleanly because it is
`ImplicitlyCopyable + RegisterPassable` plain data (a
`SIMD[DType.int32, 256]` transitions row plus scalars).

### Pattern envelope (what builds at comptime today)

| Pattern | Comptime DFA build |
|---|---|
| `hello` (literal) | OK, 6 states |
| `^abc$` (anchors) | OK, 4 states |
| `a+b*` (quantifiers) | OK, 3 states |
| `(x|y)` (alternation) | OK, 2 states |
| `[0-9]+`, `h[ae]llo` (char classes) | **blocked**, see below |

The character-class failure is *not* an interpreter capability limit.
That path calls `_SIMD_MATCHERS_GLOBAL.get_or_create_ptr()`, and the
`_Global` storage bottoms out in the external runtime call
`KGEN_CompilerRT_GetOrCreateGlobal`, which the comptime interpreter
refuses ("unable to interpret call to unknown external function").
FFI is the hard comptime boundary. A comptime-friendly code path that
constructs `CharacterClassSIMD` directly, bypassing the process-global
cache, unlocks the whole char-class family. (`h[ae]llo` additionally
hits "Pattern too complex for current DFA implementation" at runtime
too, so it is out of scope for the DFA either way.)

Build-time cost: four comptime pattern compilations added no
measurable wall-clock over the baseline library compile (~7 s total
for compile + run of the probe file).

## Design

### Public API

A parallel comptime API alongside the existing runtime one:

```mojo
# pattern as a parameter, not an argument
def search[pattern: StaticString](text: String) raises -> Optional[Match]
def match_first[pattern: StaticString](text: String) raises -> Optional[Match]
def findall[pattern: StaticString](text: String) raises -> MatchList
```

### Dispatch at compile time

Per instantiation, a comptime probe classifies the pattern:

```mojo
comptime _CT_DFA = _try_build_dfa(pattern)   # non-raising shim
comptime if _CT_DFA.ok:
    # walk the materialized static tables
else:
    # fall through to the existing runtime CompiledRegex path
    # (global cache, HybridMatcher), semantics identical
```

The fallback keeps full feature parity: anything the DFA path cannot
express (groups with captures, complex classes, lazy quantifiers)
still works, just without the comptime specialization. This mirrors
how the runtime `HybridMatcher` already routes DFA vs NFA, moved one
level earlier.

Invalid patterns: the probe carries the parse error, and a
`comptime assert _CT_DFA.parse_ok, _CT_DFA.error` turns typos into
compile errors instead of runtime exceptions.

### Materialization strategy (the one perf trap)

`materialize[...]()` copies per call, so the specialized matcher must
not materialize inside `search`. Options, in preference order:

1. Store the tables as a module-level `comptime` constant of an
   `InlineArray[DFAState, N]` (N is comptime-known), which lands in
   static data and is indexable without a heap copy.
2. If `InlineArray` proves awkward for large N, materialize once into
   a per-pattern `_Global` at first use (runtime cost: one copy per
   process instead of per call, still no compilation).

Measuring which of these LLVM folds better is part of the
implementation work. For small DFAs the static-data route also gives
the optimizer visibility to unroll the state loop entirely.

### Library refactor required

`compile_dfa_pattern` (and the helpers it calls) must avoid the
`_Global` SIMD-matcher cache when running at comptime. Sketch: give
`CharacterClassSIMD` construction a direct path and select it with a
`comptime if is_comptime()` (or pass a comptime flag down from the
probe). Runtime behavior and the cache stay exactly as they are.

## Expected wins

- **No first-call compile**: today the first `search(pattern, text)`
  pays parse + DFA/NFA construction; the comptime path pays it at
  build time instead.
- **No per-call cache lookup**: the runtime API hashes the pattern and
  probes the global `Dict` on every call (`matcher.mojo`,
  `_compile_and_cache`). The comptime path removes hash, probe, and
  the associated locking entirely.
- **Static tables**: transition tables in read-only static data,
  shared across the process, no heap, plus constant-folding
  opportunities for tiny automata.
- **Compile-time pattern validation**: malformed patterns fail the
  build with the parser's error message.

The realistic benefit concentrates in short-text, hot-loop matching
where per-call overhead dominates the actual automaton walk. For long
texts the walk dominates and the comptime path converges with the
runtime DFA. Benchmarks must therefore include short-input cases
(e.g. validating a phone/email field) and not only the 10 KB corpus
benchmarks.

## Implementation plan

1. `src/regex/comptime_regex.mojo`: probe shims, materialization
   strategy, `search`/`match_first`/`findall` parametric entry points.
   Envelope: literals, anchors, quantifiers, alternations (all verified
   working today). Fallback to runtime engine otherwise.
2. Refactor the char-class SIMD matcher construction to offer a
   cache-free direct path, unlocking `[...]` classes at comptime.
3. Benchmarks: `bench_engine.mojo` gains comptime variants of the
   literal + short-input benchmarks; compare against the runtime
   cached path (which is the honest baseline, not the first-call
   path).
4. Re-probe the envelope on each toolchain bump: the comptime
   interpreter is evolving quickly, and constraints (raising comptime
   initializers, FFI) may relax.

## Risks

- **Interpreter churn**: comptime semantics are still moving between
  nightlies; the probe shims should live behind one module so
  breakage is localized.
- **Binary size**: each instantiated pattern embeds its tables
  (a 6-state DFA row is 256 x int32 = 1 KB per state). Acceptable for
  typical pattern counts; worth documenting.
- **Compile time**: negligible per pattern today, but a project with
  hundreds of comptime patterns should be measured before this is
  advertised as free.
