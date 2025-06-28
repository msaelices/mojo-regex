"""
Regex optimization module containing pattern analysis and DFA compilation.

This module implements the optimization strategies outlined in the optimization plan:
- Pattern complexity classification
- DFA compilation for simple patterns
- SIMD character class optimization
"""

from collections import List
from regex.ast import (
    ASTNode,
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


@value
struct PatternComplexity:
    """Classification of regex pattern complexity for optimal execution strategy.
    """

    alias SIMPLE = 0  # "hello", "a+", "[a-z]*", "^start", "end$" - can use DFA
    alias MEDIUM = 1  # "(a|b)+", simple groups, basic quantifiers - hybrid approach
    alias COMPLEX = 2  # Backreferences, lookahead, nested groups - requires NFA

    var value: Int

    fn __init__(out self, value: Int):
        self.value = value

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value


struct PatternAnalyzer:
    """Analyzes regex patterns to determine optimal execution strategy."""

    fn __init__(out self):
        """Initialize the pattern analyzer."""
        pass

    fn classify(self, ast: ASTNode) -> PatternComplexity:
        """Analyze AST to determine pattern complexity.

        Args:
            ast: The root AST node of the parsed regex.

        Returns:
            PatternComplexity indicating the optimal execution strategy.
        """
        return self._analyze_node(ast, depth=0)

    fn _analyze_node(self, ast: ASTNode, depth: Int) -> PatternComplexity:
        """Recursively analyze AST nodes to determine complexity.

        Args:
            ast: Current AST node being analyzed.
            depth: Current nesting depth (for detecting complex structures).

        Returns:
            PatternComplexity of this node and its children.
        """
        if ast.type == RE:
            # Analyze root node - delegate to children
            if len(ast.children) == 0:
                return PatternComplexity(PatternComplexity.SIMPLE)
            return self._analyze_node(ast.children[0], depth)

        elif ast.type == ELEMENT:
            # Literal character - always simple
            # Check for complex quantifiers
            return self._classify_quantifier(ast)

        elif ast.type == WILDCARD:
            # Wildcard (.) - simple with basic quantifiers
            return self._classify_quantifier(ast)

        elif ast.type == SPACE:
            # Whitespace (\s) - simple with basic quantifiers
            return self._classify_quantifier(ast)

        elif ast.type == RANGE:
            # Character class [a-z] - simple with basic quantifiers
            return self._classify_quantifier(ast)

        elif ast.type == START or ast.type == END:
            # Anchors ^ and $ - always simple
            return PatternComplexity(PatternComplexity.SIMPLE)

        elif ast.type == OR:
            # Alternation (|) - analyze complexity of branches
            return self._analyze_alternation(ast, depth)

        elif ast.type == GROUP:
            # Groups (...) - analyze complexity based on nesting and content
            return self._analyze_group(ast, depth)

        else:
            # Unknown node type - assume complex for safety
            return PatternComplexity(PatternComplexity.COMPLEX)

    fn _classify_quantifier(self, ast: ASTNode) -> PatternComplexity:
        """Classify pattern based on quantifier complexity.

        Args:
            ast: AST node with potential quantifier

        Returns:
            PatternComplexity based on quantifier type
        """
        # Simple quantifiers: *, +, ?, {n}, {n,m} with reasonable bounds
        if ast.min == 1 and ast.max == 1:
            # No quantifier - simple
            return PatternComplexity(PatternComplexity.SIMPLE)
        elif (ast.min == 0 and ast.max == -1) or (
            ast.min == 1 and ast.max == -1
        ):
            # * or + quantifiers - simple for DFA
            return PatternComplexity(PatternComplexity.SIMPLE)
        elif ast.min == 0 and ast.max == 1:
            # ? quantifier - simple
            return PatternComplexity(PatternComplexity.SIMPLE)
        elif ast.max != -1 and ast.max - ast.min <= 10:
            # Bounded quantifier with reasonable range - simple
            return PatternComplexity(PatternComplexity.SIMPLE)
        elif ast.max != -1 and ast.max - ast.min <= 100:
            # Larger bounded quantifier - medium complexity
            return PatternComplexity(PatternComplexity.MEDIUM)
        else:
            # Very large or complex quantifiers - complex
            return PatternComplexity(PatternComplexity.COMPLEX)

    fn _analyze_alternation(
        self, ast: ASTNode, depth: Int
    ) -> PatternComplexity:
        """Analyze alternation (OR) complexity.

        Args:
            ast: OR node to analyze
            depth: Current nesting depth

        Returns:
            PatternComplexity of the alternation
        """
        if depth > 2:
            # Deep nesting - too complex for simple DFA
            return PatternComplexity(PatternComplexity.COMPLEX)

        var max_complexity = PatternComplexity(PatternComplexity.SIMPLE)

        # Analyze all branches of the alternation
        for i in range(len(ast.children)):
            var branch_complexity = self._analyze_node(
                ast.children[i], depth + 1
            )
            if branch_complexity.value == PatternComplexity.COMPLEX:
                return PatternComplexity(PatternComplexity.COMPLEX)
            elif branch_complexity.value == PatternComplexity.MEDIUM:
                max_complexity = PatternComplexity(PatternComplexity.MEDIUM)

        # Simple alternation between simple patterns can often be handled by DFA
        if (
            max_complexity.value == PatternComplexity.SIMPLE
            and len(ast.children) <= 5
        ):
            return PatternComplexity(PatternComplexity.SIMPLE)
        else:
            return PatternComplexity(PatternComplexity.MEDIUM)

    fn _analyze_group(self, ast: ASTNode, depth: Int) -> PatternComplexity:
        """Analyze group complexity.

        Args:
            ast: GROUP node to analyze
            depth: Current nesting depth

        Returns:
            PatternComplexity of the group
        """
        if depth > 3:
            # Deep nesting - too complex
            return PatternComplexity(PatternComplexity.COMPLEX)

        # Analyze group quantifier
        var quantifier_complexity = self._classify_quantifier(ast)
        if quantifier_complexity.value == PatternComplexity.COMPLEX:
            return PatternComplexity(PatternComplexity.COMPLEX)

        # Analyze group contents
        var max_child_complexity = PatternComplexity(PatternComplexity.SIMPLE)
        for i in range(len(ast.children)):
            var child_complexity = self._analyze_node(
                ast.children[i], depth + 1
            )
            if child_complexity.value == PatternComplexity.COMPLEX:
                return PatternComplexity(PatternComplexity.COMPLEX)
            elif child_complexity.value == PatternComplexity.MEDIUM:
                max_child_complexity = PatternComplexity(
                    PatternComplexity.MEDIUM
                )

        # Simple groups with simple contents can often be handled efficiently
        if (
            max_child_complexity.value == PatternComplexity.SIMPLE
            and quantifier_complexity.value == PatternComplexity.SIMPLE
        ):
            # For literal groups (like "hello" parsed as group of chars), be more generous
            # Check if all children are literal elements
            var all_literal = True
            for i in range(len(ast.children)):
                var child = ast.children[i]
                if child.type != ELEMENT or child.min != 1 or child.max != 1:
                    all_literal = False
                    break

            if (
                all_literal and len(ast.children) <= 20
            ):  # Allow longer literal strings
                return PatternComplexity(PatternComplexity.SIMPLE)
            elif len(ast.children) <= 3:
                return PatternComplexity(PatternComplexity.SIMPLE)
            else:
                return PatternComplexity(PatternComplexity.MEDIUM)
        else:
            return PatternComplexity(PatternComplexity.MEDIUM)


fn is_literal_pattern(ast: ASTNode) -> Bool:
    """Check if pattern is a simple literal string (possibly with anchors).

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is just literal characters, possibly with ^ or $ anchors.
    """
    if ast.type != RE:
        return False

    if len(ast.children) == 0:
        return True  # Empty pattern

    return _is_literal_sequence(ast.children[0])


fn _is_literal_sequence(ast: ASTNode) -> Bool:
    """Check if an AST node represents a literal character sequence.

    Args:
        ast: AST node to check

    Returns:
        True if node represents literal characters only
    """
    if ast.type == ELEMENT:
        # Must be a single character with no quantifier
        return ast.min == 1 and ast.max == 1
    elif ast.type == START or ast.type == END:
        # Anchors are fine in literal patterns
        return True
    elif ast.type == GROUP:
        # Group must contain only literal elements
        for i in range(len(ast.children)):
            if not _is_literal_sequence(ast.children[i]):
                return False
        return True
    else:
        # Any other node type makes it non-literal
        return False


fn get_literal_string(ast: ASTNode) -> String:
    """Extract literal string from a literal pattern AST.

    Args:
        ast: AST representing a literal pattern.

    Returns:
        The literal string represented by the AST.

    Note:
        Should only be called on patterns where is_literal_pattern() returns True.
    """
    if ast.type == RE and len(ast.children) > 0:
        return _extract_literal_chars(ast.children[0])
    else:
        return ""


fn _extract_literal_chars(ast: ASTNode) -> String:
    """Extract literal characters from an AST node.

    Args:
        ast: AST node to extract from

    Returns:
        String containing the literal characters
    """
    if ast.type == ELEMENT:
        return ast.value
    elif ast.type == GROUP:
        var result = String("")
        for i in range(len(ast.children)):
            result += _extract_literal_chars(ast.children[i])
        return result
    elif ast.type == START or ast.type == END:
        # Anchors don't contribute to literal string
        return ""
    else:
        return ""


fn pattern_has_anchors(ast: ASTNode) -> Tuple[Bool, Bool]:
    """Check if pattern has start (^) or end ($) anchors.

    Args:
        ast: Root AST node.

    Returns:
        Tuple of (has_start_anchor, has_end_anchor).
    """
    var has_start = False
    var has_end = False

    if ast.type == RE and len(ast.children) > 0:
        var child = ast.children[0]
        has_start, has_end = _check_anchors_recursive(child)

    return (has_start, has_end)


fn _check_anchors_recursive(ast: ASTNode) -> Tuple[Bool, Bool]:
    """Recursively check for anchors in AST.

    Args:
        ast: AST node to check

    Returns:
        Tuple of (has_start_anchor, has_end_anchor)
    """
    if ast.type == START:
        return (True, False)
    elif ast.type == END:
        return (False, True)
    elif ast.type == GROUP:
        var has_start = False
        var has_end = False
        for i in range(len(ast.children)):
            var child_start, child_end = _check_anchors_recursive(
                ast.children[i]
            )
            has_start = has_start or child_start
            has_end = has_end or child_end
        return (has_start, has_end)
    else:
        return (False, False)
