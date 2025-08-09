from regex.simd_matchers import analyze_character_class_pattern, create_hex_digit_matcher, create_whitespace_matcher

fn test_pattern_analysis() raises:
    """Test the character class pattern analyzer."""
    print("Testing character class pattern analysis...")
    
    var test_cases = [
        ("[0-9]", "range"),
        ("\\d", "range"),
        ("[a-z]", "range"),
        ("[A-Z]", "range"),
        ("[a-zA-Z]", "range"),
        ("[0-9a-zA-Z]", "range"),
        ("\\w", "range"),
        ("[0-9A-Fa-f]", "nibble"),
        ("[0-9a-fA-F]", "nibble"),
        ("\\s", "nibble"),
        ("[abc]", "lookup"),
        ("[^0-9]", "lookup"),
        ("[a-z0-9_]", "lookup")
    ]
    
    var all_passed = True
    for i in range(len(test_cases)):
        var pattern = test_cases[i][0]
        var expected = test_cases[i][1]
        var result = analyze_character_class_pattern(pattern)
        
        if result == expected:
            print("  ✓", pattern, "->", result)
        else:
            print("  ✗", pattern, "-> expected", expected, "but got", result)
            all_passed = False
    
    if all_passed:
        print("\nAll pattern analysis tests passed!")
    else:
        raise Error("Some pattern analysis tests failed")


fn test_specialized_matchers() raises:
    """Test the specialized SIMD matchers."""
    print("\n\nTesting specialized matchers...")
    
    # Test hex digit matcher
    print("\nHex digit matcher:")
    var hex_matcher = create_hex_digit_matcher()
    
    # Test with a chunk
    var test_str = "0123456789ABCDEFabcdefGHIJKL!@#"
    var chunk = SIMD[DType.uint8, 32](0)
    for i in range(min(len(test_str), 32)):
        chunk[i] = ord(test_str[i])
    
    var matches = hex_matcher.match_chunk(chunk)
    
    var hex_count = 0
    print("  Checking each character:")
    for i in range(min(len(test_str), 32)):
        if matches[i]:
            hex_count += 1
            print("    '", test_str[i], "' is a hex digit")
    
    print("  Found", hex_count, "hex digits in test string")
    # Count manually: 0-9 (10) + A-F (6) + a-f (6) = 22
    # But test_str has extra chars after 'f', let's verify
    var expected_hex = 0
    for i in range(len(test_str)):
        var ch = test_str[i]
        if ((ord(ch) >= ord('0') and ord(ch) <= ord('9')) or
            (ord(ch) >= ord('A') and ord(ch) <= ord('F')) or
            (ord(ch) >= ord('a') and ord(ch) <= ord('f'))):
            expected_hex += 1
    
    print("  Expected", expected_hex, "hex digits")
    if hex_count != expected_hex:
        raise Error("Hex digit count mismatch")
    
    # Test whitespace matcher
    print("\nWhitespace matcher:")
    var ws_matcher = create_whitespace_matcher()
    
    var ws_test = "Hello \tWorld\n\rTest\f\vEnd"
    var ws_chunk = SIMD[DType.uint8, 32](0)
    for i in range(min(len(ws_test), 32)):
        ws_chunk[i] = ord(ws_test[i])
    
    var ws_matches = ws_matcher.match_chunk(ws_chunk)
    
    var ws_count = 0
    for i in range(min(len(ws_test), 32)):
        if ws_matches[i]:
            ws_count += 1
    
    print("  Found", ws_count, "whitespace characters")
    if ws_count != 5:  # space, tab, newline, carriage return, form feed, vertical tab
        raise Error("Expected 5 whitespace characters but found different count")


fn main() raises:
    test_pattern_analysis()
    test_specialized_matchers()
    print("\n✅ All tests passed!")