"""
DFA (Deterministic Finite Automaton) implementation for high-performance regex matching.

This module provides O(n) time complexity regex matching for simple patterns that can be
compiled to DFA, as opposed to the exponential worst-case of NFA backtracking.
"""

from regex.aliases import ALL_EXCEPT_NEWLINE, ImmSlice, WORD_CHARS
from regex.ast import (
    ASTNode,
    DIGIT,
    ELEMENT,
    GROUP,
    OR,
    RANGE,
    RE,
    SPACE,
    WILDCARD,
    WORD,
)
from regex.engine import Engine
from regex.matching import Match, MatchList
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
    CharacterClassSIMD,
    SIMD_WIDTH,
    get_character_class_matcher,
    apply_quantifier_simd_generic,
    find_in_text_simd,
    simd_search,
    verify_match,
    twoway_search,
)
from regex.simd_matchers import (
    analyze_character_class_pattern,
    get_digit_matcher,
    get_alpha_matcher,
    get_alnum_matcher,
    get_whitespace_matcher,
    get_hex_digit_matcher,
    get_word_matcher,
    RangeBasedMatcher,
    NibbleBasedMatcher,
)

comptime DEFAULT_DFA_CAPACITY = 64  # Default capacity for DFA states
comptime DEFAULT_DFA_TRANSITIONS = 256  # Number of ASCII transitions (0-255)

# Pre-defined character sets for efficient lookup
comptime LOWERCASE_LETTERS = "abcdefghijklmnopqrstuvwxyz"
comptime UPPERCASE_LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
comptime ALL_LETTERS = LOWERCASE_LETTERS + UPPERCASE_LETTERS
comptime ALPHANUMERIC = LOWERCASE_LETTERS + UPPERCASE_LETTERS + DIGITS


def _expand_character_range(
    node_type: Int,
    range_str: StringSlice[ImmutAnyOrigin],
) -> String:
    """Expand a character range like '[a-z]' to 'abcdefghijklmnopqrstuvwxyz'.

    Args:
        node_type: AST node type for fast type-based optimization.
        range_str: Range string like '[a-z]' or '[0-9]' or 'abcd'.

    Returns:
        Expanded character set string.
    """
    # Fast path using AST node type (much faster than string comparisons)
    if node_type == DIGIT:
        return DIGITS
    elif node_type == WORD:
        return WORD_CHARS
    elif node_type == SPACE:
        return " \t\n\r\f"  # Space characters

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
    elif range_str == "\\w":
        # Word character pattern
        return WORD_CHARS

    # Extract the inner part: [a-z] -> a-z
    var inner = range_str[byte=1:-1]

    # Handle negated ranges like [^a-z]
    var negated = inner.startswith("^")
    if negated:
        inner = inner[byte=1:]

    # For simple single ranges, use slicing from pre-defined sets
    var inner_ptr = inner.unsafe_ptr()
    if len(inner) == 3 and Int(inner_ptr[1]) == ord("-"):
        var start_char = inner[byte=0]
        var end_char = inner[byte=2]

        # Handle lowercase letter ranges
        if ord(start_char) >= CHAR_A and ord(end_char) <= CHAR_Z:
            var start_idx = ord(start_char) - CHAR_A
            var end_idx = ord(end_char) - CHAR_A + 1
            return String(LOWERCASE_LETTERS[byte=start_idx:end_idx])

        # Handle uppercase letter ranges
        elif ord(start_char) >= CHAR_A and ord(end_char) <= CHAR_Z_UPPER:
            var start_idx = ord(start_char) - CHAR_A_UPPER
            var end_idx = ord(end_char) - CHAR_A_UPPER + 1
            return String(UPPERCASE_LETTERS[byte=start_idx:end_idx])

        # Handle digit ranges
        elif ord(start_char) >= CHAR_ZERO and ord(end_char) <= CHAR_NINE:
            var start_idx = ord(start_char) - CHAR_ZERO
            var end_idx = ord(end_char) - CHAR_ZERO + 1
            return String(DIGITS[byte=start_idx:end_idx])

    # Fallback for complex cases - expand all ranges and characters
    # Estimate capacity: each range a-z adds up to 26 chars, single chars add 1
    var estimated_capacity = len(inner) * 10  # Generous estimate
    var result = String(capacity=estimated_capacity)
    var i = 0
    while i < len(inner):
        if i + 2 < len(inner) and Int(inner_ptr[i + 1]) == ord("-"):
            # Found a range like a-z
            var start_char = inner[byte=i]
            var end_char = inner[byte=i + 2]
            var start_code = ord(start_char)
            var end_code = ord(end_char)

            # Add all characters in the range
            for char_code in range(start_code, end_code + 1):
                result += chr(char_code)
            i += 3
        else:
            # Single character
            result += inner[byte=i]
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
    var alternation_branches: List[String]
    """For alternation groups: list of literal branch strings. Empty for normal elements."""

    def __init__(
        out self,
        var char_class: String,
        min_matches: Int,
        max_matches: Int,
        positive_logic: Bool = True,
    ):
        self.char_class = char_class^
        self.min_matches = min_matches
        self.max_matches = max_matches
        self.positive_logic = positive_logic
        self.alternation_branches = List[String]()


struct SequentialPatternInfo(Copyable, Movable):
    """Information about a sequential pattern like [+]*\\d+[-]*\\d+."""

    var elements: List[SequentialPatternElement]
    """List of sequential pattern elements in the pattern."""
    var has_start_anchor: Bool
    """Whether the pattern starts with ^ anchor."""
    var has_end_anchor: Bool
    """Whether the pattern ends with $ anchor."""

    def __init__(out self):
        self.elements = List[SequentialPatternElement]()
        self.has_start_anchor = False
        self.has_end_anchor = False


struct DFAState(ImplicitlyCopyable, Movable, RegisterPassable):
    """A single state in the DFA state machine."""

    var transitions: SIMD[DType.int32, DEFAULT_DFA_TRANSITIONS]
    """Transition table for this state, indexed by character code (0-255)."""
    var is_accepting: Bool
    """A state is accepting if it can end a match following this path."""
    var match_length: Int  # Length of match when this state is reached
    """Length of the match when this state is reached, used for quantifiers."""

    def __init__(out self, is_accepting: Bool = False, match_length: Int = 0):
        """Initialize a DFA state with no transitions."""
        self.transitions = SIMD[DType.int32, DEFAULT_DFA_TRANSITIONS](
            -1
        )  # -1 means no transition
        self.is_accepting = is_accepting
        self.match_length = match_length

    @always_inline
    def add_transition(mut self, char_code: Int, target_state: Int):
        """Add a transition from this state to target_state on character char_code.

        Args:
            char_code: ASCII code of the character (0-255).
            target_state: Target state index, or -1 for no transition.
        """
        if char_code >= 0 and char_code < DEFAULT_DFA_TRANSITIONS:
            self.transitions[char_code] = Int32(target_state)

    @always_inline
    def get_transition(self, char_code: Int) -> Int:
        """Get the target state for a given character.

        Args:
            char_code: ASCII code of the character (0-255).

        Returns:
            Target state index, or -1 if no transition exists.
        """
        return Int(self.transitions[char_code])


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
    var is_pure_literal: Bool
    """Whether this is a pure literal pattern (no regex operators)."""
    var _simd_char_matcher: CharacterClassSIMD
    """SIMD-optimized character class matcher for simple patterns."""
    var _has_simd_matcher: Bool
    """Whether the SIMD matcher is set. Workaround for Mojo 0.26.2 bug where
    Optional[T] silently fails for large TrivialRegisterPassable structs
    (https://github.com/modular/modular/issues/6253).
    TODO: Revert to Optional[CharacterClassSIMD] once upgraded to Mojo 0.26.3+
    where this bug is fixed."""
    var _simd_scan_eligible: Bool
    """Whether the SIMD scan path can be used (has unlimited quantifier with
    self-loop, not a bounded quantifier like {3} or {2,4})."""
    var literal_pattern: String
    """Storage for literal pattern to keep it alive for SIMD string search."""

    def __init__(out self):
        """Initialize an empty DFA engine."""
        self.states = List[DFAState](capacity=DEFAULT_DFA_CAPACITY)
        self.start_state = 0
        self.has_start_anchor = False
        self.has_end_anchor = False
        self.is_pure_literal = False
        self._simd_char_matcher = CharacterClassSIMD("")
        self._has_simd_matcher = False
        self._simd_scan_eligible = False
        self.literal_pattern = ""

    def __moveinit__(out self, deinit take: Self):
        """Move constructor."""
        self.states = take.states^
        self.start_state = take.start_state
        self.has_start_anchor = take.has_start_anchor
        self.has_end_anchor = take.has_end_anchor
        self.is_pure_literal = take.is_pure_literal
        self._simd_char_matcher = take._simd_char_matcher
        self._has_simd_matcher = take._has_simd_matcher
        self._simd_scan_eligible = take._simd_scan_eligible
        self.literal_pattern = take.literal_pattern^

    def compile_pattern(
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
            # Still create DFA states as fallback

        # Create states: one for each character + one final accepting state
        # Set up transitions for each character in the pattern
        var pattern_ptr = pattern.unsafe_ptr()
        for i in range(len_pattern):
            var state = DFAState()
            var char_code = Int(pattern_ptr[i])
            state.add_transition(char_code, i + 1)
            self.states.append(state)

        # Add final accepting state
        var final_state = DFAState(is_accepting=True, match_length=len_pattern)
        self.states.append(final_state)

        self.start_state = 0

    def compile_character_class(
        mut self, var char_class: String, min_matches: Int, max_matches: Int
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

    def compile_character_class_with_logic(
        mut self,
        var char_class: String,
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
            self._simd_char_matcher = get_character_class_matcher(char_class)
            self._has_simd_matcher = True
            # Unlimited quantifiers (+ or *) are eligible for SIMD scan
            self._simd_scan_eligible = max_matches == -1

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

    def compile_sequential_pattern(
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

    def compile_multi_character_class_sequence(
        mut self, var sequence_info: SequentialPatternInfo
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

        # Enable SIMD prefilter for the first element's character class.
        # This lets match_all and match_next skip positions where the first
        # character can't match, without affecting the DFA state machine.
        if (
            len(sequence_info.elements[0].alternation_branches) == 0
            and len(sequence_info.elements[0].char_class) > 0
        ):
            self._simd_char_matcher = get_character_class_matcher(
                sequence_info.elements[0].char_class
            )
            self._has_simd_matcher = True
            # Not scan eligible - this is a multi-element pattern that needs
            # the full DFA state machine, not just consecutive char counting

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

            # Handle alternation group elements (e.g., (?:00|33|44))
            if len(element.alternation_branches) > 0:
                if element_idx == 0:
                    var start_state = DFAState()
                    self.states.append(start_state)
                    current_state_index = 0

                # All branches converge to a single end state
                var end_state = DFAState(
                    is_accepting=is_last_element or all_remaining_optional
                )
                self.states.append(end_state)
                var end_state_index = len(self.states) - 1

                # Build chain of states for each branch
                for branch_idx in range(len(element.alternation_branches)):
                    ref branch = element.alternation_branches[branch_idx]
                    var branch_ptr = branch.unsafe_ptr()
                    var prev_state = current_state_index

                    for ch_idx in range(len(branch)):
                        var char_code = Int(branch_ptr[ch_idx])
                        if ch_idx == len(branch) - 1:
                            # Last char in branch -> transition to shared end state
                            self.states[prev_state].add_transition(
                                char_code, end_state_index
                            )
                        else:
                            # Intermediate char -> create intermediate state
                            var mid_state = DFAState()
                            self.states.append(mid_state)
                            var mid_state_index = len(self.states) - 1
                            self.states[prev_state].add_transition(
                                char_code, mid_state_index
                            )
                            prev_state = mid_state_index

                current_state_index = end_state_index
                continue

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
                if element_idx == 0:
                    # First element - create start state
                    var start_state = DFAState()
                    self.states.append(start_state)
                    current_state_index = 0

                # Create required states
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

    def compile_alternation(mut self, ast: ASTNode[MutAnyOrigin]) raises:
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
            var branch_text_ptr = branch_text.unsafe_ptr()

            for j in range(len(branch_text)):
                var char_code = Int(branch_text_ptr[j])

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

    def compile_quantified_group(mut self, ast: ASTNode[MutAnyOrigin]) raises:
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

    def _compile_optional_group(
        mut self, group_text: String, accepting_index: Int
    ):
        """Compile an optional group (pattern)? - match 0 or 1 times."""
        # Start state can go directly to accepting (0 matches) or through pattern (1 match)

        # Direct path to accepting state (0 matches)
        self.states[0].add_transition(0, accepting_index)  # epsilon transition

        # Path through pattern (1 match)
        var current_state_index = 0
        var group_text_ptr = group_text.unsafe_ptr()
        for i in range(len(group_text)):
            var char_code = Int(group_text_ptr[i])

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

    def _compile_zero_or_more_group(
        mut self, group_text: String, accepting_index: Int
    ):
        """Compile a zero-or-more group (pattern)* - match 0 or more times."""
        # Start state can go directly to accepting or start the pattern

        # Direct path to accepting state (0 matches)
        # For DFA, we'll make start state accepting
        self.states[0].is_accepting = True

        # Create loop through pattern
        var current_state_index = 0
        var group_text_ptr = group_text.unsafe_ptr()
        for i in range(len(group_text)):
            var char_code = Int(group_text_ptr[i])

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

    def _compile_one_or_more_group(
        mut self, group_text: String, accepting_index: Int
    ):
        """Compile a one-or-more group (pattern)+ - match 1 or more times."""
        # Must match at least once, then can loop

        var current_state_index = 0
        var group_text_ptr = group_text.unsafe_ptr()
        for i in range(len(group_text)):
            var char_code = Int(group_text_ptr[i])

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
                    Int(group_text_ptr[0]),
                    1 if len(group_text) > 1 else loop_index,
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

    def compile_simple_quantifier(mut self, ast: ASTNode[MutAnyOrigin]) raises:
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

    def _compile_simple_optional(
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
        var pattern_text_ptr = pattern_text.unsafe_ptr()
        for i in range(len(pattern_text)):
            var char_code = Int(pattern_text_ptr[i])

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

    def _compile_simple_zero_or_more(
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
        var pattern_text_ptr = pattern_text.unsafe_ptr()
        for i in range(len(pattern_text)):
            var char_code = Int(pattern_text_ptr[i])

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

    def _compile_simple_one_or_more(
        mut self, pattern_text: String, accepting_index: Int
    ):
        """Compile a simple one-or-more pattern (pattern+) - match 1 or more times.
        """
        # Must match at least once, then can loop

        var current_state_index = 0
        var pattern_text_ptr = pattern_text.unsafe_ptr()
        for i in range(len(pattern_text)):
            var char_code = Int(pattern_text_ptr[i])

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
                    Int(pattern_text_ptr[0]),
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

    def _find_or_create_state(mut self, from_state: Int, char_code: Int) -> Int:
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
        if existing_target != -1:  # -1 means no transition
            # Transition already exists, reuse the target state
            return existing_target
        else:
            # Create new state and add transition
            var new_state = DFAState()
            self.states.append(new_state)
            var new_state_index = len(self.states) - 1
            self.states[from_state].add_transition(char_code, new_state_index)
            return new_state_index

    def compile_wildcard_quantifier(
        mut self, ast: ASTNode[MutAnyOrigin]
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

    def _compile_wildcard_optional(mut self, accepting_index: Int):
        """Compile .? - match any character 0 or 1 times."""
        # Start state is accepting (0 matches)
        self.states[0].is_accepting = True

        # Add transitions from start state to accepting for any character except newline
        for i in range(256):
            if i != ord("\n"):  # Wildcard doesn't match newline by default
                self.states[0].add_transition(i, accepting_index)

    def _compile_wildcard_zero_or_more(mut self, accepting_index: Int):
        """Compile .* - match any character 0 or more times."""
        # Start state is accepting (0 matches)
        self.states[0].is_accepting = True

        # Add transitions from start state back to itself for any character except newline
        for i in range(256):
            if i != ord("\n"):  # Wildcard doesn't match newline by default
                self.states[0].add_transition(i, 0)  # Loop back to start

    def _compile_wildcard_one_or_more(mut self, accepting_index: Int):
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

    def _compile_wildcard_single(mut self, accepting_index: Int):
        """Compile . - match any single character."""
        # Add transitions from start state to accepting for any character except newline
        for i in range(256):
            if i != ord("\n"):  # Wildcard doesn't match newline by default
                self.states[0].add_transition(i, accepting_index)

    def compile_common_prefix_alternation(
        mut self, ast: ASTNode[MutAnyOrigin]
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

    def _extract_all_prefix_branches(
        self, node: ASTNode[MutAnyOrigin], mut branches: List[String]
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

    def _build_prefix_trie(mut self, branches: List[String]) raises:
        """Build a trie-like DFA structure from alternation branches."""
        if len(branches) == 0:
            return

        # Find the common prefix among all branches
        ref common_prefix = self._find_common_prefix(branches)
        var prefix_len = len(common_prefix)

        # Build states for the common prefix
        var current_state = 0
        var common_prefix_ptr = common_prefix.unsafe_ptr()
        for i in range(prefix_len):
            var char_code = Int(common_prefix_ptr[i])
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
                var suffix = branch[byte=prefix_len:]
                var suffix_current_state = current_state
                var suffix_ptr = suffix.unsafe_ptr()

                for j in range(len(suffix)):
                    var char_code = Int(suffix_ptr[j])

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

    def _find_common_prefix(self, branches: List[String]) -> String:
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
        var first_branch_ptr = first_branch.unsafe_ptr()
        for pos in range(min_length):
            var char_at_pos = Int(first_branch_ptr[pos])
            var all_match = True

            for i in range(1, len(branches)):
                var branch_ptr_i = branches[i].unsafe_ptr()
                if Int(branch_ptr_i[pos]) != char_at_pos:
                    all_match = False
                    break

            if all_match:
                prefix += chr(char_at_pos)
            else:
                break

        return prefix

    @always_inline
    def _create_accepting_state(mut self: Self):
        """Create a single accepting state as the pattern is empty."""
        var state = DFAState(is_accepting=True, match_length=0)
        self.states.append(state)
        self.start_state = 0

    def compile_quantified_alternation_group(
        mut self, ast: ASTNode[MutAnyOrigin]
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

    def _extract_all_alternation_branches_for_quantified(
        self, node: ASTNode[MutAnyOrigin], mut branches: List[String]
    ):
        """Extract all string branches from alternation for quantified groups.
        """
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

    def _compile_quantified_alternation_optional(
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
            var branch_ptr = branch.unsafe_ptr()

            for j in range(len(branch)):
                var char_code = Int(branch_ptr[j])

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

    def _compile_quantified_alternation_zero_or_more(
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
            var branch_ptr = branch.unsafe_ptr()

            for j in range(len(branch)):
                var char_code = Int(branch_ptr[j])

                if j == len(branch) - 1:
                    # Last character - loop back to start for more matches
                    self.states[current_state].add_transition(char_code, 0)
                else:
                    # Intermediate character - find or create state
                    current_state = self._find_or_create_state(
                        current_state, char_code
                    )

    def _compile_quantified_alternation_one_or_more(
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
            var branch_ptr = branch.unsafe_ptr()

            for j in range(len(branch)):
                var char_code = Int(branch_ptr[j])

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
            var branch_ptr = branch.unsafe_ptr()

            for j in range(len(branch)):
                var char_code = Int(branch_ptr[j])

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

    def _try_enable_simd_for_sequence(
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
            ref element = sequence_info.elements[i]
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
            self._simd_char_matcher = get_character_class_matcher(DIGITS)
            self._has_simd_matcher = True
            self._simd_scan_eligible = (
                True  # Digit sequence patterns use unlimited scan
            )

    @always_inline
    def _add_character_class_transitions(
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
    def _add_character_class_transitions_with_logic(
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

        var cc_ptr = char_class.unsafe_ptr()

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
                    var char_code = Int(cc_ptr[i])
                    state.add_transition(char_code, to_state)
        else:
            # Negative logic: [^abc] - add transitions for all characters
            # NOT in char_class. Set all transitions first, then remove
            # the excluded ones. Much faster for small exclusion sets.
            state.transitions = SIMD[DType.int32, DEFAULT_DFA_TRANSITIONS](
                to_state
            )
            # Remove transitions for excluded characters
            for i in range(char_class_len):
                var char_code = Int(cc_ptr[i])
                if char_code >= 0 and char_code < DEFAULT_DFA_TRANSITIONS:
                    state.transitions[char_code] = -1

    @always_inline
    def get_pattern(self) -> String:
        """Returns the pattern string.

        Returns:
            The pattern string.
        """
        return self.literal_pattern

    def is_match(self, text: ImmSlice, start: Int = 0) -> Bool:
        """Check if pattern matches at the given position without computing
        match boundaries. Much faster than match_first for simple checks.

        Args:
            text: Input text to match against.
            start: Starting position in text.

        Returns:
            True if pattern matches, False otherwise.
        """
        if self.has_start_anchor and start > 0:
            return False

        # Fast SIMD path: just check if first character matches
        if self._has_simd_matcher and len(self.states) > 0:
            var text_len = len(text)
            if start >= text_len:
                # Only match empty if start state is accepting
                return self.states[self.start_state].is_accepting
            # Check if the character at start matches
            var ch_code = Int(text.unsafe_ptr()[start])
            if self._simd_char_matcher.contains(ch_code):
                return True
            # No match at start - only valid if start state accepts
            return self.states[self.start_state].is_accepting

        # Fallback to full match
        return Bool(
            self._try_match_at_position(
                text, start, require_exact_position=True
            )
        )

    @always_inline
    def match_first(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
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

    def match_next(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
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
        if self._has_simd_matcher and not self.has_end_anchor:
            return self._optimized_simd_search(text, start)

        # Fallback: Try to find a match starting from each position from 'start' onwards
        for try_pos in range(start, len(text) + 1):
            var match_result = self._try_match_at_position(text, try_pos)
            if match_result:
                return match_result
        return None

    @always_inline
    def _try_match_at_position(
        self, text: ImmSlice, start_pos: Int, require_exact_position: Bool = False
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
        if self.is_pure_literal:
            var pattern = self.get_pattern()
            var pattern_bytes = pattern.as_bytes()
            var pattern_len = len(pattern)
            if require_exact_position:
                # For match_first, must match at exact position
                if verify_match(
                    pattern_bytes,
                    text,
                    start_pos,
                ):
                    return Match(0, start_pos, start_pos + pattern_len, text)
                return None
            else:
                # For match_next, can search from position
                var pos = simd_search(
                    pattern_bytes,
                    text,
                    start_pos,
                )
                if pos != -1:
                    return Match(0, pos, pos + pattern_len, text)
                return None

        # Try SIMD matching for simple character class patterns
        if self._has_simd_matcher and len(self.states) > 0:
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
        var text_ptr = text.unsafe_ptr()
        var text_len = len(text)
        var num_states = len(self.states)

        # Direct pointer to states for unchecked access in hot loop
        var states_ptr = self.states.unsafe_ptr()

        # Check if start state is accepting (for patterns like a*)
        if (
            current_state < num_states
            and states_ptr[current_state].is_accepting
        ):
            last_accepting_pos = pos

        while pos < text_len:
            var next_state = states_ptr[current_state].get_transition(
                Int(text_ptr[pos])
            )

            if next_state == -1:
                break

            current_state = next_state
            pos += 1

            # Check if current state is accepting
            if states_ptr[current_state].is_accepting:
                last_accepting_pos = pos

        # Check final state at text end
        if (
            pos == text_len
            and current_state < num_states
            and states_ptr[current_state].is_accepting
        ):
            last_accepting_pos = pos

        # Return longest match found
        if last_accepting_pos != -1:
            # Check end anchor constraint
            if self.has_end_anchor and last_accepting_pos != text_len:
                return None  # End anchor requires match to end at string end
            return Match(0, start_pos, last_accepting_pos, text)

        return None

    def match_all(self, text: ImmSlice) -> MatchList:
        """Find all non-overlapping matches using DFA.

        Args:
            text: Input text to search.

        Returns:
            Matches container with all matches found.
        """
        var matches = MatchList()

        # Special handling for anchored patterns
        if self.has_start_anchor or self.has_end_anchor:
            var match_result = self.match_next(text, 0)
            if match_result:
                matches.append(match_result.value())
            return matches^

        var pos = 0
        var text_len = len(text)
        var text_ptr = text.unsafe_ptr()
        var num_states = len(self.states)

        # Fast path: use SIMD matcher to skip non-matching positions
        if self._has_simd_matcher and num_states > 0:
            if self._simd_scan_eligible:
                # Nibble-based SIMD scan for unlimited quantifiers
                ref simd_matcher = self._simd_char_matcher
                while pos < text_len:
                    var match_pos = simd_matcher.find_first_nibble_match(
                        text_ptr, pos, text_len
                    )
                    if match_pos == -1:
                        break
                    var match_len = simd_matcher.count_consecutive_matches(
                        text_ptr, match_pos, text_len
                    )
                    if match_len > 0:
                        matches.append(
                            Match(0, match_pos, match_pos + match_len, text)
                        )
                        pos = match_pos + match_len
                    else:
                        pos = match_pos + 1
                return matches^

            # General SIMD path: nibble skip + full DFA
            ref skip_matcher = self._simd_char_matcher
            while pos < text_len:
                var next_pos = skip_matcher.find_first_nibble_match(
                    text_ptr, pos, text_len
                )
                if next_pos == -1:
                    break
                pos = next_pos
                var match_result = self._try_match_at_position(text, pos)
                if match_result:
                    ref match_obj = match_result.value()
                    matches.append(match_obj)
                    if match_obj.end_idx == match_obj.start_idx:
                        pos += 1
                    else:
                        pos = match_obj.end_idx
                else:
                    pos += 1
            return matches^

        # General path: try every position
        while pos <= text_len:
            var match_result = self._try_match_at_position(text, pos)
            if match_result:
                ref match_obj = match_result.value()
                matches.append(match_obj)
                if match_obj.end_idx == match_obj.start_idx:
                    pos += 1
                else:
                    pos = match_obj.end_idx
            else:
                pos += 1

        return matches^

    @always_inline
    def _try_match_simd(self, text: ImmSlice, start_pos: Int) -> Optional[Match]:
        """SIMD-optimized matching for character class patterns with quantifier support.

        This hybrid approach uses SIMD for fast character matching while respecting
        DFA quantifier constraints by validating the result through state machine simulation.

        Args:
            text: Input text to match against.
            start_pos: Position to start matching from.

        Returns:
            Optional Match if pattern matches at this position, None otherwise.
        """
        if not self._has_simd_matcher:
            return None

        ref simd_matcher = self._simd_char_matcher
        var text_len = len(text)

        if len(self.states) == 0:
            return None

        # Check if start state is accepting (for patterns like [a-z]*)
        var start_accepting = self.states[self.start_state].is_accepting

        # Bounded quantifiers like {3} or {2,4} can't use SIMD scan because
        # the match length is constrained. This flag is computed at compile time.
        if not start_accepting and not self._simd_scan_eligible:
            return None

        # Count consecutive matching characters using fast lookup table scan
        var text_ptr = text.unsafe_ptr()
        var match_count = simd_matcher.count_consecutive_matches(
            text_ptr, start_pos, text_len
        )

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

    @always_inline
    def _optimized_simd_search(
        self, text: ImmSlice, start: Int
    ) -> Optional[Match]:
        """Optimized SIMD-based search for character class patterns.

        Args:
            text: Input text to search.
            start: Starting position for search.

        Returns:
            Optional Match if found, None otherwise.
        """
        if not self._has_simd_matcher:
            return None

        ref simd_matcher = self._simd_char_matcher
        var text_len = len(text)
        var text_ptr = text.unsafe_ptr()
        var pos = start

        # Fast path for unlimited quantifiers: use nibble-based SIMD scan
        # to find first match and its extent in one pass
        if self._simd_scan_eligible:
            while pos < text_len:
                var match_pos = simd_matcher.find_first_nibble_match(
                    text_ptr, pos, text_len
                )
                if match_pos == -1:
                    return None
                var match_len = simd_matcher.count_consecutive_matches(
                    text_ptr, match_pos, text_len
                )
                if match_len > 0:
                    var match_end = match_pos + match_len
                    if self.has_end_anchor and match_end != text_len:
                        pos = match_end
                        continue
                    return Match(0, match_pos, match_end, text)
                pos = match_pos + 1
            return None

        # General path: nibble skip + full DFA
        while pos < text_len:
            var found_pos = simd_matcher.find_first_nibble_match(
                text_ptr, pos, text_len
            )
            if found_pos == -1:
                return None
            var match_result = self._try_match_at_position(text, found_pos)
            if match_result:
                return match_result
            pos = found_pos + 1

        return None

    def _find_next_matching_char(
        self, text: ImmSlice, start: Int, simd_matcher: CharacterClassSIMD
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
        var text_ptr = text.unsafe_ptr()

        # Process characters in SIMD chunks for maximum efficiency
        comptime CHUNK_SIZE = 16  # Process 16 characters at once

        while pos + CHUNK_SIZE <= text_len:
            # Load a chunk of characters
            var match_pos = simd_matcher.find_first_match(
                text[byte = pos : pos + CHUNK_SIZE]
            )
            if match_pos != -1:
                return pos + match_pos

            pos += CHUNK_SIZE

        # Handle remaining characters one by one
        while pos < text_len:
            var char_code = Int(text_ptr[pos])
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

    def __init__(out self, pattern: String):
        """Initialize Boyer-Moore with a pattern.

        Args:
            pattern: Literal string pattern to search for.
        """
        self.pattern = pattern
        self.bad_char_table = List[Int](capacity=256)
        self._build_bad_char_table()

    def _build_bad_char_table(mut self):
        """Build the bad character heuristic table."""
        # Initialize all characters to -1 (not in pattern)
        for _ in range(256):
            self.bad_char_table.append(-1)

        # Set the last occurrence of each character in pattern
        var pattern_ptr = self.pattern.unsafe_ptr()
        for i in range(len(self.pattern)):
            var char_code = Int(pattern_ptr[i])
            self.bad_char_table[char_code] = i

    def search(self, text: String, start: Int = 0) -> Int:
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
        var text_ptr = text.unsafe_ptr()
        var pattern_ptr = self.pattern.unsafe_ptr()

        while s <= n - m:
            var j = m - 1

            # Compare pattern from right to left
            while j >= 0 and Int(pattern_ptr[j]) == Int(text_ptr[s + j]):
                j -= 1

            if j < 0:
                # Pattern found at position s
                return s
            else:
                # Mismatch occurred, use bad character heuristic
                var bad_char = Int(text_ptr[s + j])
                var shift = j - self.bad_char_table[bad_char]
                s += max(1, shift)

        return -1  # Pattern not found

    def search_all(self, text: String) -> List[Int]:
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

        return positions^


def compile_dfa_pattern(ast: ASTNode[MutAnyOrigin]) raises -> DFAEngine:
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
        var expanded_char_class = _expand_character_range(
            ast.type, char_class_str
        )
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
        sequence_info = _extract_multi_class_sequence_info(ast)
        dfa.compile_multi_character_class_sequence(sequence_info^)
    elif _is_sequential_character_class_pattern(ast):
        # Handle sequential character class patterns like [+]*\d+[-]*\d+
        sequence_info = _extract_sequential_pattern_info(ast)
        dfa.compile_sequential_pattern(sequence_info^)
    elif _is_mixed_sequential_pattern(ast):
        # Handle mixed patterns like [0-9]+\.?[0-9]* (numbers with optional decimal)
        sequence_info = _extract_mixed_sequential_pattern_info(ast)
        dfa.compile_multi_character_class_sequence(sequence_info^)
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


def _is_simple_character_class_pattern(ast: ASTNode[MutAnyOrigin]) -> Bool:
    """Check if pattern is a simple character class (single \\d, \\d+, \\d{3}, [a-z]+, etc.).

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a simple character class pattern.
    """
    from regex.ast import RE, DIGIT, WORD, RANGE, GROUP

    # First check if it's a multi-character sequence - if so, not simple
    if _is_multi_character_class_sequence(ast):
        return False

    if ast.type == RE and ast.get_children_len() == 1:
        ref child = ast.get_child(0)
        if child.type == DIGIT or child.type == WORD or child.type == RANGE:
            return True
        elif child.type == GROUP and child.get_children_len() == 1:
            # Check if group contains single digit or range element
            ref inner = child.get_child(0)
            return (
                inner.type == DIGIT or inner.type == WORD or inner.type == RANGE
            )
    elif ast.type == DIGIT or ast.type == WORD or ast.type == RANGE:
        return True

    return False


def _extract_character_class_info(
    ast: ASTNode[ImmutAnyOrigin],
) -> Tuple[Optional[String], Int, Int, Bool, Bool, Bool]:
    """Extract character class information from AST.

    Args:
        ast: AST node representing a character class pattern.

    Returns:
        Tuple of (char_class_string, min_matches, max_matches, has_start_anchor, has_end_anchor, positive_logic).
    """
    from regex.ast import RE, DIGIT, WORD, RANGE, GROUP

    var char_class: Optional[String] = None
    var min_matches = 1
    var max_matches = 1
    var has_start = False
    var has_end = False
    var positive_logic = True

    # Find the character class node (DIGIT, WORD, or RANGE)
    var class_node: ASTNode[ImmutAnyOrigin]
    if ast.type == DIGIT or ast.type == WORD or ast.type == RANGE:
        class_node = ast
    elif ast.type == RE and ast.get_children_len() == 1:
        ref ast_child = ast.get_child(0)
        if (
            ast_child.type == DIGIT
            or ast_child.type == WORD
            or ast_child.type == RANGE
        ):
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
        char_class = DIGITS
    elif class_node.type == WORD:
        min_matches = class_node.min
        max_matches = class_node.max
        positive_logic = class_node.positive_logic
        # Generate word character class string
        char_class = WORD_CHARS
    elif class_node.type == RANGE:
        min_matches = class_node.min
        max_matches = class_node.max
        positive_logic = class_node.positive_logic
        # Use the range value directly - expansion will be done when used
        var val = class_node.get_value()
        if val:
            char_class = String(val.value())

    return (
        char_class^,
        min_matches,
        max_matches,
        has_start,
        has_end,
        positive_logic,
    )


def _is_pure_anchor_pattern(ast: ASTNode[MutAnyOrigin]) -> Bool:
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


def _is_sequential_character_class_pattern(
    ast: ASTNode[MutAnyOrigin],
) -> Bool:
    """Check if pattern is a sequence of character classes with quantifiers.

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a sequence like [+]*\\d+[-]*\\d+.
    """
    from regex.ast import RE, DIGIT, WORD, RANGE, GROUP

    if ast.type != RE or ast.get_children_len() != 1:
        return False

    ref child = ast.get_child(0)
    if child.type != GROUP:
        return False

    # Check if all children are character classes (RANGE, DIGIT, or WORD)
    for i in range(child.get_children_len()):
        ref element = child.get_child(i)
        if (
            element.type != RANGE
            and element.type != DIGIT
            and element.type != WORD
        ):
            return False

    # Must have at least 2 elements to be considered sequential
    return child.get_children_len() >= 2


def _extract_sequential_pattern_info(
    ast: ASTNode[MutAnyOrigin],
) -> SequentialPatternInfo:
    """Extract information about a sequential pattern.

    Args:
        ast: AST node representing a sequential pattern.

    Returns:
        SequentialPatternInfo with details about each element.
    """
    from regex.ast import RE, DIGIT, WORD, RANGE, GROUP

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
                elif element.type == WORD:
                    char_class = WORD_CHARS
                elif element.type == RANGE:
                    char_class = _expand_character_range(
                        element.type, element.get_value().value()
                    )
                else:
                    continue  # Skip unknown elements

                var pattern_element = SequentialPatternElement(
                    char_class, element.min, element.max, element.positive_logic
                )
                info.elements.append(pattern_element^)

    return info^


def _is_char_class_group(node: ASTNode[MutAnyOrigin]) -> Bool:
    """Check if a GROUP node contains only character classes and literals.

    This allows capturing groups like ([A-Z]{3}[0-9]{4}) to be flattened
    into DFA sequences. Safe because match_first/match_next/match_all don't
    return sub-group captures. When captures() is implemented, these patterns
    should route to NFA instead.
    """
    from regex.ast import GROUP

    if node.type != GROUP:
        return False

    from regex.ast import ELEMENT

    var has_char_class = False
    for i in range(node.get_children_len()):
        ref child = node.get_child(i)
        if not _element_to_char_class(child):
            return False  # Nested groups or other unrecognized types
        if child.type != ELEMENT:
            has_char_class = True
    return has_char_class


def _is_literal_alternation_group(node: ASTNode[MutAnyOrigin]) -> Bool:
    """Check if a GROUP node contains only OR with literal branches.

    Examples: (?:00|33|44|55|66|77|88), (?:hello|world|test)
    Branches can have different lengths.
    """
    from regex.ast import GROUP, OR, ELEMENT

    if node.type != GROUP or node.get_children_len() != 1:
        return False

    ref child = node.get_child(0)
    if child.type != OR:
        return False

    # Walk the OR tree iteratively to verify all branches are literal
    var has_branch = False
    var stack = List[ASTNode[MutAnyOrigin]](capacity=16)
    stack.append(child)

    while len(stack) > 0:
        var current = stack.pop()
        if current.type == GROUP:
            for i in range(current.get_children_len()):
                if current.get_child(i).type != ELEMENT:
                    return False
            has_branch = True
        elif current.type == OR:
            if current.get_children_len() != 2:
                return False
            stack.append(current.get_child(1))
            stack.append(current.get_child(0))
        else:
            return False

    return has_branch


def _collect_alternation_branches(
    node: ASTNode[MutAnyOrigin],
) -> List[String]:
    """Collect all literal branch strings from a literal alternation GROUP."""
    from regex.ast import GROUP, OR, ELEMENT

    var branches = List[String](capacity=16)
    # Walk the OR tree iteratively using a stack
    var stack = List[Int](capacity=16)
    var nodes = List[ASTNode[MutAnyOrigin]](capacity=16)
    if node.get_children_len() > 0:
        nodes.append(node.get_child(0))
        stack.append(0)

    while len(stack) > 0:
        var idx = stack.pop()
        ref current = nodes[idx]
        if current.type == GROUP:
            var branch = String(capacity=current.get_children_len())
            for i in range(current.get_children_len()):
                ref child = current.get_child(i)
                if child.type == ELEMENT and child.get_value():
                    branch += String(child.get_value().value())
            branches.append(branch^)
        elif current.type == OR:
            if current.get_children_len() >= 2:
                nodes.append(current.get_child(1))
                stack.append(len(nodes) - 1)
            if current.get_children_len() >= 1:
                nodes.append(current.get_child(0))
                stack.append(len(nodes) - 1)

    return branches^


def _is_multi_character_class_sequence(ast: ASTNode[MutAnyOrigin]) -> Bool:
    """Check if pattern is a sequence of multiple character classes.

    Examples: [a-z]+[0-9]+, digit+word+, [A-Z][a-z]*[0-9]{2,4}

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a multi-character class sequence.
    """
    from regex.ast import (
        RE,
        DIGIT,
        WORD,
        RANGE,
        GROUP,
        SPACE,
        WILDCARD,
        ELEMENT,
    )

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
            or element.type == WORD
            or element.type == SPACE
        ):
            char_class_count += 1
        elif element.type == WILDCARD:
            # Wildcard can be considered a character class
            char_class_count += 1
        elif element.type == ELEMENT and element.min == 1 and element.max == 1:
            # Single literal characters are OK (like @ and . in email patterns)
            literal_count += 1
        elif element.type == GROUP and _is_literal_alternation_group(element):
            # Non-capturing group with literal alternation like (?:00|33|44)
            literal_count += 1
        elif element.type == GROUP and _is_char_class_group(element):
            # Capturing group containing only char classes, e.g., ([A-Z]{3}[0-9]{4})
            # Safe to flatten into DFA since we don't track sub-group captures yet
            char_class_count += 1
        else:
            # Other types make it non-sequential
            return False

    # It's a multi-char sequence if it has at least 2 character classes
    # and any number of single literals
    return char_class_count >= 2


@always_inline
def _element_to_char_class(element: ASTNode[MutAnyOrigin]) -> String:
    """Convert an AST element node to its character class string.

    Returns empty string if the element type is not recognized.
    """
    from regex.ast import DIGIT, WORD, RANGE, SPACE, WILDCARD, ELEMENT

    if element.type == DIGIT:
        return "0123456789"
    elif element.type == WORD:
        return WORD_CHARS
    elif element.type == RANGE:
        return _expand_character_range(
            element.type, element.get_value().value()
        )
    elif element.type == SPACE:
        return " \t\n\r\f"
    elif element.type == WILDCARD:
        return ALL_EXCEPT_NEWLINE
    elif element.type == ELEMENT:
        if element.get_value():
            return String(element.get_value().value())
    return ""


def _extract_multi_class_sequence_info(
    ast: ASTNode[MutAnyOrigin],
) -> SequentialPatternInfo:
    """Extract information about a multi-character class sequence.

    Args:
        ast: AST node representing a multi-character class sequence.

    Returns:
        SequentialPatternInfo with details about each character class element.
    """
    var info = SequentialPatternInfo()

    # Check for anchors at root level
    info.has_start_anchor, info.has_end_anchor = pattern_has_anchors(ast)

    if ast.type == RE and ast.get_children_len() == 1:
        ref child = ast.get_child(0)
        if child.type == GROUP:
            # Extract each element into the sequence
            for i in range(child.get_children_len()):
                ref element = child.get_child(i)

                if element.type == GROUP and _is_literal_alternation_group(
                    element
                ):
                    var branches = _collect_alternation_branches(element)
                    var pattern_element = SequentialPatternElement(
                        "", 1, 1, True
                    )
                    pattern_element.alternation_branches = branches^
                    info.elements.append(pattern_element^)
                elif element.type == GROUP and _is_char_class_group(element):
                    # Flatten capturing group children into the sequence.
                    # Safe because current API doesn't return sub-group captures.
                    for j in range(element.get_children_len()):
                        ref sub = element.get_child(j)
                        var sub_class = _element_to_char_class(sub)
                        if sub_class:
                            info.elements.append(
                                SequentialPatternElement(
                                    sub_class^,
                                    sub.min,
                                    sub.max,
                                    sub.positive_logic,
                                )
                            )
                else:
                    var char_class = _element_to_char_class(element)
                    if char_class:
                        info.elements.append(
                            SequentialPatternElement(
                                char_class^,
                                element.min,
                                element.max,
                                element.positive_logic,
                            )
                        )

    return info^


def _is_mixed_sequential_pattern(ast: ASTNode[MutAnyOrigin]) -> Bool:
    """Check if pattern is a mixed sequential pattern with optional literals.

    Examples: [0-9]+\\.?[0-9]*, [a-z]+@[a-z]+\\.[a-z]+

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is a mixed sequential pattern.
    """
    from regex.ast import RE, DIGIT, WORD, RANGE, GROUP, ELEMENT

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

        if (
            element.type == RANGE
            or element.type == DIGIT
            or element.type == WORD
        ):
            has_char_class = True
        elif element.type == ELEMENT:
            # Check if it's an optional literal (min=0, max=1)
            if element.min == 0 and element.max == 1:
                has_optional_literal = True

    # It's a mixed pattern if it has both character classes and optional literals
    return has_char_class and has_optional_literal


def _extract_mixed_sequential_pattern_info(
    ast: ASTNode[MutAnyOrigin],
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


def _is_alternation_pattern(ast: ASTNode[MutAnyOrigin]) -> Bool:
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


def _is_simple_alternation_branches(ast: ASTNode[MutAnyOrigin]) -> Bool:
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
            # Check that the group contains only literal elements,
            # or is a nested alternation group like (?:a|b)
            if not _group_contains_only_literals(branch):
                # Unwrap nested GROUP -> OR for patterns like (?:(?:a|b)|(?:c|d))
                var inner = branch
                while inner.type == GROUP and inner.get_children_len() == 1:
                    inner = inner.get_child(0)
                if inner.type == OR:
                    if not _is_simple_alternation_branches(inner):
                        return False
                else:
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


def _group_contains_only_literals(group: ASTNode[MutAnyOrigin]) -> Bool:
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


def _find_and_check_or_node(ast: ASTNode[MutAnyOrigin]) -> Bool:
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


def _find_or_node(
    ast: ASTNode[MutAnyOrigin],
) -> Optional[ASTNode[MutAnyOrigin]]:
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


def _extract_branch_text(branch: ASTNode[MutAnyOrigin]) -> String:
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


def _is_quantified_group(ast: ASTNode[MutAnyOrigin]) -> Bool:
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


def _group_content_is_simple(group: ASTNode[MutAnyOrigin]) -> Bool:
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


def _extract_group_text(group: ASTNode[MutAnyOrigin]) -> String:
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


def _collect_all_alternation_branches(
    or_node: ASTNode[MutAnyOrigin],
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
        elif branch.type == GROUP:
            # Unwrap nested GROUPs to find OR or literal content
            var inner = branch
            while inner.type == GROUP and inner.get_children_len() == 1:
                inner = inner.get_child(0)
            if inner.type == OR:
                ref nested = _collect_all_alternation_branches(inner)
                for j in range(len(nested)):
                    branches.append(nested[j])
            else:
                ref branch_text = _extract_branch_text(branch)
                if len(branch_text) > 0:
                    branches.append(branch_text)
        else:
            ref branch_text = _extract_branch_text(branch)
            if len(branch_text) > 0:
                branches.append(branch_text)

    return branches^


def _is_pure_alternation_pattern(ast: ASTNode[MutAnyOrigin]) -> Bool:
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

    # Case 2: RE -> GROUP(s) -> OR (grouped alternation, unwrap nested GROUPs)
    var node = child
    while node.type == GROUP and node.get_children_len() == 1:
        node = node.get_child(0)
    if node.type == OR:
        return _is_simple_alternation_branches(node)

    return False


def _is_simple_quantifier_pattern(ast: ASTNode[MutAnyOrigin]) -> Bool:
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


def _is_wildcard_quantifier_pattern(ast: ASTNode[MutAnyOrigin]) -> Bool:
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


def _is_common_prefix_alternation_pattern(
    ast: ASTNode[MutAnyOrigin],
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


def _extract_literal_branches(
    node: ASTNode[MutAnyOrigin], mut branches: List[String]
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


def _compute_common_prefix(branches: List[String]) -> String:
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
    var first_branch_ptr = first_branch.unsafe_ptr()
    for pos in range(min_length):
        var char_at_pos = Int(first_branch_ptr[pos])
        var all_match = True

        for i in range(1, len(branches)):
            var branch_ptr_i = branches[i].unsafe_ptr()
            if Int(branch_ptr_i[pos]) != char_at_pos:
                all_match = False
                break

        if all_match:
            prefix += chr(char_at_pos)
        else:
            break

    return prefix


def _is_quantified_alternation_group(ast: ASTNode[MutAnyOrigin]) -> Bool:
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


def _extract_literal_alternation_branches(
    node: ASTNode[MutAnyOrigin], mut branches: List[String]
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
