from testing import assert_equal, assert_true, assert_false, assert_raises
from regex.ast import (
    ASTNode,
    GROUP,
    ELEMENT,
    RE,
    START,
    END,
    RANGE,
    SPACE,
    WILDCARD,
    OR,
)
from regex.parser import parse


fn test_simple_regex() raises:
    var ast = parse("a")
    assert_true(Bool(ast))
    assert_equal(ast.type, RE)
    assert_equal(len(ast.children), 1)
    var child = ast.children[0]
    assert_equal(child.type, GROUP)
    assert_equal(len(child.children), 1)
    var element = child.children[0]
    assert_equal(element.type, ELEMENT)
    assert_equal(element.value, "a")


fn test_grouping() raises:
    var ast = parse("a(b)c")

    # Top level group
    var top_group = ast.children[0]
    assert_equal(len(top_group.children), 3)
    assert_equal(top_group.children[0].type, ELEMENT)
    assert_equal(top_group.children[1].type, GROUP)
    assert_equal(top_group.children[2].type, ELEMENT)

    # Nested group
    var nested_group = top_group.children[1]
    assert_equal(len(nested_group.children), 1)
    assert_equal(nested_group.children[0].type, ELEMENT)
    assert_equal(nested_group.children[0].value, "b")


fn test_quantifiers() raises:
    var ast = parse("a*")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.type, ELEMENT)
    assert_equal(element.min, 0)
    assert_equal(element.max, -1)  # -1 represents infinity


fn test_match_start_end() raises:
    var ast = parse("^a$")
    var top_group = ast.children[0]
    assert_equal(len(top_group.children), 3)
    assert_equal(top_group.children[0].type, START)
    assert_equal(top_group.children[1].type, ELEMENT)
    assert_equal(top_group.children[2].type, END)


fn test_wildcard() raises:
    var ast = parse(".")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.type, WILDCARD)


fn test_space_element() raises:
    var ast = parse("\\s")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.type, SPACE)


fn test_range_positive() raises:
    var ast = parse("[abc]")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.type, RANGE)
    assert_equal(element.min, 1)  # Positive logic
    assert_true(element.is_match("a"))
    assert_false(element.is_match("x"))


fn test_range_negative() raises:
    var ast = parse("[^abc]")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.type, RANGE)
    assert_equal(
        element.min, 1
    )  # Both positive and negative logic should match 1 character
    assert_false(element.is_match("a"))
    assert_true(element.is_match("x"))


fn test_or_operation() raises:
    var ast = parse("a|b")
    var top_node = ast.children[0]
    assert_equal(top_node.type, OR)
    assert_equal(len(top_node.children), 2)


fn test_curly_exact() raises:
    var ast = parse("a{3}")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.min, 3)
    assert_equal(element.max, 3)


fn test_curly_range() raises:
    var ast = parse("a{2,5}")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.min, 2)
    assert_equal(element.max, 5)


fn test_curly_braces_1() raises:
    var ast = parse("a{5}b")
    var top_group = ast.children[0]
    assert_equal(len(top_group.children), 2)


fn test_parse_curly_2() raises:
    var ast = parse("a{,2}")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.type, ELEMENT)
    assert_equal(element.min, 0)
    assert_equal(element.max, 2)


fn test_parse_curly_3() raises:
    var ast = parse("a{2,}")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.type, ELEMENT)
    assert_equal(element.min, 2)
    assert_equal(element.max, -1)  # -1 represents infinity


fn test_parse_curly_4() raises:
    var ast = parse("a{,}")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.type, ELEMENT)
    assert_equal(element.min, 0)
    assert_equal(element.max, -1)  # -1 represents infinity


fn test_parse_match_start_end() raises:
    var ast = parse("^aaaa.*a$")
    var top_group = ast.children[0]
    assert_equal(len(top_group.children), 8)


fn test_complex_regex() raises:
    var ast = parse("^[a-zA-Z]{1,20}@[a-zA-Z]\\.[a-z]{1,3}$")
    var top_group = ast.children[0]
    # Our parser correctly produces 7 elements:
    # ^, [a-zA-Z]{1,20}, @, [a-zA-Z], \., [a-z]{1,3}, $
    assert_equal(len(top_group.children), 7)

    # Verify structure: START, RANGE, ELEMENT, RANGE, ELEMENT, RANGE, END
    assert_equal(top_group.children[0].type, START)
    assert_equal(top_group.children[1].type, RANGE)
    assert_equal(top_group.children[2].type, ELEMENT)
    assert_equal(top_group.children[3].type, RANGE)
    assert_equal(top_group.children[4].type, ELEMENT)
    assert_equal(top_group.children[5].type, RANGE)
    assert_equal(top_group.children[6].type, END)

    # Verify quantifiers on ranges
    assert_equal(top_group.children[1].min, 1)  # [a-zA-Z]{1,20}
    assert_equal(top_group.children[1].max, 20)
    assert_equal(top_group.children[5].min, 1)  # [a-z]{1,3}
    assert_equal(top_group.children[5].max, 3)


fn test_range_1() raises:
    var ast = parse("[^a-z]")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.type, RANGE)
    assert_equal(
        element.min, 1
    )  # Both positive and negative logic should match 1 character
    assert_false(element.is_match("a"))


fn test_range_2() raises:
    var ast = parse("[^a-z-\\s-]")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.type, RANGE)
    assert_false(element.is_match("a"))
    assert_false(element.is_match("-"))
    # Note: Space matching would need to be tested differently due to escaping


fn test_range_3() raises:
    var ast = parse("[a-z-\\s-]")
    var top_group = ast.children[0]
    var element = top_group.children[0]
    assert_equal(element.type, RANGE)
    assert_true(element.is_match("a"))
    assert_true(element.is_match("-"))
    # Note: Space matching would need to be tested differently due to escaping


fn test_parse_fail_missing_closing_bracket() raises:
    with assert_raises():
        _ = parse("a[abc")


fn test_parse_fail_unescaped_closing_bracket() raises:
    with assert_raises():
        _ = parse("abc]")


fn test_parse_fail_unescaped_closing_parenthesis() raises:
    with assert_raises():
        _ = parse("a)")


fn test_fail_no_closing_par() raises:
    with assert_raises():
        _ = parse("a[d]((vfw)")


fn test_parse_fail_non_closed_range() raises:
    with assert_raises():
        _ = parse("[a")

    with assert_raises():
        _ = parse("[")


# import math
# import pytest
# from ..pyregexp.re_ast import (
#     RE,
#     EndElement,
#     GroupNode,
#     Element,
#     OrNode,
#     RangeElement,
#     SpaceElement,
#     StartElement,
# )
# from ..pyregexp.pyrser import Pyrser
#
#
# @pytest.fixture
# def parser():
#     return Pyrser()
#
#
# def test_simple_regex(parser: Pyrser):
#     ast = parser.parse("a")
#     print(ast)
#     assert type(ast) is RE
#     assert type(ast.child) is GroupNode
#     assert type(ast.child.children[0]) is Element
#
#
# def test_grouping(parser: Pyrser):
#     ast = parser.parse("a(b)c")
#
#     # top level group
#     assert len(ast.child.children) == 3
#     assert type(ast.child.children[0]) is Element
#     assert type(ast.child.children[1]) is GroupNode
#     assert type(ast.child.children[2]) is Element
#
#     # ast.child.children[1] group '(a)'
#     assert len(ast.child.children[1].children) == 1
#     assert type(ast.child.children[1].children[0]) is Element
#
#
# def test_curly_braces_1(parser: Pyrser):
#     ast = parser.parse(r"a{5}b")
#     assert len(ast.child.children) == 2
#
#
# def test_fail_curly(parser: Pyrser):
#     with pytest.raises(Exception):
#         parser.parse("a{3,3}}")
#
#
# def test_fail_no_closing_par(parser: Pyrser):
#     with pytest.raises(Exception):
#         parser.parse("a[d]((vfw)")
#
#
# def test_parse_match_start_end(parser: Pyrser):
#     ast = parser.parse("^aaaa.*a$")
#     assert len(ast.child.children) == 8
#
#
# def test_complex_regex(parser: Pyrser):
#     ast = parser.parse(r"^[a-zA-Z]{1,20}@[a-zA-Z]\.[a-z]{1,3}$")
#     assert len(ast.child.children) == 7
#
#     assert type(ast.child.children[0]) is StartElement
#
#     assert type(ast.child.children[1]) is RangeElement
#     assert ast.child.children[1].min == 1
#     assert ast.child.children[1].max == 20
#
#     assert type(ast.child.children[2]) is Element
#
#     assert type(ast.child.children[3]) is RangeElement
#
#     assert type(ast.child.children[4]) is Element
#
#     assert type(ast.child.children[5]) is RangeElement
#     assert ast.child.children[5].min == 1
#     assert ast.child.children[5].max == 3
#
#     assert type(ast.child.children[6]) is EndElement
#
#
# def test_space_element(parser: Pyrser):
#     ast = parser.parse(r"\s")
#     assert len(ast.child.children) == 1
#     assert type(ast.child.children[0]) is SpaceElement
#
#
# def test_range_1(parser: Pyrser):
#     ast = parser.parse("[^a-z]")
#     assert len(ast.child.children) == 1
#     assert type(ast.child.children[0]) is RangeElement
#     assert ast.child.children[0].is_match("a") == False
#
#
# def test_range_2(parser: Pyrser):
#     ast = parser.parse(r"[^a-z-\s-]")
#     assert len(ast.child.children) == 1
#     assert type(ast.child.children[0]) is RangeElement
#     assert ast.child.children[0].is_match("a") == False
#     assert ast.child.children[0].is_match("-") == False
#     ast.child.children[0].is_match(" ") == False
#
#
# def test_range_3(parser: Pyrser):
#     ast = parser.parse(r"[a-z-\s-]")
#     assert len(ast.child.children) == 1
#     assert type(ast.child.children[0]) is RangeElement
#     assert ast.child.children[0].is_match("a") == True
#     assert ast.child.children[0].is_match("-") == True
#     ast.child.children[0].is_match(" ") == True
#
#
# def test_range_2(parser: Pyrser):
#     ast = parser.parse(r"[\]]")
#     assert len(ast.child.children) == 1
#     assert type(ast.child.children[0]) is RangeElement
#     assert ast.child.children[0].is_match("]") == True
#
#
# def test_parse_curly_1(parser: Pyrser):
#     ast = parser.parse(r"a{2}")
#     assert len(ast.child.children) == 1
#     assert type(ast.child.children[0]) is Element
#     assert ast.child.children[0].is_match("a") == True
#     assert ast.child.children[0].min == 2
#     ast.child.children[0].max == 2
#
#
# def test_parse_curly_2(parser: Pyrser):
#     ast = parser.parse(r"a{,2}")
#     assert len(ast.child.children) == 1
#     assert type(ast.child.children[0]) is Element
#     assert ast.child.children[0].is_match("a") == True
#     assert ast.child.children[0].min == 0
#     ast.child.children[0].max == 2
#
#
# def test_parse_curly_3(parser: Pyrser):
#     ast = parser.parse(r"a{2,}")
#     assert len(ast.child.children) == 1
#     assert type(ast.child.children[0]) is Element
#     assert ast.child.children[0].is_match("a") == True
#     assert ast.child.children[0].min == 2
#     ast.child.children[0].max == math.inf
#
#
# def test_parse_curly_4(parser: Pyrser):
#     ast = parser.parse(r"a{,}")
#     assert len(ast.child.children) == 1
#     assert type(ast.child.children[0]) is Element
#     assert ast.child.children[0].is_match("a") == True
#     assert ast.child.children[0].min == 0
#     ast.child.children[0].max == math.inf
#
#
# def test_parse_fail_empty_curly(parser: Pyrser):
#     with pytest.raises(Exception):
#         ast = parser.parse(r"a{}")
#
#
# def test_fail_quatifier_unescaped(parser: Pyrser):
#     with pytest.raises(Exception):
#         ast = parser.parse(r"?")
#
#
# def test_parse_fail_missing_clising_bracket(parser: Pyrser):
#     with pytest.raises(Exception):
#         ast = parser.parse(r"a[abc")
#
#
# def test_parse_fail_unescaped_closing_bracket(parser: Pyrser):
#     with pytest.raises(Exception):
#         ast = parser.parse(r"abc]")
#
#
# def test_parse_fail_unescaped_closing_parenthesis(parser: Pyrser):
#     with pytest.raises(Exception):
#         ast = parser.parse(r"a)")
#
#
# def test_parse_fail_unescaped_start(parser: Pyrser):
#     with pytest.raises(Exception):
#         ast = parser.parse(r"^^")
#
#
# def test_parse_fail_unescaped_end(parser: Pyrser):
#     with pytest.raises(Exception):
#         ast = parser.parse(r"$$")
#
#
# def test_parse_fail_swapped_range(parser: Pyrser):
#     with pytest.raises(Exception):
#         ast = parser.parse(r"[z-a]")
#
#
# def test_parse_fail_non_capturing_group(parser: Pyrser):
#     with pytest.raises(Exception):
#         parser.parse(r"(?")
#
#     with pytest.raises(Exception):
#         parser.parse(r"(?aa")
#
#
# def test_parse_fail_non_closed_range(parser: Pyrser):
#     with pytest.raises(Exception):
#         parser.parse(r"[a")
#
#     with pytest.raises(Exception):
#         parser.parse(r"[")
#
#
# def test_parse_onrnode_groups_names(parser: Pyrser):
#     regex = r"a|b"
#     ast = parser.parse(regex)
#     assert len(ast.children) == 1
#     assert isinstance(ast.child, OrNode)
#     assert isinstance(ast.child.left, GroupNode)
#     assert isinstance(ast.child.right, GroupNode)
#     assert ast.child.left.group_name == ast.child.right.group_name
#     assert ast.child.left.group_id == ast.child.right.group_id
#
#
# def test_groups_names_double_ornode(parser: Pyrser):
#     regex = r"a|b|c"
#     ast = parser.parse(regex)
#     assert len(ast.children) == 1
#     assert isinstance(ast.child, OrNode)
#     assert isinstance(ast.child.left, GroupNode)
#     leftmost_gid = ast.child.left.group_id
#     leftmost_gname = ast.child.left.group_name
#
#     assert isinstance(ast.child.right, OrNode)
#     assert isinstance(ast.child.right.left, GroupNode)
#     central_gid = ast.child.right.left.group_id
#     central_gname = ast.child.right.left.group_name
#
#     assert isinstance(ast.child.right.right, GroupNode)
#     rightmost_gid = ast.child.right.right.group_id
#     rightmost_gname = ast.child.right.right.group_name
#
#     assert leftmost_gid == central_gid
#     assert central_gid == rightmost_gid
#     assert leftmost_gname == central_gname
#     assert central_gname == rightmost_gname
