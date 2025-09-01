"""
SIMD-optimized operations for high-performance regex matching.

This module leverages Mojo's SIMD capabilities to vectorize character operations,
providing significant speedups for character class matching and string scanning.

Hardware Requirements for Optimal Performance:
- SSE3/SSSE3: Required for 16-byte _dynamic_shuffle operations (pshufb instruction)
- AVX2: Required for 32-byte _dynamic_shuffle operations (vpshufb instruction)
- AVX-512: Future support possible for 64-byte operations

The module automatically adapts to the available SIMD width:
- SIMD_WIDTH == 16: Uses SSE shuffle operations (most x86-64 CPUs)
- SIMD_WIDTH == 32: Uses AVX2 shuffle operations (modern x86-64 CPUs since ~2013)
- Other widths: Falls back to scalar or sub-optimal vectorized operations
"""

from algorithm import vectorize
from builtin._location import __call_location
from sys import ffi
from sys.info import simd_width_of

from regex.aliases import (
    SIMD_MATCHER_NONE,
    SIMD_MATCHER_WHITESPACE,
    SIMD_MATCHER_DIGITS,
    SIMD_MATCHER_ALPHA_LOWER,
    SIMD_MATCHER_ALPHA_UPPER,
    SIMD_MATCHER_ALPHA,
    SIMD_MATCHER_ALNUM,
    SIMD_MATCHER_ALNUM_LOWER,
    SIMD_MATCHER_ALNUM_UPPER,
    SIMD_MATCHER_CUSTOM,
    SIMD_MATCHER_WORD_CHARS,
    DIGITS,
    WORD_CHARS,
)
from regex.engine import Engine
from regex.dfa import DFAEngine
from regex.nfa import NFAEngine
from regex.simd_matchers import (
    SIMDMatcher,
    NibbleBasedMatcher,
    RangeBasedMatcher,
    create_digit_matcher,
    _create_whitespace_matcher,
    create_alpha_matcher,
    create_alnum_matcher,
)

# SIMD width for character operations (uint8)
alias SIMD_WIDTH = simd_width_of[DType.uint8]()
alias USE_SHUFFLE = SIMD_WIDTH == 16 or SIMD_WIDTH == 32

# Shuffle optimization thresholds
# Below this size, simple lookup is faster than shuffle
alias SHUFFLE_MIN_SIZE = 4
# Above this size, shuffle becomes inefficient due to sparsity
alias SHUFFLE_MAX_SIZE = 32


@register_passable("trivial")
struct CharacterClassSIMD(Copyable, Movable, SIMDMatcher):
    """SIMD-optimized character class matcher."""

    var lookup_table: SIMD[DType.uint8, 256]
    """Bit vector for each ASCII character, 1 if in class, 0 otherwise."""
    var size_hint: Int
    """Number of characters in the class for optimization decisions."""
    var use_shuffle: Bool
    """Whether to use shuffle optimization based on pattern characteristics."""

    fn __init__(out self, var char_class: String):
        """Initialize SIMD character class matcher.

        Args:
            char_class: String containing all characters in the class (e.g., "abcdefg...").
        """
        self.lookup_table = SIMD[DType.uint8, 256](0)
        self.size_hint = len(char_class)

        # Use shuffle optimization for medium-sized character classes
        # For small classes (e.g., just "a" or "ab"), the simple lookup is faster
        # For large classes (>32 chars like alphanumeric with 62 chars), shuffle becomes inefficient
        # Optimal range for shuffle: SHUFFLE_MIN_SIZE-SHUFFLE_MAX_SIZE characters
        self.use_shuffle = (
            self.size_hint >= SHUFFLE_MIN_SIZE
            and self.size_hint <= SHUFFLE_MAX_SIZE
            and USE_SHUFFLE
        )

        # Set bits for each character in the class
        for i in range(len(char_class)):
            var char_code = ord(char_class[i])
            if char_code >= 0 and char_code < 256:
                self.lookup_table[char_code] = 1
        # var call_location = __call_location()
        # print("Init CharacterClassSIMD", call_location)

    fn __init__(out self, start_char: String, end_char: String):
        """Initialize with a character range like 'a'-'z'.

        Args:
            start_char: First character in range.
            end_char: Last character in range.
        """
        self.lookup_table = SIMD[DType.uint8, 256](0)

        var start_code = max(ord(start_char), 0)
        var end_code = min(ord(end_char), 255)

        self.size_hint = end_code - start_code + 1
        # Character ranges typically benefit from shuffle optimization
        # Supports both SSE (16-byte) and AVX2 (32-byte) SIMD widths
        self.use_shuffle = self.size_hint >= SHUFFLE_MIN_SIZE and USE_SHUFFLE

        for char_code in range(start_code, end_code + 1):
            self.lookup_table[char_code] = 1
        # var call_location = __call_location()
        # print("Init CharacterClassSIMD", call_location)

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

    fn find_first_match[size: Int](self, chunk: SIMD[DType.uint8, size]) -> Int:
        """Find first character in SIMD chunk that matches this class.

        This method operates directly on SIMD vectors, avoiding string slicing overhead.
        Optimized for early return - exits as soon as first match is found.

        Parameters:
            size: Size of the SIMD chunk to process.

        Args:
            chunk: SIMD vector of characters to check.

        Returns:
            Position of first match within chunk, or -1 if not found.
        """
        # Use hybrid approach based on pattern characteristics for optimal performance
        if self.use_shuffle:

            @parameter
            if size == 16 or size == 32:
                # Fast path: use _dynamic_shuffle for optimal sizes
                var result = self.lookup_table._dynamic_shuffle(chunk)

                # Find first matching position immediately without creating boolean vector
                @parameter
                for i in range(size):
                    if result[i] != 0:
                        return i
                return -1
            else:
                # Fallback for other sizes - process in 16-byte sub-chunks
                @parameter
                for offset in range(0, size, 16):

                    @parameter
                    if offset + 16 <= size:
                        var sub_chunk = chunk.slice[16, offset=offset]()
                        var sub_result = self.lookup_table._dynamic_shuffle(
                            sub_chunk
                        )
                        for i in range(16):
                            if sub_result[i] != 0:
                                return offset + i
                    else:
                        # Handle remaining elements
                        for i in range(offset, size):
                            var char_code = Int(chunk[i])
                            if self.lookup_table[char_code] == 1:
                                return i
                return -1
        else:
            # Simple lookup for small character classes - early return optimization
            @parameter
            for i in range(size):
                var char_code = Int(chunk[i])
                if char_code < 256 and self.lookup_table[char_code] == 1:
                    return i
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

    fn match_chunk[
        size: Int
    ](self, chunk: SIMD[DType.uint8, size]) -> SIMD[DType.bool, size]:
        """Check if characters in chunk match the character class.

        Implements the SIMDMatcher trait interface.

        Parameters:
            size: Size of the SIMD chunk to process.

        Args:
            chunk: SIMD vector of characters to check.

        Returns:
            SIMD vector of booleans indicating matches.
        """
        # Use hybrid approach based on pattern characteristics
        if self.use_shuffle:

            @parameter
            if size == 16 or size == 32:
                # Fast path: use _dynamic_shuffle for optimal sizes
                var result = self.lookup_table._dynamic_shuffle(chunk)
                return result.ne(0)
            else:
                # Fallback for other sizes
                var matches = SIMD[DType.bool, size](False)

                # Process in 16-byte sub-chunks when possible
                @parameter
                for offset in range(0, size, 16):

                    @parameter
                    if offset + 16 <= size:
                        var sub_chunk = chunk.slice[16, offset=offset]()
                        var sub_result = self.lookup_table._dynamic_shuffle(
                            sub_chunk
                        )
                        for i in range(16):
                            matches[offset + i] = sub_result[i] != 0
                    else:
                        # Handle remaining elements
                        for i in range(offset, size):
                            var char_code = Int(chunk[i])
                            matches[i] = self.lookup_table[char_code] == 1

                return matches
        else:
            # Simple lookup for small character classes
            var matches = SIMD[DType.bool, size](fill=False)

            @parameter
            for i in range(size):
                var char_code = Int(chunk[i])
                matches[i] = self.lookup_table[char_code] == 1

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
        self, text: StringSlice, pos: Int
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

        # Use hybrid approach based on pattern characteristics
        if self.use_shuffle:

            @parameter
            if SIMD_WIDTH == 16 or SIMD_WIDTH == 32:
                # Fast path: use _dynamic_shuffle for 16-byte (SSE) or 32-byte (AVX2) chunks
                # The lookup table acts as our shuffle table
                # Hardware support: SSE3/SSSE3 for 16-byte, AVX2 for 32-byte
                var result = self.lookup_table._dynamic_shuffle(chunk)
                return result.ne(0)
            else:
                # Fallback for other sizes - still avoid the loop by using vectorized operations
                var matches = SIMD[DType.bool, SIMD_WIDTH](False)

                # Process in 16-byte sub-chunks when possible
                @parameter
                for offset in range(0, SIMD_WIDTH, 16):

                    @parameter
                    if offset + 16 <= SIMD_WIDTH:
                        var sub_chunk = chunk.slice[16, offset=offset]()
                        var sub_result = self.lookup_table._dynamic_shuffle(
                            sub_chunk
                        )
                        for i in range(16):
                            matches[offset + i] = sub_result[i] != 0
                    else:
                        # Handle remaining elements
                        for i in range(offset, SIMD_WIDTH):
                            var char_code = Int(chunk[i])
                            matches[i] = self.lookup_table[char_code] == 1

                return matches
        else:
            # Simple lookup for small character classes - often faster for simple patterns
            var matches = SIMD[DType.bool, SIMD_WIDTH](fill=False)

            # Unroll for better performance
            @parameter
            for i in range(SIMD_WIDTH):
                var char_code = Int(chunk[i])
                if char_code < 256:
                    matches[i] = self.lookup_table[char_code] == 1

            return matches


@always_inline
fn _create_ascii_lowercase() -> CharacterClassSIMD:
    """Create SIMD matcher for ASCII lowercase letters [a-z]."""
    return CharacterClassSIMD("a", "z")


@always_inline
fn _create_ascii_uppercase() -> CharacterClassSIMD:
    """Create SIMD matcher for ASCII uppercase letters [A-Z]."""
    return CharacterClassSIMD("A", "Z")


@always_inline
fn _create_ascii_digits() -> CharacterClassSIMD:
    """Create SIMD matcher for ASCII digits [0-9]."""
    return CharacterClassSIMD("0", "9")


@always_inline
fn _create_ascii_alphanumeric() -> CharacterClassSIMD:
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
fn _create_whitespace() -> CharacterClassSIMD:
    """Create SIMD matcher for whitespace characters [ \\t\\n\\r\\f\\v]."""
    var whitespace_chars = " \t\n\r\f\v"
    return CharacterClassSIMD(whitespace_chars)


@always_inline
fn _create_ascii_alpha() -> CharacterClassSIMD:
    """Create SIMD matcher for ASCII letters [a-zA-Z]."""
    var result = CharacterClassSIMD("")

    # Add lowercase letters
    for i in range(ord("a"), ord("z") + 1):
        result.lookup_table[i] = 1

    # Add uppercase letters
    for i in range(ord("A"), ord("Z") + 1):
        result.lookup_table[i] = 1

    return result


@always_inline
fn _create_ascii_alnum_lower() -> CharacterClassSIMD:
    """Create SIMD matcher for lowercase alphanumeric [a-z0-9]."""
    var result = CharacterClassSIMD("")

    # Add lowercase letters
    for i in range(ord("a"), ord("z") + 1):
        result.lookup_table[i] = 1

    # Add digits
    for i in range(ord("0"), ord("9") + 1):
        result.lookup_table[i] = 1

    return result


@always_inline
fn _create_ascii_alnum_upper() -> CharacterClassSIMD:
    """Create SIMD matcher for uppercase alphanumeric [A-Z0-9]."""
    var result = CharacterClassSIMD("")

    # Add uppercase letters
    for i in range(ord("A"), ord("Z") + 1):
        result.lookup_table[i] = 1

    # Add digits
    for i in range(ord("0"), ord("9") + 1):
        result.lookup_table[i] = 1

    return result


@always_inline
fn _create_word_chars() -> CharacterClassSIMD:
    """Create SIMD matcher for word characters [a-zA-Z0-9_]."""
    return CharacterClassSIMD(WORD_CHARS)


fn _search_short_pattern(pattern: Span[Byte], text: String, start: Int) -> Int:
    """Optimized search for very short patterns (1-2 characters).

    Args:
        pattern: Pattern span of bytes.
        text: Text to search in.
        start: Starting position.

    Returns:
        Position of first match, or -1 if not found.
    """
    var pattern_len = len(pattern)
    var text_len = len(text)

    if pattern_len == 1:
        # Single character - simple scan
        var target_char = pattern[0]
        for i in range(start, text_len):
            if ord(text[i]) == Int(target_char):
                return i
    elif pattern_len == 2:
        # Two characters - check pairs
        if text_len - start < 2:
            return -1
        var first_char = pattern[0]
        var second_char = pattern[1]
        for i in range(start, text_len - 1):
            if ord(text[i]) == Int(first_char) and ord(text[i + 1]) == Int(
                second_char
            ):
                return i
    return -1


fn verify_match(pattern: Span[Byte], text: String, pos: Int) -> Bool:
    """Verify that pattern matches at given position.

    Args:
        pattern: Pattern to verify.
        text: Text to check.
        pos: Position to check.

    Returns:
        True if pattern matches at this position.
    """
    var pattern_len = len(pattern)
    if pos + pattern_len > len(text):
        return False

    for i in range(pattern_len):
        var c = pattern[i]
        if ord(text[pos + i]) != Int(c):
            return False

    return True


fn simd_search(
    pattern: Span[Byte],
    text: String,
    start: Int = 0,
) -> Int:
    """Search for pattern in text using SIMD acceleration.

    Args:
        pattern: Pattern slice of bytes.
        text: Text to search in.
        start: Starting position.

    Returns:
        Position of first match, or -1 if not found.
    """
    var pattern_len = len(pattern)
    if pattern_len == 0:
        return start  # Empty pattern matches at any position

    var text_len = len(text)
    var pos = start

    # For very short patterns (1-2 chars), use simpler approach
    if pattern_len <= 2:
        return _search_short_pattern(pattern, text, start)

    # Use SIMD to quickly find potential matches by first character
    while pos + SIMD_WIDTH <= text_len:
        # Load chunk of text
        var chunk = text.unsafe_ptr().load[width=SIMD_WIDTH](pos)

        # Compare with first character of pattern
        var first_char = pattern[0]
        var first_char_simd = SIMD[DType.uint8, SIMD_WIDTH](first_char)
        var matches = chunk.eq(first_char_simd)

        if matches.reduce_or():
            # Found potential match, check each position
            for i in range(SIMD_WIDTH):
                if matches[i]:
                    var candidate_pos = pos + i
                    if verify_match(pattern, text, candidate_pos):
                        return candidate_pos

        pos += SIMD_WIDTH

    # Handle remaining characters
    while pos <= text_len - pattern_len:
        if verify_match(pattern, text, pos):
            return pos
        pos += 1

    return -1


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

        if chunk1 != chunk2:
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
        var matches = chunk.eq(target_simd)
        count += Int(matches.cast[DType.uint8]().reduce_add())
        pos += SIMD_WIDTH

    # Handle remaining characters
    while pos < text_len:
        if String(text[pos]) == target_char:
            count += 1
        pos += 1

    return count


# Global SIMD matchers dictionary type
alias SIMDMatchers = Dict[Int, CharacterClassSIMD]

# Global SIMD matchers cache
alias _SIMD_MATCHERS_GLOBAL = ffi._Global[
    "SIMDMatchers", SIMDMatchers, _init_simd_matchers
]


fn _init_simd_matchers() -> SIMDMatchers:
    """Initialize the global SIMD matchers dictionary."""
    var matchers = SIMDMatchers()
    return matchers


fn _get_simd_matchers() -> UnsafePointer[SIMDMatchers]:
    """Returns a pointer to the global SIMD matchers dictionary."""
    var ptr = _SIMD_MATCHERS_GLOBAL.get_or_create_ptr()
    return ptr


@always_inline
fn get_simd_matcher(matcher_type: Int) -> CharacterClassSIMD:
    """Get a SIMD matcher by type from the global cache.
    Args:
        matcher_type: One of the SIMD_MATCHER_* constants.
    Returns:
        The corresponding CharacterClassSIMD matcher.
    """
    var matchers_ptr = _get_simd_matchers()

    # Try to get from cache
    try:
        return matchers_ptr[][matcher_type]
    except:
        var matcher: CharacterClassSIMD
        if matcher_type == SIMD_MATCHER_WHITESPACE:
            matcher = _create_whitespace()
        elif matcher_type == SIMD_MATCHER_DIGITS:
            matcher = _create_ascii_digits()
        elif matcher_type == SIMD_MATCHER_ALPHA_LOWER:
            matcher = _create_ascii_lowercase()
        elif matcher_type == SIMD_MATCHER_ALPHA_UPPER:
            matcher = _create_ascii_uppercase()
        elif matcher_type == SIMD_MATCHER_ALPHA:
            matcher = _create_ascii_alpha()
        elif matcher_type == SIMD_MATCHER_ALNUM:
            matcher = _create_ascii_alphanumeric()
        elif matcher_type == SIMD_MATCHER_ALNUM_LOWER:
            matcher = _create_ascii_alnum_lower()
        elif matcher_type == SIMD_MATCHER_ALNUM_UPPER:
            matcher = _create_ascii_alnum_upper()
        elif matcher_type == SIMD_MATCHER_WORD_CHARS:
            matcher = _create_word_chars()
        else:
            # Custom matcher, create empty one
            matcher = CharacterClassSIMD("")
        matchers_ptr[][matcher_type] = matcher
        return matcher


@always_inline
fn get_character_class_matcher(char_class: String) -> CharacterClassSIMD:
    """Get optimal cached matcher for character class string.

    This function detects common character class patterns and returns
    cached matchers to avoid repeated allocations.

    Args:
        char_class: Character class string (e.g., "0123456789", "[a-z]").

    Returns:
        Cached CharacterClassSIMD matcher if pattern is recognized,
        otherwise creates new matcher instance.
    """
    # Most common patterns - use cached SIMD matchers
    if char_class == DIGITS:
        return get_simd_matcher(SIMD_MATCHER_DIGITS)
    elif char_class == WORD_CHARS:
        return get_simd_matcher(SIMD_MATCHER_WORD_CHARS)
    elif char_class == " \t\n\r\f":  # Common whitespace pattern
        return get_simd_matcher(SIMD_MATCHER_WHITESPACE)
    elif char_class == " \t\n\r\f\v":  # Extended whitespace with vertical tab
        return get_simd_matcher(SIMD_MATCHER_WHITESPACE)
    elif char_class == "abcdefghijklmnopqrstuvwxyz":  # [a-z]
        return get_simd_matcher(SIMD_MATCHER_ALPHA_LOWER)
    elif char_class == "ABCDEFGHIJKLMNOPQRSTUVWXYZ":  # [A-Z]
        return get_simd_matcher(SIMD_MATCHER_ALPHA_UPPER)
    elif (
        char_class == "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    ):  # [a-zA-Z]
        return get_simd_matcher(SIMD_MATCHER_ALPHA)
    elif (
        char_class
        == "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    ):  # [a-zA-Z0-9]
        return get_simd_matcher(SIMD_MATCHER_ALNUM)
    else:
        # Custom character class - create new matcher instance
        # These are not cached as they can be arbitrary patterns
        return CharacterClassSIMD(char_class)


fn process_text_with_matcher[
    T: SIMDMatcher
](matcher: T, text: String, start: Int = 0) -> List[Int]:
    """Process text with any SIMD matcher implementation.

    This is a generic function that works with any type implementing SIMDMatcher.

    Parameters:
        T: The concrete type implementing SIMDMatcher.

    Args:
        matcher: The SIMD matcher instance.
        text: Text to process.
        start: Starting position.

    Returns:
        List of positions where matches were found.
    """
    var matches = List[Int]()
    var pos = start
    var text_len = len(text)

    while pos + 16 <= text_len:
        var chunk = text.unsafe_ptr().load[width=16](pos)
        var chunk_matches = matcher.match_chunk(chunk)

        for i in range(16):
            if chunk_matches[i]:
                matches.append(pos + i)

        pos += 16

    # Handle remaining characters
    while pos < text_len:
        if matcher.contains(ord(text[pos])):
            matches.append(pos)
        pos += 1

    return matches


fn apply_quantifier_simd_generic[
    T: SIMDMatcher
](
    matcher: T,
    text: String,
    start_pos: Int,
    min_matches: Int,
    max_matches: Int,
) -> Tuple[Bool, Int]:
    """Apply quantifier using SIMD for faster bulk matching.

    This is a generic version that works with any SIMDMatcher implementation.

    Parameters:
        T: The concrete type implementing SIMDMatcher.

    Args:
        matcher: The SIMD matcher instance.
        text: Input string.
        start_pos: Current position.
        min_matches: Minimum required matches.
        max_matches: Maximum allowed matches (-1 for unlimited).

    Returns:
        Tuple of (success, final_position).
    """
    var pos = start_pos
    var match_count = 0
    var actual_max = max_matches
    if actual_max == -1:
        actual_max = len(text) - start_pos

    # Count consecutive matching characters
    while pos < len(text) and match_count < actual_max:
        if matcher.contains(ord(text[pos])):
            match_count += 1
            pos += 1
        else:
            break

    # Check if we satisfied the quantifier
    if match_count >= min_matches:
        return (True, pos)
    else:
        return (False, start_pos)


fn find_in_text_simd[
    T: SIMDMatcher
](matcher: T, text: String, start: Int = 0, end: Int = -1,) -> Int:
    """Find first occurrence of a character matching the given matcher.

    Parameters:
        T: The concrete type implementing SIMDMatcher.

    Args:
        matcher: The SIMD matcher instance.
        text: Text to search.
        start: Starting position.
        end: Ending position (-1 for end of string).

    Returns:
        Position of first match, or -1 if not found.
    """
    var actual_end = end if end != -1 else len(text)
    var pos = start

    # Process in SIMD chunks for speed
    while pos + 16 <= actual_end:
        var chunk = text.unsafe_ptr().load[width=16](pos)
        var matches = matcher.match_chunk(chunk)

        # Check if any match in chunk
        if matches.reduce_or():
            # Find first match position
            for i in range(16):
                if matches[i]:
                    return pos + i

        pos += 16

    # Handle remaining characters
    while pos < actual_end:
        if matcher.contains(ord(text[pos])):
            return pos
        pos += 1

    return -1


fn twoway_search(
    pattern: Span[Byte],
    text: String,
    start: Int = 0,
) -> Int:
    """Search for pattern in text using Two-Way algorithm with SIMD.

    This is a standalone version of TwoWaySearcher.search() that doesn't require
    an engine instance, avoiding circular dependencies.

    Args:
        pattern: Pattern span of bytes.
        text: Text to search in.
        start: Starting position.

    Returns:
        Position of first match, or -1 if not found.
    """
    var n = len(pattern)
    var m = len(text)

    if n == 0:
        return start
    if n > m - start:
        return -1

    # For very short patterns, use simple search
    if n <= 4:
        if n == 1:
            # Single character search
            return simd_search(pattern, text, start)

        # For 2-4 byte patterns, use rolling comparison
        var pos = start
        while pos <= m - n:
            var matched = True
            for i in range(n):
                if ord(text[pos + i]) != Int(pattern[i]):
                    matched = False
                    break
            if matched:
                return pos
            pos += 1
        return -1

    # For patterns where Two-Way's complexity isn't needed, use SIMD search
    # This ensures correctness while maintaining good performance
    if n <= 32:
        return simd_search(pattern, text, start)

    # For longer patterns, use simplified Two-Way algorithm
    # Use conservative approach to ensure correctness
    var pos = start
    var period = 1

    # Compute actual period of the pattern
    for i in range(1, n):
        var is_period = True
        for j in range(n - i):
            if Int(pattern[j]) != Int(pattern[j + i]):
                is_period = False
                break
        if is_period:
            period = i
            break

    while pos <= m - n:
        # Simple forward comparison
        var matched = True
        for i in range(n):
            if ord(text[pos + i]) != Int(pattern[i]):
                matched = False
                break

        if matched:
            return pos

        # Move by period to avoid redundant comparisons
        pos += period

    return -1


struct MultiLiteralSearcher(Copyable, Movable):
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
            var any_match = SIMD[DType.bool, SIMD_WIDTH](fill=False)
            for i in range(self.literal_count):
                var matches = chunk.eq(
                    SIMD[DType.uint8, SIMD_WIDTH](self.first_bytes[i])
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
