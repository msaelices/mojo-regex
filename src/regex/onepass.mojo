"""
OnePass NFA: DFA-like execution for patterns without ambiguity.

A regex is "one-pass" if at every state, for every input byte, at most one
forward transition fires. Such patterns can be run in O(n) per byte with
no backtracking, no state-set tracking, and no per-call setup. This is
dramatically faster than the backtracking NFA or the PikeVM on patterns
like `^\\+?1?[\\s.-]?\\(?([2-9]\\d{2})\\)?[\\s.-]?([2-9]\\d{2})[\\s.-]?(\\d{4})$`
where every optional group is unambiguously distinguishable by the next
byte.

Unlike `LazyDFA`, this engine:
- Compiles all transitions ahead of time (eagerly), so there is no
  cache-miss cost during matching.
- Handles `$` anchor correctly by keeping `OP_END_ANCHOR` in the state
  set and firing it only at `pos == text_len`, whereas `LazyDFA` drops
  `OP_END_ANCHOR` from cached state sets (correctness issue PR #132).
- Rejects patterns that are not one-pass (returns `None` from
  `compile_onepass`), in which case callers fall back to `LazyDFA` or
  the backtracking NFA.

The compilation is effectively a subset construction from PikeVM
bytecode, with an added ambiguity check: if any byte can fire more than
one distinct follow-up closure, the pattern is rejected.
"""

from std.memory import alloc, UnsafePointer

from regex.matching import Match, MatchList
from regex.aliases import ImmSlice
from regex.pikevm import (
    Program,
    Instruction,
    OP_BYTE,
    OP_RANGE,
    OP_CLASS,
    OP_ANY,
    OP_SPLIT,
    OP_JUMP,
    OP_MATCH,
    OP_START_ANCHOR,
    OP_END_ANCHOR,
    MAX_STATES,
)


comptime ONEPASS_DEAD = -1
"""Special state id: no match can start from here."""

comptime ONEPASS_MAX_STATES = 512
"""Upper bound on compiled OnePass state count. Beyond this the engine
declines to build (returns `None` from `compile_onepass`); the caller
falls back to `LazyDFA` or the backtracking NFA. Realistic one-pass
patterns compile to tens of states; the limit guards against pathological
blow-ups."""


fn _epsilon_close(
    program: Program,
    read start_pcs: InlineArray[Int, MAX_STATES],
    start_count: Int,
    at_start: Bool,
) -> SIMD[DType.uint8, MAX_STATES]:
    """Compute the set of PCs reachable from `start_pcs` via epsilon
    transitions only. Byte-consuming ops (OP_BYTE, OP_CLASS, OP_ANY,
    OP_RANGE) and `OP_END_ANCHOR` are kept in the closure (they are
    "waiting for input" or "waiting for end of text"); all other ops
    are traversed.

    `at_start` controls whether `OP_START_ANCHOR` is fired (true at
    position 0, false elsewhere).
    """
    var result = SIMD[DType.uint8, MAX_STATES](0)
    var stack = InlineArray[Int, MAX_STATES](uninitialized=True)
    var stack_len = start_count
    for i in range(start_count):
        stack[i] = start_pcs[i]
    var prog_len = len(program)
    while stack_len > 0:
        stack_len -= 1
        var pc = stack[stack_len]
        if pc < 0 or pc >= prog_len or result[pc] != 0:
            continue
        result[pc] = 1
        ref inst = program.instructions[pc]
        if inst.opcode == OP_SPLIT:
            stack[stack_len] = inst.arg0
            stack_len += 1
            stack[stack_len] = inst.arg1
            stack_len += 1
        elif inst.opcode == OP_JUMP:
            stack[stack_len] = inst.arg0
            stack_len += 1
        elif inst.opcode == OP_START_ANCHOR:
            if at_start:
                stack[stack_len] = pc + 1
                stack_len += 1
        # OP_END_ANCHOR, OP_BYTE, OP_CLASS, OP_ANY, OP_RANGE, OP_MATCH:
        # do not advance past; remain in the closure.
    return result


fn _set_contains_match(
    program: Program,
    nfa_set: SIMD[DType.uint8, MAX_STATES],
) -> Bool:
    """True iff any PC in `nfa_set` is an OP_MATCH instruction."""
    for pc in range(len(program)):
        if nfa_set[pc] != 0:
            if program.instructions[pc].opcode == OP_MATCH:
                return True
    return False


@always_inline
fn _hash_set(nfa_set: SIMD[DType.uint8, MAX_STATES]) -> UInt64:
    """Hash of the state set bytes for O(1) dedup during subset
    construction. Bitcasts the 512-byte set to uint64 lanes, XORs against
    per-lane mixers (breaks lane symmetry), XOR-reduces to one u64 via
    AVX2 `vpxor`, then finishes with a single scalar FNV-style mix.
    Collisions fall through to an explicit equality check in
    _find_or_add_state."""
    from std.memory import bitcast

    comptime NUM_U64 = MAX_STATES // 8

    # Per-lane mixers: two states with identical non-zero data in
    # different lane positions must hash differently. All constants fold
    # to .rodata.
    var mixers = SIMD[DType.uint64, NUM_U64](0)
    comptime for i in range(NUM_U64):
        mixers[i] = UInt64(i + 1) * 0x9E3779B97F4A7C15

    var u64_view = bitcast[DType.uint64, NUM_U64](nfa_set)

    @parameter
    fn xor_op[
        w: Int
    ](a: SIMD[DType.uint64, w], b: SIMD[DType.uint64, w]) -> SIMD[
        DType.uint64, w
    ]:
        return a ^ b

    # XOR reduction is native on AVX2 (vpxor on ymm registers). A SIMD
    # multiply over 64 u64 lanes would fall back to scalar without
    # AVX-512 (vpmullq), so skip it in the reduction and apply one
    # scalar mix to diffuse bits at the end.
    var reduced = (u64_view ^ mixers).reduce[xor_op]()
    return (reduced ^ 0xCBF29CE484222325) * 0x100000001B3


def compile_onepass(
    var program: Program,
) -> UnsafePointer[OnePassNFA, MutAnyOrigin]:
    # Compile a PikeVM program into a OnePass NFA and heap-allocate it.
    # Returns a null pointer when the pattern is not one-pass (caller
    # falls back to another engine).
    #
    # Walks the state-set graph starting from the epsilon closure of
    # PC 0 with at_start=True. For each state and each input byte,
    # collects the PCs whose byte-consuming op fires. If more than one
    # PC fires and their follow-up epsilon closures differ, the pattern
    # is not one-pass and this function returns null. State dedup is by
    # nfa_set equality; a linear scan suffices since typical programs
    # produce <50 states.
    var prog_len = len(program)
    if prog_len == 0 or prog_len > MAX_STATES:
        return UnsafePointer[OnePassNFA, MutAnyOrigin]()

    var has_start_anchor = False
    var has_end_anchor = False
    for i in range(prog_len):
        ref op = program.instructions[i].opcode
        if op == OP_START_ANCHOR:
            has_start_anchor = True
        elif op == OP_END_ANCHOR:
            has_end_anchor = True

    # Seed the worklist with the start state.
    var start_pcs = InlineArray[Int, MAX_STATES](uninitialized=True)
    start_pcs[0] = 0
    var start_set = _epsilon_close(program, start_pcs, 1, at_start=True)
    var states = List[OnePassState](capacity=32)
    states.append(
        OnePassState(start_set, _set_contains_match(program, start_set))
    )
    var state_index = Dict[UInt64, List[Int]]()
    try:
        state_index[_hash_set(start_set)] = [0]
    except:
        pass

    var worklist = List[Int](capacity=32)
    worklist.append(0)

    # Temporary buffers reused per state.
    var next_pcs = InlineArray[Int, MAX_STATES](uninitialized=True)
    var first_pcs = InlineArray[Int, MAX_STATES](uninitialized=True)
    var other_pcs = InlineArray[Int, MAX_STATES](uninitialized=True)

    # Per-state scratch: list of "active" PCs (those marked in nfa_set
    # with a byte-consuming op). Filtering once per state is O(prog_len);
    # the inner byte loop then only touches the (typically small) active
    # set instead of probing all PCs for every byte.
    var active_pcs = InlineArray[Int, MAX_STATES](uninitialized=True)

    while len(worklist) > 0:
        var state_id = worklist[len(worklist) - 1]
        _ = worklist.pop()
        var cur_set = states[state_id].nfa_set
        var transitions = InlineArray[Int, 256](fill=ONEPASS_DEAD)

        # Collect byte-consuming PCs once per state.
        var active_count = 0
        for pc in range(prog_len):
            if cur_set[pc] == 0:
                continue
            var opc = program.instructions[pc].opcode
            if (
                opc == OP_BYTE
                or opc == OP_CLASS
                or opc == OP_ANY
                or opc == OP_RANGE
            ):
                active_pcs[active_count] = pc
                active_count += 1

        for byte in range(256):
            # For each byte, walk only the active byte-consuming PCs.
            var next_count = 0
            for i in range(active_count):
                var pc = active_pcs[i]
                ref inst = program.instructions[pc]
                var fires = False
                if inst.opcode == OP_BYTE:
                    fires = byte == inst.arg0
                elif inst.opcode == OP_CLASS:
                    fires = program.class_tables[inst.arg0][byte] != 0
                elif inst.opcode == OP_ANY:
                    fires = byte != 10  # `.` excludes newline
                elif inst.opcode == OP_RANGE:
                    fires = inst.arg0 <= byte <= inst.arg1
                if fires:
                    next_pcs[next_count] = pc + 1
                    next_count += 1

            if next_count == 0:
                continue  # DEAD (already initialised to ONEPASS_DEAD)

            # One-pass check: all firing PCs must lead to the same
            # epsilon closure; otherwise this byte has ambiguous
            # successors and the pattern is not one-pass.
            var is_new = False
            var idx: Int
            if next_count == 1:
                first_pcs[0] = next_pcs[0]
                var new_set = _epsilon_close(
                    program, first_pcs, 1, at_start=False
                )
                idx = _find_or_add_state(
                    program, states, state_index, new_set, is_new
                )
            else:
                first_pcs[0] = next_pcs[0]
                var first_closure = _epsilon_close(
                    program, first_pcs, 1, at_start=False
                )
                var one_pass = True
                for i in range(1, next_count):
                    other_pcs[0] = next_pcs[i]
                    var other_closure = _epsilon_close(
                        program, other_pcs, 1, at_start=False
                    )
                    if not first_closure.eq(other_closure).reduce_and():
                        one_pass = False
                        break
                if not one_pass:
                    return UnsafePointer[OnePassNFA, MutAnyOrigin]()
                idx = _find_or_add_state(
                    program, states, state_index, first_closure, is_new
                )
            if idx < 0:
                return UnsafePointer[OnePassNFA, MutAnyOrigin]()
            if is_new:
                worklist.append(idx)
            transitions[byte] = idx

        states[state_id].transitions = transitions

    var ptr = alloc[OnePassNFA](1)
    ptr.init_pointee_move(
        OnePassNFA(program^, states^, has_start_anchor, has_end_anchor)
    )
    return ptr


def _find_or_add_state(
    program: Program,
    mut states: List[OnePassState],
    mut index: Dict[UInt64, List[Int]],
    nfa_set: SIMD[DType.uint8, MAX_STATES],
    mut is_new: Bool,
) -> Int:
    """Hash-indexed lookup-or-append for an OnePass state set.

    Sets `is_new = True` when a new state was appended (the caller uses
    this to schedule the state on the worklist exactly once). Returns
    -1 if the state cap was exceeded.

    Without hash indexing, compile_onepass is O(num_states * prog_len)
    per lookup (linear scan + SIMD compare over all existing states),
    which for a 40-instruction anchored phone pattern compiled in ~13s.
    The FNV-1a hash buckets the states by nfa_set bytes; collisions
    fall through to a short bucket scan, so the common case is O(1).
    """
    is_new = False
    var key = _hash_set(nfa_set)
    try:
        if key in index:
            ref bucket = index[key]
            for i in range(len(bucket)):
                var sid = bucket[i]
                if states[sid].nfa_set.eq(nfa_set).reduce_and():
                    return sid
    except:
        pass
    if len(states) >= ONEPASS_MAX_STATES:
        return -1
    var new_id = len(states)
    states.append(OnePassState(nfa_set, _set_contains_match(program, nfa_set)))
    is_new = True
    try:
        if key in index:
            index[key].append(new_id)
        else:
            index[key] = [new_id]
    except:
        # Index insert failed; correctness preserved (state is still in
        # `states`), future lookups may dedup slower.
        pass
    return new_id


struct OnePassState(Copyable, Movable):
    """A compiled OnePass state: its NFA-set (for anchor fixup) plus the
    precomputed byte -> next_state transition table."""

    var nfa_set: SIMD[DType.uint8, MAX_STATES]
    """PCs active in this state. Only consulted at end of text to fire
    pending OP_END_ANCHOR transitions. Also used to flag accepting."""
    var is_match: Bool
    """True when OP_MATCH is in `nfa_set` (the pattern can complete
    here without consuming more input, ignoring any pending `$`)."""
    var transitions: InlineArray[Int, 256]
    """Byte -> next OnePass state id. `ONEPASS_DEAD` for bytes that
    have no valid successor."""

    def __init__(
        out self,
        nfa_set: SIMD[DType.uint8, MAX_STATES],
        is_match: Bool,
    ):
        self.nfa_set = nfa_set
        self.is_match = is_match
        self.transitions = InlineArray[Int, 256](fill=ONEPASS_DEAD)


struct OnePassNFA(Copyable, Movable):
    """Compiled OnePass NFA. Ready to match in O(n) per byte."""

    var program: Program
    """The underlying PikeVM program, kept for end-of-text anchor
    fixup."""
    var states: List[OnePassState]
    """Compiled states. Index = state id; state 0 = start state."""
    var has_start_anchor: Bool
    """Pattern pins matches to position 0."""
    var has_end_anchor: Bool
    """Pattern pins matches to text end. State accept is deferred to the
    end-of-text fixup so the dollar anchor fires at pos == text_len."""

    def __init__(
        out self,
        var program: Program,
        var states: List[OnePassState],
        has_start_anchor: Bool,
        has_end_anchor: Bool,
    ):
        self.program = program^
        self.states = states^
        self.has_start_anchor = has_start_anchor
        self.has_end_anchor = has_end_anchor

    @always_inline
    def match_first(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
        """Match the pattern starting exactly at `start`. Returns None
        if the pattern cannot match here (e.g. `^` anchor with start > 0,
        or no accepting state reached).

        `is_match` is authoritative for any state whose MATCH is already
        in the closure (no pending `$`). OR patterns with mixed anchors
        like `^a|b$` depend on this: the `^a` branch reaches MATCH
        mid-text and must not be suppressed by the end-of-text gating.
        The end-of-text fixup only extends match_end when `$` fires."""
        if self.has_start_anchor and start > 0:
            return None
        var text_ptr = text.unsafe_ptr()
        var text_len = len(text)
        var state_id = 0
        var match_end = -1
        if self.states[0].is_match:
            match_end = start
        var pos = start
        var states_ptr = self.states.unsafe_ptr()
        while pos < text_len:
            var next_id = states_ptr[state_id].transitions[Int(text_ptr[pos])]
            if next_id == ONEPASS_DEAD:
                break
            state_id = next_id
            pos += 1
            if states_ptr[state_id].is_match:
                match_end = pos
        # End-of-text fixup for `$` anchors.
        if self.has_end_anchor and pos == text_len:
            if self._fire_end_anchor(states_ptr[state_id].nfa_set, text_len):
                match_end = pos
        if match_end >= 0:
            return Match(0, start, match_end, text)
        return None

    @always_inline
    def match_next(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
        """Search for the first match at or after `start` (like
        `re.search`). Honours `^` by only trying position 0."""
        if self.has_start_anchor:
            if start > 0:
                return None
            return self.match_first(text, 0)
        var text_len = len(text)
        for try_pos in range(start, text_len + 1):
            var m = self.match_first(text, try_pos)
            if m:
                return m
        return None

    def match_all(self, text: ImmSlice) -> MatchList:
        var text_len = len(text)
        var matches = MatchList(
            capacity=text_len >> 7 if text_len >= 1024 else 0
        )
        if self.has_start_anchor:
            var m = self.match_first(text, 0)
            if m:
                matches.append(m.value())
            return matches^
        var pos = 0
        while pos <= text_len:
            var m = self.match_first(text, pos)
            if m:
                ref mref = m.value()
                matches.append(mref)
                if mref.end_idx == mref.start_idx:
                    pos += 1  # avoid infinite loop on zero-width
                else:
                    pos = mref.end_idx
            else:
                pos += 1
        return matches^

    @always_inline
    def _fire_end_anchor(
        self, nfa_set: SIMD[DType.uint8, MAX_STATES], text_len: Int
    ) -> Bool:
        var pcs = InlineArray[Int, MAX_STATES](uninitialized=True)
        var count = 0
        for pc in range(len(self.program)):
            if nfa_set[pc] != 0:
                pcs[count] = pc
                count += 1
        # Epsilon-close at at_start=False but with end-anchor firing.
        # Only `OP_END_ANCHOR` needs special handling versus
        # `_epsilon_close`; reuse the helper by walking OP_END_ANCHOR
        # manually first.
        var end_set = SIMD[DType.uint8, MAX_STATES](0)
        var stack = InlineArray[Int, MAX_STATES](uninitialized=True)
        var stack_len = count
        for i in range(count):
            stack[i] = pcs[i]
        var prog_len = len(self.program)
        while stack_len > 0:
            stack_len -= 1
            var pc = stack[stack_len]
            if pc < 0 or pc >= prog_len or end_set[pc] != 0:
                continue
            end_set[pc] = 1
            ref inst = self.program.instructions[pc]
            if inst.opcode == OP_SPLIT:
                stack[stack_len] = inst.arg0
                stack_len += 1
                stack[stack_len] = inst.arg1
                stack_len += 1
            elif inst.opcode == OP_JUMP:
                stack[stack_len] = inst.arg0
                stack_len += 1
            elif inst.opcode == OP_END_ANCHOR:
                stack[stack_len] = pc + 1
                stack_len += 1
            # OP_START_ANCHOR does not fire here (at_start=False).
        return _set_contains_match(self.program, end_set)
