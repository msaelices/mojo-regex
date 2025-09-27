"""
Prefilter system for fast regex matching candidate identification.

This module implements literal extraction and fast scanning techniques to quickly
identify potential match locations before running the full regex engine, inspired
by the Rust regex-automata prefilter system.
"""

from regex.ast import ASTNode, RE, ELEMENT, GROUP, OR, WILDCARD, START, END
from regex.aliases import EMPTY_STRING
from regex.optimizer import is_literal_pattern, get_literal_string


struct LiteralInfo(Copyable, Movable):
    """Information about literal strings extracted from a regex pattern."""

    var required_literals: List[String]
    """Literal strings that must appear in any match."""

    var literal_prefixes: List[String]
    """Literal prefixes that can appear at the start of matches."""

    var literal_suffixes: List[String]
    """Literal suffixes that can appear at the end of matches."""

    var is_exact_match: Bool
    """True if the pattern matches only exact literal strings."""

    var has_anchors: Bool
    """True if the pattern has start or end anchors."""

    fn __init__(out self):
        """Initialize empty literal info."""
        self.required_literals = List[String]()
        self.literal_prefixes = List[String]()
        self.literal_suffixes = List[String]()
        self.is_exact_match = False
        self.has_anchors = False

    fn __copyinit__(out self, other: Self):
        """Copy constructor."""
        self.required_literals = other.required_literals.copy()
        self.literal_prefixes = other.literal_prefixes.copy()
        self.literal_suffixes = other.literal_suffixes.copy()
        self.is_exact_match = other.is_exact_match
        self.has_anchors = other.has_anchors

    fn __moveinit__(out self, deinit other: Self):
        """Move constructor."""
        self.required_literals = other.required_literals^
        self.literal_prefixes = other.literal_prefixes^
        self.literal_suffixes = other.literal_suffixes^
        self.is_exact_match = other.is_exact_match
        self.has_anchors = other.has_anchors

    fn has_prefilter_candidates(self) -> Bool:
        """Check if this pattern has candidates suitable for prefiltering."""
        return (
            len(self.required_literals) > 0
            or len(self.literal_prefixes) > 0
            or len(self.literal_suffixes) > 0
        )

    fn get_best_required_literal(self) -> Optional[String]:
        """Get the best required literal for prefiltering (longest first)."""
        if len(self.required_literals) == 0:
            return None

        var best_literal = self.required_literals[0]
        var best_len = len(best_literal)

        for i in range(1, len(self.required_literals)):
            var current_literal = self.required_literals[i]
            var current_len = len(current_literal)
            if current_len > best_len:
                best_literal = current_literal
                best_len = current_len

        return best_literal

    fn get_best_prefix(self) -> Optional[String]:
        """Get the best literal prefix for prefiltering."""
        if len(self.literal_prefixes) == 0:
            return None

        var best_prefix = self.literal_prefixes[0]
        var best_len = len(best_prefix)

        for i in range(1, len(self.literal_prefixes)):
            var current_prefix = self.literal_prefixes[i]
            var current_len = len(current_prefix)
            if current_len > best_len:
                best_prefix = current_prefix
                best_len = current_len

        return best_prefix


struct LiteralExtractor:
    """Extracts literal information from regex AST patterns for prefilter optimization.
    """

    fn __init__(out self):
        """Initialize the literal extractor."""
        pass

    fn extract(self, ast: ASTNode[MutableAnyOrigin]) -> LiteralInfo:
        """Extract literal information from an AST pattern.

        Args:
            ast: Root AST node of the parsed regex.

        Returns:
            LiteralInfo containing extracted literal strings and metadata.
        """
        var info = LiteralInfo()

        # Check for exact literal patterns first
        if is_literal_pattern(ast):
            var literal_str = get_literal_string(ast)
            if len(literal_str) > 0:
                info.required_literals.append(literal_str)
                info.literal_prefixes.append(literal_str)
                info.literal_suffixes.append(literal_str)
                info.is_exact_match = True
            # Always check for anchors, even for literal patterns
            info.has_anchors = self._has_anchors(ast)
            return info^

        # Check for anchors
        info.has_anchors = self._has_anchors(ast)

        # Extract literals from complex patterns
        self._extract_from_node(ast, info)

        return info^

    fn _has_anchors(self, ast: ASTNode[MutableAnyOrigin]) -> Bool:
        """Check if pattern has start or end anchors."""
        return self._check_anchors_recursive(ast)

    fn _check_anchors_recursive(self, ast: ASTNode[MutableAnyOrigin]) -> Bool:
        """Recursively check for anchors in AST."""
        if ast.type == START or ast.type == END:
            return True
        elif ast.type == GROUP or ast.type == RE:
            for i in range(ast.get_children_len()):
                if self._check_anchors_recursive(ast.get_child(i)):
                    return True
        return False

    fn _extract_from_node(
        self, ast: ASTNode[MutableAnyOrigin], mut info: LiteralInfo
    ):
        """Extract literals from a specific AST node."""
        if ast.type == RE:
            # Process root node children
            for i in range(ast.get_children_len()):
                self._extract_from_node(ast.get_child(i), info)

        elif ast.type == GROUP:
            # Check if this is a literal group
            var literal_text = self._extract_literal_sequence(ast)
            if len(literal_text) > 0:
                info.required_literals.append(literal_text)
                # If it's at the beginning, it's also a prefix
                if self._is_at_beginning(ast):
                    info.literal_prefixes.append(literal_text)
                # If it's at the end, it's also a suffix
                if self._is_at_end(ast):
                    info.literal_suffixes.append(literal_text)
            else:
                # Process group children
                for i in range(ast.get_children_len()):
                    self._extract_from_node(ast.get_child(i), info)

        elif ast.type == OR:
            # Extract common prefixes from alternation branches
            self._extract_alternation_literals(ast, info)

        elif ast.type == ELEMENT:
            # Single character literal
            if ast.min == 1 and ast.max == 1:
                var char_value = ast.get_value()
                if char_value:
                    var char_str = String(char_value.value())
                    info.required_literals.append(char_str)
                    if self._is_at_beginning(ast):
                        info.literal_prefixes.append(char_str)
                    if self._is_at_end(ast):
                        info.literal_suffixes.append(char_str)

    fn _extract_literal_sequence(
        self, ast: ASTNode[MutableAnyOrigin]
    ) -> String:
        """Extract literal string from a sequence of ELEMENT nodes."""
        if ast.type == ELEMENT:
            if ast.min == 1 and ast.max == 1:
                var char_value = ast.get_value()
                if char_value:
                    return String(char_value.value())
            return EMPTY_STRING

        elif ast.type == GROUP:
            var result = String()
            for i in range(ast.get_children_len()):
                var child_literal = self._extract_literal_sequence(
                    ast.get_child(i)
                )
                if len(child_literal) == 0:
                    return EMPTY_STRING  # Non-literal child found
                result += child_literal
            return result^

        return EMPTY_STRING

    fn _extract_alternation_literals(
        self, ast: ASTNode[MutableAnyOrigin], mut info: LiteralInfo
    ):
        """Extract literals from alternation patterns (a|b|c)."""
        var branches = List[String]()
        self._collect_alternation_branches(ast, branches)

        if len(branches) == 0:
            return

        # Check if all branches are literals
        var all_literal = True
        for i in range(len(branches)):
            if len(branches[i]) == 0:
                all_literal = False
                break

        if all_literal:
            # All branches are literals, add them as required literals
            for i in range(len(branches)):
                info.required_literals.append(branches[i])

            # Check for common prefix among all branches
            var common_prefix = self._compute_common_prefix(branches)
            if len(common_prefix) > 0:
                info.literal_prefixes.append(common_prefix)

            # Check for common suffix among all branches
            var common_suffix = self._compute_common_suffix(branches)
            if len(common_suffix) > 0:
                info.literal_suffixes.append(common_suffix)

    fn _collect_alternation_branches(
        self, ast: ASTNode[MutableAnyOrigin], mut branches: List[String]
    ):
        """Collect literal branches from alternation tree."""
        if ast.type == OR:
            # Process both children
            self._collect_alternation_branches(ast.get_child(0), branches)
            self._collect_alternation_branches(ast.get_child(1), branches)
        else:
            # Try to extract literal from this branch
            var literal_text = self._extract_literal_sequence(ast)
            branches.append(literal_text)

    fn _compute_common_prefix(self, branches: List[String]) -> String:
        """Compute longest common prefix among all branches."""
        if len(branches) <= 1:
            return EMPTY_STRING

        var prefix = String()
        var first_branch = branches[0]
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

        return prefix^

    fn _compute_common_suffix(self, branches: List[String]) -> String:
        """Compute longest common suffix among all branches."""
        if len(branches) <= 1:
            return EMPTY_STRING

        var suffix = String()
        var first_branch = branches[0]
        var min_length = len(first_branch)

        # Find minimum length
        for i in range(1, len(branches)):
            if len(branches[i]) < min_length:
                min_length = len(branches[i])

        if min_length == 0:
            return EMPTY_STRING

        # Find common suffix (work backwards)
        for pos in range(1, min_length + 1):
            var char_at_pos = first_branch[len(first_branch) - pos]
            var all_match = True

            for i in range(1, len(branches)):
                var branch = branches[i]
                if branch[len(branch) - pos] != char_at_pos:
                    all_match = False
                    break

            if all_match:
                suffix = String(char_at_pos) + suffix
            else:
                break

        return suffix^

    fn _is_at_beginning(self, ast: ASTNode[MutableAnyOrigin]) -> Bool:
        """Check if this node is at the beginning of the pattern."""
        # Simplified check - in a full implementation, this would check
        # the position within the parent's children
        return True  # Conservative approach for now

    fn _is_at_end(self, ast: ASTNode[MutableAnyOrigin]) -> Bool:
        """Check if this node is at the end of the pattern."""
        # Simplified check - in a full implementation, this would check
        # the position within the parent's children
        return True  # Conservative approach for now


trait PrefilterMatcher:
    """Interface for prefilter matchers that quickly identify candidate positions.
    """

    fn find_candidates(self, text: String) -> List[Int]:
        """Find candidate positions where the full regex might match.

        Args:
            text: Input text to scan.

        Returns:
            List of byte positions where matches might occur.
        """
        ...

    fn find_first_candidate(
        self, text: String, start: Int = 0
    ) -> Optional[Int]:
        """Find the first candidate position at or after start.

        Args:
            text: Input text to scan.
            start: Starting position for the search.

        Returns:
            First candidate position, or None if no candidates found.
        """
        ...


struct MemchrPrefilter(Copyable, Movable, PrefilterMatcher):
    """Fast literal-based prefilter using memchr-style byte scanning."""

    var literal: String
    """The literal string to search for."""

    var is_prefix: Bool
    """True if this literal must appear at the start of matches."""

    fn __init__(out self, literal: String, is_prefix: Bool = False):
        """Initialize memchr prefilter.

        Args:
            literal: Literal string to search for.
            is_prefix: Whether this literal is a required prefix.
        """
        self.literal = literal
        self.is_prefix = is_prefix

    fn __copyinit__(out self, other: Self):
        """Copy constructor."""
        self.literal = other.literal
        self.is_prefix = other.is_prefix

    fn __moveinit__(out self, deinit other: Self):
        """Move constructor."""
        self.literal = other.literal^
        self.is_prefix = other.is_prefix

    fn find_candidates(self, text: String) -> List[Int]:
        """Find all candidate positions of the literal in text."""
        var candidates = List[Int]()
        var start = 0

        while start < len(text):
            var pos = text.find(self.literal, start)
            if pos == -1:
                break
            candidates.append(pos)
            start = pos + 1

        return candidates^

    fn find_first_candidate(
        self, text: String, start: Int = 0
    ) -> Optional[Int]:
        """Find the first occurrence of the literal at or after start."""
        if start >= len(text):
            return None

        var pos = text.find(self.literal, start)
        if pos == -1:
            return None
        return pos


struct ExactLiteralMatcher(PrefilterMatcher):
    """Matcher for patterns that are exact literal strings."""

    var literals: List[String]
    """List of exact literal strings this pattern matches."""

    fn __init__(out self, var literals: List[String]):
        """Initialize exact literal matcher.

        Args:
            literals: List of literal strings the pattern matches exactly.
        """
        self.literals = literals^

    fn find_candidates(self, text: String) -> List[Int]:
        """Find all positions where any of the literals match exactly."""
        var candidates = List[Int]()

        for i in range(len(self.literals)):
            var literal = self.literals[i]
            var start = 0

            while start <= len(text) - len(literal):
                var pos = text.find(literal, start)
                if pos == -1:
                    break
                # Verify this is a complete match (for anchored patterns)
                candidates.append(pos)
                start = pos + 1

        return candidates^

    fn find_first_candidate(
        self, text: String, start: Int = 0
    ) -> Optional[Int]:
        """Find the first exact literal match at or after start."""
        var best_pos: Optional[Int] = None

        for i in range(len(self.literals)):
            var literal = self.literals[i]
            if start + len(literal) > len(text):
                continue

            var pos = text.find(literal, start)
            if pos != -1:
                if not best_pos or pos < best_pos.value():
                    best_pos = pos

        return best_pos


fn create_prefilter(literal_info: LiteralInfo) -> Optional[MemchrPrefilter]:
    """Create the best prefilter for the given literal information.

    Args:
        literal_info: Extracted literal information from pattern analysis.

    Returns:
        Optimal prefilter matcher, or None if no good prefilter available.
    """
    # For exact literal matches, we could bypass regex entirely
    if literal_info.is_exact_match and len(literal_info.required_literals) > 0:
        # Use the first required literal for now
        var literal = literal_info.required_literals[0]
        return MemchrPrefilter(literal, False)

    # Use the best required literal for prefiltering
    var best_literal = literal_info.get_best_required_literal()
    if best_literal:
        var literal = best_literal.value()
        # Only use literals that are long enough to be effective
        if len(literal) >= 2:
            return MemchrPrefilter(literal, False)

    # Use the best prefix if available
    var best_prefix = literal_info.get_best_prefix()
    if best_prefix:
        var prefix = best_prefix.value()
        if len(prefix) >= 2:
            return MemchrPrefilter(prefix, True)

    return None
