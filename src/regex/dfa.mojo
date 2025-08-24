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
from regex.simd_ops import (
    SIMDStringSearch,
    CharacterClassSIMD,
    apply_quantifier_simd_generic,
    find_in_text_simd,
)
from regex.simd_matchers import (
    analyze_character_class_pattern,
    get_digit_matcher,
    get_alpha_matcher,
    get_alnum_matcher,
    get_whitespace_matcher,
    get_hex_digit_matcher,
    RangeBasedMatcher,
    NibbleBasedMatcher,
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
    var literal_pattern: String
    """Storage for literal pattern to keep it alive for SIMD string search."""

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
        self.literal_pattern = ""

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
        self.literal_pattern = other.literal_pattern^

    fn compile_pattern(
        mut self,
        pattern: String,
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
        self.literal_pattern = pattern

        if len_pattern == 0:
            self._create_accepting_state()
            return

        # For pure literal patterns without anchors, use SIMD string search
        if not has_start_anchor and not has_end_anchor and len_pattern > 0:
            self.literal_pattern = pattern  # Store pattern to keep it alive
            self.is_pure_literal = True
            self.simd_string_search = SIMDStringSearch(self.literal_pattern)
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
            ref element = pattern_info.elements[element_idx]
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

        # TODO: Enable SIMD optimization for digit-heavy patterns
        # This addresses performance regression in patterns like [0-9]+[.]?[0-9]*
        # Currently disabled due to correctness issues - needs better integration with DFA logic
        # self._try_enable_simd_for_sequence(sequence_info)

        # Build a chain of states for each character class in the sequence
        var current_state_index = 0

        for element_idx in range(len(sequence_info.elements)):
            ref element = sequence_info.elements[element_idx]
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
                    ref prev_element = sequence_info.elements[0]
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

    fn compile_alternation(mut self, ast: ASTNode[MutableAnyOrigin]) raises:
        """Compile an alternation pattern like a|b or (cat|dog) into a DFA.

        Creates a state machine with parallel branches that converge to accepting states.

        Args:
            ast: AST node representing the alternation pattern.
        """
        from regex.ast import RE, OR, GROUP, ELEMENT

        # Clear existing states
        self.states.clear()

        # Create start state
        var start_state = DFAState()
        self.states.append(start_state)
        self.start_state = 0

        # Extract the OR node
        ref or_node_opt = _find_or_node(ast)
        if not or_node_opt:
            raise Error("No OR node found in alternation pattern")

        ref or_node = or_node_opt.value()

        # Create accepting state that all branches will lead to
        var accepting_state = DFAState(is_accepting=True, match_length=0)
        self.states.append(accepting_state)
        var accepting_index = len(self.states) - 1

        # Collect all branch texts (flattening nested OR structures)
        ref all_branches = _collect_all_alternation_branches(or_node)

        # Build trie-like DFA structure to handle shared prefixes
        for i in range(len(all_branches)):
            ref branch_text = all_branches[i]
            if len(branch_text) == 0:
                continue

            # Navigate/create path for this branch
            var current_state_index = 0  # Start from start state

            for j in range(len(branch_text)):
                var char_code = ord(branch_text[j])

                if j == len(branch_text) - 1:
                    # Last character - transition to accepting state
                    self.states[current_state_index].add_transition(
                        char_code, accepting_index
                    )
                else:
                    # Intermediate character - find existing state or create new one
                    var next_state_index = self._find_or_create_state(
                        current_state_index, char_code
                    )
                    current_state_index = next_state_index

    fn compile_quantified_group(
        mut self, ast: ASTNode[MutableAnyOrigin]
    ) raises:
        """Compile a quantified group pattern like (abc)+, (test)*, (a)? into a DFA.

        Creates a state machine with loops and optional paths based on quantifiers.

        Args:
            ast: AST node representing the quantified group pattern.
        """
        from regex.ast import RE, GROUP, ELEMENT

        # Clear existing states
        self.states.clear()

        # Create start state
        var start_state = DFAState()
        self.states.append(start_state)
        self.start_state = 0

        # Navigate to the quantified group: RE -> GROUP -> GROUP (with quantifier)
        ref outer_group = ast.get_child(0)  # First GROUP
        ref inner_group = outer_group.get_child(
            0
        )  # Second GROUP (with quantifier)

        var min_matches = inner_group.min
        var max_matches = inner_group.max

        # Extract the literal text from the group
        ref group_text = _extract_group_text(inner_group)
        if len(group_text) == 0:
            raise Error("Empty quantified group")

        # Create accepting state
        var accepting_state = DFAState(is_accepting=True, match_length=0)
        self.states.append(accepting_state)
        var accepting_index = len(self.states) - 1

        # Handle different quantifier types
        if min_matches == 0 and max_matches == 1:
            # Optional: (pattern)?
            self._compile_optional_group(group_text, accepting_index)
        elif min_matches == 0 and max_matches == -1:
            # Zero or more: (pattern)*
            self._compile_zero_or_more_group(group_text, accepting_index)
        elif min_matches == 1 and max_matches == -1:
            # One or more: (pattern)+
            self._compile_one_or_more_group(group_text, accepting_index)
        else:
            raise Error("Unsupported quantifier range for group")

    fn _compile_optional_group(
        mut self, group_text: String, accepting_index: Int
    ):
        """Compile an optional group (pattern)? - match 0 or 1 times."""
        # Start state can go directly to accepting (0 matches) or through pattern (1 match)

        # Direct path to accepting state (0 matches)
        self.states[0].add_transition(0, accepting_index)  # epsilon transition

        # Path through pattern (1 match)
        var current_state_index = 0
        for i in range(len(group_text)):
            var char_code = ord(group_text[i])

            if i == len(group_text) - 1:
                # Last character - go to accepting state
                self.states[current_state_index].add_transition(
                    char_code, accepting_index
                )
            else:
                # Intermediate character - create new state
                var next_state = DFAState()
                self.states.append(next_state)
                var next_index = len(self.states) - 1
                self.states[current_state_index].add_transition(
                    char_code, next_index
                )
                current_state_index = next_index

    fn _compile_zero_or_more_group(
        mut self, group_text: String, accepting_index: Int
    ):
        """Compile a zero-or-more group (pattern)* - match 0 or more times."""
        # Start state can go directly to accepting or start the pattern

        # Direct path to accepting state (0 matches)
        # For DFA, we'll make start state accepting
        self.states[0].is_accepting = True

        # Create loop through pattern
        var current_state_index = 0
        for i in range(len(group_text)):
            var char_code = ord(group_text[i])

            if i == len(group_text) - 1:
                # Last character - loop back to start (for more matches) or stay accepting
                self.states[current_state_index].add_transition(char_code, 0)
            else:
                # Intermediate character - create new state
                var next_state = DFAState()
                self.states.append(next_state)
                var next_index = len(self.states) - 1
                self.states[current_state_index].add_transition(
                    char_code, next_index
                )
                current_state_index = next_index

    fn _compile_one_or_more_group(
        mut self, group_text: String, accepting_index: Int
    ):
        """Compile a one-or-more group (pattern)+ - match 1 or more times."""
        # Must match at least once, then can loop

        var current_state_index = 0
        for i in range(len(group_text)):
            var char_code = ord(group_text[i])

            if i == len(group_text) - 1:
                # Last character - create accepting state that can loop back
                var loop_state = DFAState(is_accepting=True)
                self.states.append(loop_state)
                var loop_index = len(self.states) - 1
                self.states[current_state_index].add_transition(
                    char_code, loop_index
                )

                # From loop state, can start pattern again or stay accepting
                self.states[loop_index].add_transition(
                    ord(group_text[0]), 1 if len(group_text) > 1 else loop_index
                )
            else:
                # Intermediate character - create new state
                var next_state = DFAState()
                self.states.append(next_state)
                var next_index = len(self.states) - 1
                self.states[current_state_index].add_transition(
                    char_code, next_index
                )
                current_state_index = next_index

    fn compile_simple_quantifier(
        mut self, ast: ASTNode[MutableAnyOrigin]
    ) raises:
        """Compile a simple quantifier pattern like a*, test+, char? into a DFA.

        Creates a state machine based on the quantifier type applied to literal sequences.

        Args:
            ast: AST node representing the simple quantifier pattern.
        """
        from regex.ast import RE, GROUP, ELEMENT

        # Clear existing states
        self.states.clear()

        # Create start state
        var start_state = DFAState()
        self.states.append(start_state)
        self.start_state = 0

        # Navigate to the group containing elements with quantifiers
        ref group = ast.get_child(0)  # GROUP

        # Extract pattern text and find quantifier info
        var pattern_parts = List[String]()
        var quantifier_type = String("")
        var quantifier_min = 1
        var quantifier_max = 1

        # Process each element to build pattern and detect quantifier
        for i in range(group.get_children_len()):
            ref element = group.get_child(i)
            ref char_text = String(element.get_value().value())

            if element.min == 0 and element.max == -1:  # *
                quantifier_type = "*"
                quantifier_min = 0
                quantifier_max = -1
            elif element.min == 1 and element.max == -1:  # +
                quantifier_type = "+"
                quantifier_min = 1
                quantifier_max = -1
            elif element.min == 0 and element.max == 1:  # ?
                quantifier_type = "?"
                quantifier_min = 0
                quantifier_max = 1

            pattern_parts.append(char_text)

        # Build the pattern string
        var pattern_text = String("")
        for i in range(len(pattern_parts)):
            pattern_text += pattern_parts[i]

        if len(pattern_text) == 0:
            raise Error("Empty quantifier pattern")

        # Create accepting state
        var accepting_state = DFAState(is_accepting=True, match_length=0)
        self.states.append(accepting_state)
        var accepting_index = len(self.states) - 1

        # Handle different quantifier types
        if quantifier_min == 0 and quantifier_max == 1:
            # Optional: pattern?
            self._compile_simple_optional(pattern_text, accepting_index)
        elif quantifier_min == 0 and quantifier_max == -1:
            # Zero or more: pattern*
            self._compile_simple_zero_or_more(pattern_text, accepting_index)
        elif quantifier_min == 1 and quantifier_max == -1:
            # One or more: pattern+
            self._compile_simple_one_or_more(pattern_text, accepting_index)
        else:
            raise Error("Unsupported quantifier type for simple quantifier")

    fn _compile_simple_optional(
        mut self, pattern_text: String, accepting_index: Int
    ):
        """Compile a simple optional pattern (pattern?) - match 0 or 1 times."""
        # Start state can go directly to accepting (0 matches) or through pattern (1 match)

        # Direct path to accepting state (0 matches)
        self.states[
            0
        ].is_accepting = True  # Make start state accepting for empty match

        # Path through pattern (1 match)
        var current_state_index = 0
        for i in range(len(pattern_text)):
            var char_code = ord(pattern_text[i])

            if i == len(pattern_text) - 1:
                # Last character - go to accepting state
                self.states[current_state_index].add_transition(
                    char_code, accepting_index
                )
            else:
                # Intermediate character - create new state
                var next_state = DFAState()
                self.states.append(next_state)
                var next_index = len(self.states) - 1
                self.states[current_state_index].add_transition(
                    char_code, next_index
                )
                current_state_index = next_index

    fn _compile_simple_zero_or_more(
        mut self, pattern_text: String, accepting_index: Int
    ):
        """Compile a simple zero-or-more pattern (pattern*) - match 0 or more times.
        """
        # Start state can go directly to accepting or start the pattern

        # Direct path to accepting state (0 matches)
        # For DFA, we'll make start state accepting
        self.states[0].is_accepting = True

        # Create loop through pattern
        var current_state_index = 0
        for i in range(len(pattern_text)):
            var char_code = ord(pattern_text[i])

            if i == len(pattern_text) - 1:
                # Last character - loop back to start (for more matches) or stay accepting
                self.states[current_state_index].add_transition(char_code, 0)
            else:
                # Intermediate character - create new state
                var next_state = DFAState()
                self.states.append(next_state)
                var next_index = len(self.states) - 1
                self.states[current_state_index].add_transition(
                    char_code, next_index
                )
                current_state_index = next_index

    fn _compile_simple_one_or_more(
        mut self, pattern_text: String, accepting_index: Int
    ):
        """Compile a simple one-or-more pattern (pattern+) - match 1 or more times.
        """
        # Must match at least once, then can loop

        var current_state_index = 0
        for i in range(len(pattern_text)):
            var char_code = ord(pattern_text[i])

            if i == len(pattern_text) - 1:
                # Last character - create accepting state that can loop back
                var loop_state = DFAState(is_accepting=True)
                self.states.append(loop_state)
                var loop_index = len(self.states) - 1
                self.states[current_state_index].add_transition(
                    char_code, loop_index
                )

                # From loop state, can start pattern again or stay accepting
                self.states[loop_index].add_transition(
                    ord(pattern_text[0]),
                    1 if len(pattern_text) > 1 else loop_index,
                )
            else:
                # Intermediate character - create new state
                var next_state = DFAState()
                self.states.append(next_state)
                var next_index = len(self.states) - 1
                self.states[current_state_index].add_transition(
                    char_code, next_index
                )
                current_state_index = next_index

    fn _find_or_create_state(mut self, from_state: Int, char_code: Int) -> Int:
        """Find existing state for transition or create new one.

        Args:
            from_state: Source state index.
            char_code: Character code for the transition.

        Returns:
            State index for the target of this transition.
        """
        # Check if transition already exists
        var existing_target = Int(
            self.states[from_state].transitions[char_code]
        )
        if existing_target != 255:  # 255 is -1 in uint8
            # Transition already exists, reuse the target state
            return existing_target
        else:
            # Create new state and add transition
            var new_state = DFAState()
            self.states.append(new_state)
            var new_state_index = len(self.states) - 1
            self.states[from_state].add_transition(char_code, new_state_index)
            return new_state_index

    fn compile_wildcard_quantifier(
        mut self, ast: ASTNode[MutableAnyOrigin]
    ) raises:
        """Compile a wildcard quantifier pattern like .*, .+, .? into a DFA.

        Creates a state machine that matches any character with the specified quantifier.

        Args:
            ast: AST node representing the wildcard quantifier pattern.
        """
        from regex.ast import RE, GROUP, WILDCARD

        # Clear existing states
        self.states.clear()

        # Create start state
        var start_state = DFAState()
        self.states.append(start_state)
        self.start_state = 0

        # Navigate to the wildcard element
        ref group = ast.get_child(0)  # GROUP
        ref wildcard = group.get_child(0)  # WILDCARD

        # Extract quantifier information
        var quantifier_min = wildcard.min
        var quantifier_max = wildcard.max

        # Create accepting state
        var accepting_state = DFAState(is_accepting=True, match_length=0)
        self.states.append(accepting_state)
        var accepting_index = len(self.states) - 1

        # Handle different quantifier types
        if quantifier_min == 0 and quantifier_max == 1:
            # Optional: .?
            self._compile_wildcard_optional(accepting_index)
        elif quantifier_min == 0 and quantifier_max == -1:
            # Zero or more: .*
            self._compile_wildcard_zero_or_more(accepting_index)
        elif quantifier_min == 1 and quantifier_max == -1:
            # One or more: .+
            self._compile_wildcard_one_or_more(accepting_index)
        elif quantifier_min == 1 and quantifier_max == 1:
            # Single dot: .
            self._compile_wildcard_single(accepting_index)
        else:
            raise Error("Unsupported quantifier type for wildcard quantifier")

    fn _compile_wildcard_optional(mut self, accepting_index: Int):
        """Compile .? - match any character 0 or 1 times."""
        # Start state is accepting (0 matches)
        self.states[0].is_accepting = True

        # Add transitions from start state to accepting for any character except newline
        for i in range(256):
            if i != ord("\n"):  # Wildcard doesn't match newline by default
                self.states[0].add_transition(i, accepting_index)

    fn _compile_wildcard_zero_or_more(mut self, accepting_index: Int):
        """Compile .* - match any character 0 or more times."""
        # Start state is accepting (0 matches)
        self.states[0].is_accepting = True

        # Add transitions from start state back to itself for any character except newline
        for i in range(256):
            if i != ord("\n"):  # Wildcard doesn't match newline by default
                self.states[0].add_transition(i, 0)  # Loop back to start

    fn _compile_wildcard_one_or_more(mut self, accepting_index: Int):
        """Compile .+ - match any character 1 or more times."""
        # Create an accepting state that can loop
        var loop_state = DFAState(is_accepting=True)
        self.states.append(loop_state)
        var loop_index = len(self.states) - 1

        # Add transitions from start state to loop state for any character except newline
        for i in range(256):
            if i != ord("\n"):  # Wildcard doesn't match newline by default
                self.states[0].add_transition(i, loop_index)

        # Add transitions from loop state back to itself for any character except newline
        for i in range(256):
            if i != ord("\n"):
                self.states[loop_index].add_transition(i, loop_index)

    fn _compile_wildcard_single(mut self, accepting_index: Int):
        """Compile . - match any single character."""
        # Add transitions from start state to accepting for any character except newline
        for i in range(256):
            if i != ord("\n"):  # Wildcard doesn't match newline by default
                self.states[0].add_transition(i, accepting_index)

    fn compile_common_prefix_alternation(
        mut self, ast: ASTNode[MutableAnyOrigin]
    ) raises:
        """Compile common prefix alternation patterns like (hello|help|helicopter) into a DFA.

        Creates a trie-like DFA structure that shares common prefixes and branches for suffixes.

        Args:
            ast: AST node representing the common prefix alternation pattern.
        """
        from regex.ast import RE, GROUP, OR

        # Clear existing states
        self.states.clear()

        # Create start state
        var start_state = DFAState()
        self.states.append(start_state)
        self.start_state = 0

        # Navigate to the OR structure inside the group
        # Pattern structure: RE -> GROUP -> GROUP -> OR tree
        ref outer_group = ast.get_child(0)  # Outer GROUP
        ref inner_group = outer_group.get_child(0)  # Inner GROUP
        ref or_node = inner_group.get_child(0)  # OR node

        # Extract all alternation branches
        var branches = List[String]()
        self._extract_all_prefix_branches(or_node, branches)

        # Build trie-like DFA structure
        self._build_prefix_trie(branches)

    fn _extract_all_prefix_branches(
        self, node: ASTNode[MutableAnyOrigin], mut branches: List[String]
    ):
        """Extract all string branches from nested OR structure."""
        from regex.ast import OR, GROUP, ELEMENT

        if node.type == OR:
            # Get left and right children
            ref left_child = node.get_child(0)
            ref right_child = node.get_child(1)

            # Recursively process both sides
            self._extract_all_prefix_branches(left_child, branches)
            self._extract_all_prefix_branches(right_child, branches)
        elif node.type == GROUP:
            # Extract string from GROUP of ELEMENTs
            var branch_text = String("")
            for i in range(node.get_children_len()):
                ref element = node.get_child(i)
                if element.type == ELEMENT:
                    ref char_value = element.get_value().value()
                    branch_text += String(char_value)
            branches.append(branch_text)

    fn _build_prefix_trie(mut self, branches: List[String]) raises:
        """Build a trie-like DFA structure from alternation branches."""
        if len(branches) == 0:
            return

        # Find the common prefix among all branches
        ref common_prefix = self._find_common_prefix(branches)
        var prefix_len = len(common_prefix)

        # Build states for the common prefix
        var current_state = 0
        for i in range(prefix_len):
            var char_code = ord(common_prefix[i])
            var next_state_index = self._find_or_create_state(
                current_state, char_code
            )
            current_state = next_state_index

        # Process each branch after common prefix
        for i in range(len(branches)):
            ref branch = branches[i]
            if len(branch) == prefix_len:
                # Branch ends at common prefix - make current state accepting
                self.states[current_state].is_accepting = True
            else:
                # Branch continues - build suffix directly
                var suffix = branch[prefix_len:]
                var suffix_current_state = current_state

                for j in range(len(suffix)):
                    var char_code = ord(suffix[j])

                    if j == len(suffix) - 1:
                        # Last character - create or mark accepting state
                        var target_state = self._find_or_create_state(
                            suffix_current_state, char_code
                        )
                        self.states[target_state].is_accepting = True
                    else:
                        # Intermediate character
                        suffix_current_state = self._find_or_create_state(
                            suffix_current_state, char_code
                        )

    fn _find_common_prefix(self, branches: List[String]) -> String:
        """Find the longest common prefix among all branches."""
        if len(branches) == 0:
            return String("")
        if len(branches) == 1:
            return branches[0]

        var prefix = String("")
        ref first_branch = branches[0]
        var min_length = len(first_branch)

        # Find minimum length
        for i in range(1, len(branches)):
            if len(branches[i]) < min_length:
                min_length = len(branches[i])

        # Find common prefix
        for pos in range(min_length):
            var char_at_pos = first_branch[pos]
            var all_match = True

            for i in range(1, len(branches)):
                if branches[i][pos] != char_at_pos:
                    all_match = False
                    break

            if all_match:
                prefix += String(char_at_pos)
            else:
                break

        return prefix

    @always_inline
    fn _create_accepting_state(mut self: Self):
        """Create a single accepting state as the pattern is empty."""
        var state = DFAState(is_accepting=True, match_length=0)
        self.states.append(state)
        self.start_state = 0

    fn compile_quantified_alternation_group(
        mut self, ast: ASTNode[MutableAnyOrigin]
    ) raises:
        """Compile quantified alternation groups like (a|b)*, (cat|dog)+ into a DFA.

        Creates a state machine that loops through alternation choices with quantifier behavior.

        Args:
            ast: AST node representing the quantified alternation group pattern.
        """
        from regex.ast import RE, GROUP, OR

        # Clear existing states
        self.states.clear()

        # Create start state
        var start_state = DFAState()
        self.states.append(start_state)
        self.start_state = 0

        # Navigate to the quantified group and alternation
        # Pattern structure: RE -> GROUP -> GROUP(quantified) -> OR
        ref outer_group = ast.get_child(0)  # Outer GROUP
        ref quantified_group = outer_group.get_child(0)  # Quantified GROUP
        ref or_node = quantified_group.get_child(0)  # OR node

        # Extract quantifier information
        var quantifier_min = quantified_group.min
        var quantifier_max = quantified_group.max

        # Extract alternation branches
        var branches = List[String]()
        self._extract_all_alternation_branches_for_quantified(or_node, branches)

        # Handle different quantifier types
        if quantifier_min == 0 and quantifier_max == 1:
            # Optional: (a|b)?
            self._compile_quantified_alternation_optional(branches)
        elif quantifier_min == 0 and quantifier_max == -1:
            # Zero or more: (a|b)*
            self._compile_quantified_alternation_zero_or_more(branches)
        elif quantifier_min == 1 and quantifier_max == -1:
            # One or more: (a|b)+
            self._compile_quantified_alternation_one_or_more(branches)
        else:
            raise Error(
                "Unsupported quantifier type for quantified alternation group"
            )

    fn _extract_all_alternation_branches_for_quantified(
        self, node: ASTNode[MutableAnyOrigin], mut branches: List[String]
    ):
        """Extract all string branches from alternation for quantified groups.
        """
        from regex.ast import OR, GROUP, ELEMENT

        if node.type == OR:
            # Get left and right children
            ref left_child = node.get_child(0)
            ref right_child = node.get_child(1)

            # Recursively process both sides
            self._extract_all_alternation_branches_for_quantified(
                left_child, branches
            )
            self._extract_all_alternation_branches_for_quantified(
                right_child, branches
            )
        elif node.type == GROUP:
            # Extract string from GROUP of ELEMENTs
            var branch_text = String("")
            for i in range(node.get_children_len()):
                ref element = node.get_child(i)
                if element.type == ELEMENT:
                    ref char_value = element.get_value().value()
                    branch_text += String(char_value)
            branches.append(branch_text)

    fn _compile_quantified_alternation_optional(
        mut self, branches: List[String]
    ) raises:
        """Compile (a|b)? - match one of the alternation branches 0 or 1 times.
        """
        # Start state is accepting (0 matches)
        self.states[0].is_accepting = True

        # Create accepting state for matches
        var accepting_state = DFAState(is_accepting=True)
        self.states.append(accepting_state)
        var accepting_index = len(self.states) - 1

        # Add paths for each branch
        for i in range(len(branches)):
            ref branch = branches[i]
            var current_state = 0

            for j in range(len(branch)):
                var char_code = ord(branch[j])

                if j == len(branch) - 1:
                    # Last character - go to accepting state
                    self.states[current_state].add_transition(
                        char_code, accepting_index
                    )
                else:
                    # Intermediate character - find or create state
                    current_state = self._find_or_create_state(
                        current_state, char_code
                    )

    fn _compile_quantified_alternation_zero_or_more(
        mut self, branches: List[String]
    ) raises:
        """Compile (a|b)* - match any of the alternation branches 0 or more times.
        """
        # Start state is accepting (0 matches)
        self.states[0].is_accepting = True

        # For each branch, create path that loops back to start
        for i in range(len(branches)):
            ref branch = branches[i]
            var current_state = 0

            for j in range(len(branch)):
                var char_code = ord(branch[j])

                if j == len(branch) - 1:
                    # Last character - loop back to start for more matches
                    self.states[current_state].add_transition(char_code, 0)
                else:
                    # Intermediate character - find or create state
                    current_state = self._find_or_create_state(
                        current_state, char_code
                    )

    fn _compile_quantified_alternation_one_or_more(
        mut self, branches: List[String]
    ) raises:
        """Compile (a|b)+ - match any of the alternation branches 1 or more times.
        """
        # Create an accepting state that can loop
        var loop_state = DFAState(is_accepting=True)
        self.states.append(loop_state)
        var loop_index = len(self.states) - 1

        # For each branch, create path to loop state
        for i in range(len(branches)):
            ref branch = branches[i]
            var current_state = 0

            for j in range(len(branch)):
                var char_code = ord(branch[j])

                if j == len(branch) - 1:
                    # Last character - go to loop state
                    self.states[current_state].add_transition(
                        char_code, loop_index
                    )
                else:
                    # Intermediate character - find or create state
                    current_state = self._find_or_create_state(
                        current_state, char_code
                    )

        # From loop state, can match any branch again (loop back through each branch)
        for i in range(len(branches)):
            ref branch = branches[i]
            var current_state = loop_index

            for j in range(len(branch)):
                var char_code = ord(branch[j])

                if j == len(branch) - 1:
                    # Last character - back to loop state
                    self.states[current_state].add_transition(
                        char_code, loop_index
                    )
                else:
                    # Intermediate character - find or create state
                    current_state = self._find_or_create_state(
                        current_state, char_code
                    )

    fn _try_enable_simd_for_sequence(
        mut self, sequence_info: SequentialPatternInfo
    ):
        """Try to enable SIMD optimization for multi-character sequences dominated by digits.

        This addresses performance regression in patterns like [0-9]+[.]?[0-9]*
        where SIMD optimization was disabled despite being digit-heavy.

        Args:
            sequence_info: Information about the pattern sequence.
        """
        if not sequence_info.elements:
            return

        # Analyze the sequence to see if it's digit-dominated
        var digit_elements = 0
        var total_elements = len(sequence_info.elements)
        var first_element_is_digits = False

        for i in range(total_elements):
            var element = sequence_info.elements[i]
            if (
                element.char_class == DIGITS
                or element.char_class == "0123456789"
            ):
                digit_elements += 1
                if i == 0:
                    first_element_is_digits = True

        # Enable SIMD for patterns where:
        # 1. First element is digits with min_matches >= 1 (like [0-9]+)
        # 2. At least half the elements are digit-related
        # This covers patterns like [0-9]+[.]?[0-9]*
        if (
            first_element_is_digits
            and sequence_info.elements[0].min_matches >= 1
            and digit_elements * 2 >= total_elements
        ):
            self.simd_char_matcher = CharacterClassSIMD(DIGITS)
            self.simd_char_pattern = "[0-9]"

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

        # Optimization: Use SIMD to quickly find candidate positions for character class patterns
        if self.simd_char_matcher and not self.has_end_anchor:
            return self._optimized_simd_search(text, start)

        # Fallback: Try to find a match starting from each position from 'start' onwards
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
            ref searcher = self.simd_string_search.value()
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

        # Check if we ended in an accepting state (important for exact matches)
        if (
            pos == len(text)
            and current_state < len(self.states)
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
        # Smart capacity allocation - avoid over-allocation for sparse matches
        var estimated_capacity = min(
            len(text) // 20, 10
        )  # Conservative estimate
        var matches = List[Match, hint_trivial_type=True](
            capacity=estimated_capacity
        )

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
                ref match_obj = match_result.value()
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
        """SIMD-optimized matching for character class patterns with quantifier support.

        This hybrid approach uses SIMD for fast character matching while respecting
        DFA quantifier constraints by validating the result through state machine simulation.

        Args:
            text: Input text to match against.
            start_pos: Position to start matching from.

        Returns:
            Optional Match if pattern matches at this position, None otherwise.
        """
        if not self.simd_char_matcher:
            return None

        ref simd_matcher = self.simd_char_matcher.value()
        var text_len = len(text)

        if len(self.states) == 0:
            return None

        # Check if start state is accepting (for patterns like [a-z]*)
        var start_accepting = self.states[self.start_state].is_accepting

        # Disable SIMD for exact quantifier patterns to ensure correctness
        if len(self.states) > 1 and not start_accepting:
            # Check if this looks like an exact quantifier pattern
            var accepting_states = 0
            var min_length = -1
            var max_length = -1

            for i in range(len(self.states)):
                if self.states[i].is_accepting:
                    accepting_states += 1
                    if self.states[i].match_length > 0:
                        if (
                            min_length == -1
                            or self.states[i].match_length < min_length
                        ):
                            min_length = self.states[i].match_length
                        if (
                            max_length == -1
                            or self.states[i].match_length > max_length
                        ):
                            max_length = self.states[i].match_length

            # If we have specific length constraints, this indicates quantifiers like {3} or {2,4}
            if min_length > 0:
                if accepting_states == 1:
                    # Exact quantifier like {3} - disable SIMD, fall back to DFA
                    return None
                elif max_length > min_length:
                    # Range quantifier like {2,4} - disable SIMD, fall back to DFA
                    return None

        # Use SIMD to count consecutive matching characters
        var pos = start_pos
        var match_count = 0

        while pos < text_len:
            var ch_code = ord(text[pos])
            if simd_matcher.contains(ch_code):
                match_count += 1
                pos += 1
            else:
                break

        # Restore original fast SIMD logic (from before commit 0f5804a3e8df649030ee7cfaa8b3a87fc9c4ad68)
        # This provides maximum performance for the common case

        # Original logic: simple and fast
        var is_valid_match = False
        var match_end = start_pos + match_count

        if match_count == 0:
            # No characters matched - only valid if start state accepts (e.g., [a-z]*)
            if start_accepting:
                is_valid_match = True
                match_end = start_pos
        else:
            # Some characters matched - for character class patterns, any positive match count is typically valid
            # This is the original logic that provided high performance
            is_valid_match = True

        if is_valid_match:
            # Check end anchor constraint
            if self.has_end_anchor and match_end != text_len:
                return None
            return Match(0, start_pos, match_end, text)

        return None

    fn _optimized_simd_search(
        self, text: String, start: Int
    ) -> Optional[Match]:
        """Optimized SIMD-based search for character class patterns.

        This method uses SIMD to quickly scan through the text and find positions
        where the character class might match, avoiding the O(n²) problem of
        trying every position individually.

        Args:
            text: Input text to search.
            start: Starting position for search.

        Returns:
            Optional Match if found, None otherwise.
        """
        if not self.simd_char_matcher:
            return None

        ref simd_matcher = self.simd_char_matcher.value()
        var text_len = len(text)
        var pos = start

        # Use SIMD to scan for potential match positions
        while pos < text_len:
            # Find next character that matches our character class
            var found_pos = self._find_next_matching_char(
                text, pos, simd_matcher
            )
            if found_pos == -1:
                # No more matching characters found
                return None

            # Try to match the full pattern starting at this position
            var match_result = self._try_match_at_position(text, found_pos)
            if match_result:
                return match_result

            # Move to next position to continue searching
            pos = found_pos + 1

        return None

    fn _find_next_matching_char(
        self, text: String, start: Int, simd_matcher: CharacterClassSIMD
    ) -> Int:
        """Use SIMD to find the next character that matches the character class.

        Args:
            text: Text to search in.
            start: Starting position.
            simd_matcher: SIMD matcher for the character class.

        Returns:
            Position of next matching character, or -1 if not found.
        """
        var pos = start
        var text_len = len(text)

        # Process characters in SIMD chunks for maximum efficiency
        alias CHUNK_SIZE = 16  # Process 16 characters at once

        while pos + CHUNK_SIZE <= text_len:
            # Load a chunk of characters
            var chars = SIMD[DType.uint8, CHUNK_SIZE]()
            for i in range(CHUNK_SIZE):
                chars[i] = ord(text[pos + i])

            # Use SIMD matcher to check all characters at once
            var matches = simd_matcher.match_chunk[CHUNK_SIZE](chars)

            # Find first matching position in this chunk
            for i in range(CHUNK_SIZE):
                if matches[i]:
                    return pos + i

            pos += CHUNK_SIZE

        # Handle remaining characters one by one
        while pos < text_len:
            var char_code = ord(text[pos])
            if simd_matcher.contains(char_code):
                return pos
            pos += 1

        return -1


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
        ref char_class_str = char_class.value()
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
        ref sequence_info = _extract_multi_class_sequence_info(ast)
        dfa.compile_multi_character_class_sequence(sequence_info)
        dfa.has_start_anchor = sequence_info.has_start_anchor
        dfa.has_end_anchor = sequence_info.has_end_anchor
    elif _is_sequential_character_class_pattern(ast):
        # Handle sequential character class patterns like [+]*\d+[-]*\d+
        ref sequence_info = _extract_sequential_pattern_info(ast)
        dfa.compile_sequential_pattern(sequence_info)
        dfa.has_start_anchor = sequence_info.has_start_anchor
        dfa.has_end_anchor = sequence_info.has_end_anchor
    elif _is_mixed_sequential_pattern(ast):
        # Handle mixed patterns like [0-9]+\.?[0-9]* (numbers with optional decimal)
        ref sequence_info = _extract_mixed_sequential_pattern_info(ast)
        dfa.compile_multi_character_class_sequence(sequence_info)
        dfa.has_start_anchor = sequence_info.has_start_anchor
        dfa.has_end_anchor = sequence_info.has_end_anchor
    elif _is_alternation_pattern(ast):
        # Handle alternation patterns like a|b, cat|dog, (a|b)
        dfa.compile_alternation(ast)
        # Check for anchors in the original pattern
        var has_start, has_end = pattern_has_anchors(ast)
        dfa.has_start_anchor = has_start
        dfa.has_end_anchor = has_end
    elif _is_quantified_group(ast):
        # Handle quantified group patterns like (abc)+, (test)*, (a)?
        dfa.compile_quantified_group(ast)
        # Check for anchors in the original pattern
        var has_start, has_end = pattern_has_anchors(ast)
        dfa.has_start_anchor = has_start
        dfa.has_end_anchor = has_end
    elif _is_simple_quantifier_pattern(ast):
        # Handle simple quantifier patterns like a*, test+, char?
        dfa.compile_simple_quantifier(ast)
        # Check for anchors in the original pattern
        var has_start, has_end = pattern_has_anchors(ast)
        dfa.has_start_anchor = has_start
        dfa.has_end_anchor = has_end
    elif _is_wildcard_quantifier_pattern(ast):
        # Handle wildcard quantifier patterns like .*, .+, .?
        dfa.compile_wildcard_quantifier(ast)
        # Check for anchors in the original pattern
        var has_start, has_end = pattern_has_anchors(ast)
        dfa.has_start_anchor = has_start
        dfa.has_end_anchor = has_end
    elif _is_common_prefix_alternation_pattern(ast):
        # Handle common prefix alternation patterns like (hello|help|helicopter)
        dfa.compile_common_prefix_alternation(ast)
        # Check for anchors in the original pattern
        var has_start, has_end = pattern_has_anchors(ast)
        dfa.has_start_anchor = has_start
        dfa.has_end_anchor = has_end
    elif _is_quantified_alternation_group(ast):
        # Handle quantified alternation groups like (a|b)*, (cat|dog)+
        dfa.compile_quantified_alternation_group(ast)
        # Check for anchors in the original pattern
        var has_start, has_end = pattern_has_anchors(ast)
        dfa.has_start_anchor = has_start
        dfa.has_end_anchor = has_end
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
        ref child = ast.get_child(0)
        if child.type == DIGIT or child.type == RANGE:
            return True
        elif child.type == GROUP and child.get_children_len() == 1:
            # Check if group contains single digit or range element
            ref inner = child.get_child(0)
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

    ref child = ast.get_child(0)
    if child.type != GROUP:
        return False

    # Check if all children are character classes (RANGE or DIGIT)
    for i in range(child.get_children_len()):
        ref element = child.get_child(i)
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
        ref child = ast.get_child(0)
        if child.type == GROUP:
            # Extract each character class element
            for i in range(child.get_children_len()):
                ref element = child.get_child(i)
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

    ref child = ast.get_child(0)
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
        ref child = ast.get_child(0)
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

    ref child = ast.get_child(0)
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


fn _is_alternation_pattern(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if pattern is a simple alternation like a|b, cat|dog, (a|b).

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a simple alternation pattern.
    """
    from regex.ast import RE, OR, GROUP, ELEMENT

    # Direct alternation: a|b
    if ast.type == OR:
        return _is_simple_alternation_branches(ast)

    # Only allow simple patterns: RE -> GROUP -> OR or RE -> OR
    # Don't handle complex patterns mixed with wildcards, etc.
    return _is_pure_alternation_pattern(ast)


fn _is_simple_alternation_branches(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if alternation branches are simple (literal elements only).

    Args:
        ast: OR node to check branches of.

    Returns:
        True if all branches are simple literal elements.
    """
    from regex.ast import OR, ELEMENT, GROUP

    if ast.type != OR:
        return False

    # Check that all branches are simple
    for i in range(ast.get_children_len()):
        ref branch = ast.get_child(i)

        # Each branch should be a group containing literal elements, single element, or nested OR
        if branch.type == GROUP:
            # Check that the group contains only literal elements
            if not _group_contains_only_literals(branch):
                return False
        elif branch.type == ELEMENT:
            # Single literal element - good
            continue
        elif branch.type == OR:
            # Nested OR node - recursively check its branches
            if not _is_simple_alternation_branches(branch):
                return False
        else:
            # Complex branch - not supported yet
            return False

    return True


fn _group_contains_only_literals(group: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if a group contains only literal elements.

    Args:
        group: GROUP node to check.

    Returns:
        True if the group contains only ELEMENT nodes.
    """
    from regex.ast import ELEMENT, GROUP

    if group.type != GROUP:
        return False

    # All children should be ELEMENT nodes
    for i in range(group.get_children_len()):
        ref child = group.get_child(i)
        if child.type != ELEMENT:
            return False

    return True


fn _find_and_check_or_node(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Recursively search for an OR node and check if its branches are simple.

    Args:
        ast: AST node to search within.

    Returns:
        True if an OR node with simple branches is found.
    """
    from regex.ast import OR, GROUP, RE

    if ast.type == OR:
        return _is_simple_alternation_branches(ast)

    # Recursively search children
    for i in range(ast.get_children_len()):
        var child = ast.get_child(i)
        if _find_and_check_or_node(child):
            return True

    return False


fn _find_or_node(
    ast: ASTNode[MutableAnyOrigin],
) -> Optional[ASTNode[MutableAnyOrigin]]:
    """Recursively find the first OR node in the AST.

    Args:
        ast: AST node to search within.

    Returns:
        The first OR node found, or None if no OR node exists.
    """
    from regex.ast import OR

    if ast.type == OR:
        return ast

    # Recursively search children
    for i in range(ast.get_children_len()):
        var child = ast.get_child(i)
        ref found = _find_or_node(child)
        if found:
            return found

    return None


fn _extract_branch_text(branch: ASTNode[MutableAnyOrigin]) -> String:
    """Extract the literal text from an alternation branch.

    Args:
        branch: Branch node (ELEMENT or GROUP containing ELEMENTs).

    Returns:
        Literal string for this branch.
    """
    from regex.ast import ELEMENT, GROUP

    if branch.type == ELEMENT and branch.get_value():
        return String(branch.get_value().value())
    elif branch.type == GROUP:
        # Concatenate all literal elements in the group
        var result = String("")
        for i in range(branch.get_children_len()):
            var child = branch.get_child(i)
            if child.type == ELEMENT and child.get_value():
                result += child.get_value().value()
        return result

    return String("")


fn _is_quantified_group(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if pattern is a simple quantified group like (abc)+, (test)*, (a)?.

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a simple quantified group pattern.
    """
    from regex.ast import RE, GROUP

    # Pattern should be RE -> GROUP -> GROUP (with quantifier)
    if ast.type == RE and ast.get_children_len() == 1:
        ref child = ast.get_child(0)
        if child.type == GROUP and child.get_children_len() == 1:
            var grandchild = child.get_child(0)
            if grandchild.type == GROUP:
                # Check if grandchild has quantifier information
                if grandchild.min != 1 or grandchild.max != 1:
                    # Has quantifier - check if group content is simple
                    return _group_content_is_simple(grandchild)

    return False


fn _group_content_is_simple(group: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if a quantified group contains simple literal content.

    Args:
        group: GROUP node to check.

    Returns:
        True if the group contains only simple literal elements.
    """
    from regex.ast import ELEMENT, GROUP

    if group.type != GROUP:
        return False

    # Group should contain only ELEMENT nodes (literals)
    for i in range(group.get_children_len()):
        var child = group.get_child(i)
        if child.type != ELEMENT:
            return False

    return True


fn _extract_group_text(group: ASTNode[MutableAnyOrigin]) -> String:
    """Extract the literal text from a quantified group.

    Args:
        group: GROUP node containing literal elements.

    Returns:
        Concatenated text from all ELEMENT nodes in the group.
    """
    from regex.ast import ELEMENT

    var result = String()
    for i in range(group.get_children_len()):
        var child = group.get_child(i)
        if child.type == ELEMENT:
            result += child.get_value().value()

    return result


fn _collect_all_alternation_branches(
    or_node: ASTNode[MutableAnyOrigin],
) -> List[String]:
    """Recursively collect all branch texts from a potentially nested OR structure.

    Args:
        or_node: OR node that may have nested OR children.

    Returns:
        List of all branch texts flattened from the nested structure.
    """
    from regex.ast import OR, ELEMENT, GROUP

    var branches = List[String]()

    for i in range(or_node.get_children_len()):
        var branch = or_node.get_child(i)

        if branch.type == OR:
            # Nested OR - recursively collect its branches
            ref nested_branches = _collect_all_alternation_branches(branch)
            for j in range(len(nested_branches)):
                branches.append(nested_branches[j])
        else:
            # Leaf branch (ELEMENT or GROUP) - extract its text
            ref branch_text = _extract_branch_text(branch)
            if len(branch_text) > 0:
                branches.append(branch_text)

    return branches


fn _is_pure_alternation_pattern(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if pattern is a pure alternation without other complex operators.

    Only allows simple structures like:
    - RE -> OR (direct alternation: a|b)
    - RE -> GROUP -> OR (grouped alternation: (a|b))

    Rejects complex patterns like .*(a|b), (a|b)+, etc.

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a pure simple alternation.
    """
    from regex.ast import RE, OR, GROUP

    if ast.type != RE or ast.get_children_len() != 1:
        return False

    ref child = ast.get_child(0)

    # Case 1: RE -> OR (direct alternation)
    if child.type == OR:
        return _is_simple_alternation_branches(child)

    # Case 2: RE -> GROUP -> OR (grouped alternation)
    if child.type == GROUP and child.get_children_len() == 1:
        var grandchild = child.get_child(0)
        if grandchild.type == OR:
            return _is_simple_alternation_branches(grandchild)

    return False


fn _is_simple_quantifier_pattern(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if pattern is a simple quantifier like a*, test+, char?.

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a simple quantifier pattern.
    """
    from regex.ast import RE, GROUP, ELEMENT

    # Pattern should be RE -> GROUP -> ELEMENTs where at least one has quantifier
    if ast.type != RE or ast.get_children_len() != 1:
        return False

    var group = ast.get_child(0)
    if group.type != GROUP:
        return False

    # Must have at least one ELEMENT
    if group.get_children_len() == 0:
        return False

    # Check if any element has quantifier and all children are ELEMENTs
    var has_quantifier = False
    for i in range(group.get_children_len()):
        var child = group.get_child(i)
        if child.type != ELEMENT:
            return False

        # Check for quantifiers: *, +, ?
        if (
            (child.min == 0 and child.max == -1)  # *
            or (child.min == 1 and child.max == -1)  # +
            or (child.min == 0 and child.max == 1)  # ?
        ):
            has_quantifier = True

    return has_quantifier


fn _is_wildcard_quantifier_pattern(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if pattern is a wildcard quantifier like .*, .+, .?.

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a wildcard quantifier pattern.
    """
    from regex.ast import RE, GROUP, WILDCARD

    # Pattern should be RE -> GROUP -> WILDCARD
    if ast.type != RE or ast.get_children_len() != 1:
        return False

    var group = ast.get_child(0)
    if group.type != GROUP or group.get_children_len() != 1:
        return False

    var wildcard = group.get_child(0)
    if wildcard.type != WILDCARD:
        return False

    # Check for quantifiers: *, +, ? or single (min=1, max=1)
    return (
        (wildcard.min == 0 and wildcard.max == -1)
        or (wildcard.min == 1 and wildcard.max == -1)  # *
        or (wildcard.min == 0 and wildcard.max == 1)  # +
        or (wildcard.min == 1 and wildcard.max == 1)  # ?  # single dot
    )


fn _is_common_prefix_alternation_pattern(
    ast: ASTNode[MutableAnyOrigin],
) -> Bool:
    """Check if pattern is a common prefix alternation like (hello|help|helicopter).

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a common prefix alternation pattern.
    """
    from regex.ast import RE, GROUP, OR, ELEMENT

    # Pattern should be RE -> GROUP -> GROUP -> OR tree
    if ast.type != RE or ast.get_children_len() != 1:
        return False

    var outer_group = ast.get_child(0)
    if outer_group.type != GROUP or outer_group.get_children_len() != 1:
        return False

    var inner_group = outer_group.get_child(0)
    if inner_group.type != GROUP or inner_group.get_children_len() != 1:
        return False

    var or_node = inner_group.get_child(0)
    if or_node.type != OR:
        return False

    # Check if this is a literal-only alternation with potential common prefix
    # Extract all branches and check for common prefix
    var branches = List[String]()
    if not _extract_literal_branches(or_node, branches):
        return False

    # Must have at least 2 branches
    if len(branches) < 2:
        return False

    # Check if there's a meaningful common prefix (at least 2 characters)
    var common_prefix = _compute_common_prefix(branches)
    return len(common_prefix) >= 2


fn _extract_literal_branches(
    node: ASTNode[MutableAnyOrigin], mut branches: List[String]
) -> Bool:
    """Extract literal string branches from OR tree. Returns False if non-literal elements found.
    """
    from regex.ast import OR, GROUP, ELEMENT

    if node.type == OR:
        # Process both children
        return _extract_literal_branches(
            node.get_child(0), branches
        ) and _extract_literal_branches(node.get_child(1), branches)
    elif node.type == GROUP:
        # Extract literal string from GROUP of ELEMENTs
        var branch_text = String("")
        for i in range(node.get_children_len()):
            var element = node.get_child(i)
            if element.type != ELEMENT:
                return False  # Non-literal element found
            ref char_value = element.get_value().value()
            branch_text += String(char_value)
        branches.append(branch_text)
        return True
    else:
        return False  # Unexpected node type


fn _compute_common_prefix(branches: List[String]) -> String:
    """Compute the longest common prefix among all branches."""
    if len(branches) == 0:
        return String("")
    if len(branches) == 1:
        return branches[0]

    var prefix = String("")
    ref first_branch = branches[0]
    var min_length = len(first_branch)

    # Find minimum length
    for i in range(1, len(branches)):
        if len(branches[i]) < min_length:
            min_length = len(branches[i])

    # Find common prefix
    for pos in range(min_length):
        var char_at_pos = first_branch[pos]
        var all_match = True

        for i in range(1, len(branches)):
            if branches[i][pos] != char_at_pos:
                all_match = False
                break

        if all_match:
            prefix += String(char_at_pos)
        else:
            break

    return prefix


fn _is_quantified_alternation_group(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if pattern is a quantified alternation group like (a|b)*, (cat|dog)+.

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a quantified alternation group.
    """
    from regex.ast import RE, GROUP, OR

    # Pattern should be RE -> GROUP -> GROUP(quantified) -> OR
    if ast.type != RE or ast.get_children_len() != 1:
        return False

    var outer_group = ast.get_child(0)
    if outer_group.type != GROUP or outer_group.get_children_len() != 1:
        return False

    var quantified_group = outer_group.get_child(0)
    if (
        quantified_group.type != GROUP
        or quantified_group.get_children_len() != 1
    ):
        return False

    # Must have quantifier (not 1,1)
    if quantified_group.min == 1 and quantified_group.max == 1:
        return False

    # Must contain alternation
    var or_node = quantified_group.get_child(0)
    if or_node.type != OR:
        return False

    # Check if alternation contains only literal branches
    var branches = List[String]()
    return _extract_literal_alternation_branches(or_node, branches)


fn _extract_literal_alternation_branches(
    node: ASTNode[MutableAnyOrigin], mut branches: List[String]
) -> Bool:
    """Extract literal branches from alternation. Returns False if non-literal elements found.
    """
    from regex.ast import OR, GROUP, ELEMENT

    if node.type == OR:
        # Process both children
        return _extract_literal_alternation_branches(
            node.get_child(0), branches
        ) and _extract_literal_alternation_branches(node.get_child(1), branches)
    elif node.type == GROUP:
        # Extract literal string from GROUP of ELEMENTs
        var branch_text = String("")
        for i in range(node.get_children_len()):
            var element = node.get_child(i)
            if element.type != ELEMENT:
                return False  # Non-literal element found
            ref char_value = element.get_value().value()
            branch_text += String(char_value)
        branches.append(branch_text)
        return True
    else:
        return False  # Unexpected node type
