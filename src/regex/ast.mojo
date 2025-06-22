from collections import Deque


alias RE = 0
alias ELEMENT = 1
alias WILDCARD = 2
alias SPACE = 3
alias RANGE = 4
alias START = 5
alias END = 6
alias OR = 7
alias NOT = 8
alias GROUP = 9


trait Node(Copyable, Movable, ImplicitlyBoolable):

    fn is_leaf(self) -> Bool:
        """Check if the node is a leaf node."""
        pass


struct ASTNode[origin: Origin](Node):
    """Struct for all the Regex AST nodes."""
    var type: Int
    var matching: String
    var children: Deque[ASTNode[origin]]
    var capturing: Bool
    var group_name: String

    fn __init__(out self, type: Int = 0, matching: String = "", capturing: Bool = False, group_name: String = "", *children: ASTNode[origin]):
        """Initialize an ASTNode with a specific type and match string."""
        self.type = type
        self.matching = matching
        self.children = Deque(*children)

    fn __bool__(self) -> Bool:
        """Return True if the node is not None."""
        return True

    fn __as_bool__(self) -> Bool:
        """Return a boolean representation of the node."""
        return self.__bool__()

    fn is_leaf(self) -> Bool:
        """Check if the AST node is a leaf node."""
        if self.type in [ELEMENT, RANGE, START, END]:
            return True
        else:
            return False


fn RENode[origin: Origin](child: ASTNode[origin]) -> ASTNode[origin]:
    """Create a RE node with a child."""
    return ASTNode(type=RE, *children=(child,))
