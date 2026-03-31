# Proposal: PikeVM (Thompson NFA Simulation) for mojo-regex

## Problem Statement

After optimizing DFA routing, SIMD character matching, and fast paths for
`.*` patterns, mojo-regex beats Python on 85% of benchmarks (52/9). The
remaining 7 losses are all NFA backtracking patterns:

| Benchmark | Mojo/Python | Root cause |
|-----------|------------|------------|
| `multi_format_phone` | 3.4x slower | 3-branch alternation with quantifiers |
| `phone_validation` | 3.3x slower | Optional groups + quantifiers |
| `flexible_phone` | 2.9x slower | Optional groups + alternation |
| `alternation_quantifiers` | 2.7x slower | Top-level OR with captures |
| `required_literal_short` | 2.5x slower | `.*` prefix (partially mitigated) |
| `optimize_range_quantifier` | 1.8x slower | Range quantifier `{2,4}` |
| `range_lowercase` | 1.7x slower | Noise |

The backtracking NFA in `nfa.mojo` has **O(n * 2^m)** worst-case time
(n = text length, m = pattern complexity). It tries one path through the
AST, fails, backtracks, tries another. For patterns with alternation +
quantifiers, this creates exponential work per text position.

## Current Architecture

```
Pattern -> Parser -> AST -> Optimizer -> Complexity classification
                                            |
                           SIMPLE ----------+---------- MEDIUM/COMPLEX
                              |                              |
                         DFA compiler                   NFA engine
                        (state machine)            (recursive backtracking)
                              |                              |
                    match_first/next/all              match_first/next/all
```

The DFA path is fast (O(n)) but limited to patterns the compiler can handle.
The NFA path handles everything but uses recursive AST traversal with
explicit backtracking, which is:

1. **Exponential in the worst case** - alternation tries branches sequentially
2. **High per-step overhead** - each character match walks the AST tree via
   `_match_node` -> `_match_or` -> `_match_group` -> `_match_element`
3. **No parallelism** - only one path explored at a time

## How Rust Does It

Rust's `regex-automata` crate uses a **tiered engine strategy**:

1. **Full DFA** - precompiled state machine, fastest, no captures
2. **Lazy DFA** - builds DFA states on demand from NFA, caches in hash map
3. **One-pass DFA** - captures for unambiguous patterns
4. **PikeVM** - Thompson NFA simulation, handles everything, captures
5. **Bounded backtracker** - traditional backtracking with depth limit

The meta engine tries the fastest capable engine first. For patterns like
`\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}` (flexible phone), Rust uses the
lazy DFA which achieves near-DFA speed after warmup.

## Proposed Solution: PikeVM

### What is PikeVM?

PikeVM (named after Rob Pike's implementation in `sam`) simulates a Thompson
NFA by tracking **all active states simultaneously**. Instead of following
one path and backtracking, it runs all alternatives in parallel:

```
Traditional backtracking NFA:
  Try path A -> fail -> backtrack -> try path B -> fail -> backtrack -> ...
  Time: O(2^m) per text position

Thompson NFA (PikeVM):
  Process all active states at once for each input byte
  Time: O(m) per text position (m = number of NFA states)
```

### How It Works

1. **Compile AST to bytecode** - flat array of instructions:
   ```
   BYTE(c)      - match literal byte c
   RANGE(lo,hi) - match byte in range [lo,hi]
   SPLIT(x,y)   - fork: add both x and y to active states
   JUMP(x)      - unconditional jump to x
   MATCH        - accepting state
   SAVE(slot)   - record position in capture slot
   ```

2. **Execution loop** - two state lists (current / next):
   ```
   current_states = {start_state}
   for each byte in text:
     next_states = {}
     for each state in current_states:
       match instruction at state:
         BYTE(c):  if byte == c, add state+1 to next_states
         RANGE:    if byte in range, add state+1 to next_states
         SPLIT:    add both targets to current_states (epsilon closure)
         JUMP:     add target to current_states
         MATCH:    record match
         SAVE:     record position, add state+1 to current_states
     current_states = next_states
   ```

3. **Guarantees**: O(n * m) time, O(m) space per step. No backtracking.

### Capture Groups

PikeVM natively supports captures by carrying a capture slot vector per
"thread" (active state). When a SAVE instruction is hit, the current
position is recorded in the thread's slots. When MATCH is reached, the
winning thread's slots give the capture group boundaries.

This is important for future `captures()` API support.

## Alternative: Lazy DFA

### How It Works

A lazy DFA starts from the NFA but caches DFA states (each being a set of
NFA states) in a hash table. On each input byte:

1. Look up current DFA state + byte in cache
2. If found, transition directly (O(1))
3. If not found, compute the NFA epsilon closure, create new DFA state, cache it

After warmup (processing a few hundred bytes), most transitions hit the cache
and the engine runs at near-DFA speed.

### Trade-offs vs PikeVM

| Aspect | PikeVM | Lazy DFA |
|--------|--------|----------|
| Implementation | ~500-800 lines | ~1000-1500 lines |
| Prerequisite | None (new engine) | Needs PikeVM's bytecode format |
| Worst-case time | O(n * m) | O(n * m) (cache miss) to O(n) (cache hit) |
| Steady-state speed | ~2-5x slower than DFA | ~1.1-1.5x slower than full DFA |
| Capture groups | Native support | Falls back to PikeVM |
| Memory | O(m) per step | O(states_seen) cache, can grow large |
| Complexity | Simple | Complex (cache eviction, state dedup) |

## Recommendation

**Implement PikeVM first**, then optionally add lazy DFA later.

### Rationale

1. **PikeVM is a prerequisite for lazy DFA** - both need the NFA bytecode
   instruction format. Building PikeVM first gives us the foundation.

2. **Eliminates the dominant cost** - the exponential backtracking is the
   main problem (10-100x overhead). PikeVM removes it entirely.

3. **Supports capture groups** - needed for future `captures()` API.
   Lazy DFA cannot do this natively.

4. **Simpler to implement correctly** - PikeVM is ~500 lines of straightforward
   state-list processing. Lazy DFA adds ~500-700 lines of caching complexity
   with subtle correctness concerns (cache invalidation, memory limits).

5. **Proven architecture** - PikeVM is used in RE2, Go's `regexp`, Rust's
   `regex-automata`, and many other production regex engines.

### Expected Impact

| Pattern | Current | With PikeVM | Improvement |
|---------|---------|-------------|-------------|
| `flexible_phone` | 2.9x slower than Python | ~1x (parity) | ~3x |
| `multi_format_phone` | 3.4x slower | ~1-2x slower | ~2-3x |
| `phone_validation` | 3.3x slower | ~1x (parity) | ~3x |
| `alternation_quantifiers` | 2.7x slower | ~1x (parity) | ~3x |

Conservative estimates. The actual improvement depends on the NFA bytecode
compilation quality and the PikeVM loop overhead.

### Implementation Plan

1. **Phase 1: NFA bytecode compiler** (~200 lines)
   - Convert AST to flat instruction array
   - Instructions: BYTE, RANGE, SPLIT, JUMP, MATCH, ANY, SAVE
   - Reuse existing AST parsing infrastructure

2. **Phase 2: PikeVM executor** (~300 lines)
   - Two-list state simulation with epsilon closure
   - match_first, match_next, match_all entry points
   - No capture support initially

3. **Phase 3: Integration** (~100 lines)
   - Route MEDIUM/COMPLEX patterns to PikeVM instead of backtracking NFA
   - Keep backtracking NFA as fallback for unsupported features
   - Benchmark and validate

4. **Phase 4 (optional): Capture groups** (~200 lines)
   - Per-thread capture slot vectors
   - SAVE instruction support
   - `captures()` API

5. **Phase 5 (optional): Lazy DFA** (~700 lines)
   - State cache on top of PikeVM bytecode
   - Route non-capture operations through lazy DFA
   - Cache eviction policy

### Risk Assessment

- **Low risk**: PikeVM is a well-understood algorithm with 50+ years of
  production use. The bytecode format is simple and testable.
- **Medium risk**: Integration with existing DFA/NFA routing may surface
  edge cases in pattern classification.
- **Mitigation**: Keep backtracking NFA as fallback. Route incrementally,
  one pattern class at a time.
