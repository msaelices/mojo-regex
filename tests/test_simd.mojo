from testing import assert_equal, assert_true, assert_false

from regex.simd_ops import (
    CharacterClassSIMD,
    _create_ascii_lowercase,
    _create_ascii_uppercase,
    _create_ascii_digits,
    _create_ascii_alphanumeric,
    _create_whitespace,
    simd_search,
    verify_match,
    simd_memcmp,
    simd_count_char,
)
from regex.dfa import DFAEngine


def test_character_class_simd_basic():
    """Test basic SIMD character class operations."""
    var char_class = CharacterClassSIMD("abc")

    # Test contains method
    assert_true(char_class.contains(ord("a")))
    assert_true(char_class.contains(ord("b")))
    assert_true(char_class.contains(ord("c")))
    assert_false(char_class.contains(ord("d")))
    assert_false(char_class.contains(ord("1")))


def test_character_class_simd_range():
    """Test SIMD character class with ranges."""
    var char_class = CharacterClassSIMD("a", "z")

    # Test range boundaries
    assert_true(char_class.contains(ord("a")))
    assert_true(char_class.contains(ord("z")))
    assert_true(char_class.contains(ord("m")))

    # Test outside range
    assert_false(char_class.contains(ord("A")))
    assert_false(char_class.contains(ord("1")))
    assert_false(char_class.contains(ord("@")))


def test_character_class_find_first():
    """Test finding first match with SIMD."""
    var char_class = CharacterClassSIMD("aeiou")  # vowels

    # Test finding first vowel
    assert_equal(char_class.find_first_match("hello world"), 1)  # 'e'
    assert_equal(char_class.find_first_match("programming"), 2)  # 'o'

    # Test no match
    assert_equal(char_class.find_first_match("xyz"), -1)

    # Test with start position
    assert_equal(char_class.find_first_match("hello world", 2), 4)  # 'o'


def test_character_class_find_all():
    """Test finding all matches with SIMD."""
    var char_class = CharacterClassSIMD("l")

    var matches = char_class.find_all_matches("hello world")
    assert_equal(len(matches), 3)
    assert_equal(matches[0], 2)
    assert_equal(matches[1], 3)
    assert_equal(matches[2], 9)


def test_character_class_count():
    """Test counting matches with SIMD."""
    var char_class = CharacterClassSIMD("a")

    assert_equal(char_class.count_matches("banana"), 3)
    assert_equal(char_class.count_matches("hello"), 0)
    assert_equal(char_class.count_matches("aardvark"), 3)

    # Test with range
    assert_equal(char_class.count_matches("banana", 1, 5), 2)  # "anan"


def test_ascii_lowercase():
    """Test predefined ASCII lowercase character class."""
    var lowercase = _create_ascii_lowercase()

    assert_true(lowercase.contains(ord("a")))
    assert_true(lowercase.contains(ord("z")))
    assert_true(lowercase.contains(ord("m")))

    assert_false(lowercase.contains(ord("A")))
    assert_false(lowercase.contains(ord("1")))
    assert_false(lowercase.contains(ord("@")))


def test_ascii_uppercase():
    """Test predefined ASCII uppercase character class."""
    var uppercase = _create_ascii_uppercase()

    assert_true(uppercase.contains(ord("A")))
    assert_true(uppercase.contains(ord("Z")))
    assert_true(uppercase.contains(ord("M")))

    assert_false(uppercase.contains(ord("a")))
    assert_false(uppercase.contains(ord("1")))
    assert_false(uppercase.contains(ord("@")))


def test_ascii_digits():
    """Test predefined ASCII digits character class."""
    var digits = _create_ascii_digits()

    assert_true(digits.contains(ord("0")))
    assert_true(digits.contains(ord("9")))
    assert_true(digits.contains(ord("5")))

    assert_false(digits.contains(ord("a")))
    assert_false(digits.contains(ord("A")))
    assert_false(digits.contains(ord("@")))


def test_ascii_alphanumeric():
    """Test predefined ASCII alphanumeric character class."""
    var alnum = _create_ascii_alphanumeric()

    # Test letters
    assert_true(alnum.contains(ord("a")))
    assert_true(alnum.contains(ord("Z")))

    # Test digits
    assert_true(alnum.contains(ord("0")))
    assert_true(alnum.contains(ord("9")))

    # Test non-alphanumeric
    assert_false(alnum.contains(ord("@")))
    assert_false(alnum.contains(ord(" ")))
    assert_false(alnum.contains(ord("!")))


def test_whitespace():
    """Test predefined whitespace character class."""
    var whitespace = _create_whitespace()

    assert_true(whitespace.contains(ord(" ")))
    assert_true(whitespace.contains(ord("\t")))
    assert_true(whitespace.contains(ord("\n")))
    assert_true(whitespace.contains(ord("\r")))

    assert_false(whitespace.contains(ord("a")))
    assert_false(whitespace.contains(ord("1")))


def test_simd_string_search():
    """Test SIMD-accelerated string search."""
    var pattern = "hello"
    var pattern_ptr = pattern.unsafe_ptr()
    var pattern_len = len(pattern)

    # Test basic search
    assert_equal(simd_search(pattern_ptr, pattern_len, "hello world"), 0)
    assert_equal(simd_search(pattern_ptr, pattern_len, "say hello there"), 4)
    assert_equal(simd_search(pattern_ptr, pattern_len, "goodbye"), -1)

    # Test with start position
    assert_equal(
        simd_search(pattern_ptr, pattern_len, "hello hello hello", 1), 6
    )


def test_simd_string_search_all():
    """Test finding all occurrences with SIMD string search."""
    var pattern = "ll"
    var pattern_ptr = pattern.unsafe_ptr()
    var pattern_len = len(pattern)
    var text = "hello world, all well"

    # Find all non-overlapping occurrences manually using simd_search
    var positions = List[Int]()
    var start = 0

    while True:
        var pos = simd_search(pattern_ptr, pattern_len, text, start)
        if pos == -1:
            break
        positions.append(pos)
        # Move past this match to avoid overlapping matches
        start = pos + pattern_len

    assert_equal(len(positions), 3)
    assert_equal(positions[0], 2)  # "hello"
    assert_equal(positions[1], 14)  # "all"
    assert_equal(positions[2], 19)  # "well"


def test_simd_string_search_empty():
    """Test SIMD string search with empty pattern."""
    var pattern = ""
    var pattern_ptr = pattern.unsafe_ptr()
    var pattern_len = len(pattern)

    # Empty pattern should match at any position
    assert_equal(simd_search(pattern_ptr, pattern_len, "hello"), 0)
    assert_equal(simd_search(pattern_ptr, pattern_len, "hello", 2), 2)


def test_simd_string_search_single_char():
    """Test SIMD string search with single character."""
    var pattern = "a"
    var pattern_ptr = pattern.unsafe_ptr()
    var pattern_len = len(pattern)

    assert_equal(simd_search(pattern_ptr, pattern_len, "banana"), 1)
    assert_equal(simd_search(pattern_ptr, pattern_len, "hello"), -1)

    # Find all occurrences manually using simd_search
    var positions = List[Int]()
    var text = "banana"
    var start = 0

    while True:
        var pos = simd_search(pattern_ptr, pattern_len, text, start)
        if pos == -1:
            break
        positions.append(pos)
        # Move past this match to avoid overlapping matches
        start = pos + pattern_len

    assert_equal(len(positions), 3)
    assert_equal(positions[0], 1)
    assert_equal(positions[1], 3)
    assert_equal(positions[2], 5)


def test_simd_memcmp():
    """Test SIMD-accelerated memory comparison."""
    assert_true(simd_memcmp("hello", 0, "hello", 0, 5))
    assert_true(simd_memcmp("hello world", 0, "hello there", 0, 5))
    assert_false(simd_memcmp("hello", 0, "world", 0, 5))

    # Test with offsets
    assert_true(simd_memcmp("hello world", 6, "world peace", 0, 5))
    assert_false(simd_memcmp("hello world", 6, "peace", 0, 5))

    # Test zero length
    assert_true(simd_memcmp("abc", 0, "xyz", 0, 0))


def test_simd_count_char():
    """Test SIMD character counting."""
    assert_equal(simd_count_char("hello world", "l"), 3)
    assert_equal(simd_count_char("banana", "a"), 3)
    assert_equal(simd_count_char("hello", "x"), 0)

    # Test single character
    assert_equal(simd_count_char("a", "a"), 1)
    assert_equal(simd_count_char("", "a"), 0)


def test_character_class_performance():
    """Test character class with larger text for performance validation."""
    var char_class = CharacterClassSIMD("aeiou")

    # Create a longer string for testing SIMD efficiency
    var long_text = "the quick brown fox jumps over the lazy dog " * 10

    # This should find multiple vowels efficiently
    var first_match = char_class.find_first_match(long_text)
    assert_true(first_match >= 0)

    var all_matches = char_class.find_all_matches(long_text)
    assert_true(len(all_matches) > 10)  # Should find many vowels

    var count = char_class.count_matches(long_text)
    assert_equal(count, len(all_matches))


def test_simd_edge_cases():
    """Test SIMD operations with edge cases."""
    # Empty string
    var char_class = CharacterClassSIMD("abc")
    assert_equal(char_class.find_first_match(""), -1)
    assert_equal(len(char_class.find_all_matches("")), 0)
    assert_equal(char_class.count_matches(""), 0)

    # Single character string
    assert_equal(char_class.find_first_match("a"), 0)
    assert_equal(char_class.find_first_match("x"), -1)

    # Empty character class
    var empty_class = CharacterClassSIMD("")
    assert_equal(empty_class.find_first_match("hello"), -1)
    assert_equal(len(empty_class.find_all_matches("hello")), 0)
