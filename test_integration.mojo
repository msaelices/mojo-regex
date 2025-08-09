from regex import match_first, findall
from regex.dfa import compile_simple_pattern
from regex.nfa import NFAEngine
from regex.parser import parse

fn test_dfa_simd() raises:
    """Test DFA engine with SIMD optimizations."""
    print("Testing DFA with SIMD optimizations...")
    
    # Test simple digit pattern
    var pattern = "\\d+"
    var ast = parse(pattern)
    var dfa = compile_simple_pattern(ast)
    
    # Test matching
    var text = "abc123def456"
    var match_result = dfa.match_first(text)
    if match_result:
        var m = match_result.value()
        print("  Found match:", text[m.start_idx:m.end_idx], "at", m.start_idx)
    else:
        print("  No match found")


fn test_nfa_simd() raises:
    """Test NFA engine with SIMD optimizations."""
    print("\nTesting NFA with SIMD optimizations...")
    
    # Test digit pattern with quantifier
    var nfa = NFAEngine("\\d{3,5}")
    
    var text = "12 345 6789 12345 678901"
    var matches = nfa.match_all(text)
    
    print("  Found", len(matches), "matches:")
    for i in range(len(matches)):
        var m = matches[i]
        print("    -", text[m.start_idx:m.end_idx])
    
    # Test character class
    print("\n  Testing [a-z]+ pattern:")
    var nfa2 = NFAEngine("[a-z]+")
    var text2 = "Hello world Test 123"
    var matches2 = nfa2.match_all(text2)
    
    for i in range(len(matches2)):
        var m = matches2[i]
        print("    -", text2[m.start_idx:m.end_idx])


fn main() raises:
    test_dfa_simd()
    test_nfa_simd()
    print("\n✅ Integration tests complete!")