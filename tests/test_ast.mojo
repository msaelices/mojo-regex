from testing import assert_equal, assert_true, assert_false

from regex.ast import (
    ASTNode,
    RENode,
    Element,
    WildcardElement,
    SpaceElement,
    RangeElement,
    StartElement,
    EndElement,
    OrNode,
    NotNode,
    GroupNode,
    RE,
    ELEMENT,
    WILDCARD,
    SPACE,
    RANGE,
    START,
    END,
    OR,
    NOT,
    GROUP,
)


fn test_ASTNode() raises:
    var ast_node = ASTNode()
    assert_true(Bool(ast_node))


fn test_RE() raises:
    var element = Element("e")
    var re = RENode(element)
    assert_true(Bool(re))
    assert_equal(re.type, RE)
    assert_equal(len(re.children), 1)
    assert_equal(re.children[0], element)


fn test_Element() raises:
    var elem = Element("a")
    assert_true(Bool(elem))
    assert_equal(elem.type, ELEMENT)
    assert_equal(elem.value, "a")
    assert_true(elem.is_match("a"))
    assert_false(elem.is_match("b"))


fn test_WildcardElement() raises:
    var we = WildcardElement()
    assert_true(Bool(we))
    assert_equal(we.type, WILDCARD)
    assert_true(we.is_match("a"))
    assert_true(we.is_match("z"))
    assert_false(we.is_match("\n"))


fn test_SpaceElement() raises:
    var se = SpaceElement()
    assert_true(Bool(se))
    assert_equal(se.type, SPACE)
    assert_true(se.is_match(" "))
    assert_true(se.is_match("\t"))
    assert_true(se.is_match("\n"))
    assert_true(se.is_match("\f"))
    assert_true(se.is_match("\r"))
    assert_false(se.is_match("t"))


fn test_RangeElement_positive_logic() raises:
    var re = RangeElement("abc", True)
    assert_true(Bool(re))
    assert_equal(re.type, RANGE)
    assert_equal(re.min, 1)  # Positive logic encoded as min=1
    assert_true(re.is_match("a"))
    assert_true(re.is_match("b"))
    assert_true(re.is_match("c"))
    assert_false(re.is_match("x"))


fn test_RangeElement_negative_logic() raises:
    var nre = RangeElement("abc", False)
    assert_true(Bool(nre))
    assert_equal(nre.type, RANGE)
    assert_equal(
        nre.min, 1
    )  # Both positive and negative logic should match exactly 1 character
    assert_false(nre.is_match("a"))
    assert_false(nre.is_match("b"))
    assert_false(nre.is_match("c"))
    assert_true(nre.is_match("x"))


fn test_StartElement() raises:
    var start = StartElement()
    assert_true(Bool(start))
    assert_equal(start.type, START)
    assert_true(start.is_match("", 0, 10))
    assert_false(start.is_match("", 1, 10))


fn test_EndElement() raises:
    var end = EndElement()
    assert_true(Bool(end))
    assert_equal(end.type, END)
    assert_true(end.is_match("", 10, 10))
    assert_false(end.is_match("", 5, 10))


fn test_OrNode() raises:
    var left = Element("a")
    var right = Element("b")
    var or_node = OrNode(left, right)
    assert_true(Bool(or_node))
    assert_equal(or_node.type, OR)
    assert_equal(len(or_node.children), 2)
    assert_equal(or_node.children[0], left)
    assert_equal(or_node.children[1], right)


fn test_NotNode() raises:
    var element = Element("e")
    var not_node = NotNode(element)
    assert_true(Bool(not_node))
    assert_equal(not_node.type, NOT)
    assert_equal(len(not_node.children), 1)
    assert_equal(not_node.children[0], element)


fn test_GroupNode() raises:
    var elem1 = Element("a")
    var elem2 = Element("b")
    var children = List[ASTNode]()
    children.append(elem1)
    children.append(elem2)

    var group = GroupNode(
        children^, capturing=True, group_name="test_group", group_id=1
    )
    assert_true(Bool(group))
    assert_equal(group.type, GROUP)
    assert_true(group.is_capturing())
    assert_equal(group.group_name, "test_group")
    assert_equal(len(group.children), 2)


fn test_GroupNode_default_name() raises:
    var elem = Element("a")
    var children = List[ASTNode]()
    children.append(elem)

    var group = GroupNode(children^, group_id=5)
    assert_equal(group.group_name, "Group 5")


fn test_is_leaf() raises:
    var element = Element("a")
    var wildcard = WildcardElement()
    var start_elem = StartElement()
    var end_elem = EndElement()
    var range_elem = RangeElement("abc")
    var or_node = OrNode(element, wildcard)
    var group = GroupNode(List[ASTNode]())

    assert_true(element.is_leaf())
    assert_true(wildcard.is_leaf())  # WILDCARD is now in leaf list
    assert_true(start_elem.is_leaf())
    assert_true(end_elem.is_leaf())
    assert_true(range_elem.is_leaf())
    assert_false(or_node.is_leaf())
    assert_false(group.is_leaf())
