from testing import assert_equal, assert_true, assert_false

from regex.matcher import match_first, findall
from regex.nfa import match_first as nfa_match_first


# ===== DIGIT (\d) TESTS =====


def test_digit_all_ascii_digits():
    """Test \\d matches all ASCII digits 0-9."""
    for i in range(10):
        var digit_char = String(i)
        var result = match_first("\\d", digit_char)
        assert_true(result)
        var matched = result.value()
        assert_equal(matched.get_match_text(), digit_char)


def test_digit_unicode_edge_cases():
    """Test \\d with Unicode and special digit characters."""
    # ASCII digits should match
    var result1 = match_first("\\d", "0")
    assert_true(result1)

    var result2 = match_first("\\d", "9")
    assert_true(result2)

    # Non-ASCII should not match
    var result3 = match_first("\\d", "a")
    assert_false(result3)

    var result4 = match_first("\\d", " ")
    assert_false(result4)

    var result5 = match_first("\\d", "@")
    assert_false(result5)


def test_digit_quantifier_basic():
    """Test \\d with basic quantifiers +, *, ?."""
    # Test + quantifier
    var result1 = match_first("\\d+", "123")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "123")

    # Test * quantifier
    var result2 = match_first("\\d*", "123")
    assert_true(result2)
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), "123")

    # Test ? quantifier
    var result3 = match_first("\\d?", "1")
    assert_true(result3)
    var matched3 = result3.value()
    assert_equal(matched3.get_match_text(), "1")


def test_digit_empty_string():
    """Test \\d patterns with empty strings."""
    var result1 = match_first("\\d", "")
    assert_false(result1)

    var result2 = match_first("\\d*", "")
    assert_true(result2)  # * allows zero matches
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), "")

    var result3 = match_first("\\d?", "")
    assert_true(result3)  # ? allows zero matches
    var matched3 = result3.value()
    assert_equal(matched3.get_match_text(), "")

    var result4 = match_first("\\d+", "")
    assert_false(result4)  # + requires at least one match


def test_digit_mixed_strings():
    """Test \\d in mixed alphanumeric strings."""
    var result1 = match_first("\\d+", "abc123def")
    assert_false(result1)  # Doesn't start with digit

    # Test findall for multiple digit sequences
    var matches = findall("\\d+", "abc123def456ghi")
    assert_equal(len(matches), 2)
    assert_equal(matches[0].get_match_text(), "123")
    assert_equal(matches[1].get_match_text(), "456")


# ===== WORD (\w) TESTS =====


def test_word_all_ascii_letters():
    """Test \\w matches all ASCII letters."""
    # Test lowercase
    for i in range(26):
        var char_code = ord("a") + i
        var letter = chr(char_code)
        var result = match_first("\\w", letter)
        assert_true(result)
        var matched = result.value()
        assert_equal(matched.get_match_text(), letter)

    # Test uppercase
    for i in range(26):
        var char_code = ord("A") + i
        var letter = chr(char_code)
        var result = match_first("\\w", letter)
        assert_true(result)
        var matched = result.value()
        assert_equal(matched.get_match_text(), letter)


def test_word_digits_and_underscore():
    """Test \\w matches digits and underscore."""
    # Test all digits
    for i in range(10):
        var digit_char = String(i)
        var result = match_first("\\w", digit_char)
        assert_true(result)
        var matched = result.value()
        assert_equal(matched.get_match_text(), digit_char)

    # Test underscore
    var result = match_first("\\w", "_")
    assert_true(result)
    var matched = result.value()
    assert_equal(matched.get_match_text(), "_")


def test_word_special_characters():
    """Test \\w does not match special characters."""
    var special_chars = "@#$%^&*()-+=[]{}|\\:;\"'<>,.?/~`"

    for i in range(len(special_chars)):
        var char = String(special_chars[i])
        var result = match_first("\\w", char)
        assert_false(result)


def test_word_whitespace():
    """Test \\w does not match whitespace characters."""
    var result1 = match_first("\\w", " ")
    assert_false(result1)

    var result2 = match_first("\\w", "\t")
    assert_false(result2)

    var result3 = match_first("\\w", "\n")
    assert_false(result3)


def test_word_quantifier_basic():
    """Test \\w with basic quantifiers +, *, ?."""
    # Test + quantifier
    var result1 = match_first("\\w+", "hello123")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "hello123")

    # Test * quantifier
    var result2 = match_first("\\w*", "hello_world")
    assert_true(result2)
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), "hello_world")

    # Test ? quantifier
    var result3 = match_first("\\w?", "a")
    assert_true(result3)
    var matched3 = result3.value()
    assert_equal(matched3.get_match_text(), "a")


def test_word_empty_string():
    """Test \\w patterns with empty strings."""
    var result1 = match_first("\\w", "")
    assert_false(result1)

    var result2 = match_first("\\w*", "")
    assert_true(result2)
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), "")

    var result3 = match_first("\\w?", "")
    assert_true(result3)
    var matched3 = result3.value()
    assert_equal(matched3.get_match_text(), "")

    var result4 = match_first("\\w+", "")
    assert_false(result4)


def test_word_mixed_strings():
    """Test \\w in mixed strings with special characters."""
    # Test findall for multiple word sequences
    var matches = findall("\\w+", "hello@world_123#test")
    assert_equal(len(matches), 3)
    assert_equal(matches[0].get_match_text(), "hello")
    assert_equal(matches[1].get_match_text(), "world_123")
    assert_equal(matches[2].get_match_text(), "test")


# ===== COMPLEX PATTERN TESTS =====


def test_digit_word_combination():
    """Test combining \\d and \\w in patterns."""
    # Pattern for identifier: starts with letter/underscore, followed by word chars
    var result1 = match_first("[a-zA-Z_]\\w*", "variable123")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "variable123")

    var result2 = match_first("[a-zA-Z_]\\w*", "123invalid")
    assert_false(result2)  # Starts with digit


def test_digit_word_alternation():
    """Test \\d and \\w in alternation patterns."""
    var result1 = match_first("\\d|\\w", "5")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "5")

    var result2 = match_first("\\d|\\w", "a")
    assert_true(result2)
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), "a")

    var result3 = match_first("\\d|\\w", "@")
    assert_false(result3)


def test_digit_word_sequences():
    """Test sequences of \\d and \\w patterns."""
    # Pattern for simple variable names: letter followed by digits
    var result1 = match_first("[a-z]\\d+", "a123")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "a123")

    # Pattern for mixed alphanumeric
    var result2 = match_first("\\w\\d\\w", "a5b")
    assert_true(result2)
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), "a5b")


def test_anchored_patterns():
    """Test \\d and \\w with anchors."""
    var result1 = match_first("^\\d+$", "12345")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "12345")

    var result2 = match_first("^\\d+$", "abc123")
    assert_false(result2)  # Doesn't start with digit

    var result3 = match_first("^\\w+$", "hello_123")
    assert_true(result3)
    var matched3 = result3.value()
    assert_equal(matched3.get_match_text(), "hello_123")


def test_greedy_vs_minimal_matching():
    """Test greedy behavior of \\d and \\w quantifiers."""
    # \\d+ should be greedy and match all consecutive digits
    var result1 = match_first("\\d+", "123abc")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "123")

    # \\w+ should be greedy and match all consecutive word characters
    var result2 = match_first("\\w+", "hello123_world@")
    assert_true(result2)
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), "hello123_world")


# ===== BOUNDARY AND EDGE CASE TESTS =====


def test_single_character_strings():
    """Test \\d and \\w with single character strings."""
    # Boundary cases for single characters
    var result1 = match_first("\\d", "0")
    assert_true(result1)

    var result2 = match_first("\\d", "9")
    assert_true(result2)

    var result3 = match_first("\\w", "a")
    assert_true(result3)

    var result4 = match_first("\\w", "Z")
    assert_true(result4)

    var result5 = match_first("\\w", "_")
    assert_true(result5)


def test_very_long_strings():
    """Test \\d and \\w with very long strings."""
    # Create long digit string
    var long_digits = String("123456789012345678901234567890")
    var result1 = match_first("\\d+", long_digits)
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), long_digits)

    # Create long word string
    var long_words = String(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    )
    var result2 = match_first("\\w+", long_words)
    assert_true(result2)
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), long_words)


def test_zero_quantifier_edge_cases():
    """Test zero quantifier edge cases for \\d and \\w."""
    # Test \\d* at different positions in non-digit strings
    var result1 = match_first("\\d*abc", "abc")
    assert_true(result1)  # \\d* matches zero digits, then literal abc
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "abc")

    # Test \\w* at different positions
    var result2 = match_first("\\w*@", "@")
    assert_true(result2)  # \\w* matches zero word chars, then literal @
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), "@")


def test_multiple_consecutive_patterns():
    """Test multiple consecutive \\d and \\w patterns."""
    var result1 = match_first("\\d\\d\\d", "123")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "123")

    var result2 = match_first("\\w\\w\\w", "abc")
    assert_true(result2)
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), "abc")

    # Mixed patterns
    var result3 = match_first("\\w\\d\\w", "a5z")
    assert_true(result3)
    var matched3 = result3.value()
    assert_equal(matched3.get_match_text(), "a5z")


def test_nested_quantifiers():
    """Test \\d and \\w in grouped patterns with quantifiers."""
    # Test (word_char digit)+ pattern
    var result1 = match_first("(\\w\\d)+", "a1b2c3")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "a1b2c3")

    var result2 = match_first("(\\w\\d)+", "ab12")
    assert_false(result2)  # Doesn't match pattern


def test_performance_stress():
    """Test \\d and \\w with repetitive patterns."""
    # Test many digits
    var many_digits = String("")
    for i in range(100):
        many_digits += String(i % 10)

    var result1 = match_first("\\d+", many_digits)
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(len(matched1.get_match_text()), 100)

    # Test many word characters
    var many_words = String("a") * 100
    var result2 = match_first("\\w+", many_words)
    assert_true(result2)
    var matched2 = result2.value()
    assert_equal(len(matched2.get_match_text()), 100)


# ===== NFA SPECIFIC TESTS =====


def test_nfa_digit_direct():
    """Test \\d directly through NFA engine."""
    var result1 = nfa_match_first("\\d", "5")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "5")

    var result2 = nfa_match_first("\\d", "a")
    assert_false(result2)

    var result3 = nfa_match_first("\\d*", "@#$")
    assert_true(result3)
    var matched3 = result3.value()
    assert_equal(matched3.get_match_text(), "")


def test_nfa_word_direct():
    """Test \\w directly through NFA engine."""
    var result1 = nfa_match_first("\\w", "a")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "a")

    var result2 = nfa_match_first("\\w", "@")
    assert_false(result2)

    var result3 = nfa_match_first("\\w*", "@#$")
    assert_true(result3)
    var matched3 = result3.value()
    assert_equal(matched3.get_match_text(), "")


# ===== REGRESSION TESTS =====


def test_digit_word_regression():
    """Regression tests for specific patterns that previously failed."""
    # These patterns were failing before the NFA routing fix
    var result1 = match_first("\\d", "5")
    assert_true(result1)

    var result2 = match_first("\\w", "a")
    assert_true(result2)

    # Zero-match quantifier cases
    var result3 = match_first("\\d*", "abc")
    assert_true(result3)
    var matched3 = result3.value()
    assert_equal(matched3.get_match_text(), "")

    var result4 = match_first("\\w*", "@#$")
    assert_true(result4)
    var matched4 = result4.value()
    assert_equal(matched4.get_match_text(), "")


def test_complex_real_world_patterns():
    """Test real-world patterns using \\d and \\w."""
    # Simple identifier pattern
    var result1 = match_first("\\w+", "variable123")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "variable123")

    # Number at start of string
    var result2 = match_first("\\d+", "123abc")
    assert_true(result2)
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), "123")

    # Word characters at start
    var result3 = match_first("\\w+", "hello_123@world")
    assert_true(result3)
    var matched3 = result3.value()
    assert_equal(matched3.get_match_text(), "hello_123")


# ===== BOUNDARY VALUE TESTS =====


def test_digit_boundary_values():
    """Test \\d with edge cases around digit boundaries."""
    # Test ASCII values just before and after digit range
    var result1 = match_first("\\d", chr(ord("0") - 1))  # '/' character
    assert_false(result1)

    var result2 = match_first("\\d", chr(ord("9") + 1))  # ':' character
    assert_false(result2)

    # Test actual boundaries
    var result3 = match_first("\\d", "0")
    assert_true(result3)

    var result4 = match_first("\\d", "9")
    assert_true(result4)


def test_word_boundary_values():
    """Test \\w with edge cases around word character boundaries."""
    # Test ASCII values around lowercase letters
    var result1 = match_first("\\w", chr(ord("a") - 1))  # '`' character
    assert_false(result1)

    var result2 = match_first("\\w", chr(ord("z") + 1))  # '{' character
    assert_false(result2)

    # Test ASCII values around uppercase letters
    var result3 = match_first("\\w", chr(ord("A") - 1))  # '@' character
    assert_false(result3)

    var result4 = match_first("\\w", chr(ord("Z") + 1))  # '[' character
    assert_false(result4)

    # Test actual boundaries
    var result5 = match_first("\\w", "a")
    assert_true(result5)

    var result6 = match_first("\\w", "z")
    assert_true(result6)

    var result7 = match_first("\\w", "A")
    assert_true(result7)

    var result8 = match_first("\\w", "Z")
    assert_true(result8)
