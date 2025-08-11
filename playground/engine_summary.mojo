# RUN: %mojo-no-debug %s

from regex.matcher import compile_regex


def main():
    """Generate a summary of engine usage across benchmark patterns."""
    print("=== REGEX ENGINE USAGE ANALYSIS ===")
    print("")

    # All benchmark patterns with their names
    var patterns = List[String]()
    var names = List[String]()

    # Basic patterns
    patterns.append("hello")
    names.append("literal_match")

    patterns.append(".*")
    names.append("wildcard_match_any")

    patterns.append("a*")
    names.append("quantifier_zero_or_more")

    patterns.append("a+")
    names.append("quantifier_one_or_more")

    patterns.append("a?")
    names.append("quantifier_zero_or_one")

    patterns.append("[a-z]+")
    names.append("range_lowercase")

    patterns.append("[0-9]+")
    names.append("range_digits")

    patterns.append("[a-zA-Z0-9]+")
    names.append("range_alphanumeric")

    patterns.append("^abc")
    names.append("anchor_start")

    patterns.append("xyz$")
    names.append("anchor_end")

    patterns.append("a|b|c")
    names.append("alternation_simple")

    patterns.append("abc|def|ghi")
    names.append("alternation_words")

    patterns.append("(abc)+")
    names.append("group_quantified")

    patterns.append("(a|b)*")
    names.append("group_alternation")

    patterns.append("a")
    names.append("match_all_simple")

    patterns.append("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+[.][a-zA-Z]{2,}")
    names.append("complex_email_extraction")

    patterns.append("[0-9]+[.]?[0-9]*")
    names.append("complex_number_extraction")

    patterns.append("[^a-zA-Z0-9]+")
    names.append("simd_negated_alphanumeric")

    patterns.append("[a-z]+[0-9]+")
    names.append("simd_multi_char_class")

    patterns.append("hello.*world")
    names.append("literal_prefix_patterns")

    patterns.append("hello.*")
    names.append("literal_prefix_simple")

    patterns.append(".*@example\\.com")
    names.append("required_literal_patterns")

    patterns.append("(hello|help|helicopter)")
    names.append("alternation_common_prefix")

    var dfa_count = 0
    var nfa_count = 0
    var simple_count = 0
    var medium_count = 0
    var complex_count = 0

    print("Pattern Analysis:")
    print("==================")

    for i in range(len(patterns)):
        var pattern = patterns[i]
        var name = names[i]
        try:
            var compiled = compile_regex(pattern)
            var engine = compiled.matcher.get_engine_type()
            var complexity = compiled.matcher.get_complexity()

            var complexity_str: String
            if complexity.value == 0:  # SIMPLE
                complexity_str = "SIMPLE"
                simple_count += 1
            elif complexity.value == 1:  # MEDIUM
                complexity_str = "MEDIUM"
                medium_count += 1
            else:  # COMPLEX
                complexity_str = "COMPLEX"
                complex_count += 1

            if engine == "DFA":
                dfa_count += 1
            else:
                nfa_count += 1

            print(
                "  "
                + name
                + ": "
                + pattern
                + " -> "
                + engine
                + " ("
                + complexity_str
                + ")"
            )
        except e:
            print("  " + name + ": " + pattern + " -> ERROR")

    print("")
    print("=== SUMMARY ===")
    print("Total patterns analyzed: " + String(len(patterns)))
    print(
        "DFA engine used: "
        + String(dfa_count)
        + " patterns ("
        + String(Int(100 * dfa_count / len(patterns)))
        + "%)"
    )
    print(
        "NFA engine used: "
        + String(nfa_count)
        + " patterns ("
        + String(Int(100 * nfa_count / len(patterns)))
        + "%)"
    )
    print("")
    print("Complexity breakdown:")
    print(
        "  SIMPLE: "
        + String(simple_count)
        + " patterns ("
        + String(Int(100 * simple_count / len(patterns)))
        + "%)"
    )
    print(
        "  MEDIUM: "
        + String(medium_count)
        + " patterns ("
        + String(Int(100 * medium_count / len(patterns)))
        + "%)"
    )
    print(
        "  COMPLEX: "
        + String(complex_count)
        + " patterns ("
        + String(Int(100 * complex_count / len(patterns)))
        + "%)"
    )

    print("")
    print("Engine Selection Rules Observed:")
    print("  - DFA: Used for simple literals, anchors, character classes")
    print("  - NFA: Used for alternation, groups, wildcards, complex patterns")
    print(
        "  - The hybrid matcher intelligently routes based on pattern"
        " complexity"
    )
