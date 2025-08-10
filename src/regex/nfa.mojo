from memory import UnsafePointer

from regex.ast import ASTNode
from regex.aliases import (
    CHAR_ZERO,
    CHAR_NINE,
    CHAR_NEWLINE,
    SIMD_MATCHER_DIGITS,
    SIMD_MATCHER_WHITESPACE,
)
from regex.engine import Engine
from regex.matching import Match
from regex.parser import parse
from regex.simd_ops import (
    TwoWaySearcher,
    CharacterClassSIMD,
    get_simd_matcher,
    apply_quantifier_simd_generic,
    find_in_text_simd,
)
from regex.simd_matchers import (
    get_digit_matcher,
    get_whitespace_matcher,
    get_alpha_matcher,
    get_alnum_matcher,
    RangeBasedMatcher,
)
from regex.literal_optimizer import extract_literals, extract_literal_prefix
from regex.optimizer import PatternAnalyzer, PatternComplexity


# Threshold for complex character class patterns (e.g. [a-zA-Z0-9._%+-])
# When a pattern has alphanumeric ranges plus more than this many characters,
# use optimized two-phase matching (check alphanumeric first, then special chars)
alias COMPLEX_CHAR_CLASS_THRESHOLD = 10

# Minimum literal length thresholds for optimization
# Prefix literals need to be longer than this to justify optimization overhead
alias MIN_PREFIX_LITERAL_LENGTH = 3
# Non-prefix literals need even longer length to be worth the overhead
alias MIN_REQUIRED_LITERAL_LENGTH = 4


struct NFAEngine(Engine):
    """A regex engine that can match regex patterns against text."""

    var pattern: String
    """The regex pattern string to match against."""
    var prev_re: String
    """Previously parsed regex pattern for caching."""
    var prev_ast: Optional[ASTNode[MutableAnyOrigin]]
    """Cached AST from previous regex compilation."""
    var regex: Optional[ASTNode[MutableAnyOrigin]]
    """Compiled AST representation of the current regex pattern."""
    var literal_prefix: String
    """Extracted literal prefix for optimization."""
    var has_literal_optimization: Bool
    """Whether literal optimization is available for this pattern."""
    var literal_searcher: Optional[TwoWaySearcher]
    """SIMD searcher for literal prefix."""

    fn __init__(out self, pattern: String):
        """Initialize the regex engine."""
        self.prev_re = ""
        self.prev_ast = None
        self.pattern = pattern
        self.literal_prefix = ""
        self.has_literal_optimization = False
        self.literal_searcher = None

        try:
            self.regex = parse(pattern)

            # Only apply literal optimization for patterns that benefit from it
            # Skip for simple patterns that will use DFA anyway
            if self.regex:
                var ast = self.regex.value()
                var analyzer = PatternAnalyzer()
                var complexity = analyzer.classify(ast)

                # Only apply literal optimization for MEDIUM or COMPLEX patterns
                # SIMPLE patterns use DFA which is already optimized
                # This has a HUGE impact on performance
                if complexity.value != PatternComplexity.SIMPLE:
                    var literal_set = extract_literals(ast)

                    # Use best literal if available and significant
                    ref best_literal = literal_set.get_best_literal()
                    if best_literal:
                        var best = best_literal.value()
                        # Require longer literals to justify overhead
                        if (
                            best.is_prefix
                            and best.get_literal_len()
                            > MIN_PREFIX_LITERAL_LENGTH
                        ):
                            # Use prefix literal for optimization
                            self.literal_prefix = best.get_literal()
                            self.has_literal_optimization = True
                            self.literal_searcher = TwoWaySearcher(
                                self.literal_prefix
                            )
                        elif (
                            best.is_required
                            and best.get_literal_len()
                            > MIN_REQUIRED_LITERAL_LENGTH
                        ):
                            # Use required literal for prefiltering
                            # Require even longer literals for non-prefix optimization
                            self.literal_prefix = best.get_literal()
                            self.has_literal_optimization = True
                            self.literal_searcher = TwoWaySearcher(
                                self.literal_prefix
                            )
        except:
            self.regex = None

    fn match_all(
        self,
        text: String,
    ) -> List[Match, hint_trivial_type=True]:
        """Searches a regex in a test string.

        Searches the passed regular expression in the passed test string and
        returns the result.

        It is possible to customize both the returned value and the search
        method.

        The ignore_case flag may cause unexpected results in the returned
        number of matched characters, and also in the returned matches, e.g.
        when the character ẞ is present in either the regex or the test string.

        Args:
            text: The test string.

        Returns:
            A tuple containing whether a match was found or not, the last
            matched character index, and a list of deques of Match, where
            each list of matches represents in the first position the whole
            match, and in the subsequent positions all the group and subgroups
            matched.
        """
        # Parse the regex if it's different from the cached one
        var ast: ASTNode[MutableAnyOrigin]
        if self.prev_ast:
            ast = self.prev_ast.value()
        elif self.regex:
            ast = self.regex.value()
        else:
            try:
                ast = parse(self.pattern)
            except:
                return []

        var matches = List[Match, hint_trivial_type=True](capacity=len(text))
        var current_pos = 0

        var temp_matches = List[Match, hint_trivial_type=True](capacity=10)

        # Use literal prefiltering if available
        if self.has_literal_optimization and self.literal_searcher:
            var searcher = self.literal_searcher.value()

            while current_pos <= len(text):
                # Find next occurrence of literal
                var literal_pos = searcher.search(text, current_pos)
                if literal_pos == -1:
                    # No more occurrences of required literal
                    break

                # Skip literals that would create overlapping matches
                if literal_pos < current_pos:
                    current_pos = literal_pos + 1
                    continue

                # Try to match the full pattern starting from before the literal
                var try_pos = literal_pos
                if self.literal_prefix and not self._is_prefix_literal():
                    try_pos = max(current_pos, literal_pos - 100)

                # Search for matches around the literal
                var found_match = False

                while try_pos <= literal_pos and try_pos <= len(text):
                    temp_matches.clear()
                    var result = self._match_node(
                        ast,
                        text,
                        try_pos,
                        temp_matches,
                        match_first_mode=False,
                        required_start_pos=-1,
                    )
                    if result[0]:  # Match found
                        var match_end = result[1]
                        if self._match_contains_literal(
                            text, try_pos, match_end
                        ):
                            var matched = Match(0, try_pos, match_end, text)
                            matches.append(matched)

                            # Move past this match to avoid overlapping matches
                            if match_end == try_pos:
                                current_pos = try_pos + 1
                            else:
                                current_pos = match_end
                            found_match = True
                            break
                    try_pos += 1

                if not found_match:
                    # No match found around this literal, move past it
                    current_pos = literal_pos + 1
        else:
            # No literal optimization, use standard approach
            while current_pos <= len(text):
                temp_matches.clear()
                var result = self._match_node(
                    ast,
                    text,
                    current_pos,
                    temp_matches,
                    match_first_mode=False,
                    required_start_pos=-1,
                )
                if result[0]:  # Match found
                    var match_start = current_pos
                    var match_end = result[1]

                    # Create match object
                    var matched = Match(0, match_start, match_end, text)
                    matches.append(matched)

                    # Move past this match to find next one
                    # Avoid infinite loop on zero-width matches
                    if match_end == match_start:
                        current_pos += 1
                    else:
                        current_pos = match_end
                else:
                    current_pos += 1

        return matches

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Same as match_all, but always returns after the first match.
        Equivalent to re.match in Python.

        Args:
            text: The test string.
            start: The starting position in the string to search from.

        Returns:
            A tuple containing whether a match was found or not, the last
            matched character index, and a deque of Match, where the first
            position contains the whole match, and the subsequent positions
            contain all the group and subgroups matched.
        """
        var matches = List[Match, hint_trivial_type=True]()
        var str_i = start
        var ast: ASTNode[MutableAnyOrigin]
        if self.regex:
            ast = self.regex.value()
        else:
            try:
                ast = parse(self.pattern)
            except:
                return None

        # Try to match at the exact start position only (like Python's re.match)
        # Use match_first_mode for optimized early termination
        var result = self._match_node(
            ast,
            text,
            str_i,
            matches,
            match_first_mode=True,
            required_start_pos=start,
        )
        if result[0]:  # Match found
            var end_idx = result[1]
            # Create the match object
            return Match(0, str_i, end_idx, text)

        return None

    fn match_next(self, text: String, start: Int = 0) -> Optional[Match]:
        """Same as match_all, but always returns after the first match.
        It's equivalent to re.search in Python.

        Args:
            text: The test string.
            start: The starting position in the string to search from.

        Returns:
            A tuple containing whether a match was found or not, the last
            matched character index, and a deque of Match, where the first
            position contains the whole match, and the subsequent positions
            contain all the group and subgroups matched.
        """
        var matches = List[Match, hint_trivial_type=True]()
        var ast: ASTNode[MutableAnyOrigin]
        if self.regex:
            ast = self.regex.value()
        else:
            try:
                ast = parse(self.pattern)
            except:
                return None

        var search_pos = start

        # Use literal prefiltering if available
        if self.has_literal_optimization and self.literal_searcher:
            var searcher = self.literal_searcher.value()

            while search_pos <= len(text):
                # Find next occurrence of literal
                var literal_pos = searcher.search(text, search_pos)
                if literal_pos == -1:
                    # No more occurrences of required literal
                    return None

                # Try to match the full pattern starting from before the literal
                # (unless the literal is a prefix, then start at literal position)
                var try_pos = literal_pos
                if self.literal_prefix and not self._is_prefix_literal():
                    # For non-prefix literals, we need to search backwards
                    # to find where the pattern might start
                    try_pos = max(
                        0, literal_pos - 100
                    )  # Conservative backward search

                # Try matching from positions around the literal
                var end_pos = min(
                    len(text), literal_pos + len(self.literal_prefix)
                )
                while try_pos <= literal_pos:
                    matches.clear()
                    var result = self._match_node(
                        ast,
                        text,
                        try_pos,
                        matches,
                        match_first_mode=False,
                        required_start_pos=-1,
                    )
                    if result[0]:  # Match found
                        var match_end = result[1]
                        # Verify the match includes our literal
                        if self._match_contains_literal(
                            text, try_pos, match_end
                        ):
                            return Match(0, try_pos, match_end, text)
                    try_pos += 1

                # Move search position past this literal occurrence
                search_pos = literal_pos + 1
        else:
            # No literal optimization, fall back to standard search
            while search_pos <= len(text):
                matches.clear()
                var result = self._match_node(
                    ast,
                    text,
                    search_pos,
                    matches,
                    match_first_mode=False,
                    required_start_pos=-1,
                )
                if result[0]:  # Match found
                    var end_idx = result[1]
                    return Match(0, search_pos, end_idx, text)
                search_pos += 1

        return None

    fn _is_prefix_literal(self) -> Bool:
        """Check if the extracted literal is a prefix literal."""
        # Simple heuristic: if pattern starts with the literal, it's a prefix
        return self.pattern.startswith(self.literal_prefix)

    fn _create_range_matcher(
        self, range_pattern: StringSlice
    ) -> Optional[CharacterClassSIMD]:
        """Create SIMD matcher for a range pattern.

        Args:
            range_pattern: The range pattern string (e.g., "[a-z]" or "abcdefg...").

        Returns:
            Optional SIMD matcher for the pattern.
        """
        # Try to create a SIMD matcher for common patterns
        var char_class = String()

        # Expand the range pattern if needed
        if range_pattern.startswith("[") and range_pattern.endswith("]"):
            # It's a pattern like "[a-z]", need to expand it
            var inner = range_pattern[1:-1]

            # Handle common patterns with specialized matchers
            # Return None for simple ranges to use RangeBasedMatcher instead
            if inner == "a-z" or inner == "A-Z" or inner == "0-9":
                # These simple ranges should use RangeBasedMatcher for better performance
                return None
            elif inner == "a-zA-Z":
                # This can also use RangeBasedMatcher with two ranges
                return None
            elif inner == "a-zA-Z0-9":
                # Return None to signal that specialized matcher should be used
                # This will be handled in _apply_quantifier_simd
                return None
            else:
                # Check if pattern contains alphanumeric + special chars
                # Common email/identifier patterns like [a-zA-Z0-9._%-+]
                var has_lower = "a-z" in inner
                var has_upper = "A-Z" in inner
                var has_digits = "0-9" in inner
                var has_alnum = has_lower and has_upper and has_digits

                # If it has alphanumeric ranges plus special chars, return None
                # to signal specialized handling
                if (
                    has_alnum and len(inner) > COMPLEX_CHAR_CLASS_THRESHOLD
                ):  # e.g. "a-zA-Z0-9._%-+"
                    return None

                # More complex pattern, use helper to expand
                from regex.dfa import expand_character_range

                # Cannot easily convert String to StringSlice with correct origin
                # Fall back to manual expansion for complex patterns
                char_class = String()
        else:
            # Already expanded
            char_class = String(range_pattern)

        # Create SIMD matcher
        if char_class:
            return CharacterClassSIMD(char_class)

        return None

    fn _match_contains_literal(
        self, text: String, start: Int, end: Int
    ) -> Bool:
        """Verify that a match contains the required literal."""
        if not self.has_literal_optimization or len(self.literal_prefix) == 0:
            return True

        # Check if the literal appears within the match bounds
        var match_text = text[start:end]
        return self.literal_prefix in match_text

    @always_inline
    fn _match_node(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        mut matches: List[Match, hint_trivial_type=True],
        match_first_mode: Bool = False,
        required_start_pos: Int = -1,
    ) capturing -> Tuple[Bool, Int]:
        """Core matching function that processes AST nodes recursively.

        Args:
            ast: The AST node to match
            str: The input string
            str_i: Current position in string
            matches: List to collect matched groups
            match_first_mode: If True, optimize for match_first() with early termination
            required_start_pos: Required starting position for match_first mode (-1 if not applicable)

        Returns:
            Tuple of (success, final_position)
        """
        from regex.ast import (
            RE,
            ELEMENT,
            WILDCARD,
            SPACE,
            DIGIT,
            RANGE,
            START,
            END,
            OR,
            GROUP,
        )

        if ast.type == ELEMENT:
            return self._match_element(
                ast, str, str_i, match_first_mode, required_start_pos
            )
        elif ast.type == WILDCARD:
            return self._match_wildcard(
                ast, str, str_i, match_first_mode, required_start_pos
            )
        elif ast.type == SPACE:
            return self._match_space(
                ast, str, str_i, match_first_mode, required_start_pos
            )
        elif ast.type == DIGIT:
            return self._match_digit(
                ast, str, str_i, match_first_mode, required_start_pos
            )
        elif ast.type == RANGE:
            return self._match_range(
                ast, str, str_i, match_first_mode, required_start_pos
            )
        elif ast.type == START:
            return self._match_start(ast, str_i)
        elif ast.type == END:
            return self._match_end(ast, str, str_i)
        elif ast.type == OR:
            return self._match_or(
                ast,
                str,
                str_i,
                matches,
                match_first_mode,
                required_start_pos,
            )
        elif ast.type == GROUP:
            return self._match_group(
                ast,
                str,
                str_i,
                matches,
                match_first_mode,
                required_start_pos,
            )
        elif ast.type == RE:
            return self._match_re(
                ast,
                str,
                str_i,
                matches,
                match_first_mode,
                required_start_pos,
            )
        else:
            return (False, str_i)

    @always_inline
    fn _match_element(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match a literal character element."""
        if str_i >= len(str):
            return (False, str_i)

        var ch = String(str[str_i])
        if ast.get_value() and ast.get_value().value() == ch:
            return self._apply_quantifier(
                ast, str, str_i, 1, match_first_mode, required_start_pos
            )
        else:
            return (False, str_i)

    @always_inline
    fn _match_wildcard(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match wildcard (.) - any character except newline."""
        if str_i >= len(str):
            return (False, str_i)

        var ch_code = ord(str[str_i])
        if ch_code != CHAR_NEWLINE:  # Exclude newline
            return self._apply_quantifier(
                ast, str, str_i, 1, match_first_mode, required_start_pos
            )
        else:
            return (False, str_i)

    @always_inline
    fn _match_space(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match whitespace character (\\s)."""
        if str_i >= len(str):
            return (False, str_i)

        # Use specialized SIMD whitespace matcher for better performance
        var whitespace_matcher = get_whitespace_matcher()
        var ch_code = ord(str[str_i])
        if whitespace_matcher.contains(ch_code):
            return self._apply_quantifier(
                ast, str, str_i, 1, match_first_mode, required_start_pos
            )
        else:
            return (False, str_i)

    @always_inline
    fn _match_digit(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match digit character (\\d)."""
        if str_i >= len(str):
            return (False, str_i)

        # Use specialized SIMD digit matcher for better performance
        var digit_matcher = get_digit_matcher()
        var ch_code = ord(str[str_i])
        if digit_matcher.contains(ch_code):
            return self._apply_quantifier(
                ast, str, str_i, 1, match_first_mode, required_start_pos
            )
        else:
            return (False, str_i)

    @always_inline
    fn _match_range(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match character range [abc] or [^abc]."""
        if str_i >= len(str):
            return (False, str_i)

        var ch_code = ord(str[str_i])
        var ch_found = False

        if ast.get_value():
            var range_pattern = ast.get_value().value()

            # Check for common patterns with specialized matchers
            if range_pattern == "[a-zA-Z0-9]":
                var alnum_matcher = get_alnum_matcher()
                ch_found = alnum_matcher.contains(ch_code)
            elif range_pattern == "[a-z]":
                # Use RangeBasedMatcher for simple lowercase range
                ch_found = ch_code >= ord("a") and ch_code <= ord("z")
            elif range_pattern == "[A-Z]":
                # Use RangeBasedMatcher for simple uppercase range
                ch_found = ch_code >= ord("A") and ch_code <= ord("Z")
            elif range_pattern == "[0-9]":
                # Use RangeBasedMatcher for digit range
                ch_found = ch_code >= ord("0") and ch_code <= ord("9")
            elif range_pattern == "[a-zA-Z]":
                # Use RangeBasedMatcher for alphabetic range
                var alpha_matcher = get_alpha_matcher()
                ch_found = alpha_matcher.contains(ch_code)
            else:
                # Check if it's a complex pattern with alphanumeric + special chars
                if range_pattern.startswith("[") and range_pattern.endswith(
                    "]"
                ):
                    var inner = range_pattern[1:-1]
                    var has_lower = "a-z" in inner
                    var has_upper = "A-Z" in inner
                    var has_digits = "0-9" in inner
                    var has_alnum = has_lower and has_upper and has_digits

                    if has_alnum and len(inner) > COMPLEX_CHAR_CLASS_THRESHOLD:
                        # Complex pattern like [a-zA-Z0-9._%+-]
                        # Check alphanumeric first (common case)
                        var alnum_matcher = get_alnum_matcher()
                        if alnum_matcher.contains(ch_code):
                            ch_found = True
                        else:
                            # Not alphanumeric, check special chars
                            var ch = String(str[str_i])
                            ch_found = ch in inner
                    else:
                        # Try to use SIMD matcher for other patterns
                        ch_found = self._match_with_simd_or_fallback(
                            ast, range_pattern, str[str_i], ch_code
                        )
                else:
                    # Not a bracketed pattern, try SIMD matcher
                    ch_found = self._match_with_simd_or_fallback(
                        ast, range_pattern, str[str_i], ch_code
                    )

        if ch_found == ast.positive_logic:
            return self._apply_quantifier(
                ast, str, str_i, 1, match_first_mode, required_start_pos
            )
        else:
            return (False, str_i)

    @always_inline
    fn _match_start(
        self, ast: ASTNode, str_i: Int
    ) capturing -> Tuple[Bool, Int]:
        """Match start anchor (^)."""
        if str_i == 0:
            return (True, str_i)
        else:
            return (False, str_i)

    @always_inline
    fn _match_end(
        self, ast: ASTNode, str: String, str_i: Int
    ) capturing -> Tuple[Bool, Int]:
        """Match end anchor ($)."""
        if str_i == len(str):
            return (True, str_i)
        else:
            return (False, str_i)

    fn _match_with_simd_or_fallback(
        self,
        ast: ASTNode,
        range_pattern: StringSlice[__origin_of(ast.regex_ptr[].pattern)],
        ch: StringSlice,
        ch_code: Int,
    ) -> Bool:
        """Try to match with SIMD matcher, fallback to regular matching."""
        var simd_matcher = self._create_range_matcher(range_pattern)
        if simd_matcher:
            return simd_matcher.value().contains(ch_code)
        else:
            # Fallback to regular range matching
            return ast._is_char_in_range(ch, range_pattern)

    fn _match_or(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        mut matches: List[Match, hint_trivial_type=True],
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match OR node - try left branch first, then right."""
        if ast.get_children_len() < 2:
            return (False, str_i)

        # Try left branch first
        var left_result = self._match_node(
            ast.get_child(0),
            str,
            str_i,
            matches,
            match_first_mode,
            required_start_pos,
        )
        if left_result[0]:
            return left_result

        # If left fails, try right branch
        var right_result = self._match_node(
            ast.get_child(1),
            str,
            str_i,
            matches,
            match_first_mode,
            required_start_pos,
        )
        return right_result

    fn _match_group(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        mut matches: List[Match, hint_trivial_type=True],
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match GROUP node - process children sequentially with backtracking.
        """
        var start_pos = str_i

        # Check if this group itself has a quantifier
        if self._has_quantifier(ast):
            return self._match_group_with_quantifier(
                ast,
                str,
                str_i,
                matches,
                match_first_mode,
                required_start_pos,
            )

        # Simple case: no quantifier on the group itself
        var result = self._match_sequence(
            ast,
            0,
            str,
            str_i,
            matches,
            match_first_mode,
            required_start_pos,
        )
        if not result[0]:
            return (False, str_i)

        # If this is a capturing group, add the match
        if ast.is_capturing():
            var matched = Match(0, start_pos, result[1], str)
            matches.append(matched)

        return result

    fn _match_group_with_quantifier(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        mut matches: List[Match, hint_trivial_type=True],
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match a group that has a quantifier applied to it."""
        var min_matches = ast.min
        var max_matches = ast.max
        var current_pos = str_i
        var group_matches = 0

        if max_matches == -1:
            max_matches = len(str) - str_i

        # Use regular greedy matching with conservative early termination
        while group_matches < max_matches and current_pos <= len(str):
            var group_result = self._match_sequence(
                ast,
                0,
                str,
                current_pos,
                matches,
                match_first_mode,
                required_start_pos,
            )
            if group_result[0]:
                group_matches += 1
                current_pos = group_result[1]
                # Conservative early termination check only for extreme cases
                if (
                    match_first_mode
                    and required_start_pos >= 0
                    and current_pos > required_start_pos + 100
                ):
                    break
                if ast.is_capturing():
                    var matched = Match(0, str_i, current_pos, str)
                    matches.append(matched)
            else:
                break

        # Check if we have enough matches
        if group_matches >= min_matches:
            return (True, current_pos)
        else:
            return (False, str_i)

    fn _match_sequence(
        self,
        ast_parent: ASTNode,
        child_index: Int,
        str: String,
        str_i: Int,
        mut matches: List[Match, hint_trivial_type=True],
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match a sequence of AST nodes with backtracking support."""
        var children_len = ast_parent.get_children_len()
        if child_index >= children_len:
            return (True, str_i)

        if child_index == children_len - 1:
            return self._match_node(
                ast_parent.get_child(child_index),
                str,
                str_i,
                matches,
                match_first_mode,
                required_start_pos,
            )

        # For multiple remaining children, we need to handle backtracking
        ref first_child = ast_parent.get_child(child_index)

        # Try different match lengths for the first child
        if self._has_quantifier(first_child):
            return self._match_with_backtracking(
                first_child,
                ast_parent,
                child_index + 1,
                str,
                str_i,
                matches,
                match_first_mode,
                required_start_pos,
            )
        else:
            # Simple case: match first child normally, then recursively match rest
            var result = self._match_node(
                first_child,
                str,
                str_i,
                matches,
                match_first_mode,
                required_start_pos,
            )
            if not result[0]:
                return (False, str_i)
            return self._match_sequence(
                ast_parent,
                child_index + 1,
                str,
                result[1],
                matches,
                match_first_mode,
                required_start_pos,
            )

    @always_inline
    fn _has_quantifier(self, ast: ASTNode) capturing -> Bool:
        """Check if node has quantifier (min != 1 or max != 1)."""
        return ast.min != 1 or ast.max != 1

    @always_inline
    fn _match_with_backtracking(
        self,
        quantified_node: ASTNode,
        ast_parent: ASTNode,
        remaining_index: Int,
        str: String,
        str_i: Int,
        mut matches: List[Match, hint_trivial_type=True],
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match a quantified node followed by other nodes, with backtracking.
        """
        var min_matches = quantified_node.min
        var max_matches = quantified_node.max

        if max_matches == -1:
            max_matches = len(str) - str_i

        # Use regular greedy backtracking but with conservative early termination
        var match_count = max_matches
        while match_count >= min_matches:
            var consumed = self._try_match_count(
                quantified_node,
                str,
                str_i,
                match_count,
                match_first_mode,
                required_start_pos,
            )
            if consumed >= 0:  # Successfully matched this many times
                var new_pos = str_i + consumed
                # Conservative early termination only for extreme cases
                if (
                    match_first_mode
                    and required_start_pos >= 0
                    and new_pos > required_start_pos + 100
                ):
                    return (False, str_i)
                # Try to match the remaining children
                var result = self._match_sequence(
                    ast_parent,
                    remaining_index,
                    str,
                    new_pos,
                    matches,
                    match_first_mode,
                    required_start_pos,
                )
                if result[0]:
                    return (True, result[1])
            match_count -= 1

        return (False, str_i)

    @always_inline
    fn _try_match_count(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        count: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Int:
        """Try to match exactly 'count' repetitions of the node. Returns characters consumed or -1.
        """
        var pos = str_i
        var matched = 0

        while matched < count and pos < len(str):
            # Conservative early termination for match_first_mode only in extreme cases
            if (
                match_first_mode
                and required_start_pos >= 0
                and pos > required_start_pos + 100
            ):
                return -1  # Moved too far from required start position

            if ast.is_match(String(str[pos]), pos, len(str)):
                matched += 1
                pos += 1
            else:
                return -1  # Failed to match required count

        if matched == count:
            return pos - str_i
        else:
            return -1

    fn _match_re(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        mut matches: List[Match, hint_trivial_type=True],
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match RE root node."""
        if not ast.has_children():
            return (True, str_i)

        return self._match_node(
            ast.get_child(0),
            str,
            str_i,
            matches,
            match_first_mode,
            required_start_pos,
        )

    fn _apply_quantifier(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        char_consumed: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Apply quantifier logic to a matched element."""
        var min_matches = ast.min
        var max_matches = ast.max

        if max_matches == -1:  # Unlimited
            max_matches = len(str) - str_i

        # If we have a simple single match (min=1, max=1)
        if min_matches == 1 and max_matches == 1:
            return (True, str_i + char_consumed)

        # Try SIMD optimization for quantified character classes
        from regex.ast import DIGIT, SPACE, RANGE

        if ast.is_simd_optimizable(min_matches, max_matches):
            var simd_result = self._apply_quantifier_simd(
                ast, str, str_i, min_matches, max_matches
            )
            # Always return SIMD result when SIMD optimization is used
            # Don't fall through to regular matching
            return simd_result

        # Use regular greedy matching, but with early termination for match_first_mode
        var matches_count = 0
        var current_pos = str_i

        # Try to match as many times as possible (greedy)
        while matches_count < max_matches and current_pos < len(str):
            # Early termination for match_first_mode: if we're getting too far from start
            if match_first_mode and required_start_pos >= 0:
                # Allow reasonable expansion but prevent excessive backtracking
                if current_pos > required_start_pos + 50:  # Conservative limit
                    break

            if ast.is_match(String(str[current_pos]), current_pos, len(str)):
                matches_count += 1
                current_pos += 1
            else:
                break

        # Check if we have enough matches
        if matches_count >= min_matches:
            return (True, current_pos)
        else:
            return (False, str_i)

    fn _apply_quantifier_simd(
        self,
        ast: ASTNode,
        str: String,
        str_i: Int,
        min_matches: Int,
        max_matches: Int,
    ) -> Tuple[Bool, Int]:
        """Apply quantifier using SIMD for faster bulk matching.

        Args:
            ast: The AST node (DIGIT, SPACE, or RANGE).
            str: Input string.
            str_i: Current position.
            min_matches: Minimum required matches.
            max_matches: Maximum allowed matches (-1 for unlimited).

        Returns:
            Tuple of (success, final_position).
        """
        from regex.ast import DIGIT, SPACE, RANGE

        # Use specialized matchers for better performance
        if ast.type == DIGIT:
            var digit_matcher = get_digit_matcher()
            return apply_quantifier_simd_generic(
                digit_matcher, str, str_i, min_matches, max_matches
            )
        elif ast.type == SPACE:
            var whitespace_matcher = get_whitespace_matcher()
            return apply_quantifier_simd_generic(
                whitespace_matcher, str, str_i, min_matches, max_matches
            )
        elif ast.type == RANGE and ast.get_value():
            var range_pattern = String(ast.get_value().value())

            # Check for common patterns that should use RangeBasedMatcher
            if range_pattern == "[a-zA-Z0-9]":
                var alnum_matcher = get_alnum_matcher()
                if ast.positive_logic:
                    return apply_quantifier_simd_generic(
                        alnum_matcher, str, str_i, min_matches, max_matches
                    )
                else:
                    # For negated alphanumeric, use custom logic
                    var pos = str_i
                    var match_count = 0
                    var actual_max = max_matches
                    if actual_max == -1:
                        actual_max = len(str) - str_i

                    while pos < len(str) and match_count < actual_max:
                        var ch_code = ord(str[pos])
                        if not alnum_matcher.contains(ch_code):  # Negated
                            match_count += 1
                            pos += 1
                        else:
                            break

                    if match_count >= min_matches:
                        return (True, pos)
                    else:
                        return (False, str_i)
            elif range_pattern == "[a-z]":
                # Use optimized path for simple lowercase range
                var pos = str_i
                var match_count = 0
                var actual_max = max_matches
                if actual_max == -1:
                    actual_max = len(str) - str_i

                while pos < len(str) and match_count < actual_max:
                    var ch_code = ord(str[pos])
                    var is_match = ch_code >= ord("a") and ch_code <= ord("z")
                    if is_match == ast.positive_logic:
                        match_count += 1
                        pos += 1
                    else:
                        break

                if match_count >= min_matches:
                    return (True, pos)
                else:
                    return (False, str_i)
            elif range_pattern == "[A-Z]":
                # Use optimized path for simple uppercase range
                var pos = str_i
                var match_count = 0
                var actual_max = max_matches
                if actual_max == -1:
                    actual_max = len(str) - str_i

                while pos < len(str) and match_count < actual_max:
                    var ch_code = ord(str[pos])
                    var is_match = ch_code >= ord("A") and ch_code <= ord("Z")
                    if is_match == ast.positive_logic:
                        match_count += 1
                        pos += 1
                    else:
                        break

                if match_count >= min_matches:
                    return (True, pos)
                else:
                    return (False, str_i)
            elif range_pattern == "[0-9]":
                # Use digit matcher for digit range
                var digit_matcher = get_digit_matcher()
                if ast.positive_logic:
                    return apply_quantifier_simd_generic(
                        digit_matcher, str, str_i, min_matches, max_matches
                    )
                else:
                    # For negated digits, use custom logic
                    var pos = str_i
                    var match_count = 0
                    var actual_max = max_matches
                    if actual_max == -1:
                        actual_max = len(str) - str_i

                    while pos < len(str) and match_count < actual_max:
                        var ch_code = ord(str[pos])
                        if not digit_matcher.contains(ch_code):  # Negated
                            match_count += 1
                            pos += 1
                        else:
                            break

                    if match_count >= min_matches:
                        return (True, pos)
                    else:
                        return (False, str_i)
            elif range_pattern == "[a-zA-Z]":
                # Use alpha matcher for alphabetic range
                var alpha_matcher = get_alpha_matcher()
                if ast.positive_logic:
                    return apply_quantifier_simd_generic(
                        alpha_matcher, str, str_i, min_matches, max_matches
                    )
                else:
                    # For negated alpha, use custom logic
                    var pos = str_i
                    var match_count = 0
                    var actual_max = max_matches
                    if actual_max == -1:
                        actual_max = len(str) - str_i

                    while pos < len(str) and match_count < actual_max:
                        var ch_code = ord(str[pos])
                        if not alpha_matcher.contains(ch_code):  # Negated
                            match_count += 1
                            pos += 1
                        else:
                            break

                    if match_count >= min_matches:
                        return (True, pos)
                    else:
                        return (False, str_i)
            else:
                # Check if it's a complex pattern with alphanumeric + special chars
                var is_complex_pattern = False
                if range_pattern.startswith("[") and range_pattern.endswith(
                    "]"
                ):
                    var inner = range_pattern[1:-1]
                    var has_lower = "a-z" in inner
                    var has_upper = "A-Z" in inner
                    var has_digits = "0-9" in inner
                    var has_alnum = has_lower and has_upper and has_digits
                    is_complex_pattern = (
                        has_alnum and len(inner) > COMPLEX_CHAR_CLASS_THRESHOLD
                    )

                if is_complex_pattern:
                    # Handle complex patterns like [a-zA-Z0-9._%+-] efficiently
                    var alnum_matcher = get_alnum_matcher()
                    var inner = range_pattern[1:-1]
                    var pos = str_i
                    var match_count = 0
                    var actual_max = max_matches
                    if actual_max == -1:
                        actual_max = len(str) - str_i

                    while pos < len(str) and match_count < actual_max:
                        var ch_code = ord(str[pos])
                        var is_match = False

                        # Check alphanumeric first (common case)
                        if alnum_matcher.contains(ch_code):
                            is_match = True
                        else:
                            # Check special characters
                            var ch = String(str[pos])
                            is_match = ch in inner

                        if is_match == ast.positive_logic:
                            match_count += 1
                            pos += 1
                        else:
                            break

                    if match_count >= min_matches:
                        return (True, pos)
                    else:
                        return (False, str_i)

                var range_matcher = self._create_range_matcher(range_pattern)
                if range_matcher:
                    var matcher = range_matcher.value()
                    # Handle negated logic
                    if ast.positive_logic:
                        return apply_quantifier_simd_generic(
                            matcher, str, str_i, min_matches, max_matches
                        )
                    else:
                        # For negated ranges, we need custom logic
                        var pos = str_i
                        var match_count = 0
                        var actual_max = max_matches
                        if actual_max == -1:
                            actual_max = len(str) - str_i

                        while pos < len(str) and match_count < actual_max:
                            var ch_code = ord(str[pos])
                            if not matcher.contains(ch_code):  # Negated
                                match_count += 1
                                pos += 1
                            else:
                                break

                        if match_count >= min_matches:
                            return (True, pos)
                        else:
                            return (False, str_i)

        return (False, str_i)


fn findall(
    pattern: String, text: String
) raises -> List[Match, hint_trivial_type=True]:
    """Find all matches of pattern in text (equivalent to re.findall in Python).

    Args:
        pattern: Regex pattern string.
        text: Text to search in.

    Returns:
        List of all matches found.
    """
    var engine = NFAEngine(pattern)
    return engine.match_all(text)


fn match_first(pattern: String, text: String) raises -> Optional[Match]:
    """Match pattern at beginning of text (equivalent to re.match in Python).

    Args:
        pattern: Regex pattern string.
        text: Text to match against.

    Returns:
        Optional Match if pattern matches at start of text.
    """
    var engine = NFAEngine(pattern)
    var result = engine.match_first(text, 0)

    # Python's re.match only succeeds if match starts at position 0
    if result and result.value().start_idx == 0:
        return result
    else:
        return None
