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
    ) -> Tuple[Bool, Int, List[Match]]:
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
        return (False, 0, [])

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
        return None


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
