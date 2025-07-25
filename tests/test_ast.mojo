from testing import assert_equal, assert_true, assert_false

from regex.ast import (
    Regex,
    ASTNode,
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
    var regex = Regex("")
    var ast_node = ASTNode(regex=regex, type=ELEMENT, start_idx=0, end_idx=0)
    assert_true(Bool(ast_node))


fn test_Element() raises:
    var regex = Regex("a")
    var elem = Element(regex=regex, start_idx=0, end_idx=1)
    assert_true(Bool(elem))
    assert_equal(elem.type, ELEMENT)
    assert_equal(elem.get_value().value(), "a")
    assert_true(elem.is_match("a"))
    assert_false(elem.is_match("b"))


fn test_WildcardElement() raises:
    var regex = Regex(".")
    var we = WildcardElement(regex=regex, start_idx=0, end_idx=1)
    assert_true(Bool(we))
    assert_equal(we.type, WILDCARD)
    assert_true(we.is_match("a"))
    assert_true(we.is_match("z"))
    assert_false(we.is_match("\n"))


fn test_SpaceElement() raises:
    var regex = Regex("\\s")
    var se = SpaceElement(regex=regex, start_idx=0, end_idx=2)
    assert_true(Bool(se))
    assert_equal(se.type, SPACE)
    assert_true(se.is_match(" "))
    assert_true(se.is_match("\t"))
    assert_true(se.is_match("\n"))
    assert_true(se.is_match("\f"))
    assert_true(se.is_match("\r"))
    assert_false(se.is_match("t"))


fn test_RangeElement_positive_logic() raises:
    var regex = Regex("[abc]")
    var re = RangeElement(
        regex=regex, start_idx=1, end_idx=4, is_positive_logic=True
    )
    assert_true(Bool(re))
    assert_equal(re.type, RANGE)
    assert_equal(re.min, 1)
    assert_true(re.positive_logic)
    assert_true(re.is_match("a"))
    assert_true(re.is_match("b"))
    assert_true(re.is_match("c"))
    assert_false(re.is_match("x"))


fn test_RangeElement_negative_logic() raises:
    var regex = Regex("[^abc]")
    var nre = RangeElement(
        regex=regex, start_idx=2, end_idx=5, is_positive_logic=False
    )
    assert_true(Bool(nre))
    assert_equal(nre.type, RANGE)
    assert_equal(nre.min, 1)
    assert_false(nre.positive_logic)
    assert_false(nre.is_match("a"))
    assert_false(nre.is_match("b"))
    assert_false(nre.is_match("c"))
    assert_true(nre.is_match("x"))


fn test_StartElement() raises:
    var regex = Regex("^")
    var start = StartElement(regex=regex, start_idx=0, end_idx=1)
    assert_true(Bool(start))
    assert_equal(start.type, START)
    assert_true(start.is_match("", 0, 10))
    assert_false(start.is_match("", 1, 10))


fn test_EndElement() raises:
    var regex = Regex("$")
    var end = EndElement(regex=regex, start_idx=0, end_idx=1)
    assert_true(Bool(end))
    assert_equal(end.type, END)
    assert_true(end.is_match("", 10, 10))
    assert_false(end.is_match("", 5, 10))


fn test_OrNode() raises:
    var regex = Regex("a|b")
    var left = Element[ImmutableAnyOrigin](regex=regex, start_idx=0, end_idx=1)
    var right = Element[ImmutableAnyOrigin](regex=regex, start_idx=2, end_idx=3)

    # Add children to regex
    regex.children.append(left)
    regex.children.append(right)

    var or_node = OrNode[ImmutableAnyOrigin](
        regex=regex,
        left_child_index=1,
        right_child_index=2,
        start_idx=0,
        end_idx=3,
    )
    assert_true(Bool(or_node))
    assert_equal(or_node.type, OR)
    assert_equal(or_node.get_children_len(), 2)
    assert_equal(
        or_node.get_child(0).get_value().value(), left.get_value().value()
    )
    assert_equal(
        or_node.get_child(1).get_value().value(), right.get_value().value()
    )


fn test_NotNode() raises:
    var regex = Regex("^e")
    var element = Element[ImmutableAnyOrigin](
        regex=regex, start_idx=1, end_idx=2
    )

    # Add child to regex
    regex.children.append(element)

    var not_node = NotNode[ImmutableAnyOrigin](
        regex=regex, child_index=1, start_idx=0, end_idx=2
    )
    assert_true(Bool(not_node))
    assert_equal(not_node.type, NOT)
    assert_equal(not_node.get_children_len(), 1)
    assert_equal(
        not_node.get_child(0).get_value().value(), element.get_value().value()
    )


fn test_GroupNode() raises:
    var regex = Regex("(ab)")
    var elem1 = Element[ImmutableAnyOrigin](regex=regex, start_idx=1, end_idx=2)
    var elem2 = Element[ImmutableAnyOrigin](regex=regex, start_idx=2, end_idx=3)

    # Add children to regex
    regex.children.append(elem1)
    regex.children.append(elem2)

    var children_indexes = List[UInt8](1, 2)
    var group = GroupNode[ImmutableAnyOrigin](
        regex=regex,
        children_indexes=children_indexes,
        start_idx=0,
        end_idx=4,
        capturing=True,
        group_id=1,
    )
    assert_true(Bool(group))
    assert_equal(group.type, GROUP)
    assert_true(group.is_capturing())
    assert_equal(group.get_children_len(), 2)


fn test_GroupNode_default_name() raises:
    var regex = Regex("(a)")
    var elem = Element[ImmutableAnyOrigin](regex=regex, start_idx=1, end_idx=2)

    # Add child to regex
    regex.children.append(elem)

    var children_indexes = List[UInt8](1)
    var group = GroupNode[ImmutableAnyOrigin](
        regex=regex,
        children_indexes=children_indexes,
        start_idx=0,
        end_idx=3,
        group_id=5,
    )
    assert_true(Bool(group))
    assert_equal(group.type, GROUP)


fn test_is_leaf() raises:
    var regex = Regex("a.^$[abc]a|b()")
    var element = Element[ImmutableAnyOrigin](
        regex=regex, start_idx=0, end_idx=1
    )
    var wildcard = WildcardElement[ImmutableAnyOrigin](
        regex=regex, start_idx=1, end_idx=2
    )
    var start_elem = StartElement[ImmutableAnyOrigin](
        regex=regex, start_idx=2, end_idx=3
    )
    var end_elem = EndElement[ImmutableAnyOrigin](
        regex=regex, start_idx=3, end_idx=4
    )
    var range_elem = RangeElement[ImmutableAnyOrigin](
        regex=regex, start_idx=5, end_idx=8
    )

    # Add children to regex for complex nodes
    regex.children.append(element)
    regex.children.append(wildcard)

    var or_node = OrNode[ImmutableAnyOrigin](
        regex=regex,
        left_child_index=1,
        right_child_index=2,
        start_idx=9,
        end_idx=12,
    )
    var empty_children_indexes = List[UInt8]()
    var group = GroupNode[ImmutableAnyOrigin](
        regex=regex,
        children_indexes=empty_children_indexes,
        start_idx=13,
        end_idx=15,
    )

    assert_true(element.is_leaf())
    assert_true(wildcard.is_leaf())
    assert_true(start_elem.is_leaf())
    assert_true(end_elem.is_leaf())
    assert_true(range_elem.is_leaf())
    assert_false(or_node.is_leaf())
    assert_false(group.is_leaf())
