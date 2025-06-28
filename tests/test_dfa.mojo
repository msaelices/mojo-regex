from testing import assert_equal, assert_true, assert_false

from regex.dfa import (
    DFAEngine,
    BoyerMoore,
    compile_simple_pattern,
    compile_ast_pattern,
)
from regex.parser import parse


def test_dfa_literal_pattern():
    """Test DFA compilation and execution for literal patterns."""
    var dfa = DFAEngine()
    dfa.compile_pattern("hello", False, False)

    # Test successful match
    var result1 = dfa.match_first("hello world", 0)
    assert_true(result1.__bool__())
    var match1 = result1.value()
    assert_equal(match1.start_idx, 0)
    assert_equal(match1.end_idx, 5)
    assert_equal(match1.match_text, "hello")

    # Test match in middle of string
    var result2 = dfa.match_first("say hello there", 0)
    assert_true(result2.__bool__())
    var match2 = result2.value()
    assert_equal(match2.start_idx, 4)
    assert_equal(match2.end_idx, 9)

    # Test no match
    var result3 = dfa.match_first("goodbye world", 0)
    assert_false(result3.__bool__())


def test_dfa_empty_pattern():
    """Test DFA with empty pattern."""
    var dfa = DFAEngine()
    dfa.compile_pattern("", False, False)

    # Empty pattern should match at any position
    var result1 = dfa.match_first("hello", 0)
    assert_true(result1.__bool__())
    var match1 = result1.value()
    assert_equal(match1.start_idx, 0)
    assert_equal(match1.end_idx, 0)

    # Should also match in empty string
    var result2 = dfa.match_first("", 0)
    assert_true(result2.__bool__())


def test_dfa_character_class():
    """Test DFA compilation for character classes."""
    var dfa = DFAEngine()
    dfa.compile_character_class("abcdefghijklmnopqrstuvwxyz", 1, -1)  # [a-z]+

    # Test successful match
    var result1 = dfa.match_first("hello123", 0)
    assert_true(result1.__bool__())
    var match1 = result1.value()
    assert_equal(match1.start_idx, 0)
    assert_equal(match1.end_idx, 5)
    assert_equal(match1.match_text, "hello")

    # Test match found later in string (should find "hello" at position 3)
    var result2 = dfa.match_first("123hello", 0)
    assert_true(result2.__bool__())
    var match2 = result2.value()
    assert_equal(match2.start_idx, 3)
    assert_equal(match2.end_idx, 8)
    assert_equal(match2.match_text, "hello")


def test_dfa_match_all():
    """Test DFA match_all functionality."""
    var dfa = DFAEngine()
    dfa.compile_pattern("a", False, False)

    var matches = dfa.match_all("banana")
    assert_equal(len(matches), 3)

    # Check positions
    assert_equal(matches[0].start_idx, 1)
    assert_equal(matches[0].end_idx, 2)
    assert_equal(matches[1].start_idx, 3)
    assert_equal(matches[1].end_idx, 4)
    assert_equal(matches[2].start_idx, 5)
    assert_equal(matches[2].end_idx, 6)


def test_boyer_moore_search():
    """Test Boyer-Moore string search algorithm."""
    var bm = BoyerMoore("hello")

    # Test successful search
    assert_equal(bm.search("hello world"), 0)
    assert_equal(bm.search("say hello there"), 4)

    # Test unsuccessful search
    assert_equal(bm.search("goodbye world"), -1)

    # Test search with start position
    assert_equal(bm.search("hello hello hello", 1), 6)
    assert_equal(bm.search("hello hello hello", 7), 12)


def test_boyer_moore_search_all():
    """Test Boyer-Moore finding all occurrences."""
    var bm = BoyerMoore("ll")

    var positions = bm.search_all("hello world, all well")
    assert_equal(len(positions), 3)
    assert_equal(positions[0], 2)  # "hello"
    assert_equal(positions[1], 14)  # "all"
    assert_equal(positions[2], 19)  # "well"


def test_compile_simple_pattern():
    """Test high-level simple pattern compilation."""
    # Test literal pattern
    var ast1 = parse("hello")
    var dfa1 = compile_simple_pattern(ast1)

    var result1 = dfa1.match_first("hello world", 0)
    assert_true(result1.__bool__())
    assert_equal(result1.value().match_text, "hello")


def test_dfa_single_character():
    """Test DFA with single character patterns."""
    var dfa = DFAEngine()
    dfa.compile_pattern("a", False, False)

    # Should match single character
    var result1 = dfa.match_first("a", 0)
    assert_true(result1.__bool__())
    assert_equal(result1.value().match_text, "a")

    # Should match in longer string
    var result2 = dfa.match_first("banana", 0)
    assert_true(result2.__bool__())
    assert_equal(result2.value().start_idx, 1)  # First 'a' in "banana"


def test_dfa_case_sensitive():
    """Test that DFA matching is case sensitive."""
    var dfa = DFAEngine()
    dfa.compile_pattern("Hello", False, False)

    # Should match exact case
    var result1 = dfa.match_first("Hello World", 0)
    assert_true(result1.__bool__())

    # Should not match different case
    var result2 = dfa.match_first("hello world", 0)
    assert_false(result2.__bool__())

    var result3 = dfa.match_first("HELLO WORLD", 0)
    assert_false(result3.__bool__())


def test_boyer_moore_edge_cases():
    """Test Boyer-Moore with edge cases."""
    # Empty pattern
    var bm_empty = BoyerMoore("")
    assert_equal(bm_empty.search("hello"), 0)  # Empty pattern matches at start

    # Single character pattern
    var bm_single = BoyerMoore("a")
    assert_equal(bm_single.search("banana"), 1)
    assert_equal(bm_single.search("hello"), -1)

    # Pattern longer than text
    var bm_long = BoyerMoore("verylongpattern")
    assert_equal(bm_long.search("short"), -1)


def test_dfa_state_transitions():
    """Test DFA state transitions work correctly."""
    var dfa = DFAEngine()
    dfa.compile_pattern("abc", False, False)

    # Should match complete pattern
    var result1 = dfa.match_first("abc", 0)
    assert_true(result1.__bool__())
    assert_equal(result1.value().match_text, "abc")

    # Should not match partial pattern
    var result2 = dfa.match_first("ab", 0)
    assert_false(result2.__bool__())

    # Should not match with extra characters in between
    var result3 = dfa.match_first("axbc", 0)
    assert_false(result3.__bool__())


def test_dfa_start_anchor():
    """Test DFA with start anchor (^)."""
    var dfa = DFAEngine()
    dfa.compile_pattern("hello", True, False)  # ^hello

    # Should match at start
    var result1 = dfa.match_first("hello world", 0)
    assert_true(result1.__bool__())
    var match1 = result1.value()
    assert_equal(match1.start_idx, 0)
    assert_equal(match1.end_idx, 5)
    assert_equal(match1.match_text, "hello")

    # Should not match when not at start
    var result2 = dfa.match_first("say hello", 0)
    assert_false(result2.__bool__())

    # Should not match when start position is not 0
    var result3 = dfa.match_first("hello world", 1)
    assert_false(result3.__bool__())


def test_dfa_end_anchor():
    """Test DFA with end anchor ($)."""
    var dfa = DFAEngine()
    dfa.compile_pattern("world", False, True)  # world$

    # Should match at end
    var result1 = dfa.match_first("hello world", 0)
    assert_true(result1.__bool__())
    var match1 = result1.value()
    assert_equal(match1.start_idx, 6)
    assert_equal(match1.end_idx, 11)
    assert_equal(match1.match_text, "world")

    # Should not match when not at end
    var result2 = dfa.match_first("world peace", 0)
    assert_false(result2.__bool__())


def test_dfa_both_anchors():
    """Test DFA with both start and end anchors (^...$)."""
    var dfa = DFAEngine()
    dfa.compile_pattern("hello", True, True)  # ^hello$

    # Should match entire string
    var result1 = dfa.match_first("hello", 0)
    assert_true(result1.__bool__())
    var match1 = result1.value()
    assert_equal(match1.start_idx, 0)
    assert_equal(match1.end_idx, 5)
    assert_equal(match1.match_text, "hello")

    # Should not match if there's extra content
    var result2 = dfa.match_first("hello world", 0)
    assert_false(result2.__bool__())

    var result3 = dfa.match_first("say hello", 0)
    assert_false(result3.__bool__())


def test_dfa_pure_anchors():
    """Test DFA with pure anchor patterns."""
    # Test start anchor only (^)
    var ast1 = parse("^")
    var dfa1 = compile_simple_pattern(ast1)

    var result1 = dfa1.match_first("hello", 0)
    assert_true(result1.__bool__())
    var match1 = result1.value()
    assert_equal(match1.start_idx, 0)
    assert_equal(match1.end_idx, 0)  # Zero-width match

    # Should not match when not at start
    var result2 = dfa1.match_first("hello", 1)
    assert_false(result2.__bool__())

    # Test end anchor only ($)
    var ast2 = parse("$")
    var dfa2 = compile_simple_pattern(ast2)

    var result3 = dfa2.match_first("hello", 0)
    assert_true(result3.__bool__())
    var match2 = result3.value()
    assert_equal(match2.start_idx, 5)
    assert_equal(match2.end_idx, 5)  # Zero-width match at end


def test_dfa_anchored_match_all():
    """Test DFA match_all with anchored patterns."""
    # Start anchored pattern should only match once at beginning
    var dfa1 = DFAEngine()
    dfa1.compile_pattern("a", True, False)  # ^a

    var matches1 = dfa1.match_all("aaa")
    assert_equal(len(matches1), 1)
    assert_equal(matches1[0].start_idx, 0)
    assert_equal(matches1[0].end_idx, 1)

    # End anchored pattern should only match once at end
    var dfa2 = DFAEngine()
    dfa2.compile_pattern("a", False, True)  # a$

    var matches2 = dfa2.match_all("aaa")
    assert_equal(len(matches2), 1)
    assert_equal(matches2[0].start_idx, 2)
    assert_equal(matches2[0].end_idx, 3)

    # Both anchors should match only if entire string matches
    var dfa3 = DFAEngine()
    dfa3.compile_pattern("a", True, True)  # ^a$

    var matches3a = dfa3.match_all("a")
    assert_equal(len(matches3a), 1)

    var matches3b = dfa3.match_all("aaa")
    assert_equal(len(matches3b), 0)  # Should not match


def test_dfa_anchors_with_high_level_api():
    """Test that anchored patterns now use DFA through high-level API."""
    # Test that these patterns are now classified as SIMPLE and use DFA
    var ast1 = parse("^hello")
    var dfa1 = compile_simple_pattern(ast1)

    var result1 = dfa1.match_first("hello world", 0)
    assert_true(result1.__bool__())
    assert_equal(result1.value().match_text, "hello")

    var ast2 = parse("world$")
    var dfa2 = compile_simple_pattern(ast2)

    var result2 = dfa2.match_first("hello world", 0)
    assert_true(result2.__bool__())
    assert_equal(result2.value().match_text, "world")

    var ast3 = parse("^hello$")
    var dfa3 = compile_simple_pattern(ast3)

    var result3 = dfa3.match_first("hello", 0)
    assert_true(result3.__bool__())
    assert_equal(result3.value().match_text, "hello")


# def test_phone_numbers():
#     """Test phone number pattern matching using DFA."""
#     # General phone number pattern (digits, optional +, dashes, etc.)
#     pattern = "\\d{2}|[+]*(?:[-x‐-―−().\\[\\]/~*]*\\d){3,}[-x‐-―−().\\[\\]/~*ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\\d]*"
#     var ast = parse(pattern)
#     var dfa = compile_simple_pattern(ast)
#     result = dfa.match_first("+1-541-236-5432")
#     assert_true(result.__bool__())
#     assert_equal(result.value().match_text, "+1-541-236-5432")
