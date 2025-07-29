from testing import assert_equal, assert_true, assert_false

from regex.ast import (
    ChildrenIndexes,
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
    var pattern = String("")
    var regex = Regex[ImmutableAnyOrigin](pattern)
    var regex_ptr = UnsafePointer(to=regex)
    var ast_node = ASTNode[ImmutableAnyOrigin](
        type=ELEMENT, regex_ptr=regex_ptr, start_idx=0, end_idx=0
    )
    assert_true(ast_node.__bool__())


fn test_Element() raises:
    var pattern = String("a")
    var regex = Regex[ImmutableAnyOrigin](pattern)
    var elem = Element[MutableAnyOrigin](regex, start_idx=0, end_idx=1)
    assert_true(elem.__bool__())
    assert_equal(elem.type, ELEMENT)
    assert_equal(elem.get_value().value(), "a")
    assert_true(elem.is_match("a"))
    assert_false(elem.is_match("b"))


fn test_WildcardElement() raises:
    var pattern = String(".")
    var regex = Regex[ImmutableAnyOrigin](pattern)
    var we = WildcardElement[MutableAnyOrigin](regex, start_idx=0, end_idx=1)
    assert_true(we.__bool__())
    assert_equal(we.type, WILDCARD)
    assert_true(we.is_match("a"))
    assert_true(we.is_match("z"))
    assert_false(we.is_match("\n"))


fn test_SpaceElement() raises:
    var pattern = String("\\s")
    var regex = Regex[ImmutableAnyOrigin](pattern)
    var se = SpaceElement[MutableAnyOrigin](regex, start_idx=0, end_idx=2)
    assert_true(se.__bool__())
    assert_equal(se.type, SPACE)
    assert_true(se.is_match(" "))
    assert_true(se.is_match("\t"))
    assert_true(se.is_match("\n"))
    assert_true(se.is_match("\f"))
    assert_true(se.is_match("\r"))
    assert_false(se.is_match("t"))


fn test_RangeElement_positive_logic() raises:
    var pattern = String("[abc]")
    var regex = Regex[ImmutableAnyOrigin](pattern)
    var re = RangeElement[MutableAnyOrigin](
        regex, start_idx=1, end_idx=4, is_positive_logic=True
    )
    assert_true(re.__bool__())
    assert_equal(re.type, RANGE)
    assert_equal(re.min, 1)
    assert_true(re.positive_logic)
    assert_true(re.is_match("a"))
    assert_true(re.is_match("b"))
    assert_true(re.is_match("c"))
    assert_false(re.is_match("x"))


fn test_RangeElement_negative_logic() raises:
    var pattern = String("[^abc]")
    var regex = Regex[ImmutableAnyOrigin](pattern)
    var nre = RangeElement[MutableAnyOrigin](
        regex, start_idx=2, end_idx=5, is_positive_logic=False
    )
    assert_true(nre.__bool__())
    assert_equal(nre.type, RANGE)
    assert_equal(nre.min, 1)
    assert_false(nre.positive_logic)
    assert_false(nre.is_match("a"))
    assert_false(nre.is_match("b"))
    assert_false(nre.is_match("c"))
    assert_true(nre.is_match("x"))


fn test_StartElement() raises:
    var pattern = String("^")
    var regex = Regex[ImmutableAnyOrigin](pattern)
    var start = StartElement[MutableAnyOrigin](regex, start_idx=0, end_idx=1)
    assert_true(start.__bool__())
    assert_equal(start.type, START)
    assert_true(start.is_match("", 0, 10))
    assert_false(start.is_match("", 1, 10))


fn test_EndElement() raises:
    var pattern = String("$")
    var regex = Regex[ImmutableAnyOrigin](pattern)
    var end = EndElement[MutableAnyOrigin](regex, start_idx=0, end_idx=1)
    assert_true(end.__bool__())
    assert_equal(end.type, END)
    assert_true(end.is_match("", 10, 10))
    assert_false(end.is_match("", 5, 10))


fn test_OrNode() raises:
    var pattern = String("a|b")
    var mut_regex = Regex[MutableAnyOrigin](pattern)
    var regex = mut_regex.get_immutable()
    var left = Element[MutableAnyOrigin](regex, start_idx=0, end_idx=1)
    var right = Element[MutableAnyOrigin](regex, start_idx=2, end_idx=3)

    # Add children to mutable regex
    mut_regex.append_child(left)
    mut_regex.append_child(right)

    var or_node = OrNode[MutableAnyOrigin](
        regex,
        left_child_index=1,
        right_child_index=2,
        start_idx=0,
        end_idx=3,
    )
    assert_true(or_node.__bool__())
    assert_equal(or_node.type, OR)
    assert_equal(or_node.get_children_len(), 2)
    assert_equal(
        or_node.get_child(0).get_value().value(), left.get_value().value()
    )
    assert_equal(
        or_node.get_child(1).get_value().value(), right.get_value().value()
    )


fn test_NotNode() raises:
    var pattern = String("^e")
    var mut_regex = Regex[MutableAnyOrigin](pattern)
    var regex = mut_regex.get_immutable()
    var element = Element[MutableAnyOrigin](regex, start_idx=1, end_idx=2)

    # Add child to mutable regex
    mut_regex.append_child(element)

    var not_node = NotNode[MutableAnyOrigin](
        regex, child_index=1, start_idx=0, end_idx=2
    )
    assert_true(not_node.__bool__())
    assert_equal(not_node.type, NOT)
    assert_equal(not_node.get_children_len(), 1)
    assert_equal(
        not_node.get_child(0).get_value().value(), element.get_value().value()
    )


fn test_GroupNode() raises:
    var pattern = String("(ab)")
    var mut_regex = Regex[MutableAnyOrigin](pattern)
    var regex = mut_regex.get_immutable()
    var elem1 = Element[MutableAnyOrigin](regex, start_idx=1, end_idx=2)
    var elem2 = Element[MutableAnyOrigin](regex, start_idx=2, end_idx=3)

    # Add children to mutable regex
    mut_regex.append_child(elem1)
    mut_regex.append_child(elem2)

    var children_indexes = ChildrenIndexes(1, 2)
    var group = GroupNode[MutableAnyOrigin](
        regex,
        children_indexes=children_indexes,
        start_idx=0,
        end_idx=4,
        capturing=True,
    )
    assert_true(group.__bool__())
    assert_equal(group.type, GROUP)
    assert_true(group.is_capturing())
    assert_equal(group.get_children_len(), 2)


fn test_GroupNode_default_name() raises:
    var pattern = String("(a)")
    var mut_regex = Regex[MutableAnyOrigin](pattern)
    var regex = mut_regex.get_immutable()
    var elem = Element[MutableAnyOrigin](regex, start_idx=1, end_idx=2)

    # Add child to mutable regex
    mut_regex.append_child(elem)

    var children_indexes = ChildrenIndexes(1)
    var group = GroupNode[MutableAnyOrigin](
        regex,
        children_indexes=children_indexes,
        start_idx=0,
        end_idx=3,
    )
    assert_true(group.__bool__())
    assert_equal(group.type, GROUP)


fn test_is_leaf() raises:
    var pattern = String("a.^$[abc]a|b()")
    var mut_regex = Regex[MutableAnyOrigin](pattern)
    var regex = mut_regex.get_immutable()
    var element = Element[MutableAnyOrigin](regex, start_idx=0, end_idx=1)
    var wildcard = WildcardElement[MutableAnyOrigin](
        regex, start_idx=1, end_idx=2
    )
    var start_elem = StartElement[MutableAnyOrigin](
        regex, start_idx=2, end_idx=3
    )
    var end_elem = EndElement[MutableAnyOrigin](regex, start_idx=3, end_idx=4)
    var range_elem = RangeElement[MutableAnyOrigin](
        regex, start_idx=5, end_idx=8
    )

    # Add children to mutable regex for complex nodes
    mut_regex.append_child(element)
    mut_regex.append_child(wildcard)

    var or_node = OrNode[MutableAnyOrigin](
        regex,
        left_child_index=1,
        right_child_index=2,
        start_idx=9,
        end_idx=12,
    )
    var empty_children_indexes = ChildrenIndexes()
    var group = GroupNode[MutableAnyOrigin](
        regex,
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
