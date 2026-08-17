from std.testing import assert_equal, assert_true, TestSuite

from regex import split


def test_split_literal() raises:
    var parts = split(",", "a,b,c")
    assert_equal(len(parts), 3)
    assert_equal(parts[0], "a")
    assert_equal(parts[1], "b")
    assert_equal(parts[2], "c")


def test_split_regex_whitespace() raises:
    var parts = split("\\s+", "hello   world  foo")
    assert_equal(len(parts), 3)
    assert_equal(parts[0], "hello")
    assert_equal(parts[1], "world")
    assert_equal(parts[2], "foo")


def test_split_adjacent_separators() raises:
    # Two adjacent separators yield an empty field between them.
    var parts = split(",", "a,,b")
    assert_equal(len(parts), 3)
    assert_equal(parts[0], "a")
    assert_equal(parts[1], "")
    assert_equal(parts[2], "b")


def test_split_leading_and_trailing() raises:
    var parts = split(",", ",a,")
    assert_equal(len(parts), 3)
    assert_equal(parts[0], "")
    assert_equal(parts[1], "a")
    assert_equal(parts[2], "")


def test_split_no_match() raises:
    var parts = split(",", "abcdef")
    assert_equal(len(parts), 1)
    assert_equal(parts[0], "abcdef")


def test_split_empty_text() raises:
    var parts = split(",", "")
    assert_equal(len(parts), 1)
    assert_equal(parts[0], "")


def test_split_maxsplit() raises:
    # At most `maxsplit` splits; the remainder is returned unsplit.
    var parts = split(",", "a,b,c,d", maxsplit=2)
    assert_equal(len(parts), 3)
    assert_equal(parts[0], "a")
    assert_equal(parts[1], "b")
    assert_equal(parts[2], "c,d")


def test_split_maxsplit_zero_is_unlimited() raises:
    var parts = split(",", "a,b,c,d", maxsplit=0)
    assert_equal(len(parts), 4)
    assert_equal(parts[3], "d")


def test_split_negative_maxsplit_no_split() raises:
    # A negative maxsplit performs no split (matches Python re.split).
    var parts = split(",", "a,b,c", maxsplit=-1)
    assert_equal(len(parts), 1)
    assert_equal(parts[0], "a,b,c")


def test_split_char_class() raises:
    var parts = split("[;,]", "a;b,c;d")
    assert_equal(len(parts), 4)
    assert_equal(parts[0], "a")
    assert_equal(parts[3], "d")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
