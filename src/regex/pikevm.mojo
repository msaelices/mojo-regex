"""
PikeVM: Thompson NFA simulation for guaranteed O(n*m) regex matching.

Instead of backtracking, the PikeVM tracks all active NFA states
simultaneously. Each input byte processes at most N states (N = program
size), eliminating exponential blowup on alternation + quantifier patterns.

This module provides:
- Instruction: bytecode instruction enum
- Program: compiled NFA bytecode from AST
- PikeVMEngine: executor that runs the bytecode against text
"""

from regex.ast import (
    ASTNode,
    RE,
    GROUP,
    OR,
    ELEMENT,
    RANGE,
    DIGIT,
    WORD,
    SPACE,
    WILDCARD,
    START,
    END,
)
from regex.matching import Match, MatchList
from regex.aliases import WORD_CHARS
from regex.dfa import _expand_character_range


# ===-----------------------------------------------------------------------===#
# Bytecode Instructions
# ===-----------------------------------------------------------------------===#

# Instruction opcodes
comptime OP_BYTE = 0
"""Match a specific byte."""
comptime OP_RANGE = 1
"""Match byte in range [lo, hi]."""
comptime OP_CLASS = 2
"""Match byte using a 256-bit lookup table (index into class_tables)."""
comptime OP_ANY = 3
"""Match any byte except newline."""
comptime OP_SPLIT = 4
"""Fork: add both targets to active states."""
comptime OP_JUMP = 5
"""Unconditional jump."""
comptime OP_MATCH = 6
"""Accepting state."""
comptime OP_START_ANCHOR = 7
"""Match only at start of text."""
comptime OP_END_ANCHOR = 8
"""Match only at end of text."""


struct Instruction(Copyable, Movable):
    """A single PikeVM bytecode instruction."""

    var opcode: Int
    """Instruction opcode (OP_BYTE, OP_SPLIT, etc.)."""
    var arg0: Int
    """First argument (byte value, jump target, range lo, class index)."""
    var arg1: Int
    """Second argument (split second target, range hi)."""

    def __init__(out self, opcode: Int, arg0: Int = 0, arg1: Int = 0):
        self.opcode = opcode
        self.arg0 = arg0
        self.arg1 = arg1


# ===-----------------------------------------------------------------------===#
# Program (compiled bytecode)
# ===-----------------------------------------------------------------------===#


struct Program(Copyable, Movable, Sized):
    """Compiled NFA bytecode program."""

    var instructions: List[Instruction]
    """Flat instruction array."""
    var class_tables: List[SIMD[DType.uint8, 256]]
    """Lookup tables for OP_CLASS instructions."""

    def __init__(out self):
        self.instructions = List[Instruction]()
        self.class_tables = List[SIMD[DType.uint8, 256]]()

    def __len__(self) -> Int:
        return len(self.instructions)

    def emit(mut self, opcode: Int, arg0: Int = 0, arg1: Int = 0) -> Int:
        """Emit an instruction and return its index."""
        var idx = len(self.instructions)
        self.instructions.append(Instruction(opcode, arg0, arg1))
        return idx

    def add_class_table(mut self, table: SIMD[DType.uint8, 256]) -> Int:
        """Add a character class lookup table and return its index."""
        var idx = len(self.class_tables)
        self.class_tables.append(table)
        return idx

    def patch(mut self, idx: Int, arg0: Int = -1, arg1: Int = -1):
        """Patch an instruction's arguments (for forward references)."""
        if arg0 >= 0:
            self.instructions[idx].arg0 = arg0
        if arg1 >= 0:
            self.instructions[idx].arg1 = arg1


# ===-----------------------------------------------------------------------===#
# AST to Bytecode Compiler
# ===-----------------------------------------------------------------------===#


def compile_ast(ast: ASTNode) -> Program:
    """Compile an AST into PikeVM bytecode.

    Args:
        ast: Root AST node (RE type).

    Returns:
        Compiled Program ready for execution.
    """
    var program = Program()

    if ast.type == RE and ast.get_children_len() > 0:
        _compile_node(ast.get_child(0), program)

    program.emit(OP_MATCH)
    return program^


def _compile_node(node: ASTNode, mut program: Program):
    """Compile a single AST node into bytecode."""

    if node.type == GROUP:
        _compile_group(node, program)
    elif node.type == OR:
        _compile_or(node, program)
    elif node.type == ELEMENT:
        _compile_element(node, program)
    elif node.type == DIGIT:
        _compile_char_class_node(node, program)
    elif node.type == WORD:
        _compile_char_class_node(node, program)
    elif node.type == SPACE:
        _compile_char_class_node(node, program)
    elif node.type == RANGE:
        _compile_char_class_node(node, program)
    elif node.type == WILDCARD:
        _compile_wildcard(node, program)
    elif node.type == START:
        program.emit(OP_START_ANCHOR)
    elif node.type == END:
        program.emit(OP_END_ANCHOR)


def _compile_group(node: ASTNode, mut program: Program):
    """Compile a GROUP node (sequence of children)."""
    for i in range(node.get_children_len()):
        ref child = node.get_child(i)
        _compile_quantified(child, program)


def _compile_quantified(node: ASTNode, mut program: Program):
    """Compile a node with quantifier (min/max repetition)."""
    var min_rep = node.min
    var max_rep = node.max

    # No quantifier: single match
    if min_rep == 1 and max_rep == 1:
        _compile_node(node, program)
        return

    # {0,1} = ? (optional)
    if min_rep == 0 and max_rep == 1:
        var split_pc = program.emit(OP_SPLIT, 0, 0)
        var body_start = len(program)
        _compile_node(node, program)
        var after = len(program)
        # Greedy: try body first (arg0), skip second (arg1)
        program.patch(split_pc, arg0=body_start, arg1=after)
        return

    # {n} = exact repetition
    if min_rep == max_rep and min_rep > 1:
        for _ in range(min_rep):
            _compile_node(node, program)
        return

    # {n,m} = bounded repetition
    if max_rep > 0:
        # Emit min required copies
        for _ in range(min_rep):
            _compile_node(node, program)
        # Emit (max - min) optional copies
        var splits = List[Int](capacity=max_rep - min_rep)
        for _ in range(max_rep - min_rep):
            var split_pc = program.emit(OP_SPLIT, 0, 0)
            splits.append(split_pc)
            _compile_node(node, program)
        # Patch all splits to jump past the optional parts
        var after = len(program)
        for i in range(len(splits)):
            program.patch(splits[i], arg0=splits[i] + 1, arg1=after)
        return

    # {n,} = unbounded repetition (min then greedy loop)
    if max_rep == -1:
        # Emit min required copies
        for _ in range(min_rep):
            _compile_node(node, program)
        # Greedy loop: SPLIT(body, after); body; JUMP(split)
        var split_pc = program.emit(OP_SPLIT, 0, 0)
        var body_start = len(program)
        _compile_node(node, program)
        program.emit(OP_JUMP, split_pc)
        var after = len(program)
        program.patch(split_pc, arg0=body_start, arg1=after)
        return


def _compile_or(node: ASTNode, mut program: Program):
    """Compile an OR node (alternation)."""
    if node.get_children_len() == 0:
        return

    if node.get_children_len() == 1:
        _compile_node(node.get_child(0), program)
        return

    # Two branches: SPLIT(left, right); left; JUMP(after); right;
    ref left = node.get_child(0)
    ref right = node.get_child(1)

    var split_pc = program.emit(OP_SPLIT, 0, 0)
    var left_start = len(program)
    _compile_node(left, program)
    var jump_pc = program.emit(OP_JUMP, 0)
    var right_start = len(program)
    _compile_node(right, program)
    var after = len(program)

    program.patch(split_pc, arg0=left_start, arg1=right_start)
    program.patch(jump_pc, arg0=after)


def _compile_element(node: ASTNode, mut program: Program):
    """Compile an ELEMENT node (literal byte)."""
    var val = node.get_value()
    if val:
        var ch = val.value()
        if len(ch) > 0:
            program.emit(OP_BYTE, Int(ch.unsafe_ptr()[0]))


def _compile_wildcard(node: ASTNode, mut program: Program):
    """Compile a WILDCARD node (. matches any except newline)."""
    program.emit(OP_ANY)


def _compile_char_class_node(node: ASTNode, mut program: Program):
    """Compile a character class node (DIGIT, WORD, SPACE, RANGE) using a
    256-byte lookup table for O(1) membership testing."""
    var table = SIMD[DType.uint8, 256](0)

    if node.type == DIGIT:
        for c in range(ord("0"), ord("9") + 1):
            table[c] = 1
    elif node.type == WORD:
        for c in range(ord("a"), ord("z") + 1):
            table[c] = 1
        for c in range(ord("A"), ord("Z") + 1):
            table[c] = 1
        for c in range(ord("0"), ord("9") + 1):
            table[c] = 1
        table[ord("_")] = 1
    elif node.type == SPACE:
        table[ord(" ")] = 1
        table[ord("\t")] = 1
        table[ord("\n")] = 1
        table[ord("\r")] = 1
        table[12] = 1  # \f
    elif node.type == RANGE and node.get_value():
        var raw = node.get_value().value()
        # Strip brackets if present
        var inner = raw
        if raw.startswith("[") and raw.endswith("]"):
            inner = raw[byte = 1 : len(raw) - 1]
        # Parse the inner content handling \s, \d, \w and ranges
        var inner_ptr = inner.unsafe_ptr()
        var j = 0
        while j < len(inner):
            if j + 1 < len(inner) and Int(inner_ptr[j]) == ord("\\"):
                var next_ch = Int(inner_ptr[j + 1])
                if next_ch == ord("s"):
                    table[ord(" ")] = 1
                    table[ord("\t")] = 1
                    table[ord("\n")] = 1
                    table[ord("\r")] = 1
                    table[12] = 1  # \f
                elif next_ch == ord("d"):
                    for c in range(ord("0"), ord("9") + 1):
                        table[c] = 1
                elif next_ch == ord("w"):
                    for c in range(ord("a"), ord("z") + 1):
                        table[c] = 1
                    for c in range(ord("A"), ord("Z") + 1):
                        table[c] = 1
                    for c in range(ord("0"), ord("9") + 1):
                        table[c] = 1
                    table[ord("_")] = 1
                else:
                    table[next_ch] = 1
                j += 2
            elif j + 2 < len(inner) and Int(inner_ptr[j + 1]) == ord("-"):
                var lo = Int(inner_ptr[j])
                var hi = Int(inner_ptr[j + 2])
                for c in range(lo, hi + 1):
                    table[c] = 1
                j += 3
            else:
                table[Int(inner_ptr[j])] = 1
                j += 1

    # Handle negated classes
    if not node.positive_logic:
        for c in range(256):
            table[c] = 1 - table[c]

    var class_idx = program.add_class_table(table)
    program.emit(OP_CLASS, class_idx)


# ===-----------------------------------------------------------------------===#
# PikeVM Executor
# ===-----------------------------------------------------------------------===#


struct PikeVMEngine:
    """Thompson NFA simulation engine. Tracks all active states simultaneously
    for guaranteed O(n*m) matching time."""

    var program: Program
    """Compiled bytecode program."""

    def __init__(out self, var program: Program):
        self.program = program^

    def match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Match pattern at the given position (like re.match)."""
        return self._run(text, start, anchored=True)

    def match_next(self, text: String, start: Int = 0) -> Optional[Match]:
        """Search for pattern anywhere in text (like re.search)."""
        var text_len = len(text)
        for try_pos in range(start, text_len + 1):
            var result = self._run(text, try_pos, anchored=False)
            if result:
                return result
        return None

    def match_all(self, text: String) -> MatchList:
        """Find all non-overlapping matches (like re.findall)."""
        var matches = MatchList()
        var pos = 0
        var text_len = len(text)

        while pos <= text_len:
            var result = self._run(text, pos, anchored=False)
            if result:
                ref m = result.value()
                matches.append(m)
                if m.end_idx == m.start_idx:
                    pos += 1
                else:
                    pos = m.end_idx
            else:
                pos += 1

        return matches^

    def _run(self, text: String, start: Int, anchored: Bool) -> Optional[Match]:
        """Run the PikeVM from a given start position.

        Args:
            text: Input text.
            start: Position to start matching.
            anchored: If True, only match at start position.

        Returns:
            Match if found, None otherwise.
        """
        var text_ptr = text.unsafe_ptr()
        var text_len = len(text)
        var prog_len = len(self.program)

        # Two state lists: current and next
        var current = List[Int](capacity=prog_len)
        var next_states = List[Int](capacity=prog_len)

        # Track which PCs are already in a list (avoid duplicates)
        var in_current = List[Bool](length=prog_len, fill=False)
        var in_next = List[Bool](length=prog_len, fill=False)

        # Track the best (longest) match found
        var match_end = -1

        # Add start state with epsilon closure
        self._add_state(current, in_current, 0, text_ptr, start, text_len)

        # Process each byte
        var pos = start
        while pos <= text_len:
            if len(current) == 0:
                break

            # Check for match states in current before consuming byte
            for i in range(len(current)):
                var pc = current[i]
                if self.program.instructions[pc].opcode == OP_MATCH:
                    match_end = pos

            # If we're past the end, don't consume another byte
            if pos == text_len:
                break

            var ch = Int(text_ptr[pos])

            # Process all current states
            for i in range(len(current)):
                var pc = current[i]
                ref inst = self.program.instructions[pc]

                if inst.opcode == OP_BYTE:
                    if ch == inst.arg0:
                        self._add_state(
                            next_states,
                            in_next,
                            pc + 1,
                            text_ptr,
                            pos + 1,
                            text_len,
                        )
                elif inst.opcode == OP_RANGE:
                    if ch >= inst.arg0 and ch <= inst.arg1:
                        self._add_state(
                            next_states,
                            in_next,
                            pc + 1,
                            text_ptr,
                            pos + 1,
                            text_len,
                        )
                elif inst.opcode == OP_CLASS:
                    ref table = self.program.class_tables[inst.arg0]
                    if table[ch] != 0:
                        self._add_state(
                            next_states,
                            in_next,
                            pc + 1,
                            text_ptr,
                            pos + 1,
                            text_len,
                        )
                elif inst.opcode == OP_ANY:
                    if ch != ord("\n"):
                        self._add_state(
                            next_states,
                            in_next,
                            pc + 1,
                            text_ptr,
                            pos + 1,
                            text_len,
                        )
                # OP_SPLIT, OP_JUMP, OP_MATCH handled in epsilon closure

            # Swap current and next
            current = next_states^
            in_current = in_next^
            next_states = List[Int](capacity=prog_len)
            in_next = List[Bool](length=prog_len, fill=False)
            pos += 1

        if match_end >= 0:
            return Match(0, start, match_end, text)
        return None

    def _add_state(
        self,
        mut states: List[Int],
        mut in_list: List[Bool],
        pc: Int,
        text_ptr: UnsafePointer[UInt8, _],
        pos: Int,
        text_len: Int,
    ):
        """Add a state with epsilon closure (follow SPLIT/JUMP without consuming input).
        """
        if pc >= len(self.program) or in_list[pc]:
            return

        ref inst = self.program.instructions[pc]

        if inst.opcode == OP_SPLIT:
            # Fork: add both targets
            in_list[pc] = True
            self._add_state(states, in_list, inst.arg0, text_ptr, pos, text_len)
            self._add_state(states, in_list, inst.arg1, text_ptr, pos, text_len)
        elif inst.opcode == OP_JUMP:
            in_list[pc] = True
            self._add_state(states, in_list, inst.arg0, text_ptr, pos, text_len)
        elif inst.opcode == OP_START_ANCHOR:
            if pos == 0:
                in_list[pc] = True
                self._add_state(
                    states, in_list, pc + 1, text_ptr, pos, text_len
                )
        elif inst.opcode == OP_END_ANCHOR:
            if pos == text_len:
                in_list[pc] = True
                self._add_state(
                    states, in_list, pc + 1, text_ptr, pos, text_len
                )
        else:
            # Non-epsilon instruction: add to state list
            in_list[pc] = True
            states.append(pc)
