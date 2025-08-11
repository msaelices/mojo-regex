from testing import assert_equal, assert_true, assert_false

from regex.optimizer import (
    PatternAnalyzer,
    PatternComplexity,
    is_literal_pattern,
    get_literal_string,
    pattern_has_anchors,
)
from regex.parser import parse


fn test_pattern_analyzer_simple_literal_basic() raises:
    """Test pattern analyzer with basic literal string."""
    var analyzer = PatternAnalyzer()
    var ast = parse("hello")
    var complexity = analyzer.classify(ast)
    assert_equal(complexity.value, PatternComplexity.SIMPLE)


fn test_pattern_analyzer_simple_literal_start_anchor() raises:
    """Test pattern analyzer with literal and start anchor."""
    var analyzer = PatternAnalyzer()
    var ast = parse("^hello")
    assert_equal(analyzer.classify(ast).value, PatternComplexity.SIMPLE)


fn test_pattern_analyzer_simple_literal_end_anchor() raises:
    """Test pattern analyzer with literal and end anchor."""
    var analyzer = PatternAnalyzer()
    var ast = parse("hello$")
    var complexity = analyzer.classify(ast)
    assert_equal(complexity.value, PatternComplexity.SIMPLE)


fn test_pattern_analyzer_simple_quantifiers() raises:
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


fn test_pattern_analyzer_character_class_basic() raises:
    """Test pattern analyzer with basic character class."""
    var analyzer = PatternAnalyzer()
    var ast = parse("[a-z]")
    assert_equal(analyzer.classify(ast).value, PatternComplexity.SIMPLE)


fn test_pattern_analyzer_character_class_plus() raises:
    """Test pattern analyzer with character class and plus quantifier."""
    var analyzer = PatternAnalyzer()
    var ast = parse("[a-z]+")
    assert_equal(analyzer.classify(ast).value, PatternComplexity.SIMPLE)


fn test_pattern_analyzer_character_class_star() raises:
    """Test pattern analyzer with character class and star quantifier."""
    var analyzer = PatternAnalyzer()
    var ast = parse("[0-9]*")
    assert_equal(analyzer.classify(ast).value, PatternComplexity.SIMPLE)


fn test_pattern_analyzer_character_class_negated() raises:
    """Test pattern analyzer with negated character class."""
    var analyzer = PatternAnalyzer()
    var ast = parse("[^a-z]")
    assert_equal(analyzer.classify(ast).value, PatternComplexity.SIMPLE)


fn test_pattern_analyzer_medium_groups() raises:
    """Test pattern analyzer with medium complexity groups."""
    var analyzer = PatternAnalyzer()
    # Simple quantified groups are now SIMPLE (can use DFA)
    var ast1 = parse("(abc)+")
    assert_equal(analyzer.classify(ast1).value, PatternComplexity.SIMPLE)


fn test_pattern_analyzer_medium_alternation() raises:
    """Test pattern analyzer with alternation patterns."""
    var analyzer = PatternAnalyzer()
    # Simple alternation should be SIMPLE to MEDIUM depending on complexity
    var ast2 = parse("a|b|c")
    var complexity2 = analyzer.classify(ast2)
    # This could be SIMPLE or MEDIUM depending on implementation
    assert_true(
        complexity2.value == PatternComplexity.SIMPLE
        or complexity2.value == PatternComplexity.MEDIUM
    )


fn test_is_literal_pattern_hello() raises:
    """Test literal pattern detection with hello."""
    assert_true(is_literal_pattern(parse("hello")))


fn test_is_literal_pattern_alphanumeric() raises:
    """Test literal pattern detection with alphanumeric."""
    assert_true(is_literal_pattern(parse("abc123")))


fn test_is_literal_pattern_empty() raises:
    """Test literal pattern detection with empty pattern."""
    assert_true(is_literal_pattern(parse("")))


fn test_is_literal_pattern_start_anchor() raises:
    """Test literal pattern detection with start anchor."""
    assert_true(is_literal_pattern(parse("^hello")))


fn test_is_literal_pattern_end_anchor() raises:
    """Test literal pattern detection with end anchor."""
    assert_true(is_literal_pattern(parse("hello$")))


fn test_is_literal_pattern_both_anchors() raises:
    """Test literal pattern detection with both anchors."""
    assert_true(is_literal_pattern(parse("^hello$")))


fn test_is_literal_pattern_quantifiers() raises:
    """Test literal pattern detection with quantifiers (should be false)."""
    assert_false(is_literal_pattern(parse("a*")))
    assert_false(is_literal_pattern(parse("a+")))
    assert_false(is_literal_pattern(parse("a?")))


fn test_is_literal_pattern_character_classes() raises:
    """Test literal pattern detection with character classes (should be false).
    """
    assert_false(is_literal_pattern(parse("[a-z]")))


fn test_is_literal_pattern_alternation() raises:
    """Test literal pattern detection with alternation (should be false)."""
    assert_false(is_literal_pattern(parse("a|b")))


fn test_is_literal_pattern_groups() raises:
    """Test literal pattern detection with groups (should be false)."""
    assert_false(is_literal_pattern(parse("(abc)")))


fn test_get_literal_string_basic() raises:
    """Test basic literal string extraction."""
    assert_equal(get_literal_string(parse("hello")), "hello")


fn test_get_literal_string_numbers() raises:
    """Test numbers in literal string."""
    assert_equal(get_literal_string(parse("abc123")), "abc123")


fn test_get_literal_string_empty() raises:
    """Test empty literal string."""
    assert_equal(get_literal_string(parse("")), "")


fn test_get_literal_string_start_anchor() raises:
    """Test literal string extraction with start anchor."""
    assert_equal(get_literal_string(parse("^hello")), "hello")


fn test_get_literal_string_end_anchor() raises:
    """Test literal string extraction with end anchor."""
    assert_equal(get_literal_string(parse("hello$")), "hello")


fn test_get_literal_string_both_anchors() raises:
    """Test literal string extraction with both anchors."""
    assert_equal(get_literal_string(parse("^hello$")), "hello")


fn test_pattern_has_anchors_none() raises:
    """Test pattern with no anchors."""
    var no_anchors = pattern_has_anchors(parse("hello"))
    assert_false(no_anchors[0])  # has_start
    assert_false(no_anchors[1])  # has_end


fn test_pattern_has_anchors_start() raises:
    """Test pattern with start anchor."""
    var start_anchor = pattern_has_anchors(parse("^hello"))
    assert_true(start_anchor[0])  # has_start
    assert_false(start_anchor[1])  # has_end


fn test_pattern_has_anchors_end() raises:
    """Test pattern with end anchor."""
    var end_anchor = pattern_has_anchors(parse("hello$"))
    assert_false(end_anchor[0])  # has_start
    assert_true(end_anchor[1])  # has_end


fn test_pattern_has_anchors_both() raises:
    """Test pattern with both anchors."""
    var both_anchors = pattern_has_anchors(parse("^hello$"))
    assert_true(both_anchors[0])  # has_start
    assert_true(both_anchors[1])  # has_end


fn test_wildcard_classification_basic() raises:
    """Test classification of basic wildcard pattern."""
    var analyzer = PatternAnalyzer()
    assert_equal(analyzer.classify(parse(".")).value, PatternComplexity.SIMPLE)


fn test_wildcard_classification_star() raises:
    """Test classification of wildcard with star quantifier."""
    var analyzer = PatternAnalyzer()
    assert_equal(analyzer.classify(parse(".*")).value, PatternComplexity.SIMPLE)


fn test_wildcard_classification_plus() raises:
    """Test classification of wildcard with plus quantifier."""
    var analyzer = PatternAnalyzer()
    assert_equal(analyzer.classify(parse(".+")).value, PatternComplexity.SIMPLE)


fn test_wildcard_classification_question() raises:
    """Test classification of wildcard with question quantifier."""
    var analyzer = PatternAnalyzer()
    assert_equal(analyzer.classify(parse(".?")).value, PatternComplexity.SIMPLE)


fn test_space_classification() raises:
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


fn test_complex_quantifiers() raises:
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
