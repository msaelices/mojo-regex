"""
Literal optimization module for extracting and optimizing literal substrings in regex patterns.

This module implements the literal optimization strategies described in the burntsushi article,
including literal extraction, selection of optimal search strings, and prefiltering hints.
"""

from regex.ast import (
    ASTNode,
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


struct LiteralInfo(Copyable, Movable):
    """Information about a literal substring found in a regex pattern."""

    var ast_node: Optional[UnsafePointer[ASTNode[ImmutableAnyOrigin]]]
    """Pointer to the AST node containing the literal (for single nodes)."""
    var literal_string: Optional[String]
    """The literal string (for concatenated literals or computed values)."""
    var start_offset: Int
    """Minimum offset from start where this literal can appear."""
    var is_prefix: Bool
    """True if this literal must appear at the start of any match."""
    var is_suffix: Bool
    """True if this literal must appear at the end of any match."""
    var is_required: Bool
    """True if this literal must appear in every possible match."""

    fn __init__(
        out self,
        literal: String,
        start_offset: Int = 0,
        is_prefix: Bool = False,
        is_suffix: Bool = False,
        is_required: Bool = True,
    ):
        """Initialize a LiteralInfo with a string literal."""
        self.ast_node = None
        self.literal_string = literal
        self.start_offset = start_offset
        self.is_prefix = is_prefix
        self.is_suffix = is_suffix
        self.is_required = is_required

    fn __init__(
        out self,
        ast_node: UnsafePointer[ASTNode[ImmutableAnyOrigin]],
        start_offset: Int = 0,
        is_prefix: Bool = False,
        is_suffix: Bool = False,
        is_required: Bool = True,
    ):
        """Initialize a LiteralInfo with an AST node pointer."""
        self.ast_node = ast_node
        self.literal_string = None
        self.start_offset = start_offset
        self.is_prefix = is_prefix
        self.is_suffix = is_suffix
        self.is_required = is_required

    fn get_literal(self) -> String:
        """Get the literal string."""
        if self.ast_node:
            var node = self.ast_node.value()[]
            if node.get_value():
                return String(node.get_value().value())
            else:
                return ""
        elif self.literal_string:
            return self.literal_string.value()
        else:
            return ""


@fieldwise_init
struct LiteralSet(Movable):
    """A set of literals extracted from a regex pattern."""

    var literals: List[LiteralInfo]
    """All literals found in the pattern."""
    var best_literal: Optional[LiteralInfo]
    """The best literal to use for prefiltering."""

    fn __init__(out self):
        """Initialize an empty literal set."""
        self.literals = List[LiteralInfo]()
        self.best_literal = None

    fn add(mut self, literal: LiteralInfo):
        """Add a literal to the set."""
        self.literals.append(literal)

    fn select_best(mut self):
        """Select the best literal for prefiltering.

        Selection criteria:
        1. Prefer required literals over optional ones
        2. Prefer longer literals (more discriminative)
        3. Prefer literals with known positions (prefix/suffix)
        4. Prefer literals that appear later in the pattern
        """
        if len(self.literals) == 0:
            self.best_literal = None
            return

        var best_idx = 0
        var best_score = 0

        for i in range(len(self.literals)):
            var lit = self.literals[i]
            var score = 0

            # Required literals are strongly preferred
            if lit.is_required:
                score += 1000

            # Longer literals are more discriminative
            score += len(lit.get_literal()) * 10

            # Prefix/suffix literals allow for more targeted searching
            if lit.is_prefix:
                score += 100
            if lit.is_suffix:
                score += 100

            # Literals that appear later are often more selective
            score += lit.start_offset

            if score > best_score:
                best_score = score
                best_idx = i

        self.best_literal = self.literals[best_idx]


fn extract_literals(ast: ASTNode[MutableAnyOrigin]) -> LiteralSet:
    """Extract all literals from a regex AST.

    Args:
        ast: The root AST node of the regex pattern.

    Returns:
        A LiteralSet containing all extracted literals.
    """
    var result = LiteralSet()

    if ast.type == RE and ast.has_children():
        _extract_from_node(ast.get_child(0), result, 0, True, True)
    elif ast.type == GROUP:
        # Handle case where AST is already a GROUP
        _extract_from_node(ast, result, 0, True, True)

    result.select_best()
    return result^


fn _extract_from_node(
    node: ASTNode,
    mut result: LiteralSet,
    offset: Int,
    is_required: Bool,
    at_start: Bool,
):
    """Recursively extract literals from an AST node.

    Args:
        node: Current AST node being processed
        result: LiteralSet to add found literals to
        offset: Current minimum offset from pattern start
        is_required: Whether literals in this branch are required
        at_start: Whether we're still at the start of the pattern
    """
    if node.type == ELEMENT:
        # Single literal character
        if node.min >= 1 and node.get_value():
            if node.max == 1:
                # Exact single character - use String for now
                # TODO: Fix pointer usage after understanding ownership better
                var char_str = String(node.get_value().value())
                var info = LiteralInfo(
                    char_str, offset, at_start, False, is_required
                )
                result.add(info)
            elif node.max == -1:
                # Repeated character (a+, a*)
                # We can still use the character as a hint, but it's less specific
                if node.min >= 1:  # a+ requires at least one
                    var char_str = String(node.get_value().value())
                    var info = LiteralInfo(
                        char_str, offset, at_start, False, is_required
                    )
                    result.add(info)

    elif node.type == GROUP:
        # Handle groups - extract literals from group contents
        if node.min >= 1:  # Group must appear at least once
            # Check if this is a nested structure
            if node.get_children_len() == 1:
                var child = node.get_child(0)
                # If single child is GROUP or OR, process it directly
                if child.type == GROUP or child.type == OR:
                    _extract_from_node(
                        child, result, offset, is_required, at_start
                    )
                    return

            # Regular group - extract sequence
            var group_literals = _extract_sequence(
                node, offset, is_required, at_start
            )
            for lit in group_literals:
                result.add(lit)

    elif node.type == OR:
        # For alternation, literals are only required if they appear in ALL branches
        # Simplified: just check direct children of OR node
        var common_prefix = _find_common_prefix_simple(node)
        if len(common_prefix) > 0:
            var info = LiteralInfo(common_prefix, offset, at_start, False, True)
            result.add(info)

        # Also extract literals from each branch (but they're not required)
        for i in range(node.get_children_len()):
            _extract_from_node(
                node.get_child(i), result, offset, False, at_start
            )

    elif node.type == START:
        # Start anchor doesn't contribute literals but maintains position info
        pass

    elif node.type == END:
        # End anchor doesn't contribute literals
        pass

    # Character classes, wildcards, etc. don't contribute literals


fn _extract_sequence(
    group: ASTNode,
    start_offset: Int,
    is_required: Bool,
    at_start: Bool,
) -> List[LiteralInfo]:
    """Extract literal sequences from a group node.

    Looks for consecutive literal elements that form longer strings.
    """
    var literals = List[LiteralInfo]()
    var current_literal = String("")
    var current_offset = start_offset
    var sequence_at_start = at_start

    for i in range(group.get_children_len()):
        var child = group.get_child(i)

        if (
            child.type == ELEMENT
            and child.min == 1
            and child.max == 1
            and child.get_value()
        ):
            # Add to current literal sequence
            current_literal += String(child.get_value().value())
        else:
            # End of literal sequence
            if len(current_literal) > 0:
                var info = LiteralInfo(
                    current_literal,
                    current_offset,
                    sequence_at_start,
                    False,
                    is_required,
                )
                literals.append(info)
                current_offset += len(current_literal)
                sequence_at_start = False
                current_literal = ""

            # Handle non-literal child
            if child.type == START:
                continue  # Anchors don't affect offset
            elif child.type == END:
                continue
            else:
                # Other types break the sequence and add to offset
                sequence_at_start = False
                if child.min > 0:
                    current_offset += 1  # At least one character

    # Don't forget the last literal sequence
    if len(current_literal) > 0:
        var info = LiteralInfo(
            current_literal,
            current_offset,
            sequence_at_start,
            False,
            is_required,
        )
        literals.append(info)

    return literals


fn _find_common_prefix_simple(or_node: ASTNode) -> String:
    """Find the longest common prefix among all branches of OR node tree."""
    # Collect all leaf branches from the OR tree
    var prefixes = List[String]()
    _collect_or_prefixes(or_node, prefixes)

    if len(prefixes) < 2:
        return ""

    # Find common prefix among all collected prefixes
    var common = prefixes[0]
    for i in range(1, len(prefixes)):
        common = _longest_common_prefix(common, prefixes[i])
        if len(common) == 0:
            return ""

    return common


fn _collect_or_prefixes(node: ASTNode, mut prefixes: List[String]):
    """Recursively collect prefixes from OR tree structure."""
    if node.type != OR:
        # This is a leaf - get its prefix
        var prefix = _get_prefix_literal(node)
        if len(prefix) > 0:
            prefixes.append(prefix)
        return

    # This is an OR node - process both children
    for i in range(node.get_children_len()):
        _collect_or_prefixes(node.get_child(i), prefixes)


fn _get_prefix_literal(node: ASTNode) -> String:
    """Get the literal prefix of a node, if any."""
    if (
        node.type == ELEMENT
        and node.min >= 1
        and node.max >= 1
        and node.get_value()
    ):
        return String(node.get_value().value())
    elif node.type == GROUP and node.min >= 1:
        # For groups, extract the full literal sequence
        var literals = _extract_sequence(node, 0, True, True)
        if len(literals) > 0:
            return literals[0].get_literal()
    return ""


fn _longest_common_prefix(s1: String, s2: String) -> String:
    """Find the longest common prefix of two strings."""
    var min_len = min(len(s1), len(s2))
    var i = 0
    while i < min_len and s1[i] == s2[i]:
        i += 1
    return s1[:i]


fn has_literal_prefix(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if pattern starts with a literal that can be used for optimization.

    Args:
        ast: Root AST node of the pattern.

    Returns:
        True if pattern has a literal prefix suitable for optimization.
    """
    if ast.type != RE or not ast.has_children():
        return False

    var first_child = ast.get_child(0)
    return _has_literal_prefix_node(first_child)


fn _has_literal_prefix_node(node: ASTNode) -> Bool:
    """Check if a node represents or starts with a literal prefix."""
    if node.type == START:
        # Skip start anchor and check next
        # Note: This is simplified - would need to check siblings in full impl
        return False
    elif node.type == ELEMENT:
        return node.min >= 1 and node.max >= 1
    elif node.type == GROUP:
        if node.min >= 1 and node.get_children_len() > 0:
            # Check if first child is START anchor, if so check second child
            var first_child = node.get_child(0)
            if first_child.type == START and node.get_children_len() > 1:
                return _has_literal_prefix_node(node.get_child(1))
            else:
                return _has_literal_prefix_node(first_child)
        return False
    else:
        return False


fn extract_literal_prefix(ast: ASTNode[MutableAnyOrigin]) -> String:
    """Extract the literal prefix from a pattern, if any.

    Args:
        ast: Root AST node of the pattern.

    Returns:
        The literal prefix string, or empty string if none found.
    """
    var literals = extract_literals(ast)

    # Look for a prefix literal
    for lit in literals.literals:
        if lit.is_prefix and lit.is_required:
            return String(lit.get_literal())

    # Don't return non-prefix literals as prefix
    return ""
