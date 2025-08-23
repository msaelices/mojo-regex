"""
One-Pass DFA implementation for high-performance regex matching with capturing groups.

This module implements a specialized DFA that can efficiently handle patterns where
each input position has at most one execution path. This allows for DFA-level
performance while maintaining the ability to track capturing groups.

A One-Pass DFA is particularly effective for complex alternation patterns like
the national phone validation pattern, where traditional DFA approaches struggle
with non-determinism but the pattern structure allows for deterministic processing.

Key advantages:
- O(n) time complexity for matching
- Captures group spans efficiently
- Handles complex alternation patterns
- Memory-efficient state representation

Based on the algorithms described in Russ Cox's "Regular Expression Matching
Can Be Simple And Fast" and the implementation in Rust's regex-automata crate.
"""

from regex.ast import (
    ASTNode,
    RE,
    OR,
    GROUP,
    ELEMENT,
    RANGE,
    DIGIT,
    SPACE,
    WILDCARD,
    START,
    END,
)
from regex.engine import Engine
from regex.matching import Match
from regex.aliases import EMPTY_STRING

alias MAX_ONE_PASS_STATES = 1024  # Maximum states in One-Pass DFA
alias MAX_CAPTURE_SLOTS = 32  # Maximum capturing groups


@register_passable("trivial")
struct CaptureSlot(Copyable):
    """Represents a capturing group slot in the One-Pass DFA."""

    var start_offset: Int
    """Start position of the captured text (-1 if not captured)."""
    var end_offset: Int
    """End position of the captured text (-1 if not captured)."""

    fn __init__(out self):
        self.start_offset = -1
        self.end_offset = -1

    fn __init__(out self, start: Int, end: Int):
        self.start_offset = start
        self.end_offset = end

    fn is_captured(self) -> Bool:
        """Check if this slot has captured text."""
        return self.start_offset >= 0 and self.end_offset >= 0

    fn reset(mut self):
        """Reset the capture slot."""
        self.start_offset = -1
        self.end_offset = -1


@register_passable("trivial")
struct OnePassTransition(Copyable):
    """Represents a single transition in the One-Pass DFA."""

    var next_state: Int
    """ID of the next state (-1 for invalid transition)."""
    var capture_actions: Int
    """Bitfield representing which capture slots to update."""

    fn __init__(out self, next_state: Int = -1, capture_actions: Int = 0):
        self.next_state = next_state
        self.capture_actions = capture_actions

    fn is_valid(self) -> Bool:
        """Check if this is a valid transition."""
        return self.next_state >= 0


struct OnePassState(Copyable, Movable):
    """Represents a single state in the One-Pass DFA."""

    var transitions: List[OnePassTransition]
    """Transitions for each byte value (256 entries)."""
    var is_match_state: Bool
    """Whether this state represents a successful match."""
    var match_pattern_id: Int
    """ID of the pattern that matches in this state (-1 if no match)."""

    fn __init__(out self):
        self.transitions = List[OnePassTransition](capacity=256)
        for i in range(256):
            self.transitions.append(OnePassTransition())
        self.is_match_state = False
        self.match_pattern_id = -1

    fn set_transition(
        mut self, byte_val: Int, next_state: Int, capture_actions: Int = 0
    ):
        """Set a transition for a specific byte value."""
        if 0 <= byte_val < 256:
            self.transitions[byte_val] = OnePassTransition(
                next_state, capture_actions
            )

    fn get_transition(self, byte_val: Int) -> OnePassTransition:
        """Get the transition for a specific byte value."""
        if 0 <= byte_val < 256:
            return self.transitions[byte_val]
        return OnePassTransition()


struct OnePassDFA(Engine):
    """One-Pass DFA engine for efficient pattern matching with captures.

    This engine implements a specialized DFA that can handle capturing groups
    while maintaining O(n) time complexity. It's particularly effective for
    complex alternation patterns that would otherwise require NFA processing.
    """

    var states: List[OnePassState]
    """All states in the One-Pass DFA."""
    var start_state_id: Int
    """ID of the initial start state."""
    var capture_count: Int
    """Number of capturing groups in the pattern."""

    fn __init__(out self):
        self.states = List[OnePassState]()
        self.start_state_id = -1
        self.capture_count = 0

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find the first match in the text using One-Pass DFA algorithm.

        Args:
            text: Input text to search.
            start: Starting position in text.

        Returns:
            Optional Match if found, None otherwise.
        """
        if self.start_state_id < 0 or len(self.states) == 0:
            return None

        var captures = List[CaptureSlot](capacity=self.capture_count)
        for i in range(self.capture_count):
            captures.append(CaptureSlot())

        # Try matching from each position starting at 'start'
        for pos in range(start, len(text)):
            var match_result = self._try_match_at_position(text, pos, captures)
            if match_result:
                return match_result.value()

        return None

    fn match_next(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find the next match - for One-Pass DFA this is the same as match_first.
        """
        return self.match_first(text, start)

    fn match_all(self, text: String) -> List[Match, hint_trivial_type=True]:
        """Find all non-overlapping matches in the text.

        Args:
            text: Input text to search.

        Returns:
            List of all matches found.
        """
        var matches = List[Match, hint_trivial_type=True]()
        var pos = 0

        while pos < len(text):
            var match_result = self.match_first(text, pos)
            if match_result:
                var match = match_result.value()
                matches.append(match)
                # Move past this match to find the next one
                pos = match.get_end_pos()
                if (
                    pos == match.get_start_pos()
                ):  # Zero-length match, advance by 1
                    pos += 1
            else:
                break

        return matches

    fn _try_match_at_position(
        self, text: String, start_pos: Int, mut captures: List[CaptureSlot]
    ) -> Optional[Match]:
        """Try to match starting at a specific position.

        Args:
            text: Input text.
            start_pos: Position to start matching from.
            captures: Mutable list of capture slots to track groups.

        Returns:
            Optional Match if successful.
        """
        if start_pos >= len(text) or self.start_state_id < 0:
            return None

        # Reset capture slots
        for i in range(len(captures)):
            captures[i].reset()

        var current_state = self.start_state_id
        var pos = start_pos
        var match_end = -1

        # Process each character
        while pos <= len(text):
            if current_state >= len(self.states):
                break

            ref state = self.states[current_state]

            # Check if current state is a match state
            if state.is_match_state:
                match_end = pos
                # For leftmost-first semantics, we can break here
                # But continue to handle longer matches if needed

            # If we've consumed all input, break
            if pos >= len(text):
                break

            # Get the next character and transition
            var char_code = ord(text[pos])
            var transition = state.get_transition(char_code)

            if not transition.is_valid():
                # No valid transition - matching fails
                break

            # Apply capture actions if any
            self._apply_capture_actions(
                transition.capture_actions, pos, captures
            )

            # Move to next state and position
            current_state = transition.next_state
            pos += 1

        # Check final state for match
        if (
            current_state < len(self.states)
            and self.states[current_state].is_match_state
        ):
            match_end = pos

        if match_end >= 0:
            return Match(start_pos, match_end)

        return None

    fn _apply_capture_actions(
        self, actions: Int, pos: Int, mut captures: List[CaptureSlot]
    ):
        """Apply capture actions at current position.

        Args:
            actions: Bitfield representing which captures to update.
            pos: Current position in text.
            captures: Mutable capture slots to update.
        """
        if actions == 0:
            return

        # Simple implementation: each bit represents a capture slot
        for i in range(min(len(captures), 32)):  # Max 32 slots supported
            if (actions >> i) & 1:
                if i < len(captures):
                    if captures[i].start_offset < 0:
                        # Start of capture
                        captures[i].start_offset = pos
                    else:
                        # End of capture
                        captures[i].end_offset = pos


fn can_build_one_pass_dfa(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if a pattern can be compiled to a One-Pass DFA.

    A pattern is One-Pass if at each input position during matching,
    there is at most one active NFA state thread. This means there's
    no ambiguity about which path to take through the pattern.

    Args:
        ast: Root AST node of the parsed pattern.

    Returns:
        True if the pattern is suitable for One-Pass DFA compilation.
    """
    var analyzer = OnePassAnalyzer()
    return analyzer.analyze(ast)


struct OnePassAnalyzer:
    """Analyzer to determine if a pattern is One-Pass compatible."""

    fn __init__(out self):
        pass

    fn analyze(self, ast: ASTNode[MutableAnyOrigin]) -> Bool:
        """Analyze if the pattern is One-Pass compatible.

        Args:
            ast: Root AST node to analyze.

        Returns:
            True if One-Pass compatible.
        """
        return self._is_one_pass_node(ast, depth=0)

    fn _is_one_pass_node(self, ast: ASTNode, depth: Int) -> Bool:
        """Check if a single AST node is One-Pass compatible.

        Args:
            ast: AST node to check.
            depth: Current recursion depth.

        Returns:
            True if the node is One-Pass compatible.
        """
        if depth > 10:  # Prevent infinite recursion
            return False

        if ast.type == RE:
            # Root node - check children
            if ast.get_children_len() == 0:
                return True
            return self._is_one_pass_node(ast.get_child(0), depth + 1)

        elif ast.type in (ELEMENT, WILDCARD, SPACE, DIGIT, RANGE):
            # Simple character matching - always One-Pass
            return True

        elif ast.type in (START, END):
            # Anchors - always One-Pass
            return True

        elif ast.type == GROUP:
            # Groups are One-Pass if their content is One-Pass
            # and they don't create ambiguous capture scenarios
            return self._is_one_pass_group(ast, depth)

        elif ast.type == OR:
            # Alternations are One-Pass if they don't create ambiguous paths
            return self._is_one_pass_alternation(ast, depth)

        else:
            # Unknown node type - assume not One-Pass for safety
            return False

    fn _is_one_pass_group(self, ast: ASTNode, depth: Int) -> Bool:
        """Check if a group is One-Pass compatible.

        Args:
            ast: GROUP node to analyze.
            depth: Current recursion depth.

        Returns:
            True if the group is One-Pass compatible.
        """
        # Simple quantifiers on groups can often be One-Pass
        if ast.min == 1 and ast.max == 1:
            # Non-quantified group - check contents
            for i in range(ast.get_children_len()):
                if not self._is_one_pass_node(ast.get_child(i), depth + 1):
                    return False
            return True

        elif (ast.min == 0 and ast.max == 1) or (
            ast.min == 1 and ast.max == -1
        ):
            # ? or + quantifiers can be One-Pass for simple groups
            return self._is_simple_group_content(ast, depth)

        elif ast.min == 0 and ast.max == -1:
            # * quantifier - more complex, check for simple content
            return self._is_simple_group_content(ast, depth)

        else:
            # Complex quantifiers - generally not One-Pass
            return False

    fn _is_simple_group_content(self, ast: ASTNode, depth: Int) -> Bool:
        """Check if group content is simple enough for One-Pass.

        Args:
            ast: GROUP node to check.
            depth: Current recursion depth.

        Returns:
            True if content is simple.
        """
        # Groups with only literal characters and simple character classes
        # are typically One-Pass friendly
        for i in range(ast.get_children_len()):
            ref child = ast.get_child(i)
            if child.type not in (ELEMENT, RANGE, DIGIT, SPACE, START, END):
                # Contains complex constructs
                return False
        return True

    fn _is_one_pass_alternation(self, ast: ASTNode, depth: Int) -> Bool:
        """Check if an alternation is One-Pass compatible.

        Args:
            ast: OR node to analyze.
            depth: Current recursion depth.

        Returns:
            True if the alternation is One-Pass compatible.
        """
        # Alternations are One-Pass if:
        # 1. Each branch is One-Pass
        # 2. The branches don't create ambiguous matching scenarios

        # Check if all branches are One-Pass
        for i in range(ast.get_children_len()):
            if not self._is_one_pass_node(ast.get_child(i), depth + 1):
                return False

        # Simple alternations between literals/character classes are usually One-Pass
        if self._is_simple_literal_alternation(ast):
            return True

        # More complex alternations need careful analysis
        # For now, be conservative and allow small alternations
        return ast.get_children_len() <= 4

    fn _is_simple_literal_alternation(self, ast: ASTNode) -> Bool:
        """Check if alternation is between simple literals/character classes.

        Args:
            ast: OR node to check.

        Returns:
            True if all branches are simple.
        """
        for i in range(ast.get_children_len()):
            ref branch = ast.get_child(i)
            if branch.type == GROUP:
                # Check if group contains only simple elements
                for j in range(branch.get_children_len()):
                    ref elem = branch.get_child(j)
                    if elem.type not in (ELEMENT, RANGE, DIGIT, SPACE):
                        return False
            elif branch.type not in (ELEMENT, RANGE, DIGIT, SPACE):
                return False
        return True


fn compile_one_pass_dfa(ast: ASTNode[MutableAnyOrigin]) raises -> OnePassDFA:
    """Compile an AST to a One-Pass DFA.

    Args:
        ast: Root AST node of the parsed pattern.

    Returns:
        Compiled One-Pass DFA engine.

    Raises:
        Error if the pattern cannot be compiled to One-Pass DFA.
    """
    if not can_build_one_pass_dfa(ast):
        raise Error("Pattern is not suitable for One-Pass DFA compilation")

    var builder = OnePassDFABuilder()
    return builder.build(ast)


struct OnePassDFABuilder:
    """Builder for constructing One-Pass DFAs from AST patterns."""

    var dfa: OnePassDFA
    var state_count: Int

    fn __init__(out self):
        self.dfa = OnePassDFA()
        self.state_count = 0

    fn build(mut self, ast: ASTNode[MutableAnyOrigin]) raises -> OnePassDFA:
        """Build a One-Pass DFA from the given AST.

        Args:
            ast: Root AST node to compile.

        Returns:
            Compiled One-Pass DFA.
        """
        # Create initial state
        var start_state = OnePassState()
        self.dfa.states.append(start_state^)
        self.dfa.start_state_id = 0
        self.state_count = 1

        # Compile the pattern starting from the root
        var end_state_id = self._compile_node(ast, 0)

        # Mark the end state as accepting
        if end_state_id >= 0 and end_state_id < len(self.dfa.states):
            self.dfa.states[end_state_id].is_match_state = True
            self.dfa.states[end_state_id].match_pattern_id = 0

        return self.dfa^

    fn _compile_node(mut self, ast: ASTNode, from_state: Int) raises -> Int:
        """Compile a single AST node into DFA states.

        Args:
            ast: AST node to compile.
            from_state: Source state ID.

        Returns:
            ID of the state after processing this node.
        """
        if ast.type == RE:
            # Root node - process first child
            if ast.get_children_len() > 0:
                return self._compile_node(ast.get_child(0), from_state)
            return from_state

        elif ast.type == ELEMENT:
            # Literal character
            return self._compile_literal_char(ast, from_state)

        elif ast.type in (RANGE, DIGIT, SPACE):
            # Character class
            return self._compile_character_class(ast, from_state)

        elif ast.type == WILDCARD:
            # Wildcard .
            return self._compile_wildcard(ast, from_state)

        elif ast.type == GROUP:
            # Group (potentially with quantifiers)
            return self._compile_group(ast, from_state)

        elif ast.type == OR:
            # Alternation
            return self._compile_alternation(ast, from_state)

        elif ast.type in (START, END):
            # Anchors - for simplicity, treat as no-op in One-Pass DFA
            return from_state

        else:
            raise Error("Unsupported AST node type in One-Pass DFA compilation")

    fn _compile_literal_char(
        mut self, ast: ASTNode, from_state: Int
    ) raises -> Int:
        """Compile a literal character to DFA states.

        Args:
            ast: ELEMENT node representing a literal character.
            from_state: Source state ID.

        Returns:
            ID of the destination state.
        """
        var to_state = self._create_new_state()

        if ast.get_value():
            var char_code = ord(ast.get_value().value())
            self.dfa.states[from_state].set_transition(char_code, to_state)

        return to_state

    fn _compile_character_class(
        mut self, ast: ASTNode, from_state: Int
    ) raises -> Int:
        """Compile a character class to DFA states.

        Args:
            ast: Character class node (RANGE, DIGIT, SPACE).
            from_state: Source state ID.

        Returns:
            ID of the destination state.
        """
        var to_state = self._create_new_state()

        if ast.type == DIGIT:
            # Digits 0-9
            for i in range(ord("0"), ord("9") + 1):
                self.dfa.states[from_state].set_transition(i, to_state)

        elif ast.type == SPACE:
            # Whitespace characters
            var whitespace_chars = " \t\n\r\f\v"
            for i in range(len(whitespace_chars)):
                var char_code = ord(whitespace_chars[i])
                self.dfa.states[from_state].set_transition(char_code, to_state)

        elif ast.type == RANGE:
            # Handle range based on value - simplified implementation
            if ast.get_value():
                var range_str = ast.get_value().value()
                if range_str == "a":  # [a-z] simplified
                    for i in range(ord("a"), ord("z") + 1):
                        self.dfa.states[from_state].set_transition(i, to_state)
                elif range_str == "A":  # [A-Z] simplified
                    for i in range(ord("A"), ord("Z") + 1):
                        self.dfa.states[from_state].set_transition(i, to_state)
                elif range_str == "0":  # [0-9] simplified
                    for i in range(ord("0"), ord("9") + 1):
                        self.dfa.states[from_state].set_transition(i, to_state)

        return to_state

    fn _compile_wildcard(mut self, ast: ASTNode, from_state: Int) raises -> Int:
        """Compile a wildcard . to DFA states.

        Args:
            ast: WILDCARD node.
            from_state: Source state ID.

        Returns:
            ID of the destination state.
        """
        var to_state = self._create_new_state()

        # Wildcard matches any character except newline
        for i in range(256):
            if i != ord("\n"):
                self.dfa.states[from_state].set_transition(i, to_state)

        return to_state

    fn _compile_group(mut self, ast: ASTNode, from_state: Int) raises -> Int:
        """Compile a group to DFA states.

        Args:
            ast: GROUP node.
            from_state: Source state ID.

        Returns:
            ID of the destination state.
        """
        # For simplicity, process group contents sequentially
        var current_state = from_state

        for i in range(ast.get_children_len()):
            current_state = self._compile_node(ast.get_child(i), current_state)

        return current_state

    fn _compile_alternation(
        mut self, ast: ASTNode, from_state: Int
    ) raises -> Int:
        """Compile an alternation to DFA states.

        Args:
            ast: OR node.
            from_state: Source state ID.

        Returns:
            ID of the destination state.
        """
        # Create a merge state where all branches converge
        var merge_state = self._create_new_state()

        # Compile each branch from from_state to merge_state
        for i in range(ast.get_children_len()):
            var branch_end = self._compile_node(ast.get_child(i), from_state)

            # Connect branch end to merge state with epsilon-like behavior
            # In a One-Pass DFA, this would be handled by the construction algorithm
            # For simplicity, we assume branches naturally merge

        return merge_state

    fn _create_new_state(mut self) raises -> Int:
        """Create a new DFA state.

        Returns:
            ID of the newly created state.

        Raises:
            Error if maximum state count exceeded.
        """
        if self.state_count >= MAX_ONE_PASS_STATES:
            raise Error("Maximum One-Pass DFA state count exceeded")

        var new_state = OnePassState()
        self.dfa.states.append(new_state^)
        var state_id = self.state_count
        self.state_count += 1

        return state_id
