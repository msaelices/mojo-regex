from std.memory import UnsafePointer
from std.testing import assert_equal, assert_true, assert_false, TestSuite

from regex.ast import ASTNode
from regex.parser import parse
from regex.pikevm import compile_ast, PikeVMEngine
from regex.onepass import compile_onepass, OnePassNFA
from regex.aliases import ImmSlice


def _build_onepass(
    pattern: String,
) raises -> UnsafePointer[OnePassNFA, MutAnyOrigin]:
    """Parse a pattern, compile to PikeVM bytecode, attempt OnePass
    compilation, and return the heap pointer (null if not one-pass)."""
    var ast = parse(pattern)
    var program = compile_ast(ast)
    return compile_onepass(program^)


def test_onepass_compiles_simple_literal() raises:
    """The simplest possible one-pass pattern: a literal sequence."""
    var ptr = _build_onepass("abc")
    assert_true(Bool(ptr))
    if ptr:
        ptr.destroy_pointee()
        ptr.free()


def test_onepass_compiles_phone_validation() raises:
    """The motivating pattern: an anchored phone-number validator with
    optional groups whose branches are distinguishable byte-by-byte."""
    var ptr = _build_onepass(
        "^\\+?1?[\\s.-]?\\(?([2-9]\\d{2})\\)?[\\s.-]?([2-9]\\d{2})[\\s.-]?(\\d{4})$"
    )
    assert_true(Bool(ptr))
    if ptr:
        ptr.destroy_pointee()
        ptr.free()


def test_onepass_literal_matches() raises:
    """Execute the compiled automaton against matching and non-matching text."""
    var ptr = _build_onepass("abc")
    assert_true(Bool(ptr))
    var text_good = String("abc")
    var text_bad = String("abd")
    var m_good = ptr[].match_first(text_good, 0)
    var m_bad = ptr[].match_first(text_bad, 0)
    assert_true(Bool(m_good))
    assert_false(Bool(m_bad))
    if m_good:
        assert_equal(m_good.value().start_idx, 0)
        assert_equal(m_good.value().end_idx, 3)
    ptr.destroy_pointee()
    ptr.free()


def test_onepass_end_anchor() raises:
    """A dollar-anchored pattern should only match when the match
    coincides with the end of the text."""
    var ptr = _build_onepass("ab$")
    assert_true(Bool(ptr))
    var hit = String("xxab")
    var miss = String("xxab ")
    var m_hit = ptr[].match_next(hit, 0)
    var m_miss = ptr[].match_next(miss, 0)
    assert_true(Bool(m_hit))
    assert_false(Bool(m_miss))
    if m_hit:
        assert_equal(m_hit.value().end_idx, 4)
    ptr.destroy_pointee()
    ptr.free()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
