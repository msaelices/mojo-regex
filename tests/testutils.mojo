from std.testing import assert_equal


@always_inline
def assert_char_equal(actual: Int, expected: String) raises:
    """Helper to compare Codepoint with expected string."""
    assert_equal(actual, ord(StringSlice(expected)))
