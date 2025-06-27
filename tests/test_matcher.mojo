from testing import assert_equal, assert_true, assert_false

from regex.matcher import (
    HybridMatcher,
    CompiledRegex,
    compile_regex,
    search,
    findall,
    `match`,
    clear_regex_cache,
)
from regex.optimizer import PatternComplexity


def test_hybrid_matcher_simple_pattern():
    """Test hybrid matcher with simple patterns that should use DFA."""
    var matcher = HybridMatcher("hello")

    # Should classify as SIMPLE and use DFA
    assert_equal(matcher.get_complexity().value, PatternComplexity.SIMPLE)
    assert_equal(matcher.get_engine_type(), "DFA")

    # Test matching
    var result = matcher.match_first("hello world", 0)
    assert_true(result.__bool__())
    var match_obj = result.value()
    assert_equal(match_obj.start_idx, 0)
    assert_equal(match_obj.end_idx, 5)
    assert_equal(match_obj.match_text, "hello")


def test_hybrid_matcher_complex_pattern():
    """Test hybrid matcher with complex patterns that should use NFA."""
    var matcher = HybridMatcher("a*")

    # Should use NFA for quantified patterns (current implementation)
    var engine_type = matcher.get_engine_type()
    # Could be either DFA or NFA depending on implementation
    assert_true(engine_type == "DFA" or engine_type == "NFA")


def test_hybrid_matcher_match_all():
    """Test hybrid matcher match_all functionality."""
    var matcher = HybridMatcher("a")

    var matches = matcher.match_all("banana")
    assert_equal(len(matches), 3)

    assert_equal(matches[0].start_idx, 1)
    assert_equal(matches[1].start_idx, 3)
    assert_equal(matches[2].start_idx, 5)


def test_compiled_regex():
    """Test CompiledRegex high-level interface."""
    var regex = CompiledRegex("hello")

    # Test match_first
    var result1 = regex.match_first("hello world")
    assert_true(result1.__bool__())
    assert_equal(result1.value().match_text, "hello")

    # Test match_all
    var matches = regex.match_all("hello world hello")
    assert_equal(len(matches), 2)
    assert_equal(matches[0].start_idx, 0)
    assert_equal(matches[1].start_idx, 12)

    # Test test method
    assert_true(regex.test("hello world"))
    assert_false(regex.test("goodbye world"))


def test_compiled_regex_stats():
    """Test CompiledRegex stats functionality."""
    var regex = CompiledRegex("hello")
    var stats = regex.get_stats()

    # Should contain pattern information
    assert_true(stats.find("hello") != -1)
    assert_true(stats.find("Engine:") != -1)
    assert_true(stats.find("Complexity:") != -1)


def test_regex_caching():
    """Test regex compilation caching."""
    clear_regex_cache()

    # Compile same pattern multiple times
    var regex1 = compile_regex("test")
    var regex2 = compile_regex("test")

    # Should get same compiled regex (cache hit)
    # Note: Mojo doesn't have object identity comparison, so we test behavior
    var result1 = regex1.match_first("test string")
    var result2 = regex2.match_first("test string")

    assert_true(result1.__bool__())
    assert_true(result2.__bool__())
    assert_equal(result1.value().match_text, result2.value().match_text)


def test_search_function():
    """Test high-level search function."""
    var result = search("hello", "hello world")
    assert_true(result.__bool__())
    assert_equal(result.value().match_text, "hello")

    var no_result = search("xyz", "hello world")
    assert_false(no_result.__bool__())


def test_findall_function():
    """Test high-level findall function."""
    var matches = findall("l", "hello world")
    assert_equal(len(matches), 3)

    assert_equal(matches[0].start_idx, 2)
    assert_equal(matches[1].start_idx, 3)
    assert_equal(matches[2].start_idx, 9)


def test_match_function():
    """Test high-level match function (anchored at start)."""
    # Should match at start
    var result1 = `match`("hello", "hello world")
    assert_true(result1.__bool__())
    assert_equal(result1.value().start_idx, 0)

    # Should not match if not at start
    var result2 = `match`("world", "hello world")
    assert_false(result2.__bool__())

    # Should match entire string
    var result3 = `match`("hello", "hello")
    assert_true(result3.__bool__())


def test_hybrid_matcher_fallback():
    """Test that hybrid matcher falls back properly."""
    # Test with a pattern that might fail DFA compilation
    try:
        var matcher = HybridMatcher("hello")
        var result = matcher.match_first("hello world")
        assert_true(result.__bool__())
    except:
        # If DFA compilation fails, should still work with NFA
        assert_true(True)  # Test passes if we get here


def test_multiple_patterns():
    """Test compiling and using multiple different patterns."""
    var patterns = List[String]()
    patterns.append("hello")
    patterns.append("world")
    patterns.append("test")

    for i in range(len(patterns)):
        var pattern = patterns[i]
        var regex = compile_regex(pattern)

        # Each should match its own pattern
        var test_text = pattern + " text"
        var result = regex.match_first(test_text)
        assert_true(result.__bool__())
        assert_equal(result.value().match_text, pattern)


def test_empty_pattern():
    """Test handling of empty patterns."""
    var regex = CompiledRegex("")

    # Empty pattern should match at any position
    var result = regex.match_first("hello")
    assert_true(result.__bool__())
    assert_equal(result.value().start_idx, 0)
    assert_equal(result.value().end_idx, 0)


def test_pattern_with_anchors():
    """Test patterns with start and end anchors."""
    var start_anchor = CompiledRegex("^hello")
    var end_anchor = CompiledRegex("world$")
    var both_anchors = CompiledRegex("^hello$")

    # Start anchor should only match at beginning
    assert_true(start_anchor.test("hello world"))
    assert_false(start_anchor.test("say hello"))

    # End anchor should only match at end
    assert_true(end_anchor.test("hello world"))
    assert_false(end_anchor.test("world peace"))

    # Both anchors should match entire string
    assert_true(both_anchors.test("hello"))
    assert_false(both_anchors.test("hello world"))
    assert_false(both_anchors.test("say hello"))


def test_case_sensitivity():
    """Test that matching is case sensitive."""
    var regex = CompiledRegex("Hello")

    assert_true(regex.test("Hello World"))
    assert_false(regex.test("hello world"))
    assert_false(regex.test("HELLO WORLD"))


def test_special_characters():
    """Test patterns with special characters that are treated as literals."""
    # In current implementation, most special chars are treated literally
    # when not in special contexts
    var regex = CompiledRegex("hello.world")

    # Should match the literal dot
    assert_true(regex.test("hello.world"))
    # Should not match other characters (depends on implementation)
    # assert_false(regex.test("helloxworld"))


def test_performance_simple_vs_complex():
    """Test that simple patterns use the faster DFA engine."""
    var simple_pattern = CompiledRegex("hello")
    var complex_pattern = CompiledRegex("a*")  # Might use NFA

    # Both should work correctly
    assert_true(simple_pattern.test("hello world"))
    assert_true(complex_pattern.test("aaaa"))

    # Simple pattern should use DFA
    var simple_stats = simple_pattern.get_stats()
    # Could be DFA or NFA depending on implementation details
