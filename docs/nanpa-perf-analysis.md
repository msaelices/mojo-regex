# NANPA Pattern Performance Analysis

## Problem

The US NANPA area code pattern (8 nested alternation branches with character
classes) is **28x slower than Python** on `match_first` and **31x slower** on
`findall`. This pattern is critical for phone number validation in
smith-phonenums.

## Root cause

**The NANPA pattern compiles to 290 PikeVM instructions, exceeding
`MAX_STATES = 128`.** The lazy DFA is disabled entirely, falling back to
the backtracking NFA with no prefiltering and no transition caching.

```
PikeVM instructions: 290
MAX_STATES:           128
Lazy DFA:             NOT AVAILABLE
Literal prefilter:    NONE
```

## Profile data (10-digit number "6502530000")

| Operation | Mojo (us) | Python (us) | Ratio |
|-----------|----------|------------|-------|
| `match_first` | 5.5 | 0.198 | **28x slower** |
| `match_next` (search) | 22.8 | 0.288 | **79x slower** |
| `findall` (60 matches) | 1059 | 34.7 | **31x slower** |
| `\d{10}` match_first | 0.006 | — | baseline |

NANPA is 987x slower than `\d{10}` on the same 10-byte input. The entire
cost is in the backtracking NFA recursive descent through 8 branches.

## Comparison: flexible_phone (19 instructions, lazy DFA enabled)

| Pattern | Instructions | Lazy DFA | match_first |
|---------|-------------|----------|-------------|
| `\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}` | 19 | Yes | ~0.05 us |
| NANPA (full) | 290 | No | 5.5 us |

## Fix options

### Option 1: Increase MAX_STATES to 512 (simplest)

Change `comptime MAX_STATES = 128` to `comptime MAX_STATES = 512`.

**Impact:**
- NANPA (290 instructions) would fit: lazy DFA enabled
- `SIMD[uint8, 512]` = 512 bytes per NFA state set (was 128)
- `CachedState` grows from ~2.2KB to ~2.6KB
- `_add_state` epsilon closure uses `SIMD[uint8, MAX_STATES]` on the stack
  per recursive call — 512 bytes instead of 128 bytes per frame
- Covers all current real-world patterns (NANPA is the most complex)

**Risk:** Higher stack usage in `_add_state` recursion. For deeply nested
patterns, the epsilon closure chain could be 10-20 frames deep x 512 bytes
= 5-10KB stack. Acceptable.

### Option 2: Sparse NFA state representation

Replace `SIMD[uint8, MAX_STATES]` with a sparse representation:
- `InlineArray[UInt16, 64]` of active PC indices + count
- `SIMD[uint8, 16]` bloom filter for fast membership check

This would support unlimited program sizes without increasing struct size.
More complex to implement but architecturally cleaner.

### Option 3: Extend DFA compiler for nested alternation

The optimizer now correctly classifies NANPA as COMPLEX. But a DFA could
handle it if the DFA compiler were extended to:
1. Build a state machine from nested `(?:...|...)` groups
2. Handle character classes in alternation branches

This would give O(1) per-byte matching like Python/Rust. Most complex to
implement but highest payoff.

## Recommendation

**Start with Option 1** (increase MAX_STATES to 512). It's a one-line
change that immediately enables the lazy DFA for NANPA, likely bringing
Mojo within 2-5x of Python on this pattern. If that's not enough,
Option 2 or 3 can be pursued later.
