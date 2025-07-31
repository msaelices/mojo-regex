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
            if char_code >= 0 and char_code < 256:
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


struct SIMDStringSearch:
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
        """Find all occurrences of pattern in text.

        Args:
            text: Text to search.

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
            start = pos + 1

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
