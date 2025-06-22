from testing import assert_equal, assert_true, assert_raises

from regex.ast import ASTNode, RENode, Element


fn test_RE() raises:
    element = Element(matching="e")
    re = RENode(child=element)
    assert_true(re)
    assert_equal(element, re.children[0])
