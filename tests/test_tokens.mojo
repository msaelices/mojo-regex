from std.testing import assert_equal, assert_not_equal, assert_true, TestSuite
from testutils import assert_char_equal


from regex.tokens import (
    Asterisk,
    Wildcard,
    NotToken,
    StartToken,
    Start,
    EndToken,
    End,
    Escape,
    Comma,
    LeftParenthesis,
    RightParenthesis,
    LeftCurlyBrace,
    RightCurlyBrace,
    LeftBracket,
    RightBracket,
    ZeroOrMore,
    OneOrMore,
    ZeroOrOne,
    Plus,
    QuestionMark,
    OrToken,
    VerticalBar,
    Circumflex,
    Dash,
)


def test_Asterisk() raises:
    var a = Asterisk()
    assert_true(Bool(a))
    assert_char_equal(a.char, "*")


def test_NotToken() raises:
    var nt = NotToken(char=ord("^"))
    assert_true(Bool(nt))
    assert_char_equal(nt.char, "^")


def test_Wildcard() raises:
    var w = Wildcard()
    assert_true(Bool(w))
    assert_char_equal(w.char, ".")


def test_StartToken() raises:
    var st = StartToken(char=ord("^"))
    assert_true(Bool(st))
    assert_char_equal(st.char, "^")


def test_Start() raises:
    var s = Start()
    assert_true(Bool(s))
    assert_char_equal(s.char, "^")


def test_EndToken() raises:
    var et = EndToken(char=ord("$"))
    assert_true(Bool(et))
    assert_char_equal(et.char, "$")


def test_End() raises:
    var e = End()
    assert_true(Bool(e))
    assert_char_equal(e.char, "$")


def test_Escape() raises:
    var escape = Escape()
    assert_true(Bool(escape))
    assert_char_equal(escape.char, "\\")


def test_Comma() raises:
    var comma = Comma()
    assert_true(Bool(comma))
    assert_char_equal(comma.char, ",")


def test_LeftParenthesis() raises:
    var lp = LeftParenthesis()
    assert_true(Bool(lp))
    assert_char_equal(lp.char, "(")


def test_RightParenthesis() raises:
    var rp = RightParenthesis()
    assert_true(Bool(rp))
    assert_char_equal(rp.char, ")")


def test_LeftCurlyBrace() raises:
    var lcb = LeftCurlyBrace()
    assert_true(Bool(lcb))
    assert_char_equal(lcb.char, "{")


def test_RightCurlyBrace() raises:
    var rcb = RightCurlyBrace()
    assert_true(Bool(rcb))
    assert_char_equal(rcb.char, "}")


def test_LeftBracket() raises:
    var lb = LeftBracket()
    assert_true(Bool(lb))
    assert_char_equal(lb.char, "[")


def test_RightBracket() raises:
    var rb = RightBracket()
    assert_true(Bool(rb))
    assert_char_equal(rb.char, "]")


def test_ZeroOrMore() raises:
    var zom = ZeroOrMore(char=ord("*"))
    assert_true(Bool(zom))
    assert_char_equal(zom.char, "*")


def test_OneOrMore() raises:
    var oom = OneOrMore(char=ord("+"))
    assert_true(Bool(oom))
    assert_char_equal(oom.char, "+")


def test_ZeroOrOne() raises:
    var zoo = ZeroOrOne(char=ord("?"))
    assert_true(Bool(zoo))
    assert_char_equal(zoo.char, "?")


def test_Plus() raises:
    var p = Plus()
    assert_true(Bool(p))
    assert_char_equal(p.char, "+")


def test_QuestionMark() raises:
    var qm = QuestionMark()
    assert_true(Bool(qm))
    assert_char_equal(qm.char, "?")


def test_OrToken() raises:
    var ot = OrToken(char=ord("|"))
    assert_true(Bool(ot))
    assert_char_equal(ot.char, "|")


def test_VerticalBar() raises:
    var vb = VerticalBar()
    assert_true(Bool(vb))
    assert_char_equal(vb.char, "|")


def test_Circumflex() raises:
    var c = Circumflex()
    assert_true(Bool(c))
    assert_char_equal(c.char, "^")


def test_Dash() raises:
    var d = Dash()
    assert_true(Bool(d))
    assert_char_equal(d.char, "-")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
