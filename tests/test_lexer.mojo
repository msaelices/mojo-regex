from std.testing import assert_equal, assert_raises, assert_true, TestSuite
from testutils import assert_char_equal

from regex.lexer import scan


from regex.tokens import (
    Token,
    ElementToken,
    Comma,
    Start,
    End,
    SpaceToken,
    Dash,
    Wildcard,
    LeftParenthesis,
    RightParenthesis,
    LeftBracket,
    RightBracket,
    LeftCurlyBrace,
    RightCurlyBrace,
    Asterisk,
    Plus,
    QuestionMark,
    VerticalBar,
)


def test_simple_re_lexing() raises:
    var tokens = scan("a")
    assert_char_equal(tokens[0].char, "a")
    assert_equal(tokens[0].type, Token.ELEMENT)


def test_escaping_char() raises:
    var tokens = scan("a\\\\a\\\\t\\.")
    assert_equal(tokens[1].type, Token.ELEMENT)
    assert_char_equal(tokens[1].char, "\\")


def test_escaping_get_tab() raises:
    var tokens = scan("a\\h\\t")
    assert_equal(tokens[2].type, Token.ELEMENT)
    assert_char_equal(tokens[2].char, "\t")


def test_escaping_wildcard() raises:
    var tokens = scan("\\.")
    assert_equal(tokens[0].type, Token.ELEMENT)
    assert_char_equal(tokens[0].char, ".")


def test_get_comma() raises:
    var tokens = scan("a{3,5}")
    assert_equal(tokens[3].type, Token.COMMA)


def test_comma_is_element() raises:
    var tokens = scan("a,")
    assert_equal(tokens[1].type, Token.ELEMENT)


def test_match_start() raises:
    var tokens = scan("^a")
    assert_equal(tokens[0].type, Token.START)


def test_match_end() raises:
    var tokens = scan("fdsad\\$cs$")
    assert_equal(tokens[len(tokens) - 1].type, Token.END)


def test_fail_curly() raises:
    with assert_raises():
        _ = scan("advfe{a}")


def test_lexer_1() raises:
    var tokens = scan("-\\\\/\\s~")
    assert_equal(len(tokens), 5)
    assert_equal(tokens[0].type, Token.DASH)
    assert_equal(tokens[1].type, Token.ELEMENT)
    assert_equal(tokens[2].type, Token.ELEMENT)
    assert_equal(tokens[3].type, Token.SPACE)
    assert_equal(tokens[4].type, Token.ELEMENT)


def test_wildcard_lexing() raises:
    var tokens = scan(".")
    assert_equal(tokens[0].type, Token.WILDCARD)
    assert_char_equal(tokens[0].char, ".")


def test_parenthesis_lexing() raises:
    var tokens = scan("()")
    assert_equal(tokens[0].type, Token.LEFTPARENTHESIS)
    assert_equal(tokens[1].type, Token.RIGHTPARENTHESIS)


def test_bracket_lexing() raises:
    var tokens = scan("[]")
    assert_equal(tokens[0].type, Token.LEFTBRACKET)
    assert_equal(tokens[1].type, Token.RIGHTBRACKET)


def test_curly_brace_lexing() raises:
    var tokens = scan("{1}")
    assert_equal(tokens[0].type, Token.LEFTCURLYBRACE)
    assert_equal(tokens[1].type, Token.ELEMENT)
    assert_equal(tokens[2].type, Token.RIGHTCURLYBRACE)


def test_quantifiers_lexing() raises:
    var tokens = scan("*+?")
    assert_equal(tokens[0].type, Token.ASTERISK)
    assert_equal(tokens[1].type, Token.PLUS)
    assert_equal(tokens[2].type, Token.QUESTIONMARK)


def test_vertical_bar_lexing() raises:
    var tokens = scan("|")
    assert_equal(tokens[0].type, Token.VERTICALBAR)


def test_dash_lexing() raises:
    var tokens = scan("-")
    assert_equal(tokens[0].type, Token.DASH)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
