from testing import assert_equal, assert_raises

from regex.lexer import scan
from regex.tokens import ElementToken, Comma, Start, End, SpaceToken, Dash


fn test_simple_re_lexing() raises:
    tokens = scan("a")
    assert_equal(tokens[0].char, "a")


# @pytest.fixture
# def lexer():
#     return Lexer()
#
#
# def test_simple_re_lexing(lexer: Lexer):
#     tokens = lexer.scan('a')
#     assert tokens[0].char == 'a'
#
#
# def test_escaping_char(lexer: Lexer):
#     tokens = lexer.scan(r'a\\a\\t\.')
#     assert type(tokens[1]) is ElementToken and tokens[1].char == '\\'
#
#
# def test_escaping_get_tab(lexer: Lexer):
#     tokens = lexer.scan(r'a\h\t')
#     assert type(tokens[2]) is ElementToken and tokens[2].char == '\t'
#
#
# def test_escaping_wildcard(lexer: Lexer):
#     tokens = lexer.scan(r'\.')
#     assert type(tokens[0]) is ElementToken and tokens[0].char == '.'
#
#
# def test_get_comma(lexer: Lexer):
#     tokens = lexer.scan('a{3,5}')
#     assert type(tokens[3]) is Comma
#
#
# def test_comma_is_element(lexer: Lexer):
#     tokens = lexer.scan('a,')
#     assert type(tokens[1]) is ElementToken
#
#
# def test_match_start(lexer: Lexer):
#     tokens = lexer.scan('^a')
#     assert type(tokens[0]) is Start
#
#
# def test_match_end(lexer: Lexer):
#     tokens = lexer.scan(r'fdsad\$cs$')
#     assert type(tokens[len(tokens) - 1]) is End
#
#
# def test_fail_curly(lexer: Lexer):
#     with pytest.raises(Exception):
#         lexer.scan('advfe{a}')
#
#
# def test_lexer_1(lexer: Lexer):
#     tokens = lexer.scan(r'-\\\/\s~')
#     assert len(tokens) == 5
#     assert type(tokens[0]) is Dash
#     assert type(tokens[1]) is ElementToken
#     assert type(tokens[2]) is ElementToken
#     assert type(tokens[3]) is SpaceToken
#     assert type(tokens[4]) is ElementToken
