from testing import assert_equal, assert_raises, assert_true

from regex.lexer import scan


@always_inline
fn assert_char_equal(actual: Codepoint, expected: String) raises:
    """Helper to compare Codepoint with expected string."""
    assert_equal(actual, Codepoint.ord(StringSlice(expected)))


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


fn test_simple_re_lexing() raises:
    var tokens = scan("a")
    assert_char_equal(tokens[0].char, "a")
    assert_equal(tokens[0].type, Token.ELEMENT)


fn test_escaping_char() raises:
    var tokens = scan("a\\\\a\\\\t\\.")
    assert_equal(tokens[1].type, Token.ELEMENT)
    assert_char_equal(tokens[1].char, "\\")


fn test_escaping_get_tab() raises:
    var tokens = scan("a\\h\\t")
    assert_equal(tokens[2].type, Token.ELEMENT)
    assert_char_equal(tokens[2].char, "\t")


fn test_escaping_wildcard() raises:
    var tokens = scan("\\.")
    assert_equal(tokens[0].type, Token.ELEMENT)
    assert_char_equal(tokens[0].char, ".")


fn test_get_comma() raises:
    var tokens = scan("a{3,5}")
    assert_equal(tokens[3].type, Token.COMMA)


fn test_comma_is_element() raises:
    var tokens = scan("a,")
    assert_equal(tokens[1].type, Token.ELEMENT)


fn test_match_start() raises:
    var tokens = scan("^a")
    assert_equal(tokens[0].type, Token.START)


fn test_match_end() raises:
    var tokens = scan("fdsad\\$cs$")
    assert_equal(tokens[len(tokens) - 1].type, Token.END)


fn test_fail_curly() raises:
    with assert_raises():
        _ = scan("advfe{a}")


fn test_lexer_1() raises:
    var tokens = scan("-\\\\/\\s~")
    assert_equal(len(tokens), 5)
    assert_equal(tokens[0].type, Token.DASH)
    assert_equal(tokens[1].type, Token.ELEMENT)
    assert_equal(tokens[2].type, Token.ELEMENT)
    assert_equal(tokens[3].type, Token.SPACE)
    assert_equal(tokens[4].type, Token.ELEMENT)


fn test_wildcard_lexing() raises:
    var tokens = scan(".")
    assert_equal(tokens[0].type, Token.WILDCARD)
    assert_char_equal(tokens[0].char, ".")


fn test_parenthesis_lexing() raises:
    var tokens = scan("()")
    assert_equal(tokens[0].type, Token.LEFTPARENTHESIS)
    assert_equal(tokens[1].type, Token.RIGHTPARENTHESIS)


fn test_bracket_lexing() raises:
    var tokens = scan("[]")
    assert_equal(tokens[0].type, Token.LEFTBRACKET)
    assert_equal(tokens[1].type, Token.RIGHTBRACKET)


fn test_curly_brace_lexing() raises:
    var tokens = scan("{1}")
    assert_equal(tokens[0].type, Token.LEFTCURLYBRACE)
    assert_equal(tokens[1].type, Token.ELEMENT)
    assert_equal(tokens[2].type, Token.RIGHTCURLYBRACE)


fn test_quantifiers_lexing() raises:
    var tokens = scan("*+?")
    assert_equal(tokens[0].type, Token.ASTERISK)
    assert_equal(tokens[1].type, Token.PLUS)
    assert_equal(tokens[2].type, Token.QUESTIONMARK)


fn test_vertical_bar_lexing() raises:
    var tokens = scan("|")
    assert_equal(tokens[0].type, Token.VERTICALBAR)


fn test_dash_lexing() raises:
    var tokens = scan("-")
    assert_equal(tokens[0].type, Token.DASH)
