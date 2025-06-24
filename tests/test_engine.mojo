from testing import assert_equal, assert_true, assert_raises

from regex.engine import match


# import pytest
# from ..pyregexp.engine import RegexEngine
#
#
# @pytest.fixture
# def reng() -> RegexEngine:
#     return RegexEngine()
#
#
# def test_simplest(reng: RegexEngine):
#     assert (True, 1) == reng.match('a', 'a')
#
#
# def test_simplest_with_wildcard(reng: RegexEngine):
#     assert (True, 1) == reng.match('.', 'a')
#
#
# def test_simplest_but_longer(reng: RegexEngine):
#     assert (True, 3) == reng.match('a.c', 'abc')
#
#
# def test_wildcard(reng: RegexEngine):
#     assert (True, 2) == reng.match('.*a', 'aa')
#
#
# def test_backtracking(reng: RegexEngine):
#     assert (True, 4) == reng.match('a*a', 'aaaa')
#
#
# def test_or(reng: RegexEngine):
#     assert (True, 1) == reng.match('a.*|b', 'b')
#
#
# def test_or_no_match(reng: RegexEngine):
#     res, _ = reng.match('^a|b$', 'c')
#     assert res == False
#
#
# def test_or_no_match_with_bt(reng: RegexEngine):
#     res, _ = reng.match('a|b', 'c')
#     assert res == False
#
#
# def test_bt_no_match(reng: RegexEngine):
#     res, _ = reng.match('a{5}a', 'aaaaa')
#     assert res == False
#
#
# def test_match_group_zero_or_more(reng: RegexEngine):
#     res, consumed = reng.match('(a)*', 'aa')
#     assert (True, 2) == (res, consumed)
#
#
# def test_fail_group_one_or_more(reng: RegexEngine):
#     res, _ = reng.match('^(a)+', 'b')
#     assert res == False
#
#
# def test_complex_match(reng: RegexEngine):
#     res, _ = reng.match('^(a|b+c)?[n-z]{2}', 'axx')
#     assert res == True
#
#
# def test_complex_match_2(reng: RegexEngine):
#     res, _ = reng.match('^(a|b+c)?[n-z]{2}', 'xx')
#     assert res == True
#
#
# def test_match_mail_simple(reng: RegexEngine):
#     res, _ = reng.match(r'.*@.*\.(com|it)', 'vr@gmail.com')
#     assert res == True
#
#
# def test_bt_index_leaf(reng: RegexEngine):
#     res, _ = reng.match(r'^aaaa.*a$', 'aaaaa')
#     assert res == True
#
#
# def test_bt_index_or(reng: RegexEngine):
#     res, _ = reng.match(r'^x(a|b)?bc$', 'xbc')
#     assert res == True
#
#
# def test_bt_index_group(reng: RegexEngine):
#     res, _ = reng.match(r'^x(a)?ac$', 'xac')
#     assert res == True
#
#
# def test_match_or_left(reng: RegexEngine):
#     res, _ = reng.match('na|nb', 'na')
#     assert res == True
#
#
# def test_match_or_right(reng: RegexEngine):
#     res, _ = reng.match('na|nb', 'nb')
#     assert res == True
#
#
# def test_match_or_right_at_start_end(reng: RegexEngine):
#     res, _ = reng.match('^na|nb$', 'nb')
#     assert res == True
#
#
# def test_no_match_after_end(reng: RegexEngine):
#     res, _ = reng.match('^na|nb$', 'nb ')
#     assert res == False
#
#
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
