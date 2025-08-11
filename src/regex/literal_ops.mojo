"""
Literal operations module for extracting, optimizing, and searching literal substrings in regex patterns.

This module implements:
- Literal optimization strategies for extracting and selecting optimal search strings
- String search algorithms: Boyer-Moore, Two-Way, and automatic algorithm selection
- SIMD-optimized literal pattern matching
- Prefiltering hints and literal pattern analysis
"""

from builtin._location import __call_location
from sys.info import simdwidthof
from regex.aliases import EMPTY_SLICE
from regex.simd_ops import SIMDStringSearch
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

# SIMD width for character operations (uint8)
alias SIMD_WIDTH = simdwidthof[DType.uint8]()

# Pattern length thresholds for searcher selection
alias BOYER_MOORE_MIN_LENGTH = 17
alias BOYER_MOORE_MAX_LENGTH = 64


struct LiteralInfo[node_origin: ImmutableOrigin](Copyable, Movable):
    """Information about a literal substring found in a regex pattern."""

    var node_ptr: UnsafePointer[
        ASTNode[ImmutableAnyOrigin], mut=False, origin=node_origin
    ]
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
        ref [node_origin]node: ASTNode[ImmutableAnyOrigin],
        start_offset: Int = 0,
        is_prefix: Bool = False,
        is_suffix: Bool = False,
        is_required: Bool = True,
    ):
        """Initialize a LiteralInfo with a string literal."""
        self.node_ptr = UnsafePointer[
            ASTNode[ImmutableAnyOrigin], mut=False, origin=node_origin
        ](to=node)
        self.literal_string = None
        self.start_offset = start_offset
        self.is_prefix = is_prefix
        self.is_suffix = is_suffix
        self.is_required = is_required

    fn __init__(
        out self,
        owned literal: String,
        start_offset: Int = 0,
        is_prefix: Bool = False,
        is_suffix: Bool = False,
        is_required: Bool = True,
    ):
        """Initialize a LiteralInfo with a string literal."""
        self.node_ptr = UnsafePointer[ASTNode[ImmutableAnyOrigin]]()
        self.literal_string = literal^
        self.start_offset = start_offset
        self.is_prefix = is_prefix
        self.is_suffix = is_suffix
        self.is_required = is_required

    # @always_inline
    # fn __copyinit__(out self, other: Self):
    #     """Copy constructor for LiteralInfo."""
    #     self.node_ptr = other.node_ptr
    #     self.literal_string = other.literal_string
    #     self.start_offset = other.start_offset
    #     self.is_prefix = other.is_prefix
    #     self.is_suffix = other.is_suffix
    #     self.is_required = other.is_required
    #
    #     var call_location = __call_location()
    #     print("Copying LiteralInfo", call_location)

    fn get_literal(self) -> String:
        """Get the literal string."""
        if self.node_ptr and self.node_ptr[].get_value():
            # If we have an AST node, use its value
            return String(self.node_ptr[].get_value().value())
        elif self.literal_string:
            # If we have a literal string, return it
            return self.literal_string.value()
        else:
            # No literal available
            return ""

    fn get_literal_len(self) -> Int:
        """Get the length of the literal string."""
        if self.node_ptr and self.node_ptr[].get_value():
            return len(self.node_ptr[].get_value().value())
        elif self.literal_string:
            return len(self.literal_string.value())
        else:
            return 0


@fieldwise_init
struct LiteralSet[node_origin: ImmutableOrigin](Movable):
    """A set of literals extracted from a regex pattern."""

    var literals: List[LiteralInfo[node_origin]]
    """All literals found in the pattern."""
    var best_literal_idx: Optional[Int]
    """The best literal to use for prefiltering."""

    fn __init__(out self):
        """Initialize an empty literal set."""
        self.literals = List[LiteralInfo[node_origin]]()
        self.best_literal_idx = None

    fn add(mut self, owned literal: LiteralInfo[node_origin]):
        """Add a literal to the set."""
        self.literals.append(literal^)

    fn select_best(mut self):
        """Select the best literal for prefiltering.

        Selection criteria:
        1. Prefer required literals over optional ones
        2. Prefer longer literals (more discriminative)
        3. Prefer literals with known positions (prefix/suffix)
        4. Prefer literals that appear later in the pattern
        """
        if len(self.literals) == 0:
            self.best_literal_idx = None
            return

        var best_idx = 0
        var best_score = 0

        for i in range(len(self.literals)):
            ref lit = self.literals[i]
            var score = 0

            # Required literals are strongly preferred
            if lit.is_required:
                score += 1000

            # Longer literals are more discriminative
            score += lit.get_literal_len() * 10

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

        self.best_literal_idx = best_idx

    @always_inline
    fn get_best_literal(self) -> Optional[LiteralInfo[node_origin]]:
        """Get the best literal for prefiltering, if available."""
        if self.best_literal_idx:
            return self.literals[self.best_literal_idx.value()]
        else:
            return None


fn extract_literals[
    node_origin: ImmutableOrigin
](ref [node_origin]ast: ASTNode[ImmutableAnyOrigin]) -> LiteralSet[node_origin]:
    """Extract all literals from a regex AST.

    Args:
        ast: The root AST node of the regex pattern.

    Returns:
        A LiteralSet containing all extracted literals.
    """
    var result = LiteralSet[node_origin]()

    if ast.type == RE and ast.has_children():
        # TODO: Unsure if this is a safe origin cast
        # We are assumming first child's matches the parent's origin
        ref child = ast.get_child(0)
        var child_ptr = UnsafePointer[mut=False](to=child).origin_cast[
            origin = ImmutableOrigin.cast_from[node_origin], mut=False
        ]()
        _extract_from_node[node_origin](child_ptr[], result, 0, True, True)
    elif ast.type == GROUP:
        # Handle case where AST is already a GROUP
        _extract_from_node[node_origin](ast, result, 0, True, True)

    result.select_best()
    return result^


fn _extract_from_node[
    node_origin: ImmutableOrigin
](
    ref [node_origin]node: ASTNode[ImmutableAnyOrigin],
    mut result: LiteralSet[node_origin],
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
                var info = LiteralInfo[node_origin](
                    node=node,
                    start_offset=offset,
                    is_prefix=at_start,
                    is_suffix=False,
                    is_required=is_required,
                )
                result.add(info)
            elif node.max == -1:
                # Repeated character (a+, a*)
                # We can still use the character as a hint, but it's less specific
                if node.min >= 1:  # a+ requires at least one
                    var info = LiteralInfo(
                        node=node,
                        start_offset=offset,
                        is_prefix=at_start,
                        is_suffix=False,
                        is_required=is_required,
                    )
                    result.add(info)

    elif node.type == GROUP:
        # Handle groups - extract literals from group contents
        if node.min >= 1:  # Group must appear at least once
            # Check if this is a nested structure
            if node.get_children_len() == 1:
                # TODO: Unsure if this is a safe origin cast
                # We are assumming first child's matches the parent's origin
                ref child = node.get_child(0)
                var child_ptr = UnsafePointer[mut=False](to=child).origin_cast[
                    origin = ImmutableOrigin.cast_from[node_origin], mut=False
                ]()
                # If single child is GROUP or OR, process it directly
                if child.type == GROUP or child.type == OR:
                    _extract_from_node[node_origin](
                        child_ptr[], result, offset, is_required, at_start
                    )
                    return

            # Regular group - extract sequence
            ref group_literals = _extract_sequence(
                node, offset, is_required, at_start
            )
            for ref lit in group_literals:
                result.add(lit)

    elif node.type == OR:
        # For alternation, literals are only required if they appear in ALL branches
        # Simplified: just check direct children of OR node
        var common_prefix = _find_common_prefix_simple(node)
        if len(common_prefix) > 0:
            var info = LiteralInfo[node_origin](
                literal=common_prefix,
                start_offset=offset,
                is_prefix=at_start,
                is_suffix=False,
                is_required=True,
            )
            result.add(info)

        # Etract literals from each branch (but they're not required)
        for i in range(node.get_children_len()):
            # TODO: Unsure if this is a safe origin cast
            # We are assumming first child's matches the parent's origin
            ref child = node.get_child(i)
            var child_ptr = UnsafePointer[mut=False](to=child).origin_cast[
                origin = ImmutableOrigin.cast_from[node_origin], mut=False
            ]()
            _extract_from_node(child_ptr[], result, offset, False, at_start)

    elif node.type == START:
        # Start anchor doesn't contribute literals but maintains position info
        pass

    elif node.type == END:
        # End anchor doesn't contribute literals
        pass

    # Character classes, wildcards, etc. don't contribute literals


fn _extract_sequence[
    node_origin: ImmutableOrigin
](
    ref [node_origin]group: ASTNode,
    start_offset: Int,
    is_required: Bool,
    at_start: Bool,
) -> List[LiteralInfo[node_origin]]:
    """Extract literal sequences from a group node.

    Looks for consecutive literal elements that form longer strings.
    """
    var literals = List[LiteralInfo[node_origin]]()
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
                var info = LiteralInfo[node_origin](
                    literal=current_literal,
                    start_offset=current_offset,
                    is_prefix=sequence_at_start,
                    is_suffix=False,
                    is_required=is_required,
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
        var info = LiteralInfo[node_origin](
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
        return String("")

    # Find common prefix among all collected prefixes
    var common = prefixes[0]
    for i in range(1, len(prefixes)):
        common = _longest_common_prefix(common, prefixes[i])
        if len(common) == 0:
            return String("")

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
            return lit.get_literal()

    # Don't return non-prefix literals as prefix
    return ""


struct BoyerMoore(Copyable, Movable):
    """Boyer-Moore string search algorithm for fast literal string matching."""

    var pattern: String
    """The literal string pattern to search for."""
    var bad_char_table: List[Int]
    """Bad character heuristic table for Boyer-Moore algorithm."""

    fn __init__(out self, pattern: String):
        """Initialize Boyer-Moore with a pattern.

        Args:
            pattern: Literal string pattern to search for.
        """
        self.pattern = pattern
        self.bad_char_table = List[Int](capacity=256)
        self._build_bad_char_table()

    fn _build_bad_char_table(mut self):
        """Build the bad character heuristic table."""
        # Initialize all characters to -1 (not in pattern)
        for _ in range(256):
            self.bad_char_table.append(-1)

        # Set the last occurrence of each character in pattern
        for i in range(len(self.pattern)):
            var char_code = ord(self.pattern[i])
            self.bad_char_table[char_code] = i

    fn search(self, text: String, start: Int = 0) -> Int:
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

        while s <= n - m:
            var j = m - 1

            # Compare pattern from right to left
            while j >= 0 and self.pattern[j] == text[s + j]:
                j -= 1

            if j < 0:
                # Pattern found at position s
                return s
            else:
                # Mismatch occurred, use bad character heuristic
                var bad_char = ord(text[s + j])
                var shift = j - self.bad_char_table[bad_char]
                s += max(1, shift)

        return -1  # Pattern not found

    fn search_all(self, text: String) -> List[Int]:
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

        return positions


struct TwoWaySearcher(Copyable & Movable):
    """SIMD-optimized Two-Way string search algorithm.

    The Two-Way algorithm provides O(n) worst-case time complexity with O(1) space.
    This implementation enhances it with SIMD for the search phase.
    """

    var pattern: String
    """The pattern to search for."""
    var period: Int
    """The period of the pattern's critical factorization."""
    var critical_pos: Int
    """The position of the critical factorization."""
    var memory: Int
    """Memory for the backward search phase."""
    var memory_fwd: Int
    """Memory for the forward search phase."""

    fn __init__(out self, pattern: String):
        """Initialize the Two-Way searcher with a pattern.

        Args:
            pattern: The pattern to search for.
        """
        self.pattern = pattern
        self.memory = 0
        self.memory_fwd = -1

        # Compute critical factorization
        var n = len(self.pattern)
        if n == 0:
            self.critical_pos = 0
            self.period = 1
            return

        # For the Two-Way algorithm to work correctly, we need a proper critical factorization.
        # The current simplified approach causes the algorithm to skip potential matches.
        # For now, we'll use a more conservative approach that ensures correctness.

        # The critical position should be computed using maximal suffix,
        # but for correctness we can use position 1 which guarantees we won't skip matches
        self.critical_pos = 1 if n > 1 else 0

        # Compute the actual period of the pattern
        var period = 1
        var k = 1
        while k < n:
            var i = 0
            while i < n - k and self.pattern[i] == self.pattern[i + k]:
                i += 1
            if i == n - k:
                period = k
                break
            k += 1

        self.period = period

    fn search(self, text: String, start: Int = 0) -> Int:
        """Search for pattern in text using Two-Way algorithm with SIMD.

        Args:
            text: Text to search in.
            start: Starting position.

        Returns:
            Position of first match, or -1 if not found.
        """
        var n = len(self.pattern)
        var m = len(text)

        if n == 0:
            return start
        if n > m - start:
            return -1

        # For very short patterns, use simple SIMD search
        if n <= 4:
            return self._short_pattern_search(text, start)

        # For patterns where Two-Way's complexity isn't needed, use SIMD search
        # This ensures correctness while maintaining good performance
        if n <= 32:
            var search = SIMDStringSearch(self.pattern)
            return search.search(text, start)

        # For longer patterns, use the Two-Way algorithm
        var pos = start
        var memory = 0

        while pos <= m - n:
            # Check right part (from critical position to end)
            var i = max(self.critical_pos, memory)

            # Use SIMD for bulk comparison when possible
            var mismatch_pos = self._simd_compare_forward(text, pos, i)

            if mismatch_pos == n:
                # Right part matches, check left part
                i = self.critical_pos - 1

                while i >= 0 and text[pos + i] == self.pattern[i]:
                    i -= 1

                if i < 0:
                    # Full match found
                    return pos

                # Mismatch in left part
                pos += self.period
                memory = n - self.period
            else:
                # Mismatch in right part
                pos += mismatch_pos - memory + 1
                memory = 0

        return -1

    fn _simd_compare_forward(
        self, text: String, text_pos: Int, start_offset: Int
    ) -> Int:
        """Compare pattern with text starting from given offset using SIMD.

        Args:
            text: Text to compare against.
            text_pos: Starting position in text.
            start_offset: Starting offset in pattern.

        Returns:
            Position of first mismatch, or pattern length if full match.
        """
        var n = len(self.pattern)
        var i = start_offset

        # SIMD comparison for chunks
        while i + SIMD_WIDTH <= n:
            if text_pos + i + SIMD_WIDTH > len(text):
                break

            var pattern_chunk = self.pattern.unsafe_ptr().load[
                width=SIMD_WIDTH
            ](i)
            var text_chunk = text.unsafe_ptr().load[width=SIMD_WIDTH](
                text_pos + i
            )

            var matches = pattern_chunk == text_chunk
            if not matches.reduce_and():
                # Find first mismatch
                for j in range(SIMD_WIDTH):
                    if not matches[j]:
                        return i + j

            i += SIMD_WIDTH

        # Handle remaining characters
        while i < n and text_pos + i < len(text):
            if self.pattern[i] != text[text_pos + i]:
                return i
            i += 1

        return i

    fn _short_pattern_search(self, text: String, start: Int) -> Int:
        """Optimized search for very short patterns (1-4 bytes).

        Uses SIMD to search for pattern as a small integer.
        """
        var n = len(self.pattern)
        var m = len(text)

        if n == 1:
            # Single character search
            var search = SIMDStringSearch(self.pattern)
            return search.search(text, start)

        # For 2-4 byte patterns, use rolling comparison
        var pos = start
        while pos <= m - n:
            var matched = True
            for i in range(n):
                if text[pos + i] != self.pattern[i]:
                    matched = False
                    break
            if matched:
                return pos
            pos += 1

        return -1


struct LiteralSearcher(Copyable, Movable):
    """Flexible literal searcher that uses the optimal algorithm based on pattern length.
    """

    var searcher_type: Int
    """0 = TwoWaySearcher, 1 = BoyerMoore"""
    var two_way: Optional[TwoWaySearcher]
    var boyer_moore: Optional[BoyerMoore]

    fn __init__(out self, pattern: String):
        """Initialize with optimal searcher based on pattern length."""
        var pattern_len = len(pattern)

        if (
            pattern_len >= BOYER_MOORE_MIN_LENGTH
            and pattern_len <= BOYER_MOORE_MAX_LENGTH
        ):
            # Use Boyer-Moore for medium-length patterns (17-64 chars)
            self.searcher_type = 1
            self.two_way = None
            self.boyer_moore = BoyerMoore(pattern)
        else:
            # Use TwoWaySearcher for short or very long patterns
            self.searcher_type = 0
            self.two_way = TwoWaySearcher(pattern)
            self.boyer_moore = None

    fn search(self, text: String, start: Int = 0) -> Int:
        """Search for pattern in text using the optimal algorithm."""
        if self.searcher_type == 1 and self.boyer_moore:
            return self.boyer_moore.value().search(text, start)
        elif self.two_way:
            return self.two_way.value().search(text, start)
        else:
            return -1
