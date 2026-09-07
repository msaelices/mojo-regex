# Road to 1.0

## What 1.0 means here

`1.0.0` is a **commitment to a stable public API under SemVer**: after it, any
breaking change costs a major version (2.0). It is *not* a statement about
engine quality (the engine already beats Python's `re` and Rust's `regex` on
the benchmark suite, with 389 tests) and it is deliberately **not** tied to the
Mojo compiler reaching 1.0. The library and the compiler version independently.

We are on `0.x` on purpose: the public surface is small and mature, but it is
missing features that users coming from `re` expect, and adding them will shape
the public API. Freezing now would either lock in an incomplete API or force a
fast 2.0. The gate below is what makes a 1.0 commitment honest.

Current public surface (what a freeze would lock):

- Functions: `search`, `match_first`, `findall`, `sub`, `compile_regex`, and the
  comptime `regex.comptime_regex.search / match_first / findall`.
- Types: `Match` (exposes `get_match_text()`, `group_id`), `MatchList`.

Two structural gaps stand out and both must be settled **before** a freeze:
there is no **flags** mechanism at all, and `Match` has **no capture-group
accessor** (`m.group(n)`), only the whole match.

## The 1.0 gate (must land and bake before 1.0)

Ordered by "shapes the public API" first, since those are the ones a freeze
can't take back.

### 1. Capture-group access on `Match` (API-shaping)

- **Why**: table stakes for a regex library. Today a user can match `(\d{3})-(\d{4})`
  but cannot read group 1. Only `sub`'s `\1` interpolation uses group spans, and
  only internally.
- **API impact**: additive but load-bearing. Adds `Match.group(i) -> Optional[StringSlice]`
  (and `Match.group_span(i)`), plus a way to get the group count. This is the
  single biggest reason not to freeze yet.
- **Engine impact**: capture spans already exist inside the NFA/PikeVM path for
  `sub`; this is mostly exposing them on `Match`.
- **Risk**: low engine risk, high API-design importance.

### 2. Named groups `(?<name>...)`

- **Why**: common, and it extends the same Match accessor.
- **API impact**: additive, `Match.group("name")`. Best designed *together with*
  item 1 so the accessor shape is right the first time.
- **Engine impact**: parser stores names, capture storage keyed by index/name.

### 3. Flags mechanism + case-insensitive (the keystone)

- **Why**: `re.IGNORECASE` is the most-requested missing feature; the same
  mechanism unlocks **multiline** (`(?m)`) and **dot-all** (`(?s)`) for free.
- **API impact**: this is the one real design decision.
  - **Inline flags `(?i)` / `(?im)`**: **zero API change**, pure pattern syntax.
    Do this first.
  - **A `flags` argument**: additive at runtime (`search(pattern, text, flags=IGNORECASE)`),
    but on the **comptime** API it means `search[pattern, flags]` (flags as a
    comptime parameter, with a default). Additive but it touches every comptime
    signature, so decide it before the freeze.
- **Engine impact**: parser recognizes the flags; case-insensitivity folds case
  at the literal / character-class level, which interacts with the SIMD
  character-class matchers (case-folded lookup tables). This is the heaviest
  engine work of the gate.
- **Recommendation**: land inline `(?i)` first (no API cost), then add the
  `flags` argument (runtime + comptime) as a second step.

### 4. Non-greedy quantifiers `*?` `+?` `??` `{n,m}?`

- **Why**: extremely common; users hit it immediately.
- **API impact**: **none** (pure pattern syntax).
- **Engine impact**: a "lazy" flag on the quantifier; flips backtracking order in
  the NFA and thread priority in the PikeVM. The DFA path is unaffected
  (no submatch).
- **Risk**: low API risk, high value → do early.

### 5. Word boundaries `\b` `\B`

- **Why**: common.
- **API impact**: **none** (pattern syntax).
- **Engine impact**: a zero-width assertion that inspects neighbouring
  characters. `^` / `$` anchors already provide the zero-width-assertion
  scaffolding to build on.
- **Risk**: low API risk.

## Not gating 1.0 (post-1.0 or opportunistic)

These are genuinely additive and can land on `0.x` or after 1.0 without
reshaping the frozen API:

- **`split()`**: a new top-level function. Easy, additive, land whenever.
- **Negated predefined classes `\S` `\D` `\W`**: pattern syntax, additive.
- **Multiline / dot-all**: arrive with the flags mechanism (item 3).
- **Unicode character classes `\p{L}` `\p{N}`**: large (Unicode tables, memory
  footprint). Post-1.0.
- **Lookahead / lookbehind**: hard engine work. Post-1.0, possibly a 2.0-era
  feature.

## Proposed sequencing

The versions are a guide, not a contract; group by API impact so the freeze
lands on a settled surface.

- **0.22.0** - Non-greedy quantifiers + word boundaries + `split()`. High value,
  zero/low public-API impact. Good momentum, low risk.
- **0.23.0** - Capture-group access on `Match` + named groups. **Freezes the
  `Match` API** deliberately.
- **0.24.0** - Flags mechanism: inline `(?i)` then the `flags` argument
  (runtime + comptime) → case-insensitive, multiline, dot-all.
- **1.0.0** - API freeze, once the above have shipped and baked for a cycle.
  A deliberate, documented milestone. Mark `comptime_regex` stable or keep it
  explicitly experimental behind that line.

## Guiding principles

1. **1.0 is an API-freeze commitment**, not a quality badge and not a mirror of
   the Mojo compiler version.
2. **Settle API-shaping items (groups, flags) before the freeze**; land
   pattern-syntax-only features (non-greedy, `\b`) whenever, since they cost no
   API.
3. Keep the "runs on stable Mojo 1.0" milestone in the CHANGELOG (v0.21.0),
   not in the library's own version number.
