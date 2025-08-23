#!/usr/bin/env mojo

from regex import match_first, search, findall
from regex.parser import parse
from regex.optimizer import PatternAnalyzer, PatternComplexity


fn test_complex_pattern() raises:
    var pattern = "(?:3052(?:0[0-8]|[1-9]\\d)|5056(?:[0-35-9]\\d|4[0-68]))\\d{4}|(?:2742|305[3-9]|472[247-9]|505[2-57-9]|983[2-47-9])\\d{6}|(?:2(?:0[1-35-9]|1[02-9]|2[03-57-9]|3[1459]|4[08]|5[1-46]|6[0279]|7[0269]|8[13])|3(?:0[1-47-9]|1[02-9]|2[0135-79]|3[0-24679]|4[167]|5[0-2]|6[01349]|8[056])|4(?:0[124-9]|1[02-579]|2[3-5]|3[0245]|4[023578]|58|6[349]|7[0589]|8[04])|5(?:0[1-47-9]|1[0235-8]|20|3[0149]|4[01]|5[179]|6[1-47]|7[0-5]|8[0256])|6(?:0[1-35-9]|1[024-9]|2[03689]|3[016]|4[0156]|5[01679]|6[0-279]|78|8[0-29])|7(?:0[1-46-8]|1[2-9]|2[04-8]|3[0-247]|4[037]|5[47]|6[02359]|7[0-59]|8[156])|8(?:0[1-68]|1[02-8]|2[0168]|3[0-2589]|4[03578]|5[046-9]|6[02-5]|7[028])|9(?:0[1346-9]|1[02-9]|2[0589]|3[0146-8]|4[01357-9]|5[12469]|7[0-389]|8[04-69]))[2-9]\\d{6}"

    print("=== Testing Complex Pattern ===")
    print("Pattern:", pattern)
    print()

    # Test if the pattern compiles
    try:
        var ast = parse(pattern)
        print("✅ Pattern parsing: SUCCESS")

        # Analyze complexity
        var analyzer = PatternAnalyzer()
        var complexity = analyzer.classify(ast)
        var complexity_str: String
        if complexity.value == PatternComplexity.SIMPLE:
            complexity_str = "SIMPLE (DFA eligible)"
        elif complexity.value == PatternComplexity.MEDIUM:
            complexity_str = "MEDIUM (Hybrid)"
        else:
            complexity_str = "COMPLEX (NFA only)"

        print("Pattern Complexity:", complexity_str)

        var optimization_info = analyzer.analyze_optimizations(ast)
        print("Suggested engine:", optimization_info.suggested_engine)
        print()

    except e:
        print("❌ Pattern parsing FAILED:", e)
        return

    # Test with sample matching data
    var test_cases = List[String](
        "305200123456",  # Should match first alternation
        "505601234567",  # Should match first alternation
        "274212345678",  # Should match second alternation
        "305912345678",  # Should match second alternation
        "212345672890",  # Should match third alternation
        "312345672890",  # Should match third alternation
        "1234567890",  # Should NOT match
        "30520",  # Should NOT match (too short)
    )

    print("=== Testing Pattern Matches ===")
    for i in range(len(test_cases)):
        var test_str = test_cases[i]
        try:
            var result = match_first(pattern, test_str)
            if result:
                print("✅", test_str, "-> MATCH")
            else:
                print("❌", test_str, "-> NO MATCH")
        except e:
            print("💥", test_str, "-> ERROR:", e)

    print()

    # Test findall functionality
    print("=== Testing FindAll ===")
    var combined_text = "Numbers: 305200123456 and 274212345678 and 212345672890 and invalid 1234567890"
    try:
        var matches = findall(pattern, combined_text)
        print("Found", len(matches), "matches in text")
        for i in range(len(matches)):
            print("Match", i + 1, ":", matches[i].get_match_text())
    except e:
        print("💥 FindAll ERROR:", e)


fn main() raises:
    test_complex_pattern()
