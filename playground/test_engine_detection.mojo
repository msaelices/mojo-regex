# RUN: %mojo-no-debug %s

from regex.matcher import compile_regex


def main():
    """Test engine detection for various patterns."""
    print("=== REGEX ENGINE DETECTION TEST ===")
    print("")

    # Test patterns that should use DFA (SIMPLE complexity)
    var dfa_patterns = List[String]()
    dfa_patterns.append("hello")  # Simple literal
    dfa_patterns.append("^start")  # Start anchor
    dfa_patterns.append("end$")  # End anchor
    dfa_patterns.append("[a-z]+")  # Character class
    dfa_patterns.append("[0-9]*")  # Character class with quantifier

    # Test patterns that should use NFA (MEDIUM/COMPLEX complexity)
    var nfa_patterns = List[String]()
    nfa_patterns.append("a|b|c")  # Alternation
    nfa_patterns.append("(abc)+")  # Groups with quantifier
    nfa_patterns.append("hello.*world")  # Complex with wildcards
    nfa_patterns.append(
        "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+[.][a-zA-Z]{2,}"
    )  # Email regex
    nfa_patterns.append("(hello|help|helicopter)")  # Alternation with groups

    print("Expected DFA patterns:")
    for i in range(len(dfa_patterns)):
        var pattern = dfa_patterns[i]
        try:
            var compiled = compile_regex(pattern)
            var engine = compiled.matcher.get_engine_type()
            var stats = compiled.get_stats()
            print(
                "  Pattern: '"
                + pattern
                + "' -> Engine: "
                + engine
                + " | "
                + stats
            )
        except e:
            print("  Pattern: '" + pattern + "' -> ERROR: compilation failed")

    print("")
    print("Expected NFA patterns:")
    for i in range(len(nfa_patterns)):
        var pattern = nfa_patterns[i]
        try:
            var compiled = compile_regex(pattern)
            var engine = compiled.matcher.get_engine_type()
            var stats = compiled.get_stats()
            print(
                "  Pattern: '"
                + pattern
                + "' -> Engine: "
                + engine
                + " | "
                + stats
            )
        except e:
            print("  Pattern: '" + pattern + "' -> ERROR: compilation failed")

    print("")
    print("=== ENGINE DETECTION TEST COMPLETE ===")
