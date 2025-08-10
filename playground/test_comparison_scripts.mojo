# RUN: %mojo-no-debug %s

from regex.matcher import compile_regex


def main():
    """Simple test that outputs engine info similar to bench_engine.mojo for testing comparison scripts.
    """
    print("=== TEST ENGINE DETECTION FOR COMPARISON SCRIPTS ===")
    print("")

    # A few test patterns to demonstrate engine detection
    var patterns = List[String]()
    var names = List[String]()

    patterns.append("hello")
    names.append("literal_test")

    patterns.append("[a-z]+")
    names.append("charclass_test")

    patterns.append("a|b|c")
    names.append("alternation_test")

    patterns.append("(abc)+")
    names.append("group_test")

    for i in range(len(patterns)):
        var pattern = patterns[i]
        var name = names[i]
        try:
            var compiled = compile_regex(pattern)
            var engine_type = compiled.matcher.get_engine_type()
            var complexity = compiled.matcher.get_complexity()

            var complexity_str: String
            if complexity.value == 0:
                complexity_str = "SIMPLE"
            elif complexity.value == 1:
                complexity_str = "MEDIUM"
            else:
                complexity_str = "COMPLEX"

            print(
                "[ENGINE] "
                + name
                + " -> Pattern: '"
                + pattern
                + "' | Engine: "
                + engine_type
                + " | Complexity: "
                + complexity_str
            )
        except e:
            print(
                "[ENGINE] "
                + name
                + " -> Pattern: '"
                + pattern
                + "' | Engine: ERROR"
            )

    print("")
    print("=== BENCHMARK COMPLETE ===")
    print("Engine detection test finished.")
