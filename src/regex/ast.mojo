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


struct ASTNode[origin: Origin](
    Copyable, EqualityComparable, ImplicitlyBoolable, Movable, Stringable, Writable
):
    """Struct for all the Regex AST nodes."""

    var type: Int
    var matching: String
    var children: Deque[ASTNode[origin]]
    var capturing: Bool
    var group_name: String
    var min: Int
    var max: Int

    fn __init__(
        out self,
        type: Int = 0,
        owned matching: String = "",
        capturing: Bool = False,
        owned group_name: String = "",
        min: Int = 0,
        max: Int = 0,
        owned children: List[ASTNode[origin]] = [],
    ):
        """Initialize an ASTNode with a specific type and match string."""
        self.type = type
        self.capturing = capturing
        self.matching = matching^
        self.group_name = group_name^
        self.min = min
        self.max = max
        # TODO: Uncomment when unpacked arguments are supported in Mojo
        # self.children = Deque[ASTNode[origin]](*children)
        self.children = Deque[ASTNode[origin]](capacity=len(children))
        for child in children:
            self.children.append(child)

    fn __copyinit__(out self, other: ASTNode[origin]):
        """Copy constructor for ASTNode."""
        self.type = other.type
        self.matching = other.matching
        self.capturing = other.capturing
        self.group_name = other.group_name
        self.min = other.min
        self.max = other.max
        self.children = Deque[ASTNode[origin]](capacity=len(other.children))
        for child in other.children:
            self.children.append(child)

    fn __bool__(self) -> Bool:
        """Return True if the node is not None."""
        return True

    fn __as_bool__(self) -> Bool:
        """Return a boolean representation of the node."""
        return self.__bool__()

    fn __eq__(self, other: ASTNode[origin]) -> Bool:
        """Check if two AST nodes are equal."""
        return (
            self.type == other.type
            and self.matching == other.matching
            and self.capturing == other.capturing
            and self.group_name == other.group_name
            and self.min == other.min
            and self.max == other.max
            and len(self.children) == len(other.children)
            and self.children == other.children
        )

    fn __ne__(self, other: ASTNode[origin]) -> Bool:
        """Check if two AST nodes are not equal."""
        return not self.__eq__(other)

    fn __repr__(self) -> String:
        """Return a string representation of the PhoneNumberDesc."""
        return String(
            "ASTNode(type=",
            self.type,
            ", matching=",
            self.matching,
            ")",
            sep="",
        )

    fn __str__(self) -> String:
        """Returns a user-friendly string representation of the PhoneNumberDesc."""
        return String.write(self)

    @no_inline
    fn write_to[W: Writer, //](self, mut writer: W):
        """Writes a string representation of the PhoneNumberDesc to the writer.

        Parameters:
            W: The type of the writer, conforming to the `Writer` trait.

        Args:
            writer: The writer instance to output the representation to.
        """
        writer.write("ASTNode(type=", self.type, ", matching=", self.matching, ")")

    fn is_leaf(self) -> Bool:
        """Check if the AST node is a leaf node."""
        if self.type in [ELEMENT, RANGE, START, END]:
            return True
        else:
            return False

    fn is_match(self, value: String, str_i: Int = 0, str_len: Int = 0) -> Bool:
        """Check if the node matches a given value."""
        if self.type == ELEMENT:
            return self.matching == value
        elif self.type == WILDCARD:
            return value != "\n"
        else:
            return False


fn RENode[origin: Origin](child: ASTNode[origin]) -> ASTNode[origin]:
    """Create a RE node with a child."""
    return ASTNode[origin](type=RE, children=[child])


fn Element[origin: Origin](ref [origin]matching: String) -> ASTNode[origin]:
    """Create an Element node with a matching string."""
    return ASTNode[origin](
        type=ELEMENT,
        matching=matching,
    )
