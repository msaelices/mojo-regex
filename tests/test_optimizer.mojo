from testing import assert_equal, assert_true, assert_false

from regex.optimizer import (
    PatternAnalyzer,
    PatternComplexity,
    is_literal_pattern,
    get_literal_string,
    pattern_has_anchors,
)
from regex.parser import parse


def test_pattern_analyzer_simple_literal():
    """Test pattern analyzer with simple literal patterns."""
    var analyzer = PatternAnalyzer()

    # Simple literal string
    var ast1 = parse("hello")
    var complexity1 = analyzer.classify(ast1)
    assert_equal(complexity1.value, PatternComplexity.SIMPLE)

    # Literal with start anchor
    var ast2 = parse("^hello")
    var complexity2 = analyzer.classify(ast2)
    assert_equal(complexity2.value, PatternComplexity.SIMPLE)

    # Literal with end anchor
    var ast3 = parse("hello$")
    var complexity3 = analyzer.classify(ast3)
    assert_equal(complexity3.value, PatternComplexity.SIMPLE)


def test_pattern_analyzer_simple_quantifiers():
    """Test pattern analyzer with simple quantifiers."""
    var analyzer = PatternAnalyzer()

    # Simple quantifiers should be classified as SIMPLE
    var ast1 = parse("a*")
    assert_equal(analyzer.classify(ast1).value, PatternComplexity.SIMPLE)

    var ast2 = parse("a+")
    assert_equal(analyzer.classify(ast2).value, PatternComplexity.SIMPLE)

    var ast3 = parse("a?")
    assert_equal(analyzer.classify(ast3).value, PatternComplexity.SIMPLE)

    var ast4 = parse("a{3}")
    assert_equal(analyzer.classify(ast4).value, PatternComplexity.SIMPLE)

    var ast5 = parse("a{2,5}")
    assert_equal(analyzer.classify(ast5).value, PatternComplexity.SIMPLE)


def test_pattern_analyzer_character_classes():
    """Test pattern analyzer with character classes."""
    var analyzer = PatternAnalyzer()

    # Character classes should be SIMPLE
    var ast1 = parse("[a-z]")
    assert_equal(analyzer.classify(ast1).value, PatternComplexity.SIMPLE)

    var ast2 = parse("[a-z]+")
    assert_equal(analyzer.classify(ast2).value, PatternComplexity.SIMPLE)

    var ast3 = parse("[0-9]*")
    assert_equal(analyzer.classify(ast3).value, PatternComplexity.SIMPLE)

    var ast4 = parse("[^a-z]")
    assert_equal(analyzer.classify(ast4).value, PatternComplexity.SIMPLE)


def test_pattern_analyzer_medium_complexity():
    """Test pattern analyzer with medium complexity patterns."""
    var analyzer = PatternAnalyzer()

    # Simple groups should be MEDIUM
    var ast1 = parse("(abc)+")
    assert_equal(analyzer.classify(ast1).value, PatternComplexity.MEDIUM)

    # Simple alternation should be SIMPLE to MEDIUM depending on complexity
    var ast2 = parse("a|b|c")
    var complexity2 = analyzer.classify(ast2)
    # This could be SIMPLE or MEDIUM depending on implementation
    assert_true(
        complexity2.value == PatternComplexity.SIMPLE
        or complexity2.value == PatternComplexity.MEDIUM
    )


def test_is_literal_pattern():
    """Test literal pattern detection."""
    # Simple literals should be detected
    assert_true(is_literal_pattern(parse("hello")))
    assert_true(is_literal_pattern(parse("abc123")))
    assert_true(is_literal_pattern(parse("")))

    # Literals with anchors should still be literal
    assert_true(is_literal_pattern(parse("^hello")))
    assert_true(is_literal_pattern(parse("hello$")))
    assert_true(is_literal_pattern(parse("^hello$")))

    # Non-literals should not be detected
    assert_false(is_literal_pattern(parse("a*")))
    assert_false(is_literal_pattern(parse("a+")))
    assert_false(is_literal_pattern(parse("a?")))
    assert_false(is_literal_pattern(parse("[a-z]")))
    assert_false(is_literal_pattern(parse("a|b")))
    assert_false(is_literal_pattern(parse("(abc)")))


def test_get_literal_string():
    """Test literal string extraction."""
    assert_equal(get_literal_string(parse("hello")), "hello")
    assert_equal(get_literal_string(parse("abc123")), "abc123")
    assert_equal(get_literal_string(parse("")), "")

    # Anchors should be ignored in literal string extraction
    assert_equal(get_literal_string(parse("^hello")), "hello")
    assert_equal(get_literal_string(parse("hello$")), "hello")
    assert_equal(get_literal_string(parse("^hello$")), "hello")


def test_pattern_has_anchors():
    """Test anchor detection."""
    # No anchors
    var no_anchors = pattern_has_anchors(parse("hello"))
    assert_false(no_anchors[0])  # has_start
    assert_false(no_anchors[1])  # has_end

    # Start anchor only
    var start_anchor = pattern_has_anchors(parse("^hello"))
    assert_true(start_anchor[0])  # has_start
    assert_false(start_anchor[1])  # has_end

    # End anchor only
    var end_anchor = pattern_has_anchors(parse("hello$"))
    assert_false(end_anchor[0])  # has_start
    assert_true(end_anchor[1])  # has_end

    # Both anchors
    var both_anchors = pattern_has_anchors(parse("^hello$"))
    assert_true(both_anchors[0])  # has_start
    assert_true(both_anchors[1])  # has_end


def test_wildcard_classification():
    """Test classification of wildcard patterns."""
    var analyzer = PatternAnalyzer()

    # Simple wildcard patterns should be SIMPLE
    assert_equal(analyzer.classify(parse(".")).value, PatternComplexity.SIMPLE)
    assert_equal(analyzer.classify(parse(".*")).value, PatternComplexity.SIMPLE)
    assert_equal(analyzer.classify(parse(".+")).value, PatternComplexity.SIMPLE)
    assert_equal(analyzer.classify(parse(".?")).value, PatternComplexity.SIMPLE)


def test_space_classification():
    """Test classification of whitespace patterns."""
    var analyzer = PatternAnalyzer()

    # Whitespace patterns should be SIMPLE
    assert_equal(
        analyzer.classify(parse("\\s")).value, PatternComplexity.SIMPLE
    )
    assert_equal(
        analyzer.classify(parse("\\s*")).value, PatternComplexity.SIMPLE
    )
    assert_equal(
        analyzer.classify(parse("\\s+")).value, PatternComplexity.SIMPLE
    )


def test_complex_quantifiers():
    """Test classification of complex quantifiers."""
    var analyzer = PatternAnalyzer()

    # Large quantifiers should be MEDIUM or COMPLEX
    var ast1 = parse("a{50,100}")
    var complexity1 = analyzer.classify(ast1)
    assert_true(
        complexity1.value == PatternComplexity.MEDIUM
        or complexity1.value == PatternComplexity.COMPLEX
    )

    # Very large quantifiers should be COMPLEX
    var ast2 = parse("a{1000,2000}")
    assert_equal(analyzer.classify(ast2).value, PatternComplexity.COMPLEX)
