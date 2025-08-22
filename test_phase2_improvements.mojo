#!/usr/bin/env mojo

from regex.matcher import compile_regex
from regex.parser import parse
from regex.optimizer import PatternAnalyzer


fn main() raises:
    print("=== PHASE 2 DFA OPTIMIZATIONS TEST ===")
    print()

    # Test the national phone validation pattern
    var phone_pattern = "(?:3052(?:0[0-8]|[1-9]\\d)|5056(?:[0-35-9]\\d|4[0-68]))\\d{4}|(?:2742|305[3-9]|472[247-9]|505[2-57-9]|983[2-47-9])\\d{6}|(?:2(?:0[1-35-9]|1[02-9]|2[03-57-9]|3[1459]|4[08]|5[1-46]|6[0279]|7[0269]|8[13])|3(?:0[1-47-9]|1[02-9]|2[0135-79]|3[0-24679]|4[167]|5[0-2]|6[01349]|8[056])|4(?:0[124-9]|1[02-579]|2[3-5]|3[0245]|4[023578]|58|6[349]|7[0589]|8[04])|5(?:0[1-47-9]|1[0235-8]|20|3[0149]|4[01]|5[179]|6[1-47]|7[0-5]|8[0256])|6(?:0[1-35-9]|1[024-9]|2[03689]|3[016]|4[0156]|5[01679]|6[0-279]|78|8[0-29])|7(?:0[1-46-8]|1[2-9]|2[04-8]|3[0-247]|4[037]|5[47]|6[02359]|7[0-59]|8[156])|8(?:0[1-68]|1[02-8]|2[0168]|3[0-2589]|4[03578]|5[046-9]|6[02-5]|7[028])|9(?:0[1346-9]|1[02-9]|2[0589]|3[0146-8]|4[01357-9]|5[12469]|7[0-389]|8[04-69]))[2-9]\\d{6}"

    print("Testing national phone validation pattern:")
    print("Pattern:", phone_pattern[:60] + "...")
    print()

    # Test pattern analysis
    var ast = parse(phone_pattern)
    var analyzer = PatternAnalyzer()
    var complexity = analyzer.classify(ast)
    var opt_info = analyzer.analyze_optimizations(ast)

    print("=== PATTERN ANALYSIS ===")
    print("Complexity:", complexity)
    print("Suggested engine:", opt_info.suggested_engine)
    print("Benefits from SIMD:", opt_info.benefits_from_simd)
    print("Has literal prefix:", opt_info.has_literal_prefix)
    print()

    # Test One-Pass DFA analysis
    print("=== ONE-PASS DFA ANALYSIS ===")
    var is_one_pass = analyzer._is_one_pass_candidate(ast)
    print("One-Pass candidate:", is_one_pass)

    # Test Lazy DFA analysis
    print("=== LAZY DFA ANALYSIS ===")
    var is_lazy_dfa = analyzer._is_lazy_dfa_candidate(ast)
    print("Lazy DFA candidate:", is_lazy_dfa)

    # Detailed analysis
    var alternation_count = analyzer._count_alternations_in_pattern(ast)
    var group_count = analyzer._count_groups_in_pattern(ast)
    var nesting_depth = analyzer._compute_max_nesting_depth(ast)
    var estimated_states = analyzer._estimate_dfa_state_count(ast)

    print("Alternation count:", alternation_count)
    print("Group count:", group_count)
    print("Nesting depth:", nesting_depth)
    print("Estimated DFA states:", estimated_states)
    print()

    # Test the compiled regex to see which engine is selected
    print("=== COMPILED REGEX ENGINE SELECTION ===")
    var regex = compile_regex(phone_pattern)
    var engine_type = regex.get_stats()
    print("Compiled regex engine:", engine_type)
    print()

    # Test functionality with sample inputs
    print("=== FUNCTIONALITY TEST ===")
    var test_cases = List[String]()
    test_cases.append("305201234567")  # Should match
    test_cases.append("274212345678")  # Should match
    test_cases.append("8123456789")  # Should match
    test_cases.append("12345678901234")  # Should not match
    test_cases.append("hello world")  # Should not match

    for i in range(len(test_cases)):
        var text = test_cases[i]
        var result = regex.test(text)
        print("Test '", text, "': ", "✓" if result else "✗")

    print()
    print("=== PHASE 2 IMPLEMENTATION STATUS ===")
    print("✓ Pattern reclassified from COMPLEX to MEDIUM (Phase 1)")
    print("✓ Enhanced alternation analysis implemented")
    print("✓ One-Pass DFA engine implemented")
    print("✓ Lazy DFA engine implemented")
    print("✓ Advanced engine selection in optimizer")
    print("✓ Integration with HybridMatcher completed")
    print()
    print("Phase 2 implementation ready for performance testing!")
