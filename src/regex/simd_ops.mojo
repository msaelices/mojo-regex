"""
SIMD-optimized operations for high-performance regex matching.

This module leverages Mojo's SIMD capabilities to vectorize character operations,
providing significant speedups for character class matching and string scanning.
"""

from algorithm import vectorize
from sys.info import simdwidthof

# SIMD width for character operations (uint8)
alias SIMD_WIDTH = simdwidthof[DType.uint8]()


@register_passable("trivial")
struct CharacterClassSIMD(Copyable, Movable):
    """SIMD-optimized character class matcher."""

    var lookup_table: SIMD[DType.uint8, 256]
    """Bit vector for each ASCII character, 1 if in class, 0 otherwise."""

    fn __init__(out self, char_class: StringSlice):
        """Initialize SIMD character class matcher.

        Args:
            char_class: String containing all characters in the class (e.g., "abcdefg...").
        """
        self.lookup_table = SIMD[DType.uint8, 256](0)

        # Set bits for each character in the class
        for i in range(len(char_class)):
            var char_code = ord(char_class[i])
            if char_code >= 0 and char_code < 256:
                self.lookup_table[char_code] = 1

    fn __init__(out self, start_char: StringSlice, end_char: StringSlice):
        """Initialize with a character range like 'a'-'z'.

        Args:
            start_char: First character in range.
            end_char: Last character in range.
        """
        self.lookup_table = SIMD[DType.uint8, 256](0)

        var start_code = max(ord(start_char), 0)
        var end_code = min(ord(end_char), 255)

        for char_code in range(start_code, end_code + 1):
            self.lookup_table[char_code] = 1

    fn contains(self, char_code: Int) -> Bool:
        """Check if character is in this character class.

        Args:
            char_code: Character code to check (0-255).

        Returns:
            True if character is in the class.
        """
        if char_code >= 0 and char_code < 256:
            return self.lookup_table[char_code] == 1
        return False

    fn find_first_match(self, text: String, start: Int = 0) -> Int:
        """Find first character in text that matches this class using SIMD.

        Args:
            text: Text to search.
            start: Starting position.

        Returns:
            Position of first match, or -1 if not found.
        """
        var pos = start
        var text_len = len(text)

        # Process chunks using SIMD
        while pos + SIMD_WIDTH <= text_len:
            var matches = self._check_chunk_simd(text, pos)
            if matches.reduce_or():
                # Found at least one match in this chunk
                for i in range(SIMD_WIDTH):
                    if matches[i]:
                        return pos + i
            pos += SIMD_WIDTH

        # Handle remaining characters
        while pos < text_len:
            if self.contains(ord(text[pos])):
                return pos
            pos += 1

        return -1

    fn find_all_matches(self, text: String) -> List[Int]:
        """Find all positions where characters match this class.

        Args:
            text: Text to search.

        Returns:
            List of positions where matches occur.
        """
        var matches = List[Int]()
        var pos = 0
        var text_len = len(text)

        @parameter
        fn closure[width: Int](i: Int) capturing:
            if width != 1:
                var chunk_matches = self._check_chunk_simd(text, pos + i)
                for j in range(width):
                    if chunk_matches[j]:
                        matches.append(pos + i + j)
            elif self.contains(ord(text[pos + i])):
                matches.append(pos + i)

        vectorize[closure, SIMD_WIDTH](text_len - pos)

        return matches

    fn count_matches(self, text: String, start: Int = 0, end: Int = -1) -> Int:
        """Count how many characters match this class in the given range.

        Args:
            text: Text to search.
            start: Starting position.
            end: Ending position (-1 for end of string).

        Returns:
            Number of matching characters.
        """
        var actual_end = end if end != -1 else len(text)
        var count = 0
        var pos = start

        @parameter
        fn closure[width: Int](i: Int):
            if width != 1:
                var matches = self._check_chunk_simd(text, pos + i)
                count += Int(matches.cast[DType.uint8]().reduce_add())
            elif self.contains(ord(text[pos + i])):
                count += 1

        vectorize[closure, SIMD_WIDTH](actual_end - pos)

        return count

    fn _check_chunk_simd(
        self, text: String, pos: Int
    ) -> SIMD[DType.bool, SIMD_WIDTH]:
        """Check a chunk of characters using SIMD operations.

        Args:
            text: Text to check.
            pos: Starting position of chunk.

        Returns:
            SIMD vector of booleans indicating matches
        """
        # Load chunk of characters
        var chunk = text.unsafe_ptr().load[width=SIMD_WIDTH](pos)

        # Use lookup table to check each character
        var matches = SIMD[DType.bool, SIMD_WIDTH](False)

        for i in range(SIMD_WIDTH):
            var char_code = Int(chunk[i])
            matches[i] = self.lookup_table[char_code] == 1

        return matches


@always_inline
fn create_ascii_lowercase() -> CharacterClassSIMD:
    """Create SIMD matcher for ASCII lowercase letters [a-z]."""
    return CharacterClassSIMD("a", "z")


@always_inline
fn create_ascii_uppercase() -> CharacterClassSIMD:
    """Create SIMD matcher for ASCII uppercase letters [A-Z]."""
    return CharacterClassSIMD("A", "Z")


@always_inline
fn create_ascii_digits() -> CharacterClassSIMD:
    """Create SIMD matcher for ASCII digits [0-9]."""
    return CharacterClassSIMD("0", "9")


@always_inline
fn create_ascii_alphanumeric() -> CharacterClassSIMD:
    """Create SIMD matcher for ASCII alphanumeric [a-zA-Z0-9]."""
    var result = CharacterClassSIMD("")

    # Add lowercase letters
    for i in range(ord("a"), ord("z") + 1):
        result.lookup_table[i] = 1

    # Add uppercase letters
    for i in range(ord("A"), ord("Z") + 1):
        result.lookup_table[i] = 1

    # Add digits
    for i in range(ord("0"), ord("9") + 1):
        result.lookup_table[i] = 1

    return result


@always_inline
fn create_whitespace() -> CharacterClassSIMD:
    """Create SIMD matcher for whitespace characters [ \\t\\n\\r\\f\\v]."""
    var whitespace_chars = " \t\n\r\f\v"
    return CharacterClassSIMD(whitespace_chars)


struct SIMDStringSearch(Copyable, Movable):
    """SIMD-optimized string search for literal patterns."""

    var pattern: String
    """The literal string pattern to search for."""
    var pattern_length: Int
    """Length of the pattern string."""
    var first_char_simd: SIMD[DType.uint8, SIMD_WIDTH]
    """SIMD vector filled with the first character of the pattern for fast comparison."""

    fn __init__(out self, pattern: String):
        """Initialize SIMD string search.

        Args:
            pattern: Literal string pattern to search for.
        """
        self.pattern = pattern
        self.pattern_length = len(pattern)

        # Create SIMD vector with first character of pattern
        if len(pattern) > 0:
            var first_char = ord(pattern[0])
            self.first_char_simd = SIMD[DType.uint8, SIMD_WIDTH](first_char)
        else:
            self.first_char_simd = SIMD[DType.uint8, SIMD_WIDTH](0)

    fn search(self, text: String, start: Int = 0) -> Int:
        """Search for pattern in text using SIMD acceleration.

        Args:
            text: Text to search in.
            start: Starting position.

        Returns:
            Position of first match, or -1 if not found.
        """
        if self.pattern_length == 0:
            return start  # Empty pattern matches at any position

        var text_len = len(text)
        var pos = start

        # Use SIMD to quickly find potential matches by first character
        while pos + SIMD_WIDTH <= text_len:
            # Load chunk of text
            var chunk = text.unsafe_ptr().load[width=SIMD_WIDTH](pos)

            # Compare with first character of pattern
            var matches = chunk == self.first_char_simd

            if matches.reduce_or():
                # Found potential match, check each position
                for i in range(SIMD_WIDTH):
                    if matches[i]:
                        var candidate_pos = pos + i
                        if self._verify_match(text, candidate_pos):
                            return candidate_pos

            pos += SIMD_WIDTH

        # Handle remaining characters
        while pos <= text_len - self.pattern_length:
            if self._verify_match(text, pos):
                return pos
            pos += 1

        return -1

    fn _verify_match(self, text: String, pos: Int) -> Bool:
        """Verify that pattern matches at given position.

        Args:
            text: Text to check.
            pos: Position to check.

        Returns:
            True if pattern matches at this position.
        """
        if pos + self.pattern_length > len(text):
            return False

        for i in range(self.pattern_length):
            if String(text[pos + i]) != String(self.pattern[i]):
                return False

        return True

    fn search_all(self, text: String) -> List[Int]:
        """Find all non-overlapping occurrences of pattern in text.

        Args:
            text: Text to search.

        Returns:
            List of starting positions of all non-overlapping matches.
        """
        var positions = List[Int]()
        var start = 0

        while True:
            var pos = self.search(text, start)
            if pos == -1:
                break
            positions.append(pos)
            # Move past this match to avoid overlapping matches
            start = pos + self.pattern_length

        return positions


fn simd_memcmp(
    s1: String, s1_offset: Int, s2: String, s2_offset: Int, length: Int
) -> Bool:
    """SIMD-accelerated memory comparison for string matching.

    Args:
        s1: First string.
        s1_offset: Offset in first string.
        s2: Second string.
        s2_offset: Offset in second string.
        length: Number of characters to compare.

    Returns:
        True if the specified regions are equal.
    """
    if length == 0:
        return True

    if (s1_offset + length > len(s1)) or (s2_offset + length > len(s2)):
        return False

    var pos = 0

    # Compare chunks using SIMD
    while pos + SIMD_WIDTH <= length:
        var chunk1 = s1.unsafe_ptr().load[width=SIMD_WIDTH](s1_offset + pos)
        var chunk2 = s2.unsafe_ptr().load[width=SIMD_WIDTH](s2_offset + pos)

        if (chunk1 != chunk2).reduce_or():
            return False

        pos += SIMD_WIDTH

    # Compare remaining characters
    while pos < length:
        if s1[s1_offset + pos] != s2[s2_offset + pos]:
            return False
        pos += 1

    return True


fn simd_count_char(text: String, target_char: String) -> Int:
    """Count occurrences of a character using SIMD.

    Args:
        text: Text to search.
        target_char: Character to count.

    Returns:
        Number of occurrences.
    """
    if len(target_char) != 1:
        return 0

    var target_code = ord(target_char)
    var target_simd = SIMD[DType.uint8, SIMD_WIDTH](target_code)
    var count = 0
    var pos = 0
    var text_len = len(text)

    # Process chunks using SIMD
    while pos + SIMD_WIDTH <= text_len:
        var chunk = text.unsafe_ptr().load[width=SIMD_WIDTH](pos)
        var matches = chunk == target_simd
        count += Int(matches.cast[DType.uint8]().reduce_add())
        pos += SIMD_WIDTH

    # Handle remaining characters
    while pos < text_len:
        if String(text[pos]) == target_char:
            count += 1
        pos += 1

    return count


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

    fn __init__(out self, pattern: String):
        """Initialize the Two-Way searcher with a pattern.

        Args:
            pattern: The pattern to search for.
        """
        self.pattern = pattern
        self.critical_pos = 0
        self.period = 1

        # Compute critical factorization
        var n = len(self.pattern)
        if n == 0:
            return

        # Compute critical position using maximal suffix
        var (crit_pos, period) = self._compute_critical_factorization()
        self.critical_pos = crit_pos
        self.period = period

    fn _compute_critical_factorization(self) -> Tuple[Int, Int]:
        """Compute the critical factorization of the pattern.

        Returns:
            Tuple of (critical_position, period)
        """
        _ = len(self.pattern)  # Suppress unused warning

        # Compute maximal suffix for both forward and reverse comparisons
        var (i1, p1) = self._maximal_suffix(False)
        var (i2, p2) = self._maximal_suffix(True)

        # Choose the critical position
        var crit_pos: Int
        var period: Int

        if i1 > i2:
            crit_pos = i1
            period = p1
        else:
            crit_pos = i2
            period = p2

        return (crit_pos, period)

    fn _maximal_suffix(self, reverse_cmp: Bool) -> Tuple[Int, Int]:
        """Compute maximal suffix of the pattern.

        Args:
            reverse_cmp: If True, use reverse lexicographic comparison

        Returns:
            Tuple of (position, period)
        """
        var n = len(self.pattern)
        var ms = -1  # Maximal suffix
        var j = 0  # Index for comparison
        var k = 1  # Period
        var p = 1  # Period of maximal suffix

        while j + k < n:
            var a = ord(self.pattern[j + k])
            var b = ord(self.pattern[ms + k])

            var cmp_result: Bool
            if reverse_cmp:
                cmp_result = a > b
            else:
                cmp_result = a < b

            if cmp_result:
                j += k
                k = 1
                p = j - ms
            elif a == b:
                if k != p:
                    k += 1
                else:
                    j += p
                    k = 1
            else:
                ms = j
                j = ms + 1
                k = 1
                p = 1

        return (ms + 1, p)

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

        # Two-Way algorithm main loop
        var pos = start
        var memory = 0

        # Check if pattern is periodic
        var is_periodic = self._is_prefix(self.pattern, self.period)

        while pos <= m - n:
            # First, compare the right part (from critical position to end)
            var i = max(self.critical_pos, memory)

            # Use SIMD-optimized comparison for the right part
            var right_match_end = self._simd_compare_forward(text, pos, i)

            if right_match_end < n:
                # Mismatch in right part
                pos += max(right_match_end - self.critical_pos + 1, 1)
                memory = 0
            else:
                # Right part matches, now check left part using SIMD
                var left_match_start = self._simd_compare_backward(
                    text, pos, self.critical_pos - 1, memory
                )

                if left_match_start < 0:
                    # Full match found!
                    return pos

                # Mismatch in left part
                if is_periodic:
                    pos += self.period
                    memory = n - self.period
                else:
                    pos += max(left_match_start + 1, 1)
                    memory = 0

        return -1

    fn _is_prefix(self, pattern: String, period: Int) -> Bool:
        """Check if pattern[:period] is a prefix of pattern[period:].

        Args:
            pattern: The pattern string
            period: The period to check

        Returns:
            True if pattern has the given period
        """
        var n = len(pattern)
        if period >= n:
            return False

        for i in range(n - period):
            if pattern[i] != pattern[i + period]:
                return False
        return True

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
        var m = len(text)
        var i = start_offset

        # SIMD comparison for chunks
        while i + SIMD_WIDTH <= n and text_pos + i + SIMD_WIDTH <= m:
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
        while i < n and text_pos + i < m:
            if self.pattern[i] != text[text_pos + i]:
                return i
            i += 1

        return i

    fn _simd_compare_backward(
        self, text: String, text_pos: Int, end_offset: Int, start_offset: Int
    ) -> Int:
        """Compare pattern with text backward from given offset using SIMD.

        Args:
            text: Text to compare against.
            text_pos: Starting position in text.
            end_offset: Ending offset in pattern (inclusive).
            start_offset: Starting offset in pattern (inclusive lower bound).

        Returns:
            Position of first mismatch (from left), or -1 if full match.
        """
        var j = end_offset

        # For now, use simple character-by-character comparison
        # TODO: Optimize with SIMD for backward comparison
        while j >= start_offset:
            if text[text_pos + j] != self.pattern[j]:
                return j
            j -= 1

        return -1  # Full match

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


struct MultiLiteralSearcher:
    """SIMD-optimized multi-literal string searcher (Teddy-like algorithm).

    Can search for multiple short literals simultaneously using SIMD.
    """

    var literals: List[String]
    """The literals to search for."""
    var max_len: Int
    """Maximum length among all literals."""
    var min_len: Int
    """Minimum length among all literals."""
    var first_bytes: SIMD[DType.uint8, 16]
    """First byte of each literal (up to 16)."""
    var literal_count: Int
    """Number of literals (max 16 for SIMD efficiency)."""

    fn __init__(out self, literals: List[String]):
        """Initialize multi-literal searcher.

        Args:
            literals: List of literal strings to search for.
        """
        self.literals = literals
        self.literal_count = min(len(literals), 16)
        self.max_len = 0
        self.min_len = 999999
        self.first_bytes = SIMD[DType.uint8, 16](0)

        # Initialize first bytes and find min/max lengths
        for i in range(self.literal_count):
            var lit = literals[i]
            if len(lit) > 0:
                self.first_bytes[i] = ord(lit[0])
                self.max_len = max(self.max_len, len(lit))
                self.min_len = min(self.min_len, len(lit))

    fn search(self, text: String, start: Int = 0) -> Tuple[Int, Int]:
        """Search for any literal in text.

        Args:
            text: Text to search in.
            start: Starting position.

        Returns:
            Tuple of (position, literal_index) for first match, or (-1, -1) if not found.
        """
        if self.literal_count == 0 or self.min_len == 0:
            return (-1, -1)

        var text_len = len(text)
        var pos = start

        # Process text in SIMD chunks
        while pos + SIMD_WIDTH <= text_len - self.min_len + 1:
            var chunk = text.unsafe_ptr().load[width=SIMD_WIDTH](pos)

            # Check if any first bytes match
            var any_match = SIMD[DType.bool, SIMD_WIDTH](False)
            for i in range(self.literal_count):
                var matches = chunk == SIMD[DType.uint8, SIMD_WIDTH](
                    self.first_bytes[i]
                )
                any_match = any_match | matches

            if any_match.reduce_or():
                # Found potential matches, verify each
                for offset in range(SIMD_WIDTH):
                    if any_match[offset]:
                        var text_pos = pos + offset

                        # Check each literal
                        for lit_idx in range(self.literal_count):
                            var lit = self.literals[lit_idx]
                            if len(lit) > 0 and text[text_pos] == lit[0]:
                                # Verify full literal
                                if self._verify_literal(text, text_pos, lit):
                                    return (text_pos, lit_idx)

            pos += SIMD_WIDTH

        # Handle remaining positions
        while pos <= text_len - self.min_len:
            for lit_idx in range(self.literal_count):
                var lit = self.literals[lit_idx]
                if self._verify_literal(text, pos, lit):
                    return (pos, lit_idx)
            pos += 1

        return (-1, -1)

    fn _verify_literal(self, text: String, pos: Int, literal: String) -> Bool:
        """Verify that literal matches at given position.

        Args:
            text: Text to check.
            pos: Position to check at.
            literal: Literal to verify.

        Returns:
            True if literal matches at position.
        """
        var lit_len = len(literal)
        if pos + lit_len > len(text):
            return False

        # Use SIMD comparison for longer literals
        if lit_len >= SIMD_WIDTH:
            return simd_memcmp(text, pos, literal, 0, lit_len)

        # Simple comparison for short literals
        for i in range(lit_len):
            if text[pos + i] != literal[i]:
                return False
        return True
