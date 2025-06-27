from collections import Deque
from regex.ast import ASTNode
from regex.parser import parse


struct Match(Copyable, Movable):
    """Contains the information of a match in a regular expression."""

    var group_id: Int
    var start_idx: Int
    var end_idx: Int
    var match_text: String
    var name: String

    fn __init__(
        out self,
        group_id: Int,
        start_idx: Int,
        end_idx: Int,
        text: String,
        name: String,
    ):
        self.group_id = group_id
        self.name: String = name
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.match_text = text[start_idx:end_idx]


struct RegexEngine:
    """A regex engine that can match regex patterns against text."""

    var prev_re: String
    var prev_ast: Optional[ASTNode]

    fn __init__(out self):
        """Initialize the regex engine."""
        self.prev_re = ""
        self.prev_ast = None

    fn match_all(
        self,
        re: String,
        text: String,
        return_matches: Bool = False,
        continue_after_match: Bool = False,
        ignore_case: Int = 0,
    ) raises -> Tuple[Bool, Int, List[Match]]:
        """Searches a regex in a test string.

        Searches the passed regular expression in the passed test string and
        returns the result.

        It is possible to customize both the returned value and the search
        method.

        The ignore_case flag may cause unexpected results in the returned
        number of matched characters, and also in the returned matches, e.g.
        when the character ẞ is present in either the regex or the test string.

        Args:
            re: The regular expression to search.
            text: The test string.
            return_matches: If True a data structure containing the
                matches - the whole match and the subgroups matched.
            continue_after_match: If True the engine continues
                matching until the whole input is consumed.
            ignore_case: When 0 the case is not ignored, when 1 a "soft"
                case ignoring is performed, when 2 casefolding is performed.

        Returns:
            A tuple containing whether a match was found or not, the last
            matched character index, and a list of deques of Match, where
            each list of matches represents in the first position the whole
            match, and in the subsequent positions all the group and subgroups
            matched.
        """
        # Parse the regex if it's different from the cached one
        var ast: ASTNode
        if self.prev_re != re:
            from regex.parser import parse

            ast = parse(re)
            # Note: We should update cache here, but the method signature doesn't allow mutation
        else:
            if self.prev_ast:
                ast = self.prev_ast.value()
            else:
                from regex.parser import parse

                ast = parse(re)

        var matches = List[Match]()
        var last_match_end = 0
        var found_any = False
        var current_pos = 0

        while current_pos <= len(text):
            var temp_matches = Deque[Match]()
            var result = self._match_node(ast, text, current_pos, temp_matches)
            if result[0]:  # Match found
                found_any = True
                var match_start = current_pos
                var match_end = result[1]
                last_match_end = match_end

                # Create match object
                var matched = Match(0, match_start, match_end, text, "RegEx")
                if return_matches:
                    matches.append(matched)

                # Move past this match to find next one
                # Avoid infinite loop on zero-width matches
                if match_end == match_start:
                    current_pos += 1
                else:
                    current_pos = match_end

                # If continue_after_match is False, we still continue to find all matches
                # The parameter name seems to be for a different purpose in the original
            else:
                current_pos += 1

        return (found_any, last_match_end, matches)

    fn match_first(
        self, ast: ASTNode, string: String, start_str_i: Int = 0
    ) -> Optional[Match]:
        """Same as match_all, but always returns after the first match.

        Args:
            ast: The AST of the regular expression to search.
            string: The test string.
            start_str_i: The index in the string where to start matching.

        Returns:
            A tuple containing whether a match was found or not, the last
            matched character index, and a deque of Match, where the first
            position contains the whole match, and the subsequent positions
            contain all the group and subgroups matched.
        """
        var matches = Deque[Match]()
        var str_i = start_str_i

        while str_i <= len(string):
            var result = self._match_node(ast, string, str_i, matches)
            if result[0]:  # Match found
                var end_idx = result[1]
                # Always return the overall match with correct range
                var matched = Match(0, str_i, end_idx, string, "RegEx")
                return matched
            str_i += 1

        return None

    fn _match_node(
        self,
        ast: ASTNode,
        string: String,
        str_i: Int,
        mut matches: Deque[Match],
    ) capturing -> Tuple[Bool, Int]:
        """Core matching function that processes AST nodes recursively.

        Args:
            ast: The AST node to match
            string: The input string
            str_i: Current position in string
            matches: Deque to collect matched groups

        Returns:
            Tuple of (success, final_position)
        """
        from regex.ast import (
            RE,
            ELEMENT,
            WILDCARD,
            SPACE,
            RANGE,
            START,
            END,
            OR,
            GROUP,
        )

        if ast.type == ELEMENT:
            return self._match_element(ast, string, str_i)
        elif ast.type == WILDCARD:
            return self._match_wildcard(ast, string, str_i)
        elif ast.type == SPACE:
            return self._match_space(ast, string, str_i)
        elif ast.type == RANGE:
            return self._match_range(ast, string, str_i)
        elif ast.type == START:
            return self._match_start(ast, string, str_i)
        elif ast.type == END:
            return self._match_end(ast, string, str_i)
        elif ast.type == OR:
            return self._match_or(ast, string, str_i, matches)
        elif ast.type == GROUP:
            return self._match_group(ast, string, str_i, matches)
        elif ast.type == RE:
            return self._match_re(ast, string, str_i, matches)
        else:
            return (False, str_i)

    fn _match_element(
        self, ast: ASTNode, string: String, str_i: Int
    ) capturing -> Tuple[Bool, Int]:
        """Match a literal character element."""
        if str_i >= len(string):
            return (False, str_i)

        var ch = string[str_i]
        if ast.value == ch:
            return self._apply_quantifier(ast, string, str_i, 1)
        else:
            return (False, str_i)

    fn _match_wildcard(
        self, ast: ASTNode, string: String, str_i: Int
    ) capturing -> Tuple[Bool, Int]:
        """Match wildcard (.) - any character except newline."""
        if str_i >= len(string):
            return (False, str_i)

        var ch = string[str_i]
        if ch != "\n":
            return self._apply_quantifier(ast, string, str_i, 1)
        else:
            return (False, str_i)

    fn _match_space(
        self, ast: ASTNode, string: String, str_i: Int
    ) capturing -> Tuple[Bool, Int]:
        """Match whitespace character (\\s)."""
        if str_i >= len(string):
            return (False, str_i)

        var ch = string[str_i]
        if ch == " " or ch == "\t" or ch == "\n" or ch == "\r" or ch == "\f":
            return self._apply_quantifier(ast, string, str_i, 1)
        else:
            return (False, str_i)

    fn _match_range(
        self, ast: ASTNode, string: String, str_i: Int
    ) capturing -> Tuple[Bool, Int]:
        """Match character range [abc] or [^abc]."""
        if str_i >= len(string):
            return (False, str_i)

        var ch = string[str_i]
        var ch_found = ast.value.find(ch) != -1
        var positive_logic = ast.min == 1  # min=1 means positive logic

        if ch_found == positive_logic:
            return self._apply_quantifier(ast, string, str_i, 1)
        else:
            return (False, str_i)

    fn _match_start(
        self, ast: ASTNode, string: String, str_i: Int
    ) capturing -> Tuple[Bool, Int]:
        """Match start anchor (^)."""
        if str_i == 0:
            return (True, str_i)
        else:
            return (False, str_i)

    fn _match_end(
        self, ast: ASTNode, string: String, str_i: Int
    ) capturing -> Tuple[Bool, Int]:
        """Match end anchor ($)."""
        if str_i == len(string):
            return (True, str_i)
        else:
            return (False, str_i)

    fn _match_or(
        self,
        ast: ASTNode,
        string: String,
        str_i: Int,
        mut matches: Deque[Match],
    ) capturing -> Tuple[Bool, Int]:
        """Match OR node - try left branch first, then right."""
        if len(ast.children) < 2:
            return (False, str_i)

        # Try left branch first
        var left_result = self._match_node(
            ast.children[0], string, str_i, matches
        )
        if left_result[0]:
            return left_result

        # If left fails, try right branch
        var right_result = self._match_node(
            ast.children[1], string, str_i, matches
        )
        return right_result

    fn _match_group(
        self,
        ast: ASTNode,
        string: String,
        str_i: Int,
        mut matches: Deque[Match],
    ) capturing -> Tuple[Bool, Int]:
        """Match GROUP node - process children sequentially with backtracking.
        """
        var start_pos = str_i

        # Check if this group itself has a quantifier
        if self._has_quantifier(ast):
            return self._match_group_with_quantifier(
                ast, string, str_i, matches
            )

        # Simple case: no quantifier on the group itself
        var result = self._match_sequence(ast.children, string, str_i, matches)
        if not result[0]:
            return (False, str_i)

        # If this is a capturing group, add the match
        if ast.is_capturing():
            var matched = Match(0, start_pos, result[1], string, ast.group_name)
            matches.append(matched)

        return result

    fn _match_group_with_quantifier(
        self,
        ast: ASTNode,
        string: String,
        str_i: Int,
        mut matches: Deque[Match],
    ) capturing -> Tuple[Bool, Int]:
        """Match a group that has a quantifier applied to it."""
        var min_matches = ast.min
        var max_matches = ast.max
        var _ = str_i
        var current_pos = str_i
        var group_matches = 0

        if max_matches == -1:
            max_matches = len(string) - str_i

        # Try to match the group as many times as possible (greedy)
        while group_matches < max_matches and current_pos <= len(string):
            var group_result = self._match_sequence(
                ast.children, string, current_pos, matches
            )
            if group_result[0]:
                group_matches += 1
                current_pos = group_result[1]
                # If this is a capturing group, add the match for this repetition
                if ast.is_capturing():
                    var matched = Match(
                        0, str_i, current_pos, string, ast.group_name
                    )
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
        children: Deque[ASTNode],
        string: String,
        str_i: Int,
        mut matches: Deque[Match],
    ) capturing -> Tuple[Bool, Int]:
        """Match a sequence of AST nodes with backtracking support."""
        if len(children) == 0:
            return (True, str_i)

        if len(children) == 1:
            return self._match_node(children[0], string, str_i, matches)

        # For multiple children, we need to handle backtracking
        var first_child = children[0]
        var remaining_children = Deque[ASTNode](capacity=len(children) - 1)
        for i in range(1, len(children)):
            remaining_children.append(children[i])

        # Try different match lengths for the first child
        if self._has_quantifier(first_child):
            return self._match_with_backtracking(
                first_child, remaining_children, string, str_i, matches
            )
        else:
            # Simple case: match first child normally, then recursively match rest
            var result = self._match_node(first_child, string, str_i, matches)
            if not result[0]:
                return (False, str_i)
            return self._match_sequence(
                remaining_children, string, result[1], matches
            )

    fn _has_quantifier(self, ast: ASTNode) capturing -> Bool:
        """Check if node has quantifier (min != 1 or max != 1)."""
        return ast.min != 1 or ast.max != 1

    fn _match_with_backtracking(
        self,
        quantified_node: ASTNode,
        remaining_children: Deque[ASTNode],
        string: String,
        str_i: Int,
        mut matches: Deque[Match],
    ) capturing -> Tuple[Bool, Int]:
        """Match a quantified node followed by other nodes, with backtracking.
        """
        var min_matches = quantified_node.min
        var max_matches = quantified_node.max

        if max_matches == -1:
            max_matches = len(string) - str_i

        # Try from maximum matches down to minimum matches (greedy with backtracking)
        var match_count = max_matches
        while match_count >= min_matches:
            var consumed = self._try_match_count(
                quantified_node, string, str_i, match_count
            )
            if consumed >= 0:  # Successfully matched this many times
                var new_pos = str_i + consumed
                # Try to match the remaining children
                var result = self._match_sequence(
                    remaining_children, string, new_pos, matches
                )
                if result[0]:
                    return (True, result[1])
            match_count -= 1

        return (False, str_i)

    fn _try_match_count(
        self, ast: ASTNode, string: String, str_i: Int, count: Int
    ) capturing -> Int:
        """Try to match exactly 'count' repetitions of the node. Returns characters consumed or -1.
        """
        var pos = str_i
        var matched = 0

        while matched < count and pos < len(string):
            if ast.is_match(string[pos], pos, len(string)):
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
        string: String,
        str_i: Int,
        mut matches: Deque[Match],
    ) capturing -> Tuple[Bool, Int]:
        """Match RE root node."""
        if len(ast.children) == 0:
            return (True, str_i)

        return self._match_node(ast.children[0], string, str_i, matches)

    fn _apply_quantifier(
        self, ast: ASTNode, string: String, str_i: Int, char_consumed: Int
    ) capturing -> Tuple[Bool, Int]:
        """Apply quantifier logic to a matched element."""
        var min_matches = ast.min
        var max_matches = ast.max

        if max_matches == -1:  # Unlimited
            max_matches = len(string) - str_i

        # If we have a simple single match (min=1, max=1)
        if min_matches == 1 and max_matches == 1:
            return (True, str_i + char_consumed)

        # For quantifiers, we need to try different numbers of matches
        # This is a simplified version - we'll start with greedy matching
        var matches_count = 0
        var current_pos = str_i

        # Try to match as many times as possible (greedy)
        while matches_count < max_matches and current_pos < len(string):
            if ast.is_match(string[current_pos], current_pos, len(string)):
                matches_count += 1
                current_pos += 1
            else:
                break

        # Check if we have enough matches
        if matches_count >= min_matches:
            return (True, current_pos)
        else:
            return (False, str_i)


fn match_first(
    re: String, text: String, ignore_case: Int = 0
) raises -> Optional[Match]:
    """Searches a regex in a test string.

    Searches the passed regular expression in the passed test string and
    returns the result.

    Args:
        re: The regular expression to search.
        text: The test string.
        ignore_case: When 0 the case is not ignored, when 1 a "soft"
            case ignoring is performed, when 2 casefolding is performed.

    Returns:
        A tuple containing whether a match was found or not, the last
        matched character index, and a list of deques of Match, where
        each list of matches represents in the first position the whole
        match, and in the subsequent positions all the group and subgroups
        matched.
    """
    engine = RegexEngine()
    return engine.match_first(parse(re), text)


fn match_all(
    re: String, text: String, ignore_case: Int = 0
) raises -> List[Match]:
    """Searches for all matches of a regex in a test string.

    Searches the passed regular expression in the passed test string and
    returns all matches found.

    Args:
        re: The regular expression to search.
        text: The test string.
        ignore_case: When 0 the case is not ignored, when 1 a "soft"
            case ignoring is performed, when 2 casefolding is performed.

    Returns:
        A list of Match objects representing all matches found in the text.
        Returns an empty list if no matches are found.
    """
    engine = RegexEngine()
    var result = engine.match_all(
        re, text, return_matches=True, ignore_case=ignore_case
    )
    return result[2]  # Return the matches list
