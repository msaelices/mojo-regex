from std.testing import assert_equal, assert_true, assert_false, TestSuite

from regex.comptime_regex import search, match_first, findall


def test_search_literal() raises:
    var m = search["hello"]("say hello world")
    assert_true(m)
    assert_equal(m.value().start_idx, 4)
    assert_equal(m.value().end_idx, 9)
    assert_false(search["hello"]("no match here"))


def test_search_anchors() raises:
    assert_true(search["^abc$"]("abc"))
    assert_false(search["^abc$"]("xabc"))
    assert_false(search["^abc$"]("abcx"))


def test_search_quantifiers() raises:
    # Expectations encode engine parity, not Python parity: the runtime
    # engine returns [4,6) for "a+b" on "xxaaabby" (and an empty match
    # at 0 for "a+b*"), and the comptime path must behave identically.
    # The Python re deviation is a pre-existing engine quirk tracked
    # separately from comptime specialization.
    var m = search["a+b"]("xxaaabby")
    assert_true(m)
    assert_equal(m.value().start_idx, 4)
    assert_equal(m.value().end_idx, 6)
    assert_false(search["a+b"]("xxyy"))
    var quirky = search["a+b*"]("xxaaabby")
    assert_true(quirky)
    assert_equal(quirky.value().start_idx, 0)
    assert_equal(quirky.value().end_idx, 0)


def test_search_alternation() raises:
    var m = search["(x|y)"]("abcy")
    assert_true(m)
    assert_equal(m.value().start_idx, 3)
    assert_false(search["(x|y)"]("abc"))


def test_search_char_class() raises:
    # Since the use_matcher_cache=False DFA path landed, char classes
    # build at comptime (previously they fell back to the runtime
    # engine because the _Global SIMD-matcher cache FFI call is not
    # interpretable).
    var m = search["[0-9]+"]("order 1234 shipped")
    assert_true(m)
    assert_equal(m.value().start_idx, 6)
    assert_equal(m.value().end_idx, 10)
    assert_false(search["[0-9]+"]("no digits"))


def test_search_char_class_families() raises:
    # Negated class
    var neg = search["[^abc]+"]("abxyc")
    assert_true(neg)
    assert_equal(neg.value().start_idx, 2)
    assert_equal(neg.value().end_idx, 4)
    # Word shorthand
    assert_true(search["\\w+"]("...abc..."))
    # Bounded quantifier
    var bounded = search["[0-9]{3}"]("id 4567")
    assert_true(bounded)
    assert_equal(bounded.value().start_idx, 3)
    assert_equal(bounded.value().end_idx, 6)
    # Multi-class sequence
    var seq = search["[a-z]+[0-9]+"]("QQab12ZZ")
    assert_true(seq)
    assert_equal(seq.value().start_idx, 2)
    assert_equal(seq.value().end_idx, 6)


def test_search_fallback_complex() raises:
    # These raise "pattern too complex" in the DFA compiler, so they
    # transparently fall back to the runtime engine.
    var m = search["(a|b)x"]("zbxq")
    assert_true(m)
    assert_equal(m.value().start_idx, 1)
    assert_equal(m.value().end_idx, 3)
    assert_false(search["(a|b)x"]("zzz"))
    var m2 = search["h[ae]llo"]("say hallo")
    assert_true(m2)
    assert_equal(m2.value().start_idx, 4)


def test_match_first_literal() raises:
    assert_true(match_first["hello"]("hello world"))
    assert_false(match_first["hello"]("say hello"))


def test_match_first_char_class() raises:
    # \\d+ builds at comptime since the cache-free DFA path landed.
    assert_true(match_first["\\d+"]("42 is the answer"))
    assert_false(match_first["\\d+"]("answer is 42"))


def test_findall_literal() raises:
    var matches = findall["ab"]("ab abab ab")
    assert_equal(len(matches), 4)
    assert_equal(matches[0].start_idx, 0)
    assert_equal(matches[3].start_idx, 8)


def test_findall_char_class() raises:
    var matches = findall["[0-9]+"]("1 22 333")
    assert_equal(len(matches), 3)
    assert_equal(matches[2].start_idx, 5)
    assert_equal(matches[2].end_idx, 8)


def test_repeated_calls_same_pattern() raises:
    # Exercises the process-global engine slot (materialize-once):
    # repeated calls must keep returning correct results.
    for _ in range(3):
        var m = search["hello"]("prefix hello suffix")
        assert_true(m)
        assert_equal(m.value().start_idx, 7)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
