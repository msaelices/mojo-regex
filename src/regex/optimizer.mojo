"""
Regex optimization module containing pattern analysis and DFA compilation.

This module implements the optimization strategies outlined in the optimization plan:
- Pattern complexity classification
- DFA compilation for simple patterns
- SIMD character class optimization
- Literal optimization opportunities
"""

from regex.aliases import EMPTY_STRING
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
from regex.literal_optimizer import (
    extract_literals,
    has_literal_prefix,
    extract_literal_prefix,
)


@register_passable("trivial")
struct PatternComplexity(Copyable, Representable, Stringable, Writable):
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

    fn __repr__(self) -> String:
        if self.value == PatternComplexity.SIMPLE:
            return "PatternComplexity(SIMPLE)"
        elif self.value == PatternComplexity.MEDIUM:
            return "PatternComplexity(MEDIUM)"
        elif self.value == PatternComplexity.COMPLEX:
            return "PatternComplexity(COMPLEX)"
        else:
            return String("PatternComplexity(UNKNOWN:", self.value, ")")

    fn __str__(self) -> String:
        if self.value == PatternComplexity.SIMPLE:
            return "SIMPLE"
        elif self.value == PatternComplexity.MEDIUM:
            return "MEDIUM"
        elif self.value == PatternComplexity.COMPLEX:
            return "COMPLEX"
        else:
            return String("UNKNOWN:", self.value)

    @no_inline
    fn write_to[W: Writer, //](self, mut writer: W):
        """Writes a string representation of the PhoneNumberDesc to the writer.

        Parameters:
            W: The type of the writer, conforming to the `Writer` trait.

        Args:
            writer: The writer instance to output the representation to.
        """
        writer.write(self.__str__())


struct OptimizationInfo(Movable):
    """Information about optimization opportunities for a regex pattern."""

    var has_literal_prefix: Bool
    """Whether the pattern has a literal prefix that can be optimized."""
    var literal_prefix_length: Int
    """Length of the literal prefix (0 if none)."""
    var has_required_literal: Bool
    """Whether the pattern has a required literal anywhere."""
    var required_literal_length: Int
    """Length of the longest required literal."""
    var benefits_from_simd: Bool
    """Whether the pattern would benefit from SIMD character class optimization."""
    var suggested_engine: String
    """Suggested engine based on optimization analysis (DFA, NFA, or Hybrid)."""

    fn __init__(out self):
        """Initialize with no optimizations."""
        self.has_literal_prefix = False
        self.literal_prefix_length = 0
        self.has_required_literal = False
        self.required_literal_length = 0
        self.benefits_from_simd = False
        self.suggested_engine = "NFA"


struct PatternAnalyzer:
    """Analyzes regex patterns to determine optimal execution strategy."""

    fn __init__(out self):
        """Initialize the pattern analyzer."""
        pass

    fn classify(self, ast: ASTNode[MutableAnyOrigin]) -> PatternComplexity:
        """Analyze AST to determine pattern complexity.

        Args:
            ast: The root AST node of the parsed regex.

        Returns:
            PatternComplexity indicating the optimal execution strategy.
        """
        return self._analyze_node(ast, depth=0)

    fn analyze_optimizations(
        self, ast: ASTNode[MutableAnyOrigin]
    ) -> OptimizationInfo:
        """Analyze pattern for optimization opportunities.

        Args:
            ast: The root AST node of the parsed regex.

        Returns:
            OptimizationInfo with details about available optimizations.
        """
        var info = OptimizationInfo()

        # Extract literals
        var literal_set = extract_literals(ast)

        # Check for literal prefix
        if has_literal_prefix(ast):
            info.has_literal_prefix = True
            var prefix = extract_literal_prefix(ast)
            info.literal_prefix_length = len(prefix)

        # Check for required literals
        if literal_set.get_best_literal():
            var best = literal_set.get_best_literal().value()
            if best.is_required:
                info.has_required_literal = True
                info.required_literal_length = best.get_literal_len()

        # Check for SIMD optimization opportunities
        info.benefits_from_simd = self._check_simd_benefits(ast)

        # Determine suggested engine
        var complexity = self.classify(ast)
        if complexity.value == PatternComplexity.SIMPLE:
            if info.has_literal_prefix and info.literal_prefix_length > 3:
                info.suggested_engine = "DFA with literal prefilter"
            else:
                info.suggested_engine = "DFA"
        elif complexity.value == PatternComplexity.MEDIUM:
            if info.has_required_literal and info.required_literal_length > 2:
                info.suggested_engine = "NFA with literal prefilter"
            else:
                info.suggested_engine = "Hybrid"
        else:
            if info.has_required_literal:
                info.suggested_engine = "NFA with literal prefilter"
            else:
                info.suggested_engine = "NFA"

        return info^

    fn _check_simd_benefits(self, ast: ASTNode) -> Bool:
        """Check if pattern would benefit from SIMD optimizations.

        Args:
            ast: AST node to check.

        Returns:
            True if SIMD would provide significant benefits.
        """
        return self._count_simd_nodes(ast) > 0

    fn _count_simd_nodes(self, ast: ASTNode) -> Int:
        """Count nodes that benefit from SIMD optimization."""
        var count = 0

        if ast.type == RANGE or ast.type == DIGIT or ast.type == SPACE:
            # Character classes benefit from SIMD
            if ast.min > 1 or ast.max == -1:  # Repeated character classes
                count += 2  # Extra benefit for repetition
            else:
                count += 1
        elif ast.type == GROUP or ast.type == RE:
            # Recursively count in children
            for i in range(ast.get_children_len()):
                count += self._count_simd_nodes(ast.get_child(i))
        elif ast.type == OR:
            # Count in all branches
            for i in range(ast.get_children_len()):
                count += self._count_simd_nodes(ast.get_child(i))

        return count

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
            if ast.get_children_len() == 0:
                return PatternComplexity(PatternComplexity.SIMPLE)
            return self._analyze_node(ast.get_child(0), depth)

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

        elif ast.type == DIGIT:
            # Digit (\d) - simple with basic quantifiers
            return self._classify_quantifier(ast)

        elif ast.type == RANGE:
            # Character class [a-z] - simple with basic quantifiers, optimized by DFA+SIMD
            return self._classify_quantifier(ast)

        elif ast.type == START or ast.type == END:
            # Anchors ^ and $ - supported by DFA
            return PatternComplexity(PatternComplexity.SIMPLE)

        elif ast.type == OR:
            # Alternation (|) - analyze complexity of branches
            return self._analyze_alternation(ast, depth)

        elif ast.type == GROUP:
            # Groups (...) - analyze complexity based on nesting and content
            # First check if it's a multi-character class sequence
            if self._is_multi_char_class_sequence(ast):
                return PatternComplexity(PatternComplexity.SIMPLE)
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
            # Check if this is a common prefix alternation before giving up
            # These can be efficiently handled with trie-like DFA structures
            if self._is_common_prefix_alternation_in_tree(ast):
                # Common prefix alternation - can be handled by specialized DFA
                return PatternComplexity(PatternComplexity.SIMPLE)
            # Otherwise, deep nesting - too complex for simple DFA
            return PatternComplexity(PatternComplexity.COMPLEX)

        var max_complexity = PatternComplexity(PatternComplexity.SIMPLE)

        # Analyze all branches of the alternation
        for i in range(ast.get_children_len()):
            var branch_complexity = self._analyze_node(
                ast.get_child(i), depth + 1
            )
            if branch_complexity.value == PatternComplexity.COMPLEX:
                return PatternComplexity(PatternComplexity.COMPLEX)
            elif branch_complexity.value == PatternComplexity.MEDIUM:
                max_complexity = PatternComplexity(PatternComplexity.MEDIUM)

        # Simple alternation between simple patterns can often be handled by DFA
        if (
            max_complexity.value == PatternComplexity.SIMPLE
            and ast.get_children_len() <= 5
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

        # Check if group has quantifier and whether it's a simple quantified group that DFA can handle
        if ast.min != 1 or ast.max != 1:
            # Check if this is a simple quantified group that DFA can handle
            if self._is_simple_quantified_group(ast):
                # Simple quantified groups with literal content can use DFA
                pass  # Continue analysis below
            elif self._is_quantified_alternation_group_in_optimizer(ast):
                # Quantified alternation groups like (a|b)* can use DFA
                return PatternComplexity(PatternComplexity.SIMPLE)
            else:
                # Complex quantified groups still need NFA
                return PatternComplexity(PatternComplexity.MEDIUM)

        # Analyze group contents
        var max_child_complexity = PatternComplexity(PatternComplexity.SIMPLE)
        for i in range(ast.get_children_len()):
            var child_complexity = self._analyze_node(
                ast.get_child(i), depth + 1
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
            # Check if all children are literal elements or anchors
            var all_literal = True
            for i in range(ast.get_children_len()):
                var child = ast.get_child(i)
                if not (
                    (
                        child.type == ELEMENT
                        and child.min == 1
                        and child.max == 1
                    )
                    or child.type == START
                    or child.type == END
                ):
                    all_literal = False
                    break

            if (
                all_literal and ast.get_children_len() <= 20
            ):  # Allow longer literal strings
                return PatternComplexity(PatternComplexity.SIMPLE)
            elif ast.get_children_len() <= 3:
                return PatternComplexity(PatternComplexity.SIMPLE)
            else:
                return PatternComplexity(PatternComplexity.MEDIUM)
        else:
            return PatternComplexity(PatternComplexity.MEDIUM)

    fn _is_multi_char_class_sequence(self, ast: ASTNode) -> Bool:
        """Check if this GROUP represents a multi-character class sequence.

        Args:
            ast: GROUP node to analyze

        Returns:
            True if it's a sequence of character classes
        """
        if ast.type != GROUP:
            return False

        # Must have at least 2 elements to be a sequence
        if ast.get_children_len() < 2:
            return False

        # Check if it's mostly character classes with some literals
        var char_class_count = 0
        var literal_count = 0

        for i in range(ast.get_children_len()):
            var element = ast.get_child(i)
            if (
                element.type == RANGE
                or element.type == DIGIT
                or element.type == SPACE
                or element.type == WILDCARD
            ):
                char_class_count += 1
            elif (
                element.type == ELEMENT
                and element.min == 1
                and element.max == 1
            ):
                # Single literal characters are OK
                literal_count += 1
            else:
                # Other types make it non-sequential
                return False

        # It's a multi-char sequence if it has at least 2 character classes
        # and any number of single literals (like @ and .)
        return char_class_count >= 2

    fn _is_simple_quantified_group(self, ast: ASTNode) -> Bool:
        """Check if a quantified group is simple enough for DFA compilation.

        A simple quantified group is one that:
        - Has simple quantifiers (?, *, +)
        - Contains only literal elements (no nested groups or complex patterns)

        Args:
            ast: GROUP node with quantifiers.

        Returns:
            True if the quantified group can be handled by DFA.
        """
        from regex.ast import ELEMENT

        # Check for simple quantifier patterns
        if not (
            (ast.min == 0 and ast.max == 1)
            or (ast.min == 0 and ast.max == -1)  # ?
            or (ast.min == 1 and ast.max == -1)  # *
        ):  # +
            return False

        # Check that all children are simple literal elements
        for i in range(ast.get_children_len()):
            var child = ast.get_child(i)
            if child.type != ELEMENT or child.min != 1 or child.max != 1:
                return False

        return True

    fn _is_common_prefix_alternation_in_tree(self, ast: ASTNode) -> Bool:
        """Check if alternation tree represents a common prefix alternation.

        This checks if a (potentially deep) alternation tree like:
        (hello|help|helicopter) represents branches with meaningful common prefixes.

        Args:
            ast: OR node to analyze

        Returns:
            True if this is a common prefix alternation that DFA can handle efficiently
        """
        from regex.ast import OR, GROUP, ELEMENT

        # Extract all literal branches from the OR tree
        var branches = List[String]()
        if not self._extract_literal_branches_from_tree(ast, branches):
            return False

        # Must have at least 2 branches
        if len(branches) < 2:
            return False

        # Check if there's a meaningful common prefix (at least 2 characters)
        var common_prefix = self._compute_common_prefix_in_optimizer(branches)
        return len(common_prefix) >= 2

    fn _extract_literal_branches_from_tree(
        self, node: ASTNode, mut branches: List[String]
    ) -> Bool:
        """Extract literal string branches from OR tree."""
        from regex.ast import OR, GROUP, ELEMENT

        if node.type == OR:
            # Process both children
            return self._extract_literal_branches_from_tree(
                node.get_child(0), branches
            ) and self._extract_literal_branches_from_tree(
                node.get_child(1), branches
            )
        elif node.type == GROUP:
            # Extract literal string from GROUP of ELEMENTs
            var branch_text = String(capacity=String.INLINE_CAPACITY)
            for i in range(node.get_children_len()):
                var element = node.get_child(i)
                if element.type != ELEMENT:
                    return False  # Non-literal element found
                var char_value = element.get_value().value()
                branch_text += String(char_value)
            branches.append(branch_text)
            return True
        else:
            return False  # Unexpected node type

    fn _compute_common_prefix_in_optimizer(
        self, branches: List[String]
    ) -> String:
        """Compute the longest common prefix among all branches."""
        if len(branches) == 0:
            return EMPTY_STRING
        if len(branches) == 1:
            return branches[0]

        var prefix = String(capacity=String.INLINE_CAPACITY)
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

        return prefix

    fn _is_quantified_alternation_group_in_optimizer(self, ast: ASTNode) -> Bool:
        """Check if pattern is a quantified alternation group like (a|b)*, (cat|dog)+.
        
        This version is used by the optimizer to classify patterns.
        
        Args:
            ast: GROUP node to analyze (not root AST node)
            
        Returns:
            True if this group is a quantified alternation group.
        """
        from regex.ast import GROUP, OR, ELEMENT
        
        # Must be quantified (not 1,1)
        if ast.min == 1 and ast.max == 1:
            return False
        
        # Must have exactly one child that is an OR
        if ast.get_children_len() != 1:
            return False
            
        var or_node = ast.get_child(0)
        if or_node.type != OR:
            return False
        
        # Check if alternation contains only literal branches
        var branches = List[String]()
        return self._extract_literal_branches_from_or(or_node, branches)

    fn _extract_literal_branches_from_or(self, node: ASTNode, mut branches: List[String]) -> Bool:
        """Extract literal branches from OR node for optimizer."""
        from regex.ast import OR, GROUP, ELEMENT
        
        if node.type == OR:
            # Process both children
            return (self._extract_literal_branches_from_or(node.get_child(0), branches) and 
                    self._extract_literal_branches_from_or(node.get_child(1), branches))
        elif node.type == GROUP:
            # Extract literal string from GROUP of ELEMENTs
            var branch_text = String("")
            for i in range(node.get_children_len()):
                var element = node.get_child(i)
                if element.type != ELEMENT:
                    return False  # Non-literal element found
                var char_value = element.get_value().value()
                branch_text += String(char_value)
            branches.append(branch_text)
            return True
        else:
            return False  # Unexpected node type


fn is_literal_pattern(ast: ASTNode) -> Bool:
    """Check if pattern is a simple literal string (possibly with anchors).

    Args:
        ast: Root AST node.

    Returns:
        True if pattern is just literal characters, possibly with ^ or $ anchors.
    """
    if ast.type != RE:
        return False

    if not ast.has_children():
        return True  # Empty pattern

    return _is_literal_sequence(ast.get_child(0))


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
        # For literal pattern detection, check if this group contains nested GROUP nodes
        # If it does, it means there are explicit capturing groups, making it non-literal
        for i in range(ast.get_children_len()):
            var child = ast.get_child(i)
            if child.type == GROUP:
                # Nested groups make the pattern non-literal (explicit capturing groups)
                return False
            elif not _is_literal_sequence(child):
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
    if ast.type == RE and ast.get_children_len() > 0:
        return _extract_literal_chars(ast.get_child(0))
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
        return String(ast.get_value().value()) if ast.get_value() else ""
    elif ast.type == GROUP:
        var result = String(capacity=String.INLINE_CAPACITY)
        for i in range(ast.get_children_len()):
            result += _extract_literal_chars(ast.get_child(i))
        return result
    elif ast.type == START or ast.type == END:
        # Anchors don't contribute to literal string
        return EMPTY_STRING
    else:
        return EMPTY_STRING  # Non-literal nodes return empty string


fn pattern_has_anchors(ast: ASTNode) -> Tuple[Bool, Bool]:
    """Check if pattern has start (^) or end ($) anchors.

    Args:
        ast: Root AST node.

    Returns:
        Tuple of (has_start_anchor, has_end_anchor).
    """
    var has_start = False
    var has_end = False

    if ast.type == RE and ast.has_children():
        var child = ast.get_child(0)
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
        for i in range(ast.get_children_len()):
            var child_start, child_end = _check_anchors_recursive(
                ast.get_child(i)
            )
            has_start = has_start or child_start
            has_end = has_end or child_end
        return (has_start, has_end)
    else:
        return (False, False)
