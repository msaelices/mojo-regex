"""
DFA (Deterministic Finite Automaton) implementation for high-performance regex matching.

This module provides O(n) time complexity regex matching for simple patterns that can be
compiled to DFA, as opposed to the exponential worst-case of NFA backtracking.
"""

from regex.ast import ASTNode
from regex.aliases import ALL_EXCEPT_NEWLINE
from regex.engine import Engine
from regex.matching import Match
from regex.optimizer import (
    PatternComplexity,
    is_literal_pattern,
    get_literal_string,
    pattern_has_anchors,
)
from regex.tokens import (
    CHAR_A,
    CHAR_A_UPPER,
    CHAR_Z,
    CHAR_Z_UPPER,
    CHAR_ZERO,
    CHAR_NINE,
    DIGITS,
)
from regex.simd_ops import SIMDStringSearch, CharacterClassSIMD
from regex.simd_matchers import (
    analyze_character_class_pattern,
    create_digit_matcher,
    create_alpha_matcher,
    create_alnum_matcher,
    create_whitespace_matcher,
    create_hex_digit_matcher,
    RangeBasedMatcher,
    NibbleBasedMatcher,
)
from regex.parametric_nfa_helpers import (
    apply_quantifier_simd_generic,
    find_in_text_simd,
)

alias DEFAULT_DFA_CAPACITY = 64  # Default capacity for DFA states
alias DEFAULT_DFA_TRANSITIONS = 256  # Number of ASCII transitions (0-255)

# Pre-defined character sets for efficient lookup
alias LOWERCASE_LETTERS = "abcdefghijklmnopqrstuvwxyz"
alias UPPERCASE_LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
alias ALL_LETTERS = LOWERCASE_LETTERS + UPPERCASE_LETTERS
alias ALPHANUMERIC = LOWERCASE_LETTERS + UPPERCASE_LETTERS + DIGITS


fn expand_character_range(range_str: StringSlice[ImmutableAnyOrigin]) -> String:
    """Expand a character range like '[a-z]' to 'abcdefghijklmnopqrstuvwxyz'.

    Args:
        range_str: Range string like '[a-z]' or '[0-9]' or 'abcd'.

    Returns:
        Expanded character set string.
    """
    # If it's already expanded (doesn't contain '-' in brackets), return as is
    if not range_str.startswith("[") or not range_str.endswith("]"):
        return String(range_str)

    # Handle common cases efficiently with pre-defined aliases
    if range_str == "[a-z]":
        return LOWERCASE_LETTERS
    elif range_str == "[A-Z]":
        return UPPERCASE_LETTERS
    elif range_str == "[0-9]":
        return DIGITS
    elif range_str == "[a-zA-Z0-9]":
        # Common pattern for alphanumeric - return pre-computed string
        return ALPHANUMERIC
    elif range_str == "[a-zA-Z]":
        # Common pattern for letters only
        return ALL_LETTERS

    # Extract the inner part: [a-z] -> a-z
    var inner = range_str[1:-1]

    # Handle negated ranges like [^a-z]
    var negated = inner.startswith("^")
    if negated:
        inner = inner[1:]

    # For simple single ranges, use slicing from pre-defined sets
    if len(inner) == 3 and inner[1] == "-":
        var start_char = inner[0]
        var end_char = inner[2]

        # Handle lowercase letter ranges
        if ord(start_char) >= CHAR_A and ord(end_char) <= CHAR_Z:
            var start_idx = ord(start_char) - CHAR_A
            var end_idx = ord(end_char) - CHAR_A + 1
            return LOWERCASE_LETTERS[start_idx:end_idx]

        # Handle uppercase letter ranges
        elif ord(start_char) >= CHAR_A and ord(end_char) <= CHAR_Z_UPPER:
            var start_idx = ord(start_char) - CHAR_A_UPPER
            var end_idx = ord(end_char) - CHAR_A_UPPER + 1
            return UPPERCASE_LETTERS[start_idx:end_idx]

        # Handle digit ranges
        elif ord(start_char) >= CHAR_ZERO and ord(end_char) <= CHAR_NINE:
            var start_idx = ord(start_char) - CHAR_ZERO
            var end_idx = ord(end_char) - CHAR_ZERO + 1
            return DIGITS[start_idx:end_idx]

    # Fallback for complex cases - expand all ranges and characters
    var result = String(
        capacity=String.INLINE_CAPACITY
    )  # Pre-allocate for worst case
    var i = 0
    while i < len(inner):
        if i + 2 < len(inner) and inner[i + 1] == "-":
            # Found a range like a-z
            var start_char = inner[i]
            var end_char = inner[i + 2]
            var start_code = ord(start_char)
            var end_code = ord(end_char)

            # Add all characters in the range
            for char_code in range(start_code, end_code + 1):
                result += chr(char_code)
            i += 3
        else:
            # Single character
            result += inner[i]
            i += 1

    return result


struct SequentialPatternElement(Copyable, Movable):
    """Information about a single element in a sequential pattern."""

    var char_class: String
    """Character class string (e.g., "0123456789" for \\d)."""
    var min_matches: Int
    """Minimum matches for this element."""
    var max_matches: Int
    """Maximum matches for this element (-1 for unlimited)."""
    var positive_logic: Bool
    """True for [abc], False for [^abc]."""

    fn __init__(
        out self,
        owned char_class: String,
        min_matches: Int,
        max_matches: Int,
        positive_logic: Bool = True,
    ):
        self.char_class = char_class^
        self.min_matches = min_matches
        self.max_matches = max_matches
        self.positive_logic = positive_logic


struct SequentialPatternInfo(Copyable, Movable):
    """Information about a sequential pattern like [+]*\\d+[-]*\\d+."""

    var elements: List[SequentialPatternElement]
    """List of sequential pattern elements in the pattern."""
    var has_start_anchor: Bool
    """Whether the pattern starts with ^ anchor."""
    var has_end_anchor: Bool
    """Whether the pattern ends with $ anchor."""

    fn __init__(out self):
        self.elements = List[SequentialPatternElement]()
        self.has_start_anchor = False
        self.has_end_anchor = False


@register_passable
struct DFAState(Copyable, Movable):
    """A single state in the DFA state machine."""

    var transitions: SIMD[DType.uint8, DEFAULT_DFA_TRANSITIONS]
    """Transition table for this state, indexed by character code (0-255)."""
    var is_accepting: Bool
    """A state is accepting if it can end a match following this path."""
    var match_length: Int  # Length of match when this state is reached
    """Length of the match when this state is reached, used for quantifiers."""

    fn __init__(out self, is_accepting: Bool = False, match_length: Int = 0):
        """Initialize a DFA state with no transitions."""
        self.transitions = SIMD[DType.uint8, DEFAULT_DFA_TRANSITIONS](
            -1
        )  # -1 means no transition
        self.is_accepting = is_accepting
        self.match_length = match_length

    @always_inline
    fn add_transition(mut self, char_code: Int, target_state: Int):
        """Add a transition from this state to target_state on character char_code.

        Args:
            char_code: ASCII code of the character (0-255).
            target_state: Target state index, or -1 for no transition.
        """
        if char_code >= 0 and char_code < DEFAULT_DFA_TRANSITIONS:
            self.transitions[char_code] = target_state

    @always_inline
    fn get_transition(self, char_code: Int) -> Int:
        """Get the target state for a given character.

        Args:
            char_code: ASCII code of the character.

        Returns:
            Target state index, or -1 if no transition exists.
        """
        if char_code >= 0 and char_code < DEFAULT_DFA_TRANSITIONS:
            return Int(self.transitions[char_code])
        return -1


struct DFAEngine(Engine):
    """DFA-based regex engine for O(n) pattern matching."""

    var states: List[DFAState]
    """List of DFA states in the state machine."""
    var start_state: Int
    """Index of the starting state in the DFA."""
    var has_start_anchor: Bool
    """Whether the pattern starts with ^ anchor."""
    var has_end_anchor: Bool
    """Whether the pattern ends with $ anchor."""
    var simd_string_search: Optional[SIMDStringSearch]
    """SIMD-optimized string search for pure literal patterns."""
    var is_pure_literal: Bool
    """Whether this is a pure literal pattern (no regex operators)."""
    var simd_char_matcher: Optional[CharacterClassSIMD]
    """SIMD-optimized character class matcher for simple patterns."""
    var simd_char_pattern: String
    """The character class pattern being matched with SIMD."""

    fn __init__(out self):
        """Initialize an empty DFA engine."""
        self.states = List[DFAState](capacity=DEFAULT_DFA_CAPACITY)
        self.start_state = 0
        self.has_start_anchor = False
        self.has_end_anchor = False
        self.simd_string_search = None
        self.is_pure_literal = False
        self.simd_char_matcher = None
        self.simd_char_pattern = ""

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.states = other.states^
        self.start_state = other.start_state
        self.has_start_anchor = other.has_start_anchor
        self.has_end_anchor = other.has_end_anchor
        self.simd_string_search = other.simd_string_search^
        self.is_pure_literal = other.is_pure_literal
        self.simd_char_matcher = other.simd_char_matcher^
        self.simd_char_pattern = other.simd_char_pattern^

    fn compile_pattern(
        mut self,
        owned pattern: String,
        has_start_anchor: Bool,
        has_end_anchor: Bool,
    ) raises:
        """Compile a literal string pattern into a DFA.

        This creates a simple linear DFA where each character of the pattern
        corresponds to one state transition.

        Args:
            pattern: Literal string to match (e.g., "hello").
            has_start_anchor: Whether pattern has ^ anchor.
            has_end_anchor: Whether pattern has $ anchor.
        """
        var len_pattern = len(pattern)
        self.has_start_anchor = has_start_anchor
        self.has_end_anchor = has_end_anchor

        if len_pattern == 0:
            self._create_accepting_state()
            return

        # For pure literal patterns without anchors, use SIMD string search
        if not has_start_anchor and not has_end_anchor and len_pattern > 0:
            self.is_pure_literal = True
            self.simd_string_search = SIMDStringSearch(pattern)
            # Still create DFA states as fallback

        # Create states: one for each character + one final accepting state
        # Set up transitions for each character in the pattern
        for i in range(len_pattern):
            var state = DFAState()
            var char_code = ord(pattern[i])
            state.add_transition(char_code, i + 1)
            self.states.append(state)

        # Add final accepting state
        var final_state = DFAState(is_accepting=True, match_length=len_pattern)
        self.states.append(final_state)

        self.start_state = 0

    fn compile_character_class(
        mut self, owned char_class: String, min_matches: Int, max_matches: Int
    ) raises:
        """Compile a character class pattern like [a-z]+ into a DFA.

        Args:
            char_class: Character class string (e.g., "abcdefghijklmnopqrstuvwxyz" for [a-z]).
            min_matches: Minimum number of matches required.
            max_matches: Maximum number of matches (-1 for unlimited).
        """
        self.compile_character_class_with_logic(
            char_class^, min_matches, max_matches, True
        )

    fn compile_character_class_with_logic(
        mut self,
        owned char_class: String,
        min_matches: Int,
        max_matches: Int,
        positive_logic: Bool,
    ) raises:
        """Compile a character class pattern like [a-z]+ or [^a-z]+ into a DFA.

        Args:
            char_class: Character class string (e.g., "abcdefghijklmnopqrstuvwxyz" for [a-z]).
            min_matches: Minimum number of matches required.
            max_matches: Maximum number of matches (-1 for unlimited).
            positive_logic: True for [a-z], False for [^a-z].
        """
        # Try to use SIMD optimization for simple character class patterns
        if min_matches >= 0 and positive_logic:
            # Check if this is a pattern we can optimize with SIMD
            var pattern_str = String()
            if char_class == DIGITS or char_class == "0123456789":
                pattern_str = "[0-9]"
                # For now, keep using CharacterClassSIMD for compatibility
                # In future: could use create_digit_matcher() with wrapper
                self.simd_char_matcher = CharacterClassSIMD(char_class)
            elif char_class == LOWERCASE_LETTERS:
                pattern_str = "[a-z]"
                self.simd_char_matcher = CharacterClassSIMD(char_class)
            elif char_class == UPPERCASE_LETTERS:
                pattern_str = "[A-Z]"
                self.simd_char_matcher = CharacterClassSIMD(char_class)
            elif char_class == ALL_LETTERS:
                pattern_str = "[a-zA-Z]"
                # For now, keep using CharacterClassSIMD for compatibility
                # In future: could use create_alpha_matcher() with wrapper
                self.simd_char_matcher = CharacterClassSIMD(char_class)
            elif char_class == ALPHANUMERIC:
                pattern_str = "[a-zA-Z0-9]"
                # For now, keep using CharacterClassSIMD for compatibility
                # In future: could use create_alnum_matcher() with wrapper
                self.simd_char_matcher = CharacterClassSIMD(char_class)
            elif char_class == " \t\n\r\f\v":
                pattern_str = "\\s"
                # For now, keep using CharacterClassSIMD for compatibility
                # In future: could use create_whitespace_matcher() with wrapper
                self.simd_char_matcher = CharacterClassSIMD(char_class)
            else:
                # For other patterns, use standard CharacterClassSIMD
                self.simd_char_matcher = CharacterClassSIMD(char_class)

            if pattern_str:
                self.simd_char_pattern = pattern_str

        if min_matches == 0:
            # Pattern like [a-z]* - can match zero characters
            var start_state = DFAState(is_accepting=True, match_length=0)
            self.states.append(start_state)

            # Add state for one or more matches
            var match_state = DFAState(is_accepting=True, match_length=1)
            self.states.append(match_state)

            # Transitions from start to match state
            self._add_character_class_transitions_with_logic(
                0, 1, char_class, positive_logic
            )

            # Self-loop on match state for additional matches
            if max_matches == -1 or max_matches > 1:
                self._add_character_class_transitions_with_logic(
                    1, 1, char_class, positive_logic
                )

        elif min_matches == 1:
            # Pattern like [a-z]+ or [a-z] - must match at least one
            var start_state = DFAState()
            self.states.append(start_state)

            # Add accepting state for matches
            var match_state = DFAState(is_accepting=True, match_length=1)
            self.states.append(match_state)

            # Transitions from start to match state
            self._add_character_class_transitions_with_logic(
                0, 1, char_class, positive_logic
            )

            # Handle additional matches
            if max_matches == -1:
                # Unlimited matches ([a-z]+) - self-loop
                self._add_character_class_transitions_with_logic(
                    1, 1, char_class, positive_logic
                )
            elif max_matches > 1:
                # Limited matches like [a-z]{1,3} - create additional states
                for match_count in range(2, max_matches + 1):
                    var state = DFAState(
                        is_accepting=True, match_length=match_count
                    )
                    self.states.append(state)
                    # Add transitions from previous state
                    self._add_character_class_transitions_with_logic(
                        match_count - 1, match_count, char_class, positive_logic
                    )
        else:
            # Pattern with min_matches > 1, like [a-z]{3,5}
            # Create states for required matches first
            for match_count in range(min_matches + 1):
                var is_accepting = match_count >= min_matches
                var state = DFAState(
                    is_accepting=is_accepting, match_length=match_count
                )
                self.states.append(state)

                if match_count > 0:
                    # Add transitions from previous state
                    self._add_character_class_transitions_with_logic(
                        match_count - 1, match_count, char_class, positive_logic
                    )

            # Add additional optional states if max_matches allows
            if max_matches == -1:
                # Unlimited additional matches - self-loop on last state
                var last_state_idx = len(self.states) - 1
                self._add_character_class_transitions_with_logic(
                    last_state_idx, last_state_idx, char_class, positive_logic
                )
            elif max_matches > min_matches:
                # Limited additional matches
                for match_count in range(min_matches + 1, max_matches + 1):
                    var state = DFAState(
                        is_accepting=True, match_length=match_count
                    )
                    self.states.append(state)
                    self._add_character_class_transitions_with_logic(
                        match_count - 1, match_count, char_class, positive_logic
                    )

        self.start_state = 0

    fn compile_sequential_pattern(
        mut self, pattern_info: SequentialPatternInfo
    ) raises:
        """Compile a sequential pattern like [+]*\\d+[-]*\\d+ into a DFA.

        Args:
            pattern_info: Information about the sequential pattern elements.
        """
        self.has_start_anchor = pattern_info.has_start_anchor
        self.has_end_anchor = pattern_info.has_end_anchor

        if not pattern_info.elements:
            self._create_accepting_state()
            return

        # Build a chain of states for each element in the sequence
        var current_state_index = 0

        for element_idx in range(len(pattern_info.elements)):
            var element = pattern_info.elements[element_idx]
            var is_last_element = element_idx == len(pattern_info.elements) - 1

            # Create states for this element based on its quantifier
            if element.min_matches == 0:
                # Optional element - start state can skip this element
                if element_idx == 0:
                    # First element is optional - create start state that can accept or transition
                    var start_state = DFAState(is_accepting=not is_last_element)
                    self.states.append(start_state)
                    current_state_index = 0

                # Create state for matching this element
                var match_state = DFAState(is_accepting=True)
                self.states.append(match_state)
                var match_state_index = len(self.states) - 1

                # Add transitions from current state to match state
                self._add_character_class_transitions_with_logic(
                    current_state_index,
                    match_state_index,
                    element.char_class,
                    element.positive_logic,
                )

                # Handle unlimited matches (*) - self-loop
                if element.max_matches == -1:
                    self._add_character_class_transitions_with_logic(
                        match_state_index,
                        match_state_index,
                        element.char_class,
                        element.positive_logic,
                    )

                current_state_index = match_state_index
            else:
                # Required element - must match at least min_matches times
                for match_num in range(element.min_matches):
                    var is_accepting = (
                        match_num >= element.min_matches - 1
                    ) and is_last_element
                    var state = DFAState(is_accepting=is_accepting)
                    self.states.append(state)
                    var state_index = len(self.states) - 1

                    # Add transitions from previous state
                    if match_num == 0:
                        # First required match - transition from current state
                        self._add_character_class_transitions_with_logic(
                            current_state_index,
                            state_index,
                            element.char_class,
                            element.positive_logic,
                        )
                    else:
                        # Subsequent required matches - transition from previous match state
                        self._add_character_class_transitions_with_logic(
                            state_index - 1,
                            state_index,
                            element.char_class,
                            element.positive_logic,
                        )

                    current_state_index = state_index

                # Handle additional matches (+ or {n,m})
                if element.max_matches == -1:
                    # Unlimited additional matches - add self-loop
                    self._add_character_class_transitions_with_logic(
                        current_state_index,
                        current_state_index,
                        element.char_class,
                        element.positive_logic,
                    )
                elif element.max_matches > element.min_matches:
                    # Limited additional matches - create additional optional states
                    for _ in range(element.max_matches - element.min_matches):
                        var state = DFAState(is_accepting=is_last_element)
                        self.states.append(state)
                        var state_index = len(self.states) - 1
                        self._add_character_class_transitions_with_logic(
                            current_state_index,
                            state_index,
                            element.char_class,
                            element.positive_logic,
                        )
                        current_state_index = state_index

        self.start_state = 0

    fn compile_multi_character_class_sequence(
        mut self, owned sequence_info: SequentialPatternInfo
    ) raises:
        """Compile a multi-character class sequence like [a-z]+[0-9]+ into a DFA.

        Args:
            sequence_info: Information about the character class sequence elements.
        """
        self.has_start_anchor = sequence_info.has_start_anchor
        self.has_end_anchor = sequence_info.has_end_anchor

        if not sequence_info.elements:
            self._create_accepting_state()
            return

        # Build a chain of states for each character class in the sequence
        var current_state_index = 0

        for element_idx in range(len(sequence_info.elements)):
            var element = sequence_info.elements[element_idx]
            var is_last_element = element_idx == len(sequence_info.elements) - 1

            # Check if all remaining elements are optional
            var all_remaining_optional = True
            for i in range(element_idx + 1, len(sequence_info.elements)):
                if sequence_info.elements[i].min_matches > 0:
                    all_remaining_optional = False
                    break

            # For multi-character sequences, SIMD optimization is applied per character class
            # but not globally since we have multiple different character classes

            if element.min_matches == 0:
                # Optional element (e.g., [a-z]*)
                if element_idx == 0:
                    # First element is optional - start state should be accepting if all elements are optional
                    var start_state = DFAState(
                        is_accepting=all_remaining_optional
                    )
                    self.states.append(start_state)
                    current_state_index = 0

                # Create state for matching this element
                var match_state = DFAState(
                    is_accepting=is_last_element or all_remaining_optional
                )
                self.states.append(match_state)
                var match_state_index = len(self.states) - 1

                # Add transitions from current state to match state
                self._add_character_class_transitions_with_logic(
                    current_state_index,
                    match_state_index,
                    element.char_class,
                    element.positive_logic,
                )

                # Handle unlimited matches (*) - self-loop
                if element.max_matches == -1:
                    self._add_character_class_transitions_with_logic(
                        match_state_index,
                        match_state_index,
                        element.char_class,
                        element.positive_logic,
                    )

                # For the first optional element, we need epsilon transitions to subsequent elements
                # The current state should remain the start state so the next element can transition from it
                if element_idx == 0:
                    # Keep current_state_index as the start state for epsilon transitions to next elements
                    # But we also track the match state for this element
                    current_state_index = (
                        0  # Start state index for epsilon transitions
                    )
                    # Store the match state index for potential transitions too (unused for now)
                    var _ = match_state_index
                else:
                    current_state_index = match_state_index

            elif element.min_matches == 1:
                # Required element with + or {1,n} quantifier
                if element_idx == 0:
                    # First element - start from initial state
                    var start_state = DFAState()
                    self.states.append(start_state)
                    current_state_index = 0

                # Create accepting state for this element
                # State is accepting if this is the last element OR all remaining elements are optional
                var is_accepting = is_last_element or all_remaining_optional
                var match_state = DFAState(is_accepting=is_accepting)
                self.states.append(match_state)
                var match_state_index = len(self.states) - 1

                # Add transitions from current state
                self._add_character_class_transitions_with_logic(
                    current_state_index,
                    match_state_index,
                    element.char_class,
                    element.positive_logic,
                )

                # If the previous element was optional (element_idx == 1 and current_state_index == 0),
                # we also need to add transitions from the optional element's match state
                if element_idx == 1 and current_state_index == 0:
                    # The previous element was optional, add transitions from its match state too
                    var prev_element = sequence_info.elements[0]
                    if prev_element.min_matches == 0:
                        # Add transitions from the optional element's match state (which should be state 1)
                        self._add_character_class_transitions_with_logic(
                            1,  # Match state of the optional element
                            match_state_index,
                            element.char_class,
                            element.positive_logic,
                        )

                # Handle additional matches
                if element.max_matches == -1:
                    # Unlimited matches (+) - self-loop
                    self._add_character_class_transitions_with_logic(
                        match_state_index,
                        match_state_index,
                        element.char_class,
                        element.positive_logic,
                    )
                elif element.max_matches > 1:
                    # Limited additional matches - create optional states
                    for match_count in range(2, element.max_matches + 1):
                        var additional_state = DFAState(
                            is_accepting=is_last_element
                        )
                        self.states.append(additional_state)
                        var additional_state_index = len(self.states) - 1
                        self._add_character_class_transitions_with_logic(
                            match_state_index + match_count - 2,
                            additional_state_index,
                            element.char_class,
                            element.positive_logic,
                        )

                current_state_index = match_state_index

            else:
                # Element with min_matches > 1 (e.g., [a-z]{3,5})
                # Create required states first
                for match_num in range(element.min_matches):
                    var is_accepting = (
                        match_num >= element.min_matches - 1
                    ) and is_last_element
                    var state = DFAState(is_accepting=is_accepting)
                    self.states.append(state)
                    var state_index = len(self.states) - 1

                    if match_num > 0:
                        # Connect from previous state
                        self._add_character_class_transitions_with_logic(
                            state_index - 1,
                            state_index,
                            element.char_class,
                            element.positive_logic,
                        )
                    else:
                        # Connect from previous element's final state
                        self._add_character_class_transitions_with_logic(
                            current_state_index,
                            state_index,
                            element.char_class,
                            element.positive_logic,
                        )
                    current_state_index = state_index

                # Handle additional optional matches
                if element.max_matches == -1:
                    # Unlimited additional matches - self-loop on last state
                    self._add_character_class_transitions_with_logic(
                        current_state_index,
                        current_state_index,
                        element.char_class,
                        element.positive_logic,
                    )
                elif element.max_matches > element.min_matches:
                    # Limited additional matches
                    for _ in range(
                        element.min_matches + 1, element.max_matches + 1
                    ):
                        var optional_state = DFAState(
                            is_accepting=is_last_element
                        )
                        self.states.append(optional_state)
                        var optional_state_index = len(self.states) - 1
                        self._add_character_class_transitions_with_logic(
                            current_state_index,
                            optional_state_index,
                            element.char_class,
                            element.positive_logic,
                        )
                        current_state_index = optional_state_index

        self.start_state = 0

    @always_inline
    fn _create_accepting_state(mut self: Self):
        """Create a single accepting state as the pattern is empty."""
        var state = DFAState(is_accepting=True, match_length=0)
        self.states.append(state)
        self.start_state = 0

    @always_inline
    fn _add_character_class_transitions(
        mut self, from_state: Int, to_state: Int, char_class: String
    ):
        """Add transitions for all characters in a character class.

        Args:
            from_state: Source state index.
            to_state: Target state index.
            char_class: String containing all valid characters.
        """
        self._add_character_class_transitions_with_logic(
            from_state, to_state, char_class, True
        )

    @always_inline
    fn _add_character_class_transitions_with_logic(
        mut self,
        from_state: Int,
        to_state: Int,
        char_class: String,
        positive_logic: Bool,
    ):
        """Add transitions for characters in a character class, supporting negated logic.

        Args:
            from_state: Source state index.
            to_state: Target state index.
            char_class: String containing characters for the class.
            positive_logic: True for [abc], False for [^abc].
        """
        if from_state >= len(self.states):
            return

        ref state = self.states[from_state]

        # For very large character classes, use a more efficient approach
        var char_class_len = len(char_class)

        if positive_logic:
            # Positive logic: [abc] - add transitions for characters in char_class
            # For common patterns, use optimized handling
            if char_class == ALPHANUMERIC and char_class_len == 62:
                # Optimize for [a-zA-Z0-9] - add transitions in batches
                # Add lowercase letters
                for i in range(26):
                    state.add_transition(CHAR_A + i, to_state)
                # Add uppercase letters
                for i in range(26):
                    state.add_transition(CHAR_A_UPPER + i, to_state)
                # Add digits
                for i in range(10):
                    state.add_transition(CHAR_ZERO + i, to_state)
            else:
                # General case - iterate through each character
                for i in range(char_class_len):
                    var char_code = ord(char_class[i])
                    state.add_transition(char_code, to_state)
        else:
            # Negative logic: [^abc] - add transitions for all characters NOT in char_class
            # Create a bitmap for fast lookup
            var char_bitmap = SIMD[DType.uint8, DEFAULT_DFA_TRANSITIONS](0)

            # Mark characters in char_class as 1 in bitmap
            for i in range(char_class_len):
                var char_code = ord(char_class[i])
                if char_code >= 0 and char_code < DEFAULT_DFA_TRANSITIONS:
                    char_bitmap[char_code] = 1

            # Add transitions for all characters NOT in the class
            for char_code in range(DEFAULT_DFA_TRANSITIONS):
                if char_bitmap[char_code] == 0:
                    state.add_transition(char_code, to_state)

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Execute DFA matching against input text. To be Python compatible,
        it will not match if the start position is not at the beginning of a line.

        Args:
            text: Input text to match against.
            start: Starting position in text.

        Returns:
            Optional Match if pattern matches, None otherwise.
        """
        # Handle start anchor - can only match at beginning of string
        if self.has_start_anchor and start > 0:
            return None  # Start anchor requires match at position 0

        # Python only allows matching at the start of the string
        return self._try_match_at_position(
            text, start, require_exact_position=True
        )

    fn match_next(self, text: String, start: Int = 0) -> Optional[Match]:
        """Execute DFA matching against input text. It will match from the given start
        position.

        Args:
            text: Input text to match against.
            start: Starting position in text.

        Returns:
            Optional Match if pattern matches, None otherwise.
        """
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
        self, text: String, start_pos: Int, require_exact_position: Bool = False
    ) -> Optional[Match]:
        """Try to match pattern starting at a specific position.

        Args:
            text: Input text to match against.
            start_pos: Position to start matching from.
            require_exact_position: If True, only match at exact start_pos (for match_first).

        Returns:
            Optional Match if pattern matches at this position, None otherwise.
        """
        if start_pos > len(text):
            return None

        # Fast path for pure literal patterns using SIMD
        if self.is_pure_literal and self.simd_string_search:
            var searcher = self.simd_string_search.value()
            if require_exact_position:
                # For match_first, must match at exact position
                if searcher._verify_match(text, start_pos):
                    var match_len = searcher.pattern_length
                    return Match(0, start_pos, start_pos + match_len, text)
                return None
            else:
                # For match_next, can search from position
                var pos = searcher.search(text, start_pos)
                if pos != -1:
                    var match_len = searcher.pattern_length
                    return Match(0, pos, pos + match_len, text)
                return None

        # Try SIMD matching for simple character class patterns
        if self.simd_char_matcher and len(self.states) > 0:
            var match_result = self._try_match_simd(text, start_pos)
            if match_result:
                return match_result

        if start_pos == len(text):
            # Check if we can match empty string
            if (
                len(self.states) > 0
                and self.states[self.start_state].is_accepting
            ):
                return Match(0, start_pos, start_pos, text)
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
            var char_code = ord(text[pos])

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
            return Match(0, start_pos, last_accepting_pos, text)

        return None

    fn match_all(self, text: String) -> List[Match, hint_trivial_type=True]:
        """Find all non-overlapping matches using DFA.

        Args:
            text: Input text to search.

        Returns:
            List of all matches found.
        """
        var matches = List[Match, hint_trivial_type=True]()

        # Special handling for anchored patterns
        if self.has_start_anchor or self.has_end_anchor:
            # Anchored patterns can only match once
            var match_result = self.match_next(text, 0)
            if match_result:
                matches.append(match_result.value())
            return matches

        # Skip SIMD path - removed for performance

        var pos = 0
        var text_len = len(text)

        while pos <= text_len:
            # Try to match at current position directly
            var match_result = self._try_match_at_position(text, pos)
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
                # No match at this position, try next
                pos += 1

        return matches

    fn _try_match_simd(self, text: String, start_pos: Int) -> Optional[Match]:
        """SIMD-optimized matching for character class patterns.

        Args:
            text: Input text to match against.
            start_pos: Position to start matching from.

        Returns:
            Optional Match if pattern matches at this position, None otherwise.
        """
        if not self.simd_char_matcher:
            return None

        var simd_matcher = self.simd_char_matcher.value()
        var pos = start_pos
        var match_count = 0
        var text_len = len(text)

        # Check if start state is accepting (for patterns like [a-z]*)
        var start_accepting = (
            len(self.states) > 0 and self.states[self.start_state].is_accepting
        )

        # Count consecutive matching characters using SIMD
        while pos < text_len:
            var ch_code = ord(text[pos])
            if simd_matcher.contains(ch_code):
                match_count += 1
                pos += 1
            else:
                break

        # Determine if we have a valid match based on the DFA pattern
        var is_valid_match = False
        var match_end = start_pos + match_count

        if match_count == 0:
            # No characters matched - only valid if start state accepts (e.g., [a-z]*)
            if start_accepting:
                is_valid_match = True
                match_end = start_pos
        else:
            # Some characters matched - check if this satisfies the pattern
            # For character class patterns, any positive match count is typically valid
            is_valid_match = True

        if is_valid_match:
            # Check end anchor constraint
            if self.has_end_anchor and match_end != text_len:
                return None
            return Match(0, start_pos, match_end, text)

        return None


struct BoyerMoore:
    """Boyer-Moore string search algorithm for fast literal string matching."""

    var pattern: String
    """The literal string pattern to search for."""
    var bad_char_table: List[Int]
    """Bad character heuristic table for Boyer-Moore algorithm."""

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


fn compile_ast_pattern(ast: ASTNode[MutableAnyOrigin]) raises -> DFAEngine:
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
        # Handle simple character class patterns like \d, \d+, \d{3}, [a-z]+, [0-9]*, [^a-z]+
        var char_class, min_matches, max_matches, has_start, has_end, positive_logic = _extract_character_class_info(
            ast
        )
        var char_class_str = char_class.value()
        var expanded_char_class = expand_character_range(char_class_str)
        dfa.compile_character_class_with_logic(
            expanded_char_class,
            min_matches,
            max_matches,
            positive_logic,
        )
        dfa.has_start_anchor = has_start
        dfa.has_end_anchor = has_end
    elif _is_multi_character_class_sequence(ast):
        # Handle multi-character class sequences like [a-z]+[0-9]+, \d+\w+
        var sequence_info = _extract_multi_class_sequence_info(ast)
        dfa.compile_multi_character_class_sequence(sequence_info)
        dfa.has_start_anchor = sequence_info.has_start_anchor
        dfa.has_end_anchor = sequence_info.has_end_anchor
    elif _is_sequential_character_class_pattern(ast):
        # Handle sequential character class patterns like [+]*\d+[-]*\d+
        var sequence_info = _extract_sequential_pattern_info(ast)
        dfa.compile_sequential_pattern(sequence_info)
        dfa.has_start_anchor = sequence_info.has_start_anchor
        dfa.has_end_anchor = sequence_info.has_end_anchor
    elif _is_mixed_sequential_pattern(ast):
        # Handle mixed patterns like [0-9]+\.?[0-9]* (numbers with optional decimal)
        var sequence_info = _extract_mixed_sequential_pattern_info(ast)
        dfa.compile_multi_character_class_sequence(sequence_info)
        dfa.has_start_anchor = sequence_info.has_start_anchor
        dfa.has_end_anchor = sequence_info.has_end_anchor
    else:
        # Pattern too complex for current DFA implementation
        raise Error("Pattern too complex for current DFA implementation")

    return dfa^


fn compile_simple_pattern(ast: ASTNode[MutableAnyOrigin]) raises -> DFAEngine:
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


fn _is_simple_character_class_pattern(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if pattern is a simple character class (single \\d, \\d+, \\d{3}, [a-z]+, etc.).

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a simple character class pattern.
    """
    from regex.ast import RE, DIGIT, RANGE, GROUP

    # First check if it's a multi-character sequence - if so, not simple
    if _is_multi_character_class_sequence(ast):
        return False

    if ast.type == RE and ast.get_children_len() == 1:
        var child = ast.get_child(0)
        if child.type == DIGIT or child.type == RANGE:
            return True
        elif child.type == GROUP and child.get_children_len() == 1:
            # Check if group contains single digit or range element
            var inner = child.get_child(0)
            return inner.type == DIGIT or inner.type == RANGE
    elif ast.type == DIGIT or ast.type == RANGE:
        return True

    return False


fn _extract_character_class_info(
    ast: ASTNode[ImmutableAnyOrigin],
) -> Tuple[
    Optional[StringSlice[ImmutableAnyOrigin]], Int, Int, Bool, Bool, Bool
]:
    """Extract character class information from AST.

    Args:
        ast: AST node representing a character class pattern.

    Returns:
        Tuple of (char_class_string, min_matches, max_matches, has_start_anchor, has_end_anchor, positive_logic).
    """
    from regex.ast import RE, DIGIT, RANGE, GROUP

    var char_class: Optional[StringSlice[ImmutableAnyOrigin]] = None
    var min_matches = 1
    var max_matches = 1
    var has_start = False
    var has_end = False
    var positive_logic = True

    # Find the character class node (DIGIT or RANGE)
    var class_node: ASTNode[ImmutableAnyOrigin]
    if ast.type == DIGIT or ast.type == RANGE:
        class_node = ast
    elif ast.type == RE and ast.get_children_len() == 1:
        ref ast_child = ast.get_child(0)
        if ast_child.type == DIGIT or ast_child.type == RANGE:
            class_node = ast_child
        elif ast_child.type == GROUP and ast_child.get_children_len() == 1:
            class_node = ast_child.get_child(0)
        else:
            class_node = ast_child  # fallback
        # Check for anchors at root level
        has_start, has_end = pattern_has_anchors(ast)
    else:
        class_node = ast

    # Extract quantifier information and character class
    if class_node.type == DIGIT:
        min_matches = class_node.min
        max_matches = class_node.max
        positive_logic = class_node.positive_logic
        # Generate digit character class string "0123456789"
        char_class = class_node.get_value()
    elif class_node.type == RANGE:
        min_matches = class_node.min
        max_matches = class_node.max
        positive_logic = class_node.positive_logic
        # Use the range value directly - expansion will be done when used
        char_class = class_node.get_value()

    return (
        char_class^,
        min_matches,
        max_matches,
        has_start,
        has_end,
        positive_logic,
    )


fn _is_pure_anchor_pattern(ast: ASTNode[MutableAnyOrigin]) -> Bool:
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
        if not ast.has_children():
            return False
        return _is_pure_anchor_pattern(ast.get_child(0))
    elif ast.type == GROUP:
        # Check if group contains only anchors
        for i in range(ast.get_children_len()):
            if not _is_pure_anchor_pattern(ast.get_child(i)):
                return False
        return True
    else:
        return False


fn _is_sequential_character_class_pattern(
    ast: ASTNode[MutableAnyOrigin],
) -> Bool:
    """Check if pattern is a sequence of character classes with quantifiers.

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a sequence like [+]*\\d+[-]*\\d+.
    """
    from regex.ast import RE, DIGIT, RANGE, GROUP

    if ast.type != RE or ast.get_children_len() != 1:
        return False

    var child = ast.get_child(0)
    if child.type != GROUP:
        return False

    # Check if all children are character classes (RANGE or DIGIT)
    for i in range(child.get_children_len()):
        var element = child.get_child(i)
        if element.type != RANGE and element.type != DIGIT:
            return False

    # Must have at least 2 elements to be considered sequential
    return child.get_children_len() >= 2


fn _extract_sequential_pattern_info(
    ast: ASTNode[MutableAnyOrigin],
) -> SequentialPatternInfo:
    """Extract information about a sequential pattern.

    Args:
        ast: AST node representing a sequential pattern.

    Returns:
        SequentialPatternInfo with details about each element.
    """
    from regex.ast import RE, DIGIT, RANGE, GROUP

    var info = SequentialPatternInfo()

    # Check for anchors at root level
    info.has_start_anchor, info.has_end_anchor = pattern_has_anchors(ast)

    if ast.type == RE and ast.get_children_len() == 1:
        var child = ast.get_child(0)
        if child.type == GROUP:
            # Extract each character class element
            for i in range(child.get_children_len()):
                var element = child.get_child(i)
                var char_class: String

                if element.type == DIGIT:
                    char_class = DIGITS
                elif element.type == RANGE:
                    char_class = expand_character_range(
                        element.get_value().value()
                    )
                else:
                    continue  # Skip unknown elements

                var pattern_element = SequentialPatternElement(
                    char_class, element.min, element.max, element.positive_logic
                )
                info.elements.append(pattern_element)

    return info^


fn _is_multi_character_class_sequence(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if pattern is a sequence of multiple character classes.

    Examples: [a-z]+[0-9]+, digit+word+, [A-Z][a-z]*[0-9]{2,4}

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a multi-character class sequence.
    """
    from regex.ast import RE, DIGIT, RANGE, GROUP, SPACE, WILDCARD, ELEMENT

    if ast.type != RE or ast.get_children_len() != 1:
        return False

    var child = ast.get_child(0)
    if child.type != GROUP:
        return False

    # Check if all children are character classes with quantifiers
    # Must have at least 2 elements to be considered a sequence
    if child.get_children_len() < 2:
        return False

    var char_class_count = 0
    var literal_count = 0

    for i in range(child.get_children_len()):
        ref element = child.get_child(i)
        if (
            element.type == RANGE
            or element.type == DIGIT
            or element.type == SPACE
        ):
            char_class_count += 1
        elif element.type == WILDCARD:
            # Wildcard can be considered a character class
            char_class_count += 1
        elif element.type == ELEMENT and element.min == 1 and element.max == 1:
            # Single literal characters are OK (like @ and . in email patterns)
            literal_count += 1
        else:
            # Other types make it non-sequential
            return False

    # It's a multi-char sequence if it has at least 2 character classes
    # and any number of single literals
    return char_class_count >= 2


fn _extract_multi_class_sequence_info(
    ast: ASTNode[MutableAnyOrigin],
) -> SequentialPatternInfo:
    """Extract information about a multi-character class sequence.

    Args:
        ast: AST node representing a multi-character class sequence.

    Returns:
        SequentialPatternInfo with details about each character class element.
    """
    from regex.ast import RE, DIGIT, RANGE, GROUP, SPACE, WILDCARD, ELEMENT

    var info = SequentialPatternInfo()

    # Check for anchors at root level
    info.has_start_anchor, info.has_end_anchor = pattern_has_anchors(ast)

    if ast.type == RE and ast.get_children_len() == 1:
        var child = ast.get_child(0)
        if child.type == GROUP:
            # Extract each character class element
            for i in range(child.get_children_len()):
                ref element = child.get_child(i)
                var char_class: String

                if element.type == DIGIT:
                    char_class = "0123456789"
                elif element.type == RANGE:
                    char_class = expand_character_range(
                        element.get_value().value()
                    )
                elif element.type == SPACE:
                    char_class = " \t\n\r\f"
                elif element.type == WILDCARD:
                    # Wildcard matches any character except newline
                    char_class = ALL_EXCEPT_NEWLINE
                elif element.type == ELEMENT:
                    # Single literal character (like @ or .)
                    char_class = String(
                        element.get_value().value()
                    ) if element.get_value() else ""
                else:
                    continue  # Skip unknown elements

                var pattern_element = SequentialPatternElement(
                    char_class^,
                    element.min,
                    element.max,
                    element.positive_logic,
                )
                info.elements.append(pattern_element)

    return info^


fn _is_mixed_sequential_pattern(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if pattern is a mixed sequential pattern with optional literals.

    Examples: [0-9]+\\.?[0-9]*, [a-z]+@[a-z]+\\.[a-z]+

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a mixed sequential pattern.
    """
    from regex.ast import RE, DIGIT, RANGE, GROUP, ELEMENT

    if ast.type != RE or ast.get_children_len() != 1:
        return False

    var child = ast.get_child(0)
    if child.type != GROUP:
        return False

    # Must have at least 3 elements (char class, optional literal, char class)
    if child.get_children_len() < 3:
        return False

    var has_char_class = False
    var has_optional_literal = False

    for i in range(child.get_children_len()):
        ref element = child.get_child(i)

        if element.type == RANGE or element.type == DIGIT:
            has_char_class = True
        elif element.type == ELEMENT:
            # Check if it's an optional literal (min=0, max=1)
            if element.min == 0 and element.max == 1:
                has_optional_literal = True

    # It's a mixed pattern if it has both character classes and optional literals
    return has_char_class and has_optional_literal


fn _extract_mixed_sequential_pattern_info(
    ast: ASTNode[MutableAnyOrigin],
) -> SequentialPatternInfo:
    """Extract information about a mixed sequential pattern.

    Args:
        ast: AST node representing a mixed sequential pattern.

    Returns:
        SequentialPatternInfo with details about each element.
    """
    # For now, reuse the multi-class sequence extraction logic
    # It already handles ELEMENT types correctly
    return _extract_multi_class_sequence_info(ast)
