from memory import UnsafePointer

from regex.ast import ASTNode, RANGE, DIGIT, SPACE
from regex.aliases import CHAR_ZERO, CHAR_NINE, CHAR_NEWLINE
from regex.engine import Engine
from regex.matching import Match
from regex.parser import parse
from regex.simd_ops import (
    CharacterClassSIMD,
    create_whitespace,
    create_ascii_digits,
    SIMD_WIDTH,
)


fn _create_simd_matcher_from_range_pattern(
    range_pattern: StringSlice,
) -> CharacterClassSIMD:
    """Create SIMD matcher from range pattern like '[a-z]' or 'abcxyz'.

    Args:
        range_pattern: Pattern that may contain range syntax like 'a-z' or explicit chars.

    Returns:
        A CharacterClassSIMD matcher configured for the pattern.
    """
    # If pattern starts with '[', it contains range syntax
    if range_pattern.startswith("[") and range_pattern.endswith("]"):
        # Remove brackets
        var inner = range_pattern[1:-1]

        # Check for negation and strip it
        # The negation is handled by the AST node's positive_logic field
        var actual_pattern = inner
        if len(inner) > 0 and inner[0] == "^":
            actual_pattern = inner[1:]

        # Check if it's a simple range like 'a-z'
        if len(actual_pattern) == 3 and actual_pattern[1] == "-":
            # It's a range, use the range constructor
            var start_char = actual_pattern[0:1]
            var end_char = actual_pattern[2:3]
            return CharacterClassSIMD(start_char, end_char)
        else:
            # It's a character set like 'abc' or complex pattern
            # For now, just use the full actual pattern (without ^)
            # TODO: Handle complex patterns like 'a-zA-Z0-9'
            return CharacterClassSIMD(actual_pattern)
    else:
        # It's already an expanded character set
        return CharacterClassSIMD(range_pattern)


struct NFAEngine(Engine):
    """A regex engine that can match regex patterns against text."""

    var pattern: String
    var prev_re: String
    var prev_ast: Optional[ASTNode[MutableAnyOrigin]]
    var regex: Optional[ASTNode[MutableAnyOrigin]]

    fn __init__(out self, pattern: String):
        """Initialize the regex engine."""
        self.prev_re = ""
        self.prev_ast = None
        self.pattern = pattern
        try:
            self.regex = parse(pattern)
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
        var str_i = start
        var ast: ASTNode[MutableAnyOrigin]
        if self.regex:
            ast = self.regex.value()
        else:
            try:
                ast = parse(self.pattern)
            except:
                return None

        var result = self._match_node(
            ast,
            text,
            str_i,
            matches,
            match_first_mode=False,
            required_start_pos=-1,
        )
        if result[0]:  # Match found
            var end_idx = result[1]
            # Always return the overall match with correct range
            return Match(0, str_i, end_idx, text)

        return None

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
        """Match whitespace character (\\s) with SIMD optimization."""
        if str_i >= len(str):
            return (False, str_i)

        var ch = String(str[str_i])
        var is_space: Bool

        # Use cached SIMD matcher if available
        if ast.simd_matcher:
            var simd_matcher = ast.simd_matcher.value()
            is_space = simd_matcher.contains(ord(ch))
        else:
            # Fallback to traditional comparison
            is_space = (
                ch == " "
                or ch == "\t"
                or ch == "\n"
                or ch == "\r"
                or ch == "\f"
            )

        if is_space:
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
        """Match digit character (\\d) with SIMD optimization."""
        if str_i >= len(str):
            return (False, str_i)

        var ch = String(str[str_i])
        var is_digit: Bool

        # Use cached SIMD matcher if available
        if ast.simd_matcher:
            var simd_matcher = ast.simd_matcher.value()
            is_digit = simd_matcher.contains(ord(ch))
        else:
            # Fallback to traditional comparison
            is_digit = CHAR_ZERO <= ord(ch) <= CHAR_NINE

        if is_digit:
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
        """Match character range [abc] or [^abc] with SIMD optimization."""
        if str_i >= len(str):
            return (False, str_i)

        var ch = String(str[str_i])
        var match_found: Bool

        # Use cached SIMD matcher if available, otherwise create one
        if ast.simd_matcher:
            var simd_matcher = ast.simd_matcher.value()
            var simd_match = simd_matcher.contains(ord(ch))
            match_found = simd_match if ast.positive_logic else not simd_match
        elif ast.enable_simd and ast.get_value():
            var range_pattern = ast.get_value().value()
            var simd_matcher = _create_simd_matcher_from_range_pattern(
                range_pattern
            )
            var simd_match = simd_matcher.contains(ord(ch))
            match_found = simd_match if ast.positive_logic else not simd_match
        else:
            # Fallback to linear search
            var ch_found = False
            if ast.get_value():
                var range_pattern = ast.get_value().value()
                ch_found = ast._is_char_in_range(ch, range_pattern)
            match_found = ch_found == ast.positive_logic

        if match_found:
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

        # Calculate the maximum search length
        var search_len = min(max_matches, len(str) - str_i)
        if match_first_mode and required_start_pos >= 0:
            search_len = min(search_len, required_start_pos + 50 - str_i)

        # Use SIMD bulk matching when we have cached matchers and enough data
        if ast.simd_matcher and search_len >= SIMD_WIDTH:
            var simd_matcher = ast.simd_matcher.value()

            # For RANGE nodes, handle positive/negative logic
            if ast.type == RANGE:
                # For consecutive matches, we need to scan until first non-match
                var consecutive_matches = 0
                var pos = 0
                while pos < search_len:
                    var ch_code = ord(str[str_i + pos])
                    var is_match = simd_matcher.contains(ch_code)
                    if ast.positive_logic:
                        if not is_match:
                            break
                    else:
                        if is_match:
                            break
                    consecutive_matches += 1
                    pos += 1

                var matches_count = min(consecutive_matches, max_matches)
                if matches_count >= min_matches:
                    return (True, str_i + matches_count)
                else:
                    return (False, str_i)
            else:
                # For DIGIT and SPACE, use direct SIMD matching
                # Count consecutive matches using bulk operations
                var consecutive_matches = 0
                var pos = 0

                # Process in SIMD-width chunks for better performance
                while pos + SIMD_WIDTH <= search_len:
                    var chunk_matches = simd_matcher._check_chunk_simd(
                        str, str_i + pos
                    )

                    # Check if all characters in chunk match
                    var all_match = True
                    for j in range(SIMD_WIDTH):
                        if not chunk_matches[j]:
                            # Found first non-match
                            consecutive_matches += j
                            all_match = False
                            break

                    if not all_match:
                        break

                    consecutive_matches += SIMD_WIDTH
                    pos += SIMD_WIDTH

                # Handle remaining characters if all chunks matched
                if pos < search_len and consecutive_matches == pos:
                    while pos < search_len:
                        if simd_matcher.contains(ord(str[str_i + pos])):
                            consecutive_matches += 1
                            pos += 1
                        else:
                            break

                var matches_count = min(consecutive_matches, max_matches)
                if matches_count >= min_matches:
                    return (True, str_i + matches_count)
                else:
                    return (False, str_i)

        else:
            # Fallback to regular character-by-character matching
            var matches_count = 0
            var current_pos = str_i

            while matches_count < max_matches and current_pos < len(str):
                # Early termination for match_first_mode
                if match_first_mode and required_start_pos >= 0:
                    if current_pos > required_start_pos + 50:
                        break

                if ast.is_match(
                    String(str[current_pos]), current_pos, len(str)
                ):
                    matches_count += 1
                    current_pos += 1
                else:
                    break

            if matches_count >= min_matches:
                return (True, current_pos)
            else:
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
