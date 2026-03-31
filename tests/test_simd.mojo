from std.testing import assert_equal, assert_true, assert_false, TestSuite

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


def test_character_class_simd_basic() raises:
    """Test basic SIMD character class operations."""
    var char_class = CharacterClassSIMD("abc")

    # Test contains method
    assert_true(char_class.contains(ord("a")))
    assert_true(char_class.contains(ord("b")))
    assert_true(char_class.contains(ord("c")))
    assert_false(char_class.contains(ord("d")))
    assert_false(char_class.contains(ord("1")))


def test_character_class_simd_range() raises:
    """Test SIMD character class with ranges."""
    var char_class = CharacterClassSIMD(ord("a"), ord("z"))

    # Test range boundaries
    assert_true(char_class.contains(ord("a")))
    assert_true(char_class.contains(ord("z")))
    assert_true(char_class.contains(ord("m")))

    # Test outside range
    assert_false(char_class.contains(ord("A")))
    assert_false(char_class.contains(ord("1")))
    assert_false(char_class.contains(ord("@")))


def test_character_class_find_first() raises:
    """Test finding first match with SIMD."""
    var char_class = CharacterClassSIMD("aeiou")  # vowels

    # Test finding first vowel
    assert_equal(char_class.find_first_match("hello world"), 1)  # 'e'
    assert_equal(char_class.find_first_match("programming"), 2)  # 'o'

    # Test no match
    assert_equal(char_class.find_first_match("xyz"), -1)

    # Test with start position
    assert_equal(char_class.find_first_match("hello world", 2), 4)  # 'o'


def test_character_class_find_all() raises:
    """Test finding all matches with SIMD."""
    var char_class = CharacterClassSIMD("l")

    var matches = char_class.find_all_matches("hello world")
    assert_equal(len(matches), 3)
    assert_equal(matches[0], 2)
    assert_equal(matches[1], 3)
    assert_equal(matches[2], 9)


def test_character_class_count() raises:
    """Test counting matches with SIMD."""
    var char_class = CharacterClassSIMD("a")

    assert_equal(char_class.count_matches("banana"), 3)
    assert_equal(char_class.count_matches("hello"), 0)
    assert_equal(char_class.count_matches("aardvark"), 3)

    # Test with range
    assert_equal(char_class.count_matches("banana", 1, 5), 2)  # "anan"


def test_ascii_lowercase() raises:
    """Test predefined ASCII lowercase character class."""
    var lowercase = _create_ascii_lowercase()

    assert_true(lowercase.contains(ord("a")))
    assert_true(lowercase.contains(ord("z")))
    assert_true(lowercase.contains(ord("m")))

    assert_false(lowercase.contains(ord("A")))
    assert_false(lowercase.contains(ord("1")))
    assert_false(lowercase.contains(ord("@")))


def test_ascii_uppercase() raises:
    """Test predefined ASCII uppercase character class."""
    var uppercase = _create_ascii_uppercase()

    assert_true(uppercase.contains(ord("A")))
    assert_true(uppercase.contains(ord("Z")))
    assert_true(uppercase.contains(ord("M")))

    assert_false(uppercase.contains(ord("a")))
    assert_false(uppercase.contains(ord("1")))
    assert_false(uppercase.contains(ord("@")))


def test_ascii_digits() raises:
    """Test predefined ASCII digits character class."""
    var digits = _create_ascii_digits()

    assert_true(digits.contains(ord("0")))
    assert_true(digits.contains(ord("9")))
    assert_true(digits.contains(ord("5")))

    assert_false(digits.contains(ord("a")))
    assert_false(digits.contains(ord("A")))
    assert_false(digits.contains(ord("@")))


def test_ascii_alphanumeric() raises:
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


def test_whitespace() raises:
    """Test predefined whitespace character class."""
    var whitespace = _create_whitespace()

    assert_true(whitespace.contains(ord(" ")))
    assert_true(whitespace.contains(ord("\t")))
    assert_true(whitespace.contains(ord("\n")))
    assert_true(whitespace.contains(ord("\r")))

    assert_false(whitespace.contains(ord("a")))
    assert_false(whitespace.contains(ord("1")))


def test_simd_string_search() raises:
    """Test SIMD-accelerated string search."""
    var pattern = "hello"
    var pattern_span = Span[Byte](ptr=pattern.unsafe_ptr(), length=len(pattern))

    # Test basic search
    assert_equal(simd_search(pattern_span, "hello world"), 0)
    assert_equal(simd_search(pattern_span, "say hello there"), 4)
    assert_equal(simd_search(pattern_span, "goodbye"), -1)

    # Test with start position
    assert_equal(simd_search(pattern_span, "hello hello hello", 1), 6)


def test_simd_string_search_all() raises:
    """Test finding all occurrences with SIMD string search."""
    var pattern = "ll"
    var pattern_span = Span[Byte](ptr=pattern.unsafe_ptr(), length=len(pattern))
    var text = "hello world, all well"

    # Find all non-overlapping occurrences manually using simd_search
    var positions = List[Int]()
    var start = 0

    while True:
        var pos = simd_search(pattern_span, text, start)
        if pos == -1:
            break
        positions.append(pos)
        # Move past this match to avoid overlapping matches
        start = pos + len(pattern)

    assert_equal(len(positions), 3)
    assert_equal(positions[0], 2)  # "hello"
    assert_equal(positions[1], 14)  # "all"
    assert_equal(positions[2], 19)  # "well"


def test_simd_string_search_empty() raises:
    """Test SIMD string search with empty pattern."""
    var pattern = ""
    var pattern_span = Span[Byte](ptr=pattern.unsafe_ptr(), length=len(pattern))

    # Empty pattern should match at any position
    assert_equal(simd_search(pattern_span, "hello"), 0)
    assert_equal(simd_search(pattern_span, "hello", 2), 2)


def test_simd_string_search_single_char() raises:
    """Test SIMD string search with single character."""
    var pattern = "a"
    var pattern_span = Span[Byte](ptr=pattern.unsafe_ptr(), length=len(pattern))

    assert_equal(simd_search(pattern_span, "banana"), 1)
    assert_equal(simd_search(pattern_span, "hello"), -1)

    # Find all occurrences manually using simd_search
    var positions = List[Int]()
    var text = "banana"
    var start = 0

    while True:
        var pos = simd_search(pattern_span, text, start)
        if pos == -1:
            break
        positions.append(pos)
        # Move past this match to avoid overlapping matches
        start = pos + len(pattern)

    assert_equal(len(positions), 3)
    assert_equal(positions[0], 1)
    assert_equal(positions[1], 3)
    assert_equal(positions[2], 5)


def test_simd_memcmp() raises:
    """Test SIMD-accelerated memory comparison."""
    assert_true(simd_memcmp("hello", 0, "hello", 0, 5))
    assert_true(simd_memcmp("hello world", 0, "hello there", 0, 5))
    assert_false(simd_memcmp("hello", 0, "world", 0, 5))

    # Test with offsets
    assert_true(simd_memcmp("hello world", 6, "world peace", 0, 5))
    assert_false(simd_memcmp("hello world", 6, "peace", 0, 5))

    # Test zero length
    assert_true(simd_memcmp("abc", 0, "xyz", 0, 0))


def test_simd_count_char() raises:
    """Test SIMD character counting."""
    assert_equal(simd_count_char("hello world", "l"), 3)
    assert_equal(simd_count_char("banana", "a"), 3)
    assert_equal(simd_count_char("hello", "x"), 0)

    # Test single character
    assert_equal(simd_count_char("a", "a"), 1)
    assert_equal(simd_count_char("", "a"), 0)


def test_character_class_performance() raises:
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


def test_simd_edge_cases() raises:
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


def test_nibble_table_high_nibble_chars() raises:
    """Regression test for nibble table overflow with chars having nibble >= 8.

    Characters like '8' (0x38, lo=8), '9' (0x39, lo=9), '(' (0x28, lo=8)
    had their nibble table bits overflow UInt8 when using (1 << nibble),
    causing find_first_nibble_match to miss them entirely.
    """
    # [89] - both chars have lo nibble >= 8
    var matcher_89 = CharacterClassSIMD("89")
    var text_89 = String("Call 8001234567")
    var pos_89 = matcher_89.find_first_nibble_match(
        text_89.unsafe_ptr(), 0, len(text_89)
    )
    assert_equal(pos_89, 5)  # '8' at position 5

    # Single '(' - lo nibble = 8
    var matcher_paren = CharacterClassSIMD("(")
    var text_paren = String("hello (world)")
    var pos_paren = matcher_paren.find_first_nibble_match(
        text_paren.unsafe_ptr(), 0, len(text_paren)
    )
    assert_equal(pos_paren, 6)  # '(' at position 6

    # [89] findall via matcher - verifies the full pipeline
    from regex.matcher import compile_regex

    var compiled = compile_regex("[89]00[0-9]+")
    var text = "Call 8001234567 or 9005551234"
    var matches = compiled.match_all(text)
    assert_equal(len(matches), 2)
    assert_equal(matches[0].get_match_text(), "8001234567")
    assert_equal(matches[1].get_match_text(), "9005551234")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
