"""
DFA (Deterministic Finite Automaton) implementation for high-performance regex matching.

This module provides O(n) time complexity regex matching for simple patterns that can be
compiled to DFA, as opposed to the exponential worst-case of NFA backtracking.
"""

from regex.ast import ASTNode
from regex.engine import Engine
from regex.matching import Match
from regex.optimizer import (
    PatternComplexity,
    is_literal_pattern,
    get_literal_string,
    pattern_has_anchors,
)


struct DFAState(Copyable, Movable):
    """A single state in the DFA state machine."""

    var transitions: InlineArray[
        Int, 256
    ]  # ASCII transition table (256 entries)
    var is_accepting: Bool
    var match_length: Int  # Length of match when this state is reached

    fn __init__(out self):
        """Initialize a DFA state with no transitions."""
        self.transitions = InlineArray[Int, 256](
            fill=-1
        )  # -1 means no transition
        self.is_accepting = False
        self.match_length = 0

    @always_inline
    fn __copyinit__(out self, other: Self):
        """Copy constructor."""
        self.transitions = other.transitions
        self.is_accepting = other.is_accepting
        self.match_length = other.match_length

    @always_inline
    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.transitions = other.transitions^
        self.is_accepting = other.is_accepting
        self.match_length = other.match_length

    @always_inline
    fn add_transition(mut self, char_code: Int, target_state: Int):
        """Add a transition from this state to target_state on character char_code.

        Args:
            char_code: ASCII code of the character (0-255).
            target_state: Target state index, or -1 for no transition.
        """
        if char_code >= 0 and char_code < 256:
            self.transitions[char_code] = target_state

    @always_inline
    fn get_transition(self, char_code: Int) -> Int:
        """Get the target state for a given character.

        Args:
            char_code: ASCII code of the character.

        Returns:
            Target state index, or -1 if no transition exists.
        """
        if char_code >= 0 and char_code < 256:
            return self.transitions[char_code]
        return -1


struct DFAEngine(Engine):
    """DFA-based regex engine for O(n) pattern matching."""

    var states: List[DFAState]
    var start_state: Int
    var compiled_pattern: String  # The pattern this DFA was compiled from
    var has_start_anchor: Bool  # Pattern starts with ^
    var has_end_anchor: Bool  # Pattern ends with $

    fn __init__(out self):
        """Initialize an empty DFA engine."""
        self.states = List[DFAState]()
        self.start_state = 0
        self.compiled_pattern = ""
        self.has_start_anchor = False
        self.has_end_anchor = False

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.states = other.states^
        self.start_state = other.start_state
        self.compiled_pattern = other.compiled_pattern^
        self.has_start_anchor = other.has_start_anchor
        self.has_end_anchor = other.has_end_anchor

    fn compile_pattern(
        mut self, pattern: String, has_start_anchor: Bool, has_end_anchor: Bool
    ) raises:
        """Compile a literal string pattern into a DFA.

        This creates a simple linear DFA where each character of the pattern
        corresponds to one state transition.

        Args:
            pattern: Literal string to match (e.g., "hello").
            has_start_anchor: Whether pattern has ^ anchor.
            has_end_anchor: Whether pattern has $ anchor.
        """
        self.compiled_pattern = pattern
        self.has_start_anchor = has_start_anchor
        self.has_end_anchor = has_end_anchor
        self.states = List[DFAState]()

        if len(pattern) == 0:
            # Empty pattern - create single accepting state
            var state = DFAState()
            state.is_accepting = True
            state.match_length = 0
            self.states.append(state)
            self.start_state = 0
            return

        # Create states: one for each character + one final accepting state
        var num_states = len(pattern) + 1
        for _ in range(num_states):
            self.states.append(DFAState())

        # Set up transitions for each character in the pattern
        for i in range(len(pattern)):
            var char_code = ord(pattern[i])
            self.states[i].add_transition(char_code, i + 1)

        # Mark final state as accepting
        self.states[len(pattern)].is_accepting = True
        self.states[len(pattern)].match_length = len(pattern)

        self.start_state = 0

    fn compile_character_class(
        mut self, char_class: String, min_matches: Int, max_matches: Int
    ) raises:
        """Compile a character class pattern like [a-z]+ into a DFA.

        Args:
            char_class: Character class string (e.g., "abcdefghijklmnopqrstuvwxyz" for [a-z]).
            min_matches: Minimum number of matches required.
            max_matches: Maximum number of matches (-1 for unlimited).
        """
        self.compiled_pattern = "[" + char_class + "]"
        self.states = List[DFAState]()

        if min_matches == 0:
            # Can match zero characters - start state is accepting
            var start_state = DFAState()
            start_state.is_accepting = True
            start_state.match_length = 0
            self.states.append(start_state)
        else:
            # Must match at least one character
            var start_state = DFAState()
            self.states.append(start_state)

        # Add accepting state for one or more matches
        var accepting_state = DFAState()
        accepting_state.is_accepting = True
        accepting_state.match_length = 1  # Will be updated during matching
        self.states.append(accepting_state)

        # Set up transitions from start state to accepting state
        for i in range(len(char_class)):
            var char_code = ord(char_class[i])
            self.states[0].add_transition(char_code, 1)

        # Set up self-transitions on accepting state for + and * quantifiers
        if max_matches == -1 or max_matches > 1:
            for i in range(len(char_class)):
                var char_code = ord(char_class[i])
                self.states[1].add_transition(char_code, 1)

        self.start_state = 0

    fn match_first(self, text: String, start: Int) -> Optional[Match]:
        """Execute DFA matching against input text.

        Args:
            text: Input text to match against.
            start: Starting position in text.

        Returns:
            Optional Match if pattern matches, None otherwise.
        """
        # Handle start anchor - can only match at beginning of string
        if self.has_start_anchor:
            if start == 0:
                return self._try_match_at_position(text, 0)
            else:
                return None

        # Try to find a match starting from each position from 'start' onwards
        for try_pos in range(start, len(text) + 1):
            var match_result = self._try_match_at_position(text, try_pos)
            if match_result:
                return match_result

        return None

    fn _try_match_at_position(
        self, text: String, start_pos: Int
    ) -> Optional[Match]:
        """Try to match pattern starting at a specific position.

        Args:
            text: Input text to match against.
            start_pos: Position to start matching from.

        Returns:
            Optional Match if pattern matches at this position, None otherwise.
        """
        if start_pos > len(text):
            return None

        if start_pos == len(text):
            # Check if we can match empty string
            if (
                len(self.states) > 0
                and self.states[self.start_state].is_accepting
            ):
                return Match(0, start_pos, start_pos, text, "DFA")
            return None

        var current_state = self.start_state
        var pos = start_pos
        var last_accepting_pos = -1

        # Check if start state is accepting (for patterns like a*)
        if (
            current_state < len(self.states)
            and self.states[current_state].is_accepting
        ):
            last_accepting_pos = pos

        while pos < len(text):
            var ch = text[pos]
            var char_code = ord(ch)

            if current_state >= len(self.states):
                break

            var next_state = self.states[current_state].get_transition(
                char_code
            )

            if next_state == -1:
                # No transition available
                break

            current_state = next_state
            pos += 1

            # Check if current state is accepting
            if (
                current_state < len(self.states)
                and self.states[current_state].is_accepting
            ):
                last_accepting_pos = pos

        # Return longest match found
        if last_accepting_pos != -1:
            # Check end anchor constraint
            if self.has_end_anchor and last_accepting_pos != len(text):
                return None  # End anchor requires match to end at string end
            return Match(0, start_pos, last_accepting_pos, text, "DFA")

        return None

    fn match_all(self, text: String) -> List[Match]:
        """Find all non-overlapping matches using DFA.

        Args:
            text: Input text to search.

        Returns:
            List of all matches found.
        """
        var matches = List[Match]()

        # Special handling for anchored patterns
        if self.has_start_anchor or self.has_end_anchor:
            # Anchored patterns can only match once
            var match_result = self.match_first(text, 0)
            if match_result:
                matches.append(match_result.value())
            return matches

        var pos = 0
        while pos <= len(text):
            var match_result = self.match_first(text, pos)
            if match_result:
                var match_obj = match_result.value()
                matches.append(match_obj)
                # Move past this match to find next one
                if match_obj.end_idx == match_obj.start_idx:
                    # Zero-width match, advance by one to avoid infinite loop
                    pos += 1
                else:
                    pos = match_obj.end_idx
            else:
                pos += 1

        return matches


struct BoyerMoore:
    """Boyer-Moore string search algorithm for fast literal string matching."""

    var pattern: String
    var bad_char_table: List[Int]  # Bad character heuristic table

    fn __init__(out self, pattern: String):
        """Initialize Boyer-Moore with a pattern.

        Args:
            pattern: Literal string pattern to search for.
        """
        self.pattern = pattern
        self.bad_char_table = List[Int](capacity=256)
        self._build_bad_char_table()

    fn _build_bad_char_table(mut self):
        """Build the bad character heuristic table."""
        # Initialize all characters to -1 (not in pattern)
        for _ in range(256):
            self.bad_char_table.append(-1)

        # Set the last occurrence of each character in pattern
        for i in range(len(self.pattern)):
            var char_code = ord(self.pattern[i])
            self.bad_char_table[char_code] = i

    fn search(self, text: String, start: Int = 0) -> Int:
        """Search for pattern in text using Boyer-Moore algorithm.

        Args:
            text: Text to search in.
            start: Starting position in text.

        Returns:
            Position of first match, or -1 if not found.
        """
        var m = len(self.pattern)
        var n = len(text)
        var s = start  # shift of the pattern

        while s <= n - m:
            var j = m - 1

            # Compare pattern from right to left
            while j >= 0 and self.pattern[j] == text[s + j]:
                j -= 1

            if j < 0:
                # Pattern found at position s
                return s
            else:
                # Mismatch occurred, use bad character heuristic
                var bad_char = ord(text[s + j])
                var shift = j - self.bad_char_table[bad_char]
                s += max(1, shift)

        return -1  # Pattern not found

    fn search_all(self, text: String) -> List[Int]:
        """Find all occurrences of pattern in text.

        Args:
            text: Text to search in.

        Returns:
            List of starting positions of all matches.
        """
        var positions = List[Int]()
        var start = 0

        while True:
            var pos = self.search(text, start)
            if pos == -1:
                break
            positions.append(pos)
            start = pos + 1  # Look for next occurrence

        return positions


fn compile_ast_pattern(ast: ASTNode) raises -> DFAEngine:
    """Compile an AST pattern into a DFA engine.

    Args:
        ast: AST representing a pattern that may include character classes.

    Returns:
        Compiled DFA engine ready for matching.

    Raises:
        Error if pattern is too complex for DFA compilation.
    """
    var dfa = DFAEngine()

    if is_literal_pattern(ast):
        # Handle literal string patterns (possibly with anchors)
        var literal_str = get_literal_string(ast)
        var has_start, has_end = pattern_has_anchors(ast)
        dfa.compile_pattern(literal_str, has_start, has_end)
    elif _is_pure_anchor_pattern(ast):
        # Handle pure anchor patterns (just ^ or $ or ^$)
        var has_start, has_end = pattern_has_anchors(ast)
        dfa.compile_pattern("", has_start, has_end)
    elif _is_simple_character_class_pattern(ast):
        # Handle simple character class patterns like \d, \d+, \d{3}
        var char_class, min_matches, max_matches, has_start, has_end = (
            _extract_character_class_info(ast)
        )
        dfa.compile_character_class(char_class, min_matches, max_matches)
        dfa.has_start_anchor = has_start
        dfa.has_end_anchor = has_end
    else:
        # Pattern too complex for current DFA implementation
        raise Error("Pattern too complex for current DFA implementation")

    return dfa^


fn compile_simple_pattern(ast: ASTNode) raises -> DFAEngine:
    """Compile a simple pattern AST into a DFA engine.

    Args:
        ast: AST representing a simple pattern.

    Returns:
        Compiled DFA engine ready for matching.

    Raises:
        Error if pattern is too complex for DFA compilation.
    """
    # Use the enhanced compilation function
    return compile_ast_pattern(ast)


fn _is_simple_character_class_pattern(ast: ASTNode) -> Bool:
    """Check if pattern is a simple character class (single \\d, \\d+, \\d{3}, etc.).

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a simple character class pattern.
    """
    from regex.ast import RE, DIGIT, GROUP

    if ast.type == RE and len(ast.children) == 1:
        var child = ast.children[0]
        if child.type == DIGIT:
            return True
        elif child.type == GROUP and len(child.children) == 1:
            # Check if group contains single digit element
            return child.children[0].type == DIGIT
    elif ast.type == DIGIT:
        return True

    return False


fn _extract_character_class_info(
    ast: ASTNode,
) -> Tuple[String, Int, Int, Bool, Bool]:
    """Extract character class information from AST.

    Args:
        ast: AST node representing a character class pattern.

    Returns:
        Tuple of (char_class_string, min_matches, max_matches, has_start_anchor, has_end_anchor).
    """
    from regex.ast import RE, DIGIT, GROUP

    var char_class = String("")
    var min_matches = 1
    var max_matches = 1
    var has_start = False
    var has_end = False

    # Find the DIGIT node
    var digit_node: ASTNode
    if ast.type == DIGIT:
        digit_node = ast
    elif ast.type == RE and len(ast.children) == 1:
        if ast.children[0].type == DIGIT:
            digit_node = ast.children[0]
        elif (
            ast.children[0].type == GROUP and len(ast.children[0].children) == 1
        ):
            digit_node = ast.children[0].children[0]
        else:
            digit_node = ast.children[0]  # fallback
        # Check for anchors at root level
        has_start, has_end = pattern_has_anchors(ast)
    else:
        digit_node = ast  # fallback

    # Extract quantifier information
    if digit_node.type == DIGIT:
        min_matches = digit_node.min
        max_matches = digit_node.max
        # Generate digit character class string "0123456789"
        char_class = "0123456789"

    return (char_class, min_matches, max_matches, has_start, has_end)


fn _is_pure_anchor_pattern(ast: ASTNode) -> Bool:
    """Check if pattern is just anchors (^, $, or ^$).

    Args:
        ast: Root AST node.

    Returns:
        True if pattern contains only anchor nodes.
    """
    from regex.ast import RE, START, END, GROUP

    if ast.type == START or ast.type == END:
        return True
    elif ast.type == RE:
        if len(ast.children) == 0:
            return False
        return _is_pure_anchor_pattern(ast.children[0])
    elif ast.type == GROUP:
        # Check if group contains only anchors
        for i in range(len(ast.children)):
            if not _is_pure_anchor_pattern(ast.children[i]):
                return False
        return True
    else:
        return False
