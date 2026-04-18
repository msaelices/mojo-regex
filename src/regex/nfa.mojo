from std.memory import UnsafePointer

from regex.ast import (
    ASTNode,
    DIGIT,
    WORD,
    SPACE,
    RANGE_KIND_LOWERCASE,
    RANGE_KIND_UPPERCASE,
    RANGE_KIND_DIGITS,
    RANGE_KIND_ALNUM,
    RANGE_KIND_ALPHA,
    RANGE_KIND_COMPLEX_ALNUM,
    RANGE_KIND_OTHER,
    COMPLEX_CHAR_CLASS_THRESHOLD,
)
from regex.aliases import (
    CHAR_A,
    CHAR_A_UPPER,
    CHAR_CR,
    CHAR_FF,
    CHAR_NEWLINE,
    CHAR_NINE,
    CHAR_SPACE,
    CHAR_TAB_CHAR,
    CHAR_UNDERSCORE,
    CHAR_Z,
    CHAR_Z_UPPER,
    CHAR_ZERO,
    ImmSlice,
    SIMD_MATCHER_DIGITS,
    SIMD_MATCHER_WHITESPACE,
    byte_in_string,
)
from regex.engine import Engine
from regex.matching import Match, MatchList
from regex.parser import parse
from regex.simd_ops import (
    twoway_search,
    CharacterClassSIMD,
    get_character_class_matcher,
    apply_quantifier_simd_generic,
    find_in_text_simd,
)
from regex.simd_matchers import (
    get_digit_matcher,
    get_whitespace_matcher,
    get_alpha_matcher,
    get_alnum_matcher,
    get_word_matcher,
    RangeBasedMatcher,
)
from regex.literal_optimizer import extract_literals, extract_literal_prefix
from regex.optimizer import PatternAnalyzer, PatternComplexity


# COMPLEX_CHAR_CLASS_THRESHOLD is now imported from regex.ast

# Minimum literal length thresholds for optimization.
# Even single-char prefixes (like '8' in '8(?:00|33)...') are valuable
# for skipping non-matching positions in long text.
comptime MIN_PREFIX_LITERAL_LENGTH = 1
# Non-prefix literals need longer length to justify the backward search overhead
comptime MIN_REQUIRED_LITERAL_LENGTH = 3


struct NFAEngine(Copyable, Engine):
    """A regex engine that can match regex patterns against text."""

    var pattern: String
    """The regex pattern string to match against."""
    var prev_re: String
    """Previously parsed regex pattern for caching."""
    var prev_ast: Optional[ASTNode[MutAnyOrigin]]
    """Cached AST from previous regex compilation."""
    var regex: Optional[ASTNode[MutAnyOrigin]]
    """Compiled AST representation of the current regex pattern."""
    var literal_prefix: String
    """Extracted literal prefix for optimization."""
    var has_literal_optimization: Bool
    """Whether literal optimization is available for this pattern."""
    var pattern_len: Int
    var ends_with_dotstar: Bool
    var starts_with_dotstar: Bool
    var is_prefix_literal: Bool

    def __init__(out self, pattern: String):
        """Initialize the regex engine."""
        self.prev_re = ""
        self.prev_ast = None
        self.pattern = pattern
        self.literal_prefix = ""
        self.has_literal_optimization = False
        self.pattern_len = len(pattern)
        self.ends_with_dotstar = False
        self.starts_with_dotstar = False
        self.is_prefix_literal = False

        try:
            self.regex = parse(pattern)

            if self.regex:
                ref ast = self.regex.value()
                var analyzer = PatternAnalyzer()
                var complexity = analyzer.classify(ast)

                var literal_set = extract_literals(ast)

                ref best_literal = literal_set.get_best_literal()
                if best_literal:
                    ref best = best_literal.value()
                    if (
                        best.is_prefix
                        and best.is_required
                        and best.get_literal_len(literal_set)
                        >= MIN_PREFIX_LITERAL_LENGTH
                    ):
                        self.literal_prefix = best.get_literal(literal_set)
                        self.has_literal_optimization = True
                    elif (
                        best.is_required
                        and best.get_literal_len(literal_set)
                        >= MIN_REQUIRED_LITERAL_LENGTH
                    ):
                        self.literal_prefix = best.get_literal(literal_set)
                        self.has_literal_optimization = True
        except:
            self.regex = None

        self.ends_with_dotstar = pattern.endswith(
            ".*"
        ) and not pattern.endswith("\\.*")
        var _swd = False
        if pattern.startswith(".*"):
            _swd = True
            if self.pattern_len > 2:
                var third = pattern[byte=2]
                if third == "?" or third == "*" or third == "+":
                    _swd = False
        self.starts_with_dotstar = _swd
        self.is_prefix_literal = len(
            self.literal_prefix
        ) > 0 and pattern.startswith(self.literal_prefix)

    @always_inline
    def get_pattern(self) -> String:
        """Returns the pattern string (Engine trait requirement).

        Returns:
            The pattern string.
        """
        if self.has_literal_optimization:
            return self.literal_prefix
        return self.pattern

    @always_inline
    def _get_search_literal_bytes(
        self,
    ) -> Span[Byte, ImmutAnyOrigin]:
        """Returns a zero-copy byte view of the literal used for prefiltering.
        Avoids the String copy that get_pattern() would produce.
        """
        if self.has_literal_optimization:
            return rebind[Span[Byte, ImmutAnyOrigin]](
                self.literal_prefix.as_bytes()
            )
        return rebind[Span[Byte, ImmutAnyOrigin]](self.pattern.as_bytes())

    def match_all(
        self,
        text: ImmSlice,
    ) -> MatchList:
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
        # Pre-allocate for long-text findall. Skip the hint on short texts
        # where over-allocating wastes more than the grows cost.
        var text_len = len(text)
        var matches = MatchList(
            capacity=text_len >> 7 if text_len >= 1024 else 0
        )
        if not self.prev_ast and not self.regex:
            return matches^
        ref ast = self.prev_ast.value() if self.prev_ast else self.regex.value()

        # Use smart MatchList container with lazy allocation
        var current_pos = 0

        # Smaller temp capacity since we clear frequently
        var temp_matches = List[Match](capacity=3)

        # Fast path for .* prefix patterns in findall.
        # Only safe when no newlines in text (since .* doesn't match \n).
        if (
            self.starts_with_dotstar
            and self.has_literal_optimization
            and text.find("\n") == -1
        ):
            var last_pos = self._find_last_literal(text, current_pos)
            if last_pos >= 0:
                matches.append(
                    Match(
                        0,
                        current_pos,
                        last_pos + len(self.literal_prefix),
                        text,
                    )
                )
            return matches^

        # Fast path for LITERAL.* suffix patterns in findall.
        # Find the first literal, then match extends to end of text.
        if (
            self.ends_with_dotstar
            and self.has_literal_optimization
            and self.is_prefix_literal
            and text.find("\n") == -1
        ):
            var literal_bytes = self.literal_prefix.as_bytes()
            var search = current_pos
            while search < len(text):
                var pos = twoway_search(literal_bytes, text, search)
                if pos == -1:
                    break
                matches.append(Match(0, pos, len(text), text))
                # Only one match since .* consumes everything to end
                break
            return matches^

        # Use literal prefiltering if available
        if self.has_literal_optimization:
            while current_pos <= len(text):
                # Find next occurrence of literal
                var literal_pos = twoway_search(
                    self._get_search_literal_bytes(),
                    text,
                    current_pos,
                )
                if literal_pos == -1:
                    # No more occurrences of required literal
                    break

                # Skip literals that would create overlapping matches
                if literal_pos < current_pos:
                    current_pos = literal_pos + 1
                    continue

                # Try to match the full pattern starting from before the literal
                var try_pos = literal_pos
                var search_window = (
                    10  # Reduced from 100 to 10 for better performance
                )
                if self.literal_prefix and not self.is_prefix_literal:
                    try_pos = max(current_pos, literal_pos - search_window)

                # Search for matches around the literal with limited iterations
                var found_match = False
                var max_search_positions = min(5, literal_pos - try_pos + 1)
                var search_count = 0

                while (
                    try_pos <= literal_pos
                    and try_pos <= len(text)
                    and search_count < max_search_positions
                ):
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
                        ref match_end = result[1]
                        if self._match_contains_literal(
                            text, try_pos, match_end
                        ):
                            matches.append(Match(0, try_pos, match_end, text))

                            # Move past this match to avoid overlapping matches
                            if match_end == try_pos:
                                current_pos = try_pos + 1
                            else:
                                current_pos = match_end
                            found_match = True
                            break
                    try_pos += 1
                    search_count += 1

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
                    ref match_end = result[1]

                    matches.append(Match(0, match_start, match_end, text))

                    # Move past this match to find next one
                    # Avoid infinite loop on zero-width matches
                    if match_end == match_start:
                        current_pos += 1
                    else:
                        current_pos = match_end
                else:
                    current_pos += 1

        return matches^

    def match_first(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
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
        var matches = List[Match]()
        var str_i = start
        if not self.regex:
            try:
                var ast = parse(self.pattern)
                var result = self._match_node(
                    ast,
                    text,
                    str_i,
                    matches,
                    match_first_mode=True,
                    required_start_pos=start,
                )
                if result[0]:
                    return Match(0, str_i, result[1], text)
            except:
                pass
            return None

        ref ast = self.regex.value()
        var result = self._match_node(
            ast,
            text,
            str_i,
            matches,
            match_first_mode=True,
            required_start_pos=start,
        )
        if result[0]:
            return Match(0, str_i, result[1], text)
        return None

    @always_inline
    def match_next(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
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
        var matches = List[Match]()
        if not self.regex:
            return None

        ref ast = self.regex.value()
        var search_pos = start

        # Fast path: .* prefix with literal suffix. Only safe without newlines.
        if (
            self.starts_with_dotstar
            and self.has_literal_optimization
            and text.find("\n") == -1
        ):
            var last_pos = self._find_last_literal(text, start)
            if last_pos >= 0:
                return Match(
                    0, start, last_pos + len(self.literal_prefix), text
                )
            return None

        # Fast path: LITERAL.* suffix. Find first literal, match to end.
        if (
            self.ends_with_dotstar
            and self.has_literal_optimization
            and self.is_prefix_literal
            and text.find("\n") == -1
        ):
            var literal_bytes = self.literal_prefix.as_bytes()
            var pos = twoway_search(literal_bytes, text, start)
            if pos >= 0:
                return Match(0, pos, len(text), text)
            return None

        # Use literal prefiltering if available
        if self.has_literal_optimization:
            while search_pos <= len(text):
                # Find next occurrence of literal
                var literal_pos = twoway_search(
                    self._get_search_literal_bytes(),
                    text,
                    search_pos,
                )
                if literal_pos == -1:
                    return None

                var try_pos = literal_pos
                if self.literal_prefix and not self.is_prefix_literal:
                    try_pos = max(0, literal_pos - self.pattern_len)

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
                        ref match_end = result[1]
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
                    ref end_idx = result[1]
                    return Match(0, search_pos, end_idx, text)
                search_pos += 1

        return None

    def match_next_with_groups(
        self, text: ImmSlice, start: Int = 0
    ) -> Tuple[Optional[Match], List[Match]]:
        """Like match_next but also returns capture group matches.

        Uses literal prefiltering when available to skip non-matching
        positions, then runs _match_node to extract group captures.

        Returns:
            Tuple of (overall_match, group_matches). group_matches contains
            Match objects with group_id set to the 1-based capture group index.
        """
        var empty_groups = List[Match]()
        if not self.prev_ast and not self.regex:
            return (None, empty_groups^)
        ref ast = self.prev_ast.value() if self.prev_ast else self.regex.value()

        var search_pos = start
        var matches = List[Match](capacity=8)

        # Use literal prefiltering to skip positions when available
        if self.has_literal_optimization:
            while search_pos <= len(text):
                var literal_pos = twoway_search(
                    self._get_search_literal_bytes(),
                    text,
                    search_pos,
                )
                if literal_pos == -1:
                    return (None, empty_groups^)

                var try_pos = literal_pos
                if self.literal_prefix and not self.is_prefix_literal:
                    try_pos = max(0, literal_pos - self.pattern_len)

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
                    if result[0]:
                        ref match_end = result[1]
                        if self._match_contains_literal(
                            text, try_pos, match_end
                        ):
                            return (
                                Match(0, try_pos, match_end, text),
                                matches^,
                            )
                    try_pos += 1

                search_pos = literal_pos + 1
        else:
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
                if result[0]:
                    return (Match(0, search_pos, result[1], text), matches^)
                search_pos += 1

        return (None, empty_groups^)

    @always_inline
    def _find_last_literal(self, text: ImmSlice, start: Int) -> Int:
        """Find the last occurrence of the literal prefix in text from start."""
        # Use rfind for O(n) reverse search instead of repeated forward search
        var pos = text.rfind(self.literal_prefix)
        if pos >= start:
            return pos
        return -1

    def _create_range_matcher(
        self, range_pattern: StringSlice
    ) -> Optional[CharacterClassSIMD]:
        """Create SIMD matcher for a range pattern.

        Args:
            range_pattern: The range pattern string (e.g., "[a-z]" or "abcdefg...").

        Returns:
            Optional SIMD matcher for the pattern.
        """
        # Try to create a SIMD matcher for common patterns

        # Expand the range pattern if needed
        if range_pattern.startswith("[") and range_pattern.endswith("]"):
            # It's a pattern like "[a-z]", need to expand it
            var inner = range_pattern[byte=1:-1]

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

                # Complex patterns not supported by SIMD path
                return None
        else:
            # Already expanded - pass directly as StringSlice, no allocation
            return get_character_class_matcher(range_pattern)

    @always_inline
    def _match_contains_literal(
        self, text: ImmSlice, start: Int, end: Int
    ) -> Bool:
        """Verify that a match contains the required literal."""
        if not self.has_literal_optimization or len(self.literal_prefix) == 0:
            return True

        # Use twoway_search (already imported) with bounded range
        var pos = twoway_search(self.literal_prefix.as_bytes(), text, start)
        return pos != -1 and pos + len(self.literal_prefix) <= end

    @always_inline
    def _match_node(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        mut matches: List[Match],
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
            WORD,
            RANGE,
            START,
            END,
            OR,
            GROUP,
        )

        # DEBUG: Uncomment to debug
        # print("DEBUG: _match_node type =", ast.type, "str_i =", str_i, "min =", ast.min, "max =", ast.max)

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
        elif ast.type == WORD:
            return self._match_word(
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
    def _match_element(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match a literal character element."""
        if str_i >= len(str):
            return (False, str_i)

        var str_ptr = str.unsafe_ptr()
        var ch_code = Int(str_ptr[str_i])
        if (
            ast.get_value()
            and Int(ast.get_value().value().unsafe_ptr()[0]) == ch_code
        ):
            return self._apply_quantifier(
                ast, str, str_i, 1, match_first_mode, required_start_pos
            )
        else:
            return (False, str_i)

    @always_inline
    def _match_wildcard(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match wildcard (.) - any character except newline."""
        if str_i >= len(str):
            return (False, str_i)

        var str_ptr = str.unsafe_ptr()
        var ch_code = Int(str_ptr[str_i])
        if ch_code != CHAR_NEWLINE:  # Exclude newline
            return self._apply_quantifier(
                ast, str, str_i, 1, match_first_mode, required_start_pos
            )
        else:
            return (False, str_i)

    @always_inline
    def _match_space(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match whitespace character (\\s)."""
        if str_i >= len(str):
            return (False, str_i)

        # Inline range check avoids a per-character Dict lookup through
        # `get_whitespace_matcher()` (see ast.is_match_char for reference).
        var str_ptr = str.unsafe_ptr()
        var ch_code = Int(str_ptr[str_i])
        if (
            ch_code == CHAR_SPACE
            or ch_code == CHAR_TAB_CHAR
            or ch_code == CHAR_NEWLINE
            or ch_code == CHAR_CR
            or ch_code == CHAR_FF
        ):
            return self._apply_quantifier(
                ast, str, str_i, 1, match_first_mode, required_start_pos
            )
        else:
            return (False, str_i)

    @always_inline
    def _match_digit(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match digit character (\\d)."""
        if str_i >= len(str):
            # End of string - check if quantifier allows zero matches
            if (
                ast.min == 0
            ):  # Only allow zero matches if min quantifier is 0 (*, ?)
                return self._apply_quantifier(
                    ast, str, str_i, 0, match_first_mode, required_start_pos
                )
            else:
                return (False, str_i)

        # Inline range check avoids a per-character Dict lookup through
        # `get_digit_matcher()` (see ast.is_match_char for reference).
        var str_ptr = str.unsafe_ptr()
        var ch_code = Int(str_ptr[str_i])
        if CHAR_ZERO <= ch_code <= CHAR_NINE:
            return self._apply_quantifier(
                ast, str, str_i, 1, match_first_mode, required_start_pos
            )
        else:
            # Character doesn't match - check if quantifier allows zero matches
            if (
                ast.min == 0
            ):  # Only allow zero matches if min quantifier is 0 (*, ?)
                return self._apply_quantifier(
                    ast, str, str_i, 0, match_first_mode, required_start_pos
                )
            else:
                return (False, str_i)

    @always_inline
    def _match_word(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match word character (\\w)."""
        if str_i >= len(str):
            # End of string - check if quantifier allows zero matches
            if (
                ast.min == 0
            ):  # Only allow zero matches if min quantifier is 0 (*, ?)
                return self._apply_quantifier(
                    ast, str, str_i, 0, match_first_mode, required_start_pos
                )
            else:
                return (False, str_i)

        # Inline range check avoids a per-character Dict lookup through
        # `get_word_matcher()` (see ast.is_match_char for reference).
        var str_ptr = str.unsafe_ptr()
        var ch_code = Int(str_ptr[str_i])
        if (
            (CHAR_A <= ch_code <= CHAR_Z)
            or (CHAR_A_UPPER <= ch_code <= CHAR_Z_UPPER)
            or (CHAR_ZERO <= ch_code <= CHAR_NINE)
            or ch_code == CHAR_UNDERSCORE
        ):
            return self._apply_quantifier(
                ast, str, str_i, 1, match_first_mode, required_start_pos
            )
        else:
            # Character doesn't match - check if quantifier allows zero matches
            if (
                ast.min == 0
            ):  # Only allow zero matches if min quantifier is 0 (*, ?)
                return self._apply_quantifier(
                    ast, str, str_i, 0, match_first_mode, required_start_pos
                )
            else:
                return (False, str_i)

    @always_inline
    def _match_range(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match character range [abc] or [^abc]."""
        if str_i >= len(str):
            return (False, str_i)

        var str_ptr = str.unsafe_ptr()
        var ch_code = Int(str_ptr[str_i])
        var ch_found = False

        var kind = ast.range_kind
        if kind == RANGE_KIND_ALNUM:
            ch_found = (
                (CHAR_A <= ch_code <= CHAR_Z)
                or (CHAR_A_UPPER <= ch_code <= CHAR_Z_UPPER)
                or (CHAR_ZERO <= ch_code <= CHAR_NINE)
            )
        elif kind == RANGE_KIND_LOWERCASE:
            ch_found = CHAR_A <= ch_code <= CHAR_Z
        elif kind == RANGE_KIND_UPPERCASE:
            ch_found = CHAR_A_UPPER <= ch_code <= CHAR_Z_UPPER
        elif kind == RANGE_KIND_DIGITS:
            ch_found = CHAR_ZERO <= ch_code <= CHAR_NINE
        elif kind == RANGE_KIND_ALPHA:
            ch_found = (CHAR_A <= ch_code <= CHAR_Z) or (
                CHAR_A_UPPER <= ch_code <= CHAR_Z_UPPER
            )
        elif kind == RANGE_KIND_COMPLEX_ALNUM:
            # Check alphanumeric first (common case), then special chars
            if (
                (CHAR_A <= ch_code <= CHAR_Z)
                or (CHAR_A_UPPER <= ch_code <= CHAR_Z_UPPER)
                or (CHAR_ZERO <= ch_code <= CHAR_NINE)
            ):
                ch_found = True
            else:
                var opt = ast.get_value()
                if opt:
                    ref range_pattern = opt.value()
                    var inner = range_pattern[byte=1:-1]
                    ch_found = byte_in_string(ch_code, inner)
        else:
            # RANGE_KIND_OTHER: use direct byte-level range matching.
            # _create_range_matcher returns None for all bracket patterns,
            # so skip the indirection and go straight to the AST fallback.
            var opt = ast.get_value()
            if opt:
                ref range_pattern = opt.value()
                ch_found = ast._is_char_in_range_by_code(ch_code, range_pattern)

        if ch_found == ast.positive_logic:
            return self._apply_quantifier(
                ast, str, str_i, 1, match_first_mode, required_start_pos
            )
        else:
            return (False, str_i)

    @always_inline
    def _match_start(
        self, ast: ASTNode, str_i: Int
    ) capturing -> Tuple[Bool, Int]:
        """Match start anchor (^)."""
        if str_i == 0:
            return (True, str_i)
        else:
            return (False, str_i)

    @always_inline
    def _match_end(
        self, ast: ASTNode, str: ImmSlice, str_i: Int
    ) capturing -> Tuple[Bool, Int]:
        """Match end anchor ($)."""
        if str_i == len(str):
            return (True, str_i)
        else:
            return (False, str_i)

    def _match_or(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        mut matches: List[Match],
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

    def _match_group(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        mut matches: List[Match],
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match GROUP node - process children sequentially with backtracking.
        """
        var start_pos = str_i
        # DEBUG: Uncomment to debug
        # print("DEBUG: _match_group children_len =", ast.get_children_len())

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

        # If this is a capturing group, add the match with its group ID
        if ast.is_capturing():
            var gid = ast.group_id if ast.group_id >= 0 else 0
            matches.append(Match(gid, start_pos, result[1], str))

        return result

    def _match_group_with_quantifier(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        mut matches: List[Match],
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
                    var gid = ast.group_id if ast.group_id >= 0 else 0
                    matches.append(Match(gid, str_i, current_pos, str))
            else:
                break

        # Check if we have enough matches
        if group_matches >= min_matches:
            return (True, current_pos)
        else:
            return (False, str_i)

    def _match_sequence(
        self,
        ast_parent: ASTNode,
        child_index: Int,
        str: ImmSlice,
        str_i: Int,
        mut matches: List[Match],
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match a sequence of AST nodes with backtracking support."""
        var children_len = ast_parent.get_children_len()
        # DEBUG: Uncomment to debug
        # print("DEBUG: _match_sequence child_index =", child_index, "children_len =", children_len)
        if child_index >= children_len:
            # print("DEBUG: No more children, returning success at pos", str_i)
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
    def _has_quantifier(self, ast: ASTNode) capturing -> Bool:
        """Check if node has quantifier (min != 1 or max != 1)."""
        return ast.min != 1 or ast.max != 1

    @always_inline
    def _match_with_backtracking(
        self,
        quantified_node: ASTNode,
        ast_parent: ASTNode,
        remaining_index: Int,
        str: ImmSlice,
        str_i: Int,
        mut matches: List[Match],
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Match a quantified node followed by other nodes, with backtracking.
        """
        var min_matches = quantified_node.min
        var max_matches = quantified_node.max

        if max_matches == -1:
            max_matches = len(str) - str_i

        # Fast path for fixed quantifiers like {3} where min == max
        if min_matches == max_matches:
            var consumed = self._try_match_count(
                quantified_node,
                str,
                str_i,
                min_matches,
                match_first_mode,
                required_start_pos,
            )
            if consumed >= 0:
                var result = self._match_sequence(
                    ast_parent,
                    remaining_index,
                    str,
                    str_i + consumed,
                    matches,
                    match_first_mode,
                    required_start_pos,
                )
                if result[0]:
                    return (True, result[1])
            return (False, str_i)

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
    def _try_match_count(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        count: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Int:
        """Try to match exactly 'count' repetitions of the node. Returns characters consumed or -1.
        """
        var pos = str_i
        var matched = 0
        var str_ptr = str.unsafe_ptr()
        var str_len = len(str)

        while matched < count and pos < str_len:
            # Conservative early termination for match_first_mode only in extreme cases
            if (
                match_first_mode
                and required_start_pos >= 0
                and pos > required_start_pos + 100
            ):
                return -1  # Moved too far from required start position

            if ast.is_match_char(Int(str_ptr[pos]), pos, str_len):
                matched += 1
                pos += 1
            else:
                return -1  # Failed to match required count

        if matched == count:
            return pos - str_i
        else:
            return -1

    def _match_re(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        mut matches: List[Match],
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

    def _apply_quantifier(
        self,
        ast: ASTNode,
        str: ImmSlice,
        str_i: Int,
        char_consumed: Int,
        match_first_mode: Bool,
        required_start_pos: Int,
    ) capturing -> Tuple[Bool, Int]:
        """Apply quantifier logic to a matched element."""
        var min_matches = ast.min
        var max_matches = ast.max

        # DEBUG: Uncomment to debug
        # print("DEBUG: _apply_quantifier str_i =", str_i, "min =", min_matches, "max =", max_matches)

        if max_matches == -1:  # Unlimited
            max_matches = len(str) - str_i

        # If we have a simple single match (min=1, max=1)
        if min_matches == 1 and max_matches == 1:
            return (True, str_i + char_consumed)

        # Try SIMD optimization for quantified character classes
        from regex.ast import DIGIT, SPACE, RANGE

        if ast.is_simd_optimizable(min_matches, max_matches):
            # DEBUG: Uncomment to debug
            # print("DEBUG: Using SIMD optimization for quantifier")
            var simd_result = self._apply_quantifier_simd(
                ast, str, str_i, min_matches, max_matches
            )
            # Always return SIMD result when SIMD optimization is used
            # Don't fall through to regular matching
            # DEBUG: Uncomment to debug
            # print("DEBUG: SIMD result =", simd_result[0], simd_result[1])
            return simd_result

        # Use regular greedy matching, but with early termination for match_first_mode
        var matches_count = 0
        var current_pos = str_i
        var str_ptr = str.unsafe_ptr()
        var str_len = len(str)

        # Try to match as many times as possible (greedy)
        while matches_count < max_matches and current_pos < str_len:
            # Early termination for match_first_mode: if we're getting too far from start
            if match_first_mode and required_start_pos >= 0:
                # Allow reasonable expansion but prevent excessive backtracking
                if current_pos > required_start_pos + 50:  # Conservative limit
                    break

            if ast.is_match_char(
                Int(str_ptr[current_pos]), current_pos, str_len
            ):
                matches_count += 1
                current_pos += 1
            else:
                break

        # Check if we have enough matches
        # DEBUG: Uncomment to debug
        # print("DEBUG: quantifier matches_count =", matches_count, "min_matches =", min_matches, "current_pos =", current_pos)
        if matches_count >= min_matches:
            return (True, current_pos)
        else:
            return (False, str_i)

    @always_inline
    def _apply_quantifier_simd(
        self,
        ast: ASTNode,
        str: ImmSlice,
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
        from regex.ast import DIGIT, SPACE, WORD, RANGE

        var str_ptr = str.unsafe_ptr()

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
        elif ast.type == WORD:
            var word_matcher = get_word_matcher()
            return apply_quantifier_simd_generic(
                word_matcher, str, str_i, min_matches, max_matches
            )
        elif ast.type == RANGE and ast.get_value():
            ref range_pattern = ast.get_value().value()

            # Switch on precomputed range_kind tag instead of per-invocation
            # string comparisons. Classification done at AST build time.
            var kind = ast.range_kind
            if kind == RANGE_KIND_ALNUM:
                var alnum_matcher = get_alnum_matcher()
                if ast.positive_logic:
                    return apply_quantifier_simd_generic(
                        alnum_matcher, str, str_i, min_matches, max_matches
                    )
                else:
                    return self._quantifier_negated_loop(
                        alnum_matcher,
                        str_ptr,
                        str,
                        str_i,
                        min_matches,
                        max_matches,
                    )
            elif kind == RANGE_KIND_LOWERCASE:
                return self._quantifier_range_loop(
                    CHAR_A,
                    CHAR_Z,
                    ast.positive_logic,
                    str_ptr,
                    str,
                    str_i,
                    min_matches,
                    max_matches,
                )
            elif kind == RANGE_KIND_UPPERCASE:
                return self._quantifier_range_loop(
                    CHAR_A_UPPER,
                    CHAR_Z_UPPER,
                    ast.positive_logic,
                    str_ptr,
                    str,
                    str_i,
                    min_matches,
                    max_matches,
                )
            elif kind == RANGE_KIND_DIGITS:
                var digit_matcher = get_digit_matcher()
                if ast.positive_logic:
                    return apply_quantifier_simd_generic(
                        digit_matcher, str, str_i, min_matches, max_matches
                    )
                else:
                    return self._quantifier_negated_loop(
                        digit_matcher,
                        str_ptr,
                        str,
                        str_i,
                        min_matches,
                        max_matches,
                    )
            elif kind == RANGE_KIND_ALPHA:
                var alpha_matcher = get_alpha_matcher()
                if ast.positive_logic:
                    return apply_quantifier_simd_generic(
                        alpha_matcher, str, str_i, min_matches, max_matches
                    )
                else:
                    return self._quantifier_negated_loop(
                        alpha_matcher,
                        str_ptr,
                        str,
                        str_i,
                        min_matches,
                        max_matches,
                    )
            elif kind == RANGE_KIND_COMPLEX_ALNUM:
                var inner = range_pattern[byte=1:-1]
                var pos = str_i
                var match_count = 0
                var actual_max = max_matches
                if actual_max == -1:
                    actual_max = len(str) - str_i

                while pos < len(str) and match_count < actual_max:
                    var ch_code = Int(str_ptr[pos])
                    var is_match: Bool
                    if (
                        (CHAR_A <= ch_code <= CHAR_Z)
                        or (CHAR_A_UPPER <= ch_code <= CHAR_Z_UPPER)
                        or (CHAR_ZERO <= ch_code <= CHAR_NINE)
                    ):
                        is_match = True
                    else:
                        is_match = byte_in_string(ch_code, inner)

                    if is_match == ast.positive_logic:
                        match_count += 1
                        pos += 1
                    else:
                        break

                if match_count >= min_matches:
                    return (True, pos)
                else:
                    return (False, str_i)
            else:
                # RANGE_KIND_OTHER: try SIMD matcher, then general fallback
                var range_matcher = self._create_range_matcher(range_pattern)
                if range_matcher:
                    ref matcher = range_matcher.value()
                    if ast.positive_logic:
                        return apply_quantifier_simd_generic(
                            matcher, str, str_i, min_matches, max_matches
                        )
                    else:
                        # CharacterClassSIMD negated loop (can't use
                        # _quantifier_negated_loop which takes RangeBasedMatcher)
                        var pos = str_i
                        var match_count = 0
                        var actual_max = max_matches
                        if actual_max == -1:
                            actual_max = len(str) - str_i
                        while pos < len(str) and match_count < actual_max:
                            var ch_code = Int(str_ptr[pos])
                            if not matcher.contains(ch_code):
                                match_count += 1
                                pos += 1
                            else:
                                break
                        if match_count >= min_matches:
                            return (True, pos)
                        else:
                            return (False, str_i)

                # Scalar fallback for ranges without SIMD matchers
                var pos = str_i
                var match_count = 0
                var actual_max = max_matches
                if actual_max == -1:
                    actual_max = len(str) - str_i

                while pos < len(str) and match_count < actual_max:
                    var ch_code = Int(str_ptr[pos])
                    var is_match = self._match_char_in_range(
                        range_pattern, ch_code
                    )
                    if is_match == ast.positive_logic:
                        match_count += 1
                        pos += 1
                    else:
                        break

                if match_count >= min_matches:
                    return (True, pos)
                else:
                    return (False, str_i)

        return (False, str_i)

    @always_inline
    def _match_char_in_range[
        O: Origin
    ](self, range_pattern: StringSlice[O], ch_code: Int) -> Bool:
        """Helper function to check if a character matches a range pattern."""
        if range_pattern.startswith("[") and range_pattern.endswith("]"):
            var inner = range_pattern[byte=1:-1]

            # Handle simple ranges like [c-n]
            if len(inner) == 3 and inner[byte=1] == "-":
                var inner_ptr = inner.unsafe_ptr()
                var start_char = Int(inner_ptr[0])
                var end_char = Int(inner_ptr[2])
                return ch_code >= start_char and ch_code <= end_char

            # Direct byte scan instead of chr() + string `in`
            return byte_in_string(ch_code, inner)
        else:
            return byte_in_string(ch_code, range_pattern)

    @always_inline
    def _quantifier_negated_loop(
        self,
        matcher: RangeBasedMatcher,
        str_ptr: UnsafePointer[Byte, ImmutAnyOrigin],
        str: ImmSlice,
        str_i: Int,
        min_matches: Int,
        max_matches: Int,
    ) -> Tuple[Bool, Int]:
        """Run a quantifier loop for negated character classes."""
        var pos = str_i
        var match_count = 0
        var actual_max = max_matches
        if actual_max == -1:
            actual_max = len(str) - str_i
        while pos < len(str) and match_count < actual_max:
            var ch_code = Int(str_ptr[pos])
            if not matcher.contains(ch_code):
                match_count += 1
                pos += 1
            else:
                break
        if match_count >= min_matches:
            return (True, pos)
        return (False, str_i)

    @always_inline
    def _quantifier_range_loop(
        self,
        range_start: Int,
        range_end: Int,
        positive_logic: Bool,
        str_ptr: UnsafePointer[Byte, ImmutAnyOrigin],
        str: ImmSlice,
        str_i: Int,
        min_matches: Int,
        max_matches: Int,
    ) -> Tuple[Bool, Int]:
        """Run a quantifier loop for a single contiguous range."""
        var pos = str_i
        var match_count = 0
        var actual_max = max_matches
        if actual_max == -1:
            actual_max = len(str) - str_i
        while pos < len(str) and match_count < actual_max:
            var ch_code = Int(str_ptr[pos])
            var is_match = range_start <= ch_code <= range_end
            if is_match == positive_logic:
                match_count += 1
                pos += 1
            else:
                break
        if match_count >= min_matches:
            return (True, pos)
        return (False, str_i)


def findall(pattern: String, text: ImmSlice) raises -> MatchList:
    """Find all matches of pattern in text (equivalent to re.findall in Python).

    Args:
        pattern: Regex pattern string.
        text: Text to search in.

    Returns:
        MatchList container with all matches found.
    """
    var engine = NFAEngine(pattern)
    return engine.match_all(text)


def match_first(pattern: String, text: ImmSlice) raises -> Optional[Match]:
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
    if result:
        ref m = result.value()
        if m.start_idx == 0:
            return result
    return None
