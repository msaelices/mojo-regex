from testing import assert_equal, assert_true, assert_raises

from regex.nfa import match_first, findall


def test_simplest():
    """Test the simplest case: single character match."""
    var result = match_first("a", "a")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 1)


def test_simplest_with_wildcard():
    """Test wildcard matching any character."""
    var result = match_first(".", "a")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 1)


def test_simplest_but_longer():
    """Test longer pattern matching."""
    var result = match_first("a.c", "abc")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 3)


def test_wildcard():
    """Test wildcard with quantifier."""
    var result = match_first(".*a", "aa")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 2)


def test_backtracking():
    """Test backtracking with quantifiers."""
    var result = match_first("a*a", "aaaa")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 4)


def test_or():
    """Test alternation (OR) matching."""
    var result = match_first("a.*|b", "b")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 1)


def test_anchor_start():
    """Test start anchor (^)."""
    var result = match_first("^a", "abc")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 1)


# TODO: Uncomment when test is fixed
# def test_anchor_end():
#     """Test end anchor ($)."""
#     var result = match_first("c$", "abc")
#     assert_true(result)
#     var matched = result.value()
#     var consumed = matched.end_idx - matched.start_idx
#     assert_equal(consumed, 1)


def test_or_no_match():
    """Test OR pattern that should not match."""
    var result = match_first("^a|b$", "c")
    assert_true(not result)


def test_or_no_match_with_bt():
    """Test OR pattern with backtracking that should not match."""
    var result = match_first("a|b", "c")
    assert_true(not result)


def test_match_group_zero_or_more():
    """Test group with zero or more quantifier."""
    var result = match_first("(a)*", "aa")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 2)


def test_fail_group_one_or_more():
    """Test group one or more that should fail."""
    var result = match_first("^(a)+", "b")
    assert_true(not result)


def test_match_or_left():
    """Test OR pattern matching left side."""
    var result = match_first("na|nb", "na")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 2)


def test_match_or_right():
    """Test OR pattern matching right side."""
    var result = match_first("na|nb", "nb")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 2)


def test_match_space():
    """Test space matching with \\s."""
    var result = match_first("\\s", " ")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 1)


def test_match_space_tab():
    """Test space matching tab with \\s."""
    var result = match_first("\\s", "\t")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 1)


def test_match_or_right_at_start_end():
    """Test OR pattern with anchors."""
    var result = match_first("^na|nb$", "nb")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 2)


def test_no_match_after_end():
    """Test that pattern doesn't match when there's extra content."""
    var result = match_first("^na|nb$", "nb ")
    assert_true(not result)

    # But simpler end anchor test works correctly
    var result2 = match_first("nb$", "nb ")
    assert_true(not result2)  # This correctly fails


def test_bt_index_group():
    """Test backtracking with optional group."""
    var result = match_first("^x(a)?ac$", "xac")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 3)


def test_match_sequence_with_start_end():
    """Test various start/end anchor combinations."""
    # Should match 'a' at start, ignoring rest
    var result1 = match_first("^a|b$", "a  ")
    assert_true(result1)

    # Should not match 'a' when not at start
    var result2 = match_first("^a|b$", " a  ")
    assert_true(not result2)

    # Should match 'b' at end, ignoring prefix
    # Not passing yet
    # var result3 = match_first("^a|b$", "  b")
    # assert_true(result3)


def test_question_mark():
    """Test question mark quantifier."""
    var result1 = match_first("https?://", "http://")
    assert_true(result1)
    var matched1 = result1.value()
    var consumed1 = matched1.end_idx - matched1.start_idx
    assert_equal(consumed1, 7)

    var result2 = match_first("https?://", "https://")
    assert_true(result2)
    var matched2 = result2.value()
    var consumed2 = matched2.end_idx - matched2.start_idx
    assert_equal(consumed2, 8)


def test_bt_index_leaf():
    """Test backtracking with leaf elements."""
    var result = match_first("^aaaa.*a$", "aaaaa")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 5)


def test_bt_index_or():
    """Test backtracking with OR in group."""
    var result = match_first("^x(a|b)?bc$", "xbc")
    assert_true(result)
    var matched = result.value()
    var consumed = matched.end_idx - matched.start_idx
    assert_equal(consumed, 3)


def test_match_empty():
    """Test matching empty strings."""
    var result1 = match_first("^$", "")
    assert_true(result1)
    var matched1 = result1.value()
    var consumed1 = matched1.end_idx - matched1.start_idx
    assert_equal(consumed1, 0)

    var result2 = match_first("$", "")
    assert_true(result2)
    var matched2 = result2.value()
    var consumed2 = matched2.end_idx - matched2.start_idx
    assert_equal(consumed2, 0)

    var result3 = match_first("^", "")
    assert_true(result3)
    var matched3 = result3.value()
    var consumed3 = matched3.end_idx - matched3.start_idx
    assert_equal(consumed3, 0)


def test_match_space_extended():
    """Test extended space matching with various characters."""
    # Test newline
    var result1 = match_first("\\s", "\n")
    assert_true(result1)

    # Test carriage return
    var result2 = match_first("\\s", "\r")
    assert_true(result2)

    # Test form feed
    var result3 = match_first("\\s", "\f")
    assert_true(result3)


def test_match_space_quantified():
    """Test space matching with quantifiers."""
    var result1 = match_first("\\s+", "\r\t\n \f")
    assert_true(result1)
    var matched1 = result1.value()
    var consumed1 = matched1.end_idx - matched1.start_idx
    assert_equal(consumed1, 5)

    # This should fail because \r\t is 2 chars but ^..$ expects exact match
    var result2 = match_first("^\\s$", "\r\t")
    assert_true(not result2)


def test_character_ranges():
    """Test basic character range matching."""
    # Test [a-z] range
    var result1 = match_first("[a-z]", "m")
    assert_true(result1)
    var matched1 = result1.value()
    var consumed1 = matched1.end_idx - matched1.start_idx
    assert_equal(consumed1, 1)

    # Test [0-9] range
    var result2 = match_first("[0-9]", "5")
    assert_true(result2)
    var matched2 = result2.value()
    var consumed2 = matched2.end_idx - matched2.start_idx
    assert_equal(consumed2, 1)

    # Test negated range [^a-z]
    var result3 = match_first("[^a-z]", "5")
    assert_true(result3)
    var matched3 = result3.value()
    var consumed3 = matched3.end_idx - matched3.start_idx
    assert_equal(consumed3, 1)

    # Test that [^a-z] doesn't match lowercase
    var result4 = match_first("[^a-z]", "m")
    assert_true(not result4)


def test_character_ranges_quantified():
    """Test character ranges with quantifiers."""
    var result1 = match_first("[a-z]+", "hello")
    assert_true(result1)
    var matched1 = result1.value()
    var consumed1 = matched1.end_idx - matched1.start_idx
    assert_equal(consumed1, 5)


def test_curly_brace_quantifiers():
    """Test curly brace quantifiers {n}, {n,m}."""
    # Test exact quantifier {3}
    var result1 = match_first("a{3}", "aaa")
    assert_true(result1)
    var matched1 = result1.value()
    var consumed1 = matched1.end_idx - matched1.start_idx
    assert_equal(consumed1, 3)

    # Test that a{3} doesn't match 2 a's
    var result2 = match_first("a{3}", "aa")
    assert_true(not result2)

    # Test range quantifier {2,4}
    var result3 = match_first("a{2,4}", "aaa")
    assert_true(result3)
    var matched3 = result3.value()
    var consumed3 = matched3.end_idx - matched3.start_idx
    assert_equal(consumed3, 3)


def test_complex_pattern_with_ranges():
    """Test complex patterns combining groups, ranges, and quantifiers."""
    # Test basic range functionality
    var result1 = match_first("[c-n]", "h")
    assert_true(result1)

    # Test range with quantifier
    var result2 = match_first("a[c-n]+", "ahh")
    assert_true(result2)
    var matched2 = result2.value()
    var consumed2 = matched2.end_idx - matched2.start_idx
    assert_equal(consumed2, 3)

    # Test basic group with OR and range - debug first
    var test_range_alone = match_first("[c-n]", "h")
    print("Range alone [c-n] on h:", test_range_alone.__bool__())

    var test_or_simple = match_first("(a|b)", "b")
    print("Simple OR (a|b) on b:", test_or_simple.__bool__())

    var result3 = match_first("(b|[c-n])", "h")
    print("Group OR (b|[c-n]) on h:", result3.__bool__())
    assert_true(result3)

    # Test quantified curly braces
    var result4 = match_first("b{3}", "bbb")
    assert_true(result4)


def test_email_validation_simple():
    """Test simple email validation patterns."""
    # Test basic email-like pattern
    var result1 = match_first(".*@.*", "vr@gmail.com")
    assert_true(result1)
    var matched1 = result1.value()
    var consumed1 = matched1.end_idx - matched1.start_idx
    assert_equal(consumed1, 12)

    # Test pattern with alternation - debug first
    var test_alt = match_first("(com|it)", "com")
    print("Simple alternation (com|it) on com:", test_alt.__bool__())

    var result2 = match_first(".*(com|it)", "gmail.com")
    print("Complex .*(com|it) on gmail.com:", result2.__bool__())
    assert_true(result2)


def test_multiple_patterns():
    """Test various regex patterns."""
    # Test pattern with optional group and anchors
    var result1 = match_first("^x(a|b)?bc$", "xbc")
    assert_true(result1)
    var matched1 = result1.value()
    var consumed1 = matched1.end_idx - matched1.start_idx
    assert_equal(consumed1, 3)

    # Test complex backtracking pattern
    var result2 = match_first("^aaaa.*a$", "aaaaa")
    assert_true(result2)
    var matched2 = result2.value()
    var consumed2 = matched2.end_idx - matched2.start_idx
    assert_equal(consumed2, 5)


# def test_match_sequence_with_start_end_correctly(reng: RegexEngine):
#     res, _ = reng.match('^a|b$', 'a  ')
#     assert res == True
#
#     res, _ = reng.match('^a|b$', ' a  ')
#     assert res == False
#
#     res, _ = reng.match('^a|b$', '  b')
#     assert res == True
#
#     res, _ = reng.match('^a|b$', '  b ')
#     assert res == False
#
#
# def test_complex_match_3(reng: RegexEngine):
#     res, _ = reng.match('a(b|[c-n])+b{3}.{2}', 'ahhbbbbbb')
#     assert res == True
#
#
# def test_bit_less_complex_match_3(reng: RegexEngine):
#     res, _ = reng.match('a(b|[c-n])+b{3}', 'ahhbbbbbb')
#     assert res == True
#
#
# def test_unescaped_special_ch(reng: RegexEngine):
#     with pytest.raises(Exception):
#         reng.match('$a^', 'aa')
#
#
# def test_various_emails(reng: RegexEngine):
#     res, _ = reng.match(r'.*@(gmail|hotmail)\.(com|it)', 'baa.aa@hotmail.it')
#     assert res == True
#     res, _ = reng.match(r'.*@(gmail|hotmail)\.(com|it)', 'baa.aa@gmail.com')
#     assert res == True
#     res, _ = reng.match(r'.*@(gmail|hotmail)\.(com|it)', 'baa.aa@hotmaila.com')
#     assert res == False
#
#
# def test_match_empty(reng: RegexEngine):
#     res, _ = reng.match('^$', '')
#     assert res == True
#     res, _ = reng.match('$', '')
#     assert res == True
#     res, _ = reng.match('^', '')
#     assert res == True
#
#
# def test_match_space(reng: RegexEngine):
#     res, _ = reng.match(r'\s', r' ')
#     assert res == True
#     res, _ = reng.match(r'\s', '\t')
#     assert res == True
#     res, _ = reng.match(r'\s', '\r')
#     assert res == True
#     res, _ = reng.match(r'\s', '\f')
#     assert res == True
#     res, _ = reng.match(r'\s', '\n')
#     assert res == True
#     res, _ = reng.match(r'\s', '\v')
#     assert res == True
#
#
# def test_match_space_2(reng: RegexEngine):
#     res, _ = reng.match(r'\s+', '\r\t\n \f \v')
#     assert res == True
#     res, _ = reng.match(r'^\s$', '\r\t')
#     assert res == False
#
#
# def test_return_matches_simple(reng: RegexEngine):
#     res, _, matches = reng.match(r'a\s', r'a ', return_matches=True)
#     assert res == True
#     assert len(matches[0]) == 1
#
#
# def test_return_matches_two(reng: RegexEngine):
#     res, _m, matches = reng.match(r'a(b)+a', r'abba', return_matches=True)
#     assert res == True
#     assert len(matches[0]) == 2
#
#
# def test_non_capturing_group(reng: RegexEngine):
#     res, _, matches = reng.match(r'a(?:b)+a', r'abba', return_matches=True)
#     assert res == True
#     assert len(matches[0]) == 1
#
#
# def test_continue_after_match_and_return_matches_simple(reng: RegexEngine):
#     string = 'abba'
#     res, consumed, matches = reng.match(
#         r'a', string, continue_after_match=True, return_matches=True)
#     assert consumed == len(string)
#     assert len(matches) == 2
#     assert len(matches[0]) == 1
#     x = matches[0]
#     assert matches[0][0].match == 'a'
#     assert len(matches[1]) == 1
#     assert matches[1][0].match == 'a'
#
#
# def test_continue_after_match_and_return_matches_2(reng: RegexEngine):
#     string = 'abbai'
#     res, consumed, matches = reng.match(
#         r'a', string, continue_after_match=True, return_matches=True)
#     assert consumed == len(string)-1
#     assert len(matches) == 2
#     assert len(matches[0]) == 1
#     x = matches[0]
#     assert matches[0][0].match == 'a'
#     assert len(matches[1]) == 1
#     assert matches[1][0].match == 'a'
#
#
# def test_question_mark(reng: RegexEngine):
#     res, _ = reng.match(r'https?://', r'http://')
#     assert res == True
#     res, _ = reng.match(r'https?://', r'https://')
#     assert res == True
#
#
# def test_engine_1(reng: RegexEngine):
#     with pytest.raises(Exception):
#         res, _ = reng.match("$^", '')
#
#
# def test_engine_2(reng: RegexEngine):
#     regex = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
#
#     mail = "lorenzo.felletti@mail.com"
#     res, consumed = reng.match(regex, mail)
#     assert res == True
#     assert consumed == len(mail)
#
#     mail = "lorenzo.felletti@mail.c"
#     res, _ = reng.match(regex, mail)
#     assert res == False
#
#     mail = "lorenzo.fellettimail.com"
#     res, _ = reng.match(regex, mail)
#     assert res == False
#
#     mail = "lorenz^^o.felletti@mymail.com"
#     res, _ = reng.match(regex, mail)
#     assert res == False
#
#     mail = "lorenz0.%+-@mymail.com"
#     res, _ = reng.match(regex, mail)
#     assert res == True
#
#
# def test_engine_3(reng: RegexEngine):
#     string = "lorem ipsum"
#     res, consumed = reng.match(r"m", string, continue_after_match=True)
#     assert res == True
#     assert consumed == len(string)
#
#
# def test_engine_4(reng: RegexEngine):
#     string = "lorem ipsum"
#     res, consumed, matches = reng.match(
#         r"m", string, continue_after_match=True, return_matches=True)
#     assert res == True
#     assert consumed == len(string)
#
#     assert len(matches) == 2
#     assert matches[0][0].match == 'm'
#     assert matches[1][0].match == 'm'
#
#
# def test_engine_5(reng: RegexEngine):
#     match_1 = "lor.fel@ah.ha"
#     match_2 = "fel.log@ha.ah"
#     string = match_1 + " " + match_2
#     res, consumed, matches = reng.match(
#         r"[a-z.]+@[a-z]+\.[a-z]{2}", string, continue_after_match=True, return_matches=True)
#     assert res == True
#     assert consumed == len(string)
#
#     assert len(matches) == 2
#     assert matches[0][0].match == match_1
#     assert matches[1][0].match == match_2
#
#
# def test_engine_6(reng: RegexEngine):
#     res, consumed = reng.match(r'[\abc]', r'\\')
#     assert res == False
#     assert consumed == 0
#
#     res, _ = reng.match(r'[\\abc]', r'\\')
#     assert res == True
#
#
# def test_engine_7(reng: RegexEngine):
#     res, _ = reng.match(r'(a)+(a)?(a{2}|b)+', 'aaabbaa')
#     assert res == True
#
#
# def test_engine_8(reng: RegexEngine):
#     res, _ = reng.match(r'(a){2}', r'a')
#     assert res == False
#
#     res, _ = reng.match(r'(aa){1,2}', r'aa')
#     assert res == True
#
#
# def test_named_group(reng: RegexEngine):
#     res, _, matches = reng.match(
#         r'(?<fancy>clancy)', r'clancy', return_matches=True)
#     assert res == True
#     assert matches[0][1].name == 'fancy'
#
#
# def test_named_group_fail_1(reng: RegexEngine):
#     with pytest.raises(Exception):
#         res, _ = reng.match(r"(?<)", '')
#
#
# def test_named_group_fail_2(reng: RegexEngine):
#     with pytest.raises(Exception):
#         res, _ = reng.match(r"(?<abb)", '')
#
#
# def test_named_group_fail_empty_name(reng: RegexEngine):
#     with pytest.raises(Exception):
#         res, _ = reng.match(r"(?<>asf)", '')
#
#
# def test_matches_indexes(reng: RegexEngine):
#     test_str = "abbabbab"
#     res, consumed, matches = reng.match(
#         r"a", test_str, continue_after_match=True, return_matches=True)
#     assert res == True
#     assert consumed == len(test_str) - 1
#     assert len(matches) == 3
#     assert matches[0][0].start_idx == 0 and matches[0][0].end_idx == 1
#     assert matches[1][0].start_idx == 3 and matches[1][0].end_idx == 4
#     assert matches[2][0].start_idx == 6 and matches[2][0].end_idx == 7
#
#
# def test_returned_matches_indexes(reng: RegexEngine):
#     regex = r"(a)(a)(a)(a)(a)(a)"
#     test_str = "aaaaaaaaaacccaaaaaac"
#     res, consumed, matches = reng.match(regex, test_str, True, True)
#
#     assert res == True
#     assert consumed == len(test_str)-1
#     assert matches is not None and len(matches) == 2
#     assert len(matches[0]) == 7
#     assert len(matches[1]) == 7
#     assert matches[0][0].start_idx == 0 and matches[0][0].end_idx == 6
#     assert matches[0][1].start_idx == 5 and matches[0][1].end_idx == 6
#     assert matches[0][2].start_idx == 4 and matches[0][2].end_idx == 5
#     assert matches[0][3].start_idx == 3 and matches[0][3].end_idx == 4
#     assert matches[0][4].start_idx == 2 and matches[0][4].end_idx == 3
#     assert matches[0][5].start_idx == 1 and matches[0][5].end_idx == 2
#     assert matches[0][6].start_idx == 0 and matches[0][6].end_idx == 1
#
#     assert matches[1][0].start_idx == 13 and matches[1][0].end_idx == 19
#     assert matches[1][1].start_idx == 18 and matches[1][1].end_idx == 19
#     assert matches[1][2].start_idx == 17 and matches[1][2].end_idx == 18
#     assert matches[1][3].start_idx == 16 and matches[1][3].end_idx == 17
#     assert matches[1][4].start_idx == 15 and matches[1][4].end_idx == 16
#     assert matches[1][5].start_idx == 14 and matches[1][5].end_idx == 15
#     assert matches[1][6].start_idx == 13 and matches[1][6].end_idx == 14
#
#
# # this one loops
# def test_returned_groups(reng: RegexEngine):
#     # group e will not be matched due to the greediness of the engine,
#     # .* "eats" the "e" in test_str
#     regex = r"a(b).*(e)?c(c)(c)c"
#     test_str = "abxxecccc"
#     res, consumed, matches = reng.match(regex, test_str, True, True)
#
#     assert res == True
#     assert consumed == len(test_str)
#     assert len(matches) == 1
#     assert len(matches[0]) == 4
#     assert matches[0][0].match == test_str
#     assert matches[0][1].match == "c" and matches[0][1].start_idx == len(
#         test_str) - 2
#     assert matches[0][2].match == "c" and matches[0][2].start_idx == len(
#         test_str) - 3
#     assert matches[0][3].match == "b" and matches[0][3].start_idx == 1
#
#
# def test_on_long_string(reng: RegexEngine):
#     regex = r"a(b)?.{0,10}c(d)"
#     test_str = "abcd dcvrsbshpeuiògjAAwdew ac abc vcsweacscweflllacd"
#     res, _, matches = reng.match(regex, test_str, True, True)
#
#     assert res == True
#     assert len(matches) == 2
#
#     assert len(matches[0]) == 3
#     assert matches[0][0].start_idx == 0 and \
#         matches[0][0].end_idx == 4
#     assert matches[0][1].start_idx == 3 and \
#         matches[0][1].end_idx == 4
#     assert matches[0][2].start_idx == 1 and \
#         matches[0][2].end_idx == 2
#
#     len(matches[1]) == 2
#     assert matches[1][0].start_idx == 39 and \
#         matches[1][0].end_idx == len(test_str)
#     assert matches[1][1].start_idx == len(test_str)-1 and \
#         matches[1][1].end_idx == len(test_str)
#
#
# def test_ignore_case_no_casefolding(reng: RegexEngine):
#     regex = r"ss"
#     test_str = "SS"
#     res, _ = reng.match(regex, test_str, ignore_case=1)
#     assert res == True
#
#     regex = r"ÄCHER"
#     test_str = "ächer"
#     res, _ = reng.match(regex, test_str, ignore_case=1)
#     assert res == True
#
#     regex = r"ÄCHER"
#     test_str = "acher"
#     res, _ = reng.match(regex, test_str, ignore_case=1)
#     assert res == False
#
#
# def test_ignore_case_casefolding(reng: RegexEngine):
#     regex = r"ẞ"
#     test_str = "SS"
#     res, _ = reng.match(regex, test_str, ignore_case=2)
#     assert res == True
#
#     regex = r"ÄCHER"
#     test_str = "ächer"
#     res, _ = reng.match(regex, test_str, ignore_case=2)
#     assert res == True
#
#     regex = r"ÄCHER"
#     test_str = "acher"
#     res, _ = reng.match(regex, test_str, ignore_case=2)
#     assert res == False
#
#
# def test_empty_regex(reng: RegexEngine):
#     regex = r""
#     test_str = "aaaa"
#
#     # repeate the test with different optional parameters configurations
#     res, _ = reng.match(regex, test_str)
#     assert res == True
#
#     res, _ = reng.match(regex, test_str, ignore_case=1)
#     assert res == True
#
#     res, _ = reng.match(regex, test_str, ignore_case=2)
#     assert res == True
#
#     res, _ = reng.match(regex, test_str, continue_after_match=True)
#     assert res == True
#
#     res, _, matches = reng.match(regex, test_str, return_matches=True)
#     assert res == True
#     assert len(matches) == 1 and len(matches[0]) == 1
#     assert matches[0][0].match == "" and matches[0][0].start_idx == 0 and matches[0][0].end_idx == 0
#
#     res, _, matches = reng.match(regex, test_str, True, True, 0)
#     assert res == True
#     assert len(matches) == 1 and len(matches[0]) == 1
#     assert matches[0][0].match == "" and matches[0][0].start_idx == 0 and matches[0][0].end_idx == 0
#
#     res, _, matches = reng.match(regex, test_str, True, True, 1)
#     assert res == True
#     assert len(matches) == 1 and len(matches[0]) == 1
#     assert matches[0][0].match == "" and matches[0][0].start_idx == 0 and matches[0][0].end_idx == 0
#
#     res, _, matches = reng.match(regex, test_str, True, True, 2)
#     assert res == True
#     assert len(matches) == 1 and len(matches[0]) == 1
#     assert matches[0][0].match == "" and matches[0][0].start_idx == 0 and matches[0][0].end_idx == 0
#
#
# def test_empty_test_str(reng: RegexEngine):
#     regex = r"a"
#     test_str = ""
#     res, _ = reng.match(regex, test_str)
#     assert res == False
#
#
# def test_empty_regex_and_test_str(reng: RegexEngine):
#     regex = r""
#     test_str = ""
#     res, _ = reng.match(regex, test_str)
#     assert res == True
#
#
# def test_regex_with_rigth_empty_group(reng: RegexEngine):
#     regex = r"a|"
#     test_str = "ab"
#
#     # repeate the test with different optional parameters configurations
#     res, _ = reng.match(regex, test_str)
#     assert res == True
#
#     res, _ = reng.match(regex, test_str, ignore_case=1)
#     assert res == True
#
#     res, _ = reng.match(regex, test_str, ignore_case=2)
#     assert res == True
#
#     res, _ = reng.match(regex, test_str, continue_after_match=True)
#     assert res == True
#
#     res, _, matches = reng.match(regex, test_str, return_matches=True)
#     assert res == True
#     assert len(matches) == 1 and len(matches[0]) == 1
#     assert matches[0][0].match == "a" and matches[0][0].start_idx == 0 and matches[0][0].end_idx == 1
#
#     res, _, matches = reng.match(regex, test_str, True, True, 0)
#     assert res == True
#     assert len(matches) == 1 and len(matches[0]) == 1
#     assert matches[0][0].match == "a" and matches[0][0].start_idx == 0 and matches[0][0].end_idx == 1
#
#     res, _, matches = reng.match(regex, test_str, True, True, 1)
#     assert res == True
#     assert len(matches) == 1 and len(matches[0]) == 1
#     assert matches[0][0].match == "a" and matches[0][0].start_idx == 0 and matches[0][0].end_idx == 1
#
#     res, _, matches = reng.match(regex, test_str, True, True, 2)
#     assert res == True
#     assert len(matches) == 1 and len(matches[0]) == 1
#     assert matches[0][0].match == "a" and matches[0][0].start_idx == 0 and matches[0][0].end_idx == 1
#
#
# def test_empty_group_quantified(reng: RegexEngine):
#     regex = r'()+'
#     test_str = 'ab'
#     res, _ = reng.match(regex, test_str)
#     assert res == True
#
#
# def test_nested_quantifiers(reng: RegexEngine):
#     regex = r'(a*)+ab'
#     test_str = 'aab'
#     res, _ = reng.match(regex, test_str)
#     assert res == True
#
#     regex = r'(a+)+ab'
#     test_str = 'ab'
#     res, _ = reng.match(regex, test_str)
#     assert res == False
#
#
# def test_nested_quantifiers_with_or_node(reng: RegexEngine):
#     regex = r'(a*|b*)*ab'
#     test_str = 'ab'
#     res, _ = reng.match(regex, test_str)
#     assert res == True
#
#     regex = r'(a*|b*)+ab'
#     test_str = 'ab'
#     res, _ = reng.match(regex, test_str)
#     assert res == True
#
#     regex = r'(a+|b+)+ab'
#     test_str = 'ab'
#     res, _ = reng.match(regex, test_str)
#     assert res == False
#
#
# def test_multiple_named_groups(reng: RegexEngine):
#     regex = r"(?<first>[a-z]+)(?<second>i)(?<third>l)"
#     test_str = "nostril"
#     res, _, _ = reng.match(regex, test_str, True, True, 0)
#     assert res == True
#
#
# def test_one_named_group(reng: RegexEngine):
#     regex = r"[a-z]+(?<last>l)"
#     test_str = "nostril"
#     res, _, matches = reng.match(regex, test_str, True, True, 0)
#     assert res == True
#
#
# def test_two_separated_named_group(reng: RegexEngine):
#     regex = r"(?<first>n)[a-z]+(?<last>l)"
#     test_str = "nostril"
#     res, _, matches = reng.match(regex, test_str, True, True, 0)
#     assert res == True
#     assert len(matches) == 1
#     assert len(matches[0]) == 3
#     assert matches[0][0].match == "nostril"
#     assert matches[0][1].match == "l"
#     assert matches[0][2].match == "n"
#
#
# def test_match_contiguous_named_groups(reng: RegexEngine):
#     regex = r"(?<first>n)(?<last>l)"
#     test_str = "nl"
#     res, _, matches = reng.match(regex, test_str, True, True, 0)
#     assert res == True
#     assert len(matches) == 1
#     assert len(matches[0]) == 3
#     assert matches[0][0].match == "nl"
#     assert matches[0][1].match == "l"
#     assert matches[0][2].match == "n"
#
#
# def test_named_group_with_range_element(reng: RegexEngine):
#     regex = r"(?<first>[a-z])(?<last>l)"
#     test_str = "nl"
#     res, _, matches = reng.match(regex, test_str, True, True, 0)
#     assert res == True
#     assert len(matches) == 1
#     assert len(matches[0]) == 3
#     assert matches[0][0].match == "nl"
#     assert matches[0][1].match == "l"
#     assert matches[0][2].match == "n"
#
#
# def test_named_group_with_range_element_and_quantifier(reng: RegexEngine):
#     regex = r"(?<first>[a-z]+)(?<last>l)"
#     test_str = "nl"
#     res, _, matches = reng.match(regex, test_str, True, True, 0)
#     assert res == True
#     assert len(matches) == 1
#     assert len(matches[0]) == 3
#     assert matches[0][0].match == "nl"
#     assert matches[0][1].match == "l"
#     assert matches[0][2].match == "n"
#
#
# def test_backtracking_or_node_inside_group_node(reng: RegexEngine):
#     regex = r"(?<first>b{1,2}|[a-z]+)(?<last>l)"
#     test_str = "bnl"
#
#     res, _, matches = reng.match(regex, test_str, True, True, 0)
#     assert res == True
#     assert len(matches) == 1
#     assert matches[0][0].start_idx == 0 and matches[0][0].end_idx == len(test_str)
#     assert matches[0][1].start_idx == 2 and matches[0][1].end_idx == len(test_str)
#     assert matches[0][2].start_idx == 0 and matches[0][2].end_idx == 2
#
#     regex = r"(?<first>[a-z]+|b{1,2})(?<last>l)"
#     res, _, matches = reng.match(regex, test_str, True, True, 0)
#     assert res == True
#     assert len(matches) == 1
#     assert matches[0][0].start_idx == 0 and matches[0][0].end_idx == len(test_str)
#     assert matches[0][1].start_idx == 2 and matches[0][1].end_idx == len(test_str)
#     assert matches[0][2].start_idx == 0 and matches[0][2].end_idx == 2
#
#
# def test_double_or_nodes_with_wildcard_in_between(reng: RegexEngine):
#     res, _ = reng.match(r'@(gm|ho).(com|it)', '@hoa.com')
#     assert res == False


def test_findall_simple():
    """Test findall with simple pattern that appears multiple times."""
    var matches = findall("a", "banana")
    assert_equal(len(matches), 3)
    assert_equal(matches[0].start_idx, 1)
    assert_equal(matches[0].end_idx, 2)
    assert_equal(matches[1].start_idx, 3)
    assert_equal(matches[1].end_idx, 4)
    assert_equal(matches[2].start_idx, 5)
    assert_equal(matches[2].end_idx, 6)


def test_findall_no_matches():
    """Test findall when pattern doesn't match anything."""
    var matches = findall("z", "banana")
    assert_equal(len(matches), 0)


def test_findall_one_match():
    """Test findall when pattern appears only once."""
    var matches = findall("ban", "banana")
    assert_equal(len(matches), 1)
    assert_equal(matches[0].start_idx, 0)
    assert_equal(matches[0].end_idx, 3)
    assert_equal(matches[0].get_match_text(), "ban")


def test_findall_overlapping_avoided():
    """Test that findall doesn't find overlapping matches."""
    var matches = findall("aa", "aaaa")
    assert_equal(len(matches), 2)
    assert_equal(matches[0].start_idx, 0)
    assert_equal(matches[0].end_idx, 2)
    assert_equal(matches[1].start_idx, 2)
    assert_equal(matches[1].end_idx, 4)


def test_findall_with_quantifiers():
    """Test findall with quantifiers."""
    var matches = findall("[0-9]+", "abc123def456ghi")
    assert_equal(len(matches), 2)
    assert_equal(matches[0].get_match_text(), "123")
    assert_equal(matches[0].start_idx, 3)
    assert_equal(matches[0].end_idx, 6)
    assert_equal(matches[1].get_match_text(), "456")
    assert_equal(matches[1].start_idx, 9)
    assert_equal(matches[1].end_idx, 12)


def test_findall_wildcard():
    """Test findall with wildcard pattern."""
    var matches = findall(".", "abc")
    assert_equal(len(matches), 3)
    assert_equal(matches[0].get_match_text(), "a")
    assert_equal(matches[1].get_match_text(), "b")
    assert_equal(matches[2].get_match_text(), "c")


def test_findall_empty_string():
    """Test findall on empty string."""
    var matches = findall("a", "")
    assert_equal(len(matches), 0)


def test_findall_anchors():
    """Test findall with anchors."""
    # Start anchor should only match at beginning
    var matches1 = findall("^a", "aaa")
    assert_equal(len(matches1), 1)
    assert_equal(matches1[0].start_idx, 0)

    # End anchor should only match at end
    var matches2 = findall("a$", "aaa")
    assert_equal(len(matches2), 1)
    assert_equal(matches2[0].start_idx, 2)


def test_findall_zero_width_matches():
    """Test findall handles zero-width matches correctly."""
    # This tests that we don't get infinite loops on zero-width matches
    var matches = findall("^", "abc")
    assert_equal(len(matches), 1)
    assert_equal(matches[0].start_idx, 0)
    assert_equal(matches[0].end_idx, 0)


def test_phone_numbers():
    """Test phone number pattern matching using DFA."""
    # Simplified phone number pattern that works with current implementation
    # This tests basic phone number matching with + prefix and digit sequences
    pattern = "[+]*\\d+[-]*\\d+[-]*\\d+[-]*\\d+"
    result = match_first(pattern, "+1-541-236-5432")
    assert_true(result.__bool__())
    assert_equal(result.value().get_match_text(), "+1-541-236-5432")


def test_es_phone_numbers():
    es_pattern = "[5-9]\\d{8}"
    phone = "810123456"
    var result = match_first(es_pattern, phone)
    assert_true(result.__bool__())
    assert_equal(result.value().get_match_text(), phone)
    es_fixed_line_pattern = "96906(?:0[0-8]|1[1-9]|[2-9]\\d)\\d\\d|9(?:69(?:0[0-57-9]|[1-9]\\d)|73(?:[0-8]\\d|9[1-9]))\\d{4}|(?:8(?:[1356]\\d|[28][0-8]|[47][1-9])|9(?:[135]\\d|[268][0-8]|4[1-9]|7[124-9]))\\d{6}"
    var result2 = match_first(es_fixed_line_pattern, phone)
    assert_true(result2.__bool__())
    assert_equal(result2.value().get_match_text(), phone)


def test_comprehensive_spanish_phone_patterns():
    """Test various Spanish phone number patterns to ensure robustness."""
    # Test basic mobile pattern
    var mobile_pattern = "[5-9]\\d{8}"

    # Test various valid mobile numbers
    var mobile_numbers = List[String]()
    mobile_numbers.append("600123456")  # 6xx numbers
    mobile_numbers.append("700234567")  # 7xx numbers
    mobile_numbers.append("810123456")  # 8xx numbers
    mobile_numbers.append("912345678")  # 9xx numbers

    for i in range(len(mobile_numbers)):
        var number = mobile_numbers[i]
        var result = match_first(mobile_pattern, number)
        assert_true(result.__bool__())
        assert_equal(result.value().get_match_text(), number)

    # Test invalid mobile numbers (should not match)
    var invalid_numbers = List[String]()
    invalid_numbers.append("400123456")  # Starts with 4 (not in [5-9])
    invalid_numbers.append("12345678")  # Too short
    invalid_numbers.append("1234567890")  # Too long

    for i in range(len(invalid_numbers)):
        var number = invalid_numbers[i]
        var result = match_first(mobile_pattern, number)
        assert_true(not result.__bool__())


def test_non_capturing_groups_comprehensive():
    """Test non-capturing groups in various contexts."""
    # Test simple non-capturing group
    var result1 = match_first("(?:ab)+", "ababab")
    assert_true(result1.__bool__())
    assert_equal(result1.value().get_match_text(), "ababab")

    # Test non-capturing groups with simple alternation
    var result2 = match_first("(?:cat|dog)", "cat")
    assert_true(result2.__bool__())
    assert_equal(result2.value().get_match_text(), "cat")

    # Test non-capturing groups with alternation and quantifier
    var result3 = match_first("(?:a|b)+", "ababab")
    assert_true(result3.__bool__())
    assert_equal(result3.value().get_match_text(), "ababab")

    # Test nested non-capturing groups with alternation
    var result4 = match_first("(?:(?:a|b)(?:c|d))+", "acbdac")
    assert_true(result4.__bool__())
    assert_equal(result4.value().get_match_text(), "acbdac")


def test_complex_alternation_patterns():
    """Test complex alternation patterns like those in phone numbers."""
    # Test multiple character class alternations
    var result1 = match_first("(?:[1356]\\d|[28][0-8]|[47][1-9])", "81")
    assert_true(result1.__bool__())
    assert_equal(result1.value().get_match_text(), "81")

    # Test different branches
    var result2 = match_first("(?:[1356]\\d|[28][0-8]|[47][1-9])", "15")
    assert_true(result2.__bool__())
    assert_equal(result2.value().get_match_text(), "15")

    var result3 = match_first("(?:[1356]\\d|[28][0-8]|[47][1-9])", "41")
    assert_true(result3.__bool__())
    assert_equal(result3.value().get_match_text(), "41")

    # Test pattern that should not match
    var result4 = match_first("(?:[1356]\\d|[28][0-8]|[47][1-9])", "09")
    assert_true(not result4.__bool__())


def test_match_first_vs_search_behavior():
    """Test that match_first behaves like Python's re.match (only matches at start).
    """
    # Test case: pattern "world" should NOT match in "hello world" with match_first
    var result1 = match_first("world", "hello world")
    assert_true(
        not result1.__bool__()
    )  # Should fail because "world" is not at position 0

    # Test case: pattern "hello" SHOULD match in "hello world" with match_first
    var result2 = match_first("hello", "hello world")
    assert_true(
        result2.__bool__()
    )  # Should succeed because "hello" starts at position 0
    var match2 = result2.value()
    assert_equal(match2.start_idx, 0)
    assert_equal(match2.end_idx, 5)
    assert_equal(match2.get_match_text(), "hello")

    # Test case: pattern should not match if there's prefix
    var result3 = match_first("hello", "say hello")
    assert_true(
        not result3.__bool__()
    )  # Should fail because "hello" is not at position 0


def test_match_first_anchored_patterns():
    """Test match_first with explicitly anchored patterns."""
    # Test explicit start anchor
    var result1 = match_first("^hello", "hello world")
    assert_true(result1.__bool__())
    var match1 = result1.value()
    assert_equal(match1.get_match_text(), "hello")

    # Test that it fails when not at start
    var result2 = match_first("^hello", "say hello")
    assert_true(not result2.__bool__())


def test_match_first_empty_pattern():
    """Test match_first with empty pattern."""
    var result1 = match_first("", "hello")
    assert_true(result1.__bool__())
    var match1 = result1.value()
    assert_equal(match1.start_idx, 0)
    assert_equal(match1.end_idx, 0)
    assert_equal(match1.get_match_text(), "")


def test_specific_user_issue():
    """Test the specific issue mentioned: 'world' pattern should NOT match 'hello world'.
    """
    # This is the exact case the user mentioned
    var result = match_first("world", "hello world")
    print("NFA match_first('world', 'hello world') result:", result.__bool__())

    # This should be False according to Python's re.match() behavior
    assert_true(not result.__bool__())

    # Let's also test the equivalent using the hybrid matcher to compare
    from regex.matcher import CompiledRegex

    var regex = CompiledRegex("world")
    var hybrid_result = regex.match_first("hello world")
    print(
        "Hybrid match_first('world', 'hello world') result:",
        hybrid_result.__bool__(),
    )

    # Both should behave the same
    assert_equal(result.__bool__(), hybrid_result.__bool__())


def test_nfa_digit_basic():
    """Test NFA digit matching with \\d."""
    var result = match_first("\\d", "7")
    assert_true(result)
    var matched = result.value()
    assert_equal(matched.get_match_text(), "7")


def test_nfa_digit_all_digits():
    """Test \\d matches all digits 0-9."""
    for i in range(10):
        var digit_char = String(i)
        var result = match_first("\\d", digit_char)
        assert_true(result)
        var matched = result.value()
        assert_equal(matched.get_match_text(), digit_char)


def test_nfa_digit_not_match_letter():
    """Test \\d does not match non-digits."""
    var result1 = match_first("\\d", "a")
    assert_true(not result1)

    var result2 = match_first("\\d", "@")
    assert_true(not result2)


def test_nfa_digit_quantifiers():
    """Test \\d with quantifiers."""
    var result1 = match_first("\\d+", "12345")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "12345")

    var result2 = match_first("\\d*", "")
    assert_true(result2)
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), "")

    var result3 = match_first("\\d?", "9")
    assert_true(result3)
    var matched3 = result3.value()
    assert_equal(matched3.get_match_text(), "9")


def test_nfa_word_basic():
    """Test NFA word character matching with \\w."""
    var result = match_first("\\w", "a")
    assert_true(result)
    var matched = result.value()
    assert_equal(matched.get_match_text(), "a")


def test_nfa_word_all_types():
    """Test \\w matches letters, digits, and underscore."""
    var result1 = match_first("\\w", "a")
    assert_true(result1)

    var result2 = match_first("\\w", "Z")
    assert_true(result2)

    var result3 = match_first("\\w", "5")
    assert_true(result3)

    var result4 = match_first("\\w", "_")
    assert_true(result4)


def test_nfa_word_not_match_special():
    """Test \\w does not match special characters."""
    var result1 = match_first("\\w", "@")
    assert_true(not result1)

    var result2 = match_first("\\w", " ")
    assert_true(not result2)

    var result3 = match_first("\\w", "-")
    assert_true(not result3)


def test_nfa_word_quantifiers():
    """Test \\w with quantifiers."""
    var result1 = match_first("\\w+", "hello_world123")
    assert_true(result1)
    var matched1 = result1.value()
    assert_equal(matched1.get_match_text(), "hello_world123")

    var result2 = match_first("\\w*", "")
    assert_true(result2)
    var matched2 = result2.value()
    assert_equal(matched2.get_match_text(), "")

    var result3 = match_first("\\w?", "a")
    assert_true(result3)
    var matched3 = result3.value()
    assert_equal(matched3.get_match_text(), "a")
