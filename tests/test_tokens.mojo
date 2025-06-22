from testing import assert_equal, assert_not_equal, assert_true
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


def test_Asterisk():
    var a = Asterisk()
    assert_true(Bool(a))
    assert_equal(a.char, "*")


def test_NotToken():
    var nt = NotToken(char="^")
    assert_true(Bool(nt))
    assert_equal(nt.char, "^")


def test_Wildcard():
    var w = Wildcard()
    assert_true(Bool(w))
    assert_equal(w.char, ".")


def test_StartToken():
    var st = StartToken(char="^")
    assert_true(Bool(st))
    assert_equal(st.char, "^")


def test_Start():
    var s = Start()
    assert_true(Bool(s))
    assert_equal(s.char, "^")


def test_EndToken():
    var et = EndToken(char="$")
    assert_true(Bool(et))
    assert_equal(et.char, "$")


def test_End():
    var e = End()
    assert_true(Bool(e))
    assert_equal(e.char, "$")


def test_Escape():
    var escape = Escape()
    assert_true(Bool(escape))
    assert_equal(escape.char, "\\")


def test_Comma():
    var comma = Comma()
    assert_true(Bool(comma))
    assert_equal(comma.char, ",")


def test_LeftParenthesis():
    var lp = LeftParenthesis()
    assert_true(Bool(lp))
    assert_equal(lp.char, "(")


def test_RightParenthesis():
    var rp = RightParenthesis()
    assert_true(Bool(rp))
    assert_equal(rp.char, ")")


def test_LeftCurlyBrace():
    var lcb = LeftCurlyBrace()
    assert_true(Bool(lcb))
    assert_equal(lcb.char, "{")


def test_RightCurlyBrace():
    var rcb = RightCurlyBrace()
    assert_true(Bool(rcb))
    assert_equal(rcb.char, "}")


def test_LeftBracket():
    var lb = LeftBracket()
    assert_true(Bool(lb))
    assert_equal(lb.char, "[")


def test_RightBracket():
    var rb = RightBracket()
    assert_true(Bool(rb))
    assert_equal(rb.char, "]")


def test_ZeroOrMore():
    var zom = ZeroOrMore(char="*")
    assert_true(Bool(zom))
    assert_equal(zom.char, "*")


def test_OneOrMore():
    var oom = OneOrMore(char="+")
    assert_true(Bool(oom))
    assert_equal(oom.char, "+")


def test_ZeroOrOne():
    var zoo = ZeroOrOne(char="?")
    assert_true(Bool(zoo))
    assert_equal(zoo.char, "?")


def test_Plus():
    var p = Plus()
    assert_true(Bool(p))
    assert_equal(p.char, "+")


def test_QuestionMark():
    var qm = QuestionMark()
    assert_true(Bool(qm))
    assert_equal(qm.char, "?")


def test_OrToken():
    var ot = OrToken(char="|")
    assert_true(Bool(ot))
    assert_equal(ot.char, "|")


def test_VerticalBar():
    var vb = VerticalBar()
    assert_true(Bool(vb))
    assert_equal(vb.char, "|")


def test_Circumflex():
    var c = Circumflex()
    assert_true(Bool(c))
    assert_equal(c.char, "^")


def test_Dash():
    var d = Dash()
    assert_true(Bool(d))
    assert_equal(d.char, "-")
