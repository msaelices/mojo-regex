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


struct ASTNode(
    Copyable, EqualityComparable, ImplicitlyBoolable, Movable, Stringable, Writable
):
    """Struct for all the Regex AST nodes."""

    var type: Int
    var matching: String
    var children: Deque[ASTNode]
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
        owned children: List[ASTNode] = [],
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
        self.children = Deque[ASTNode](capacity=len(children))
        for child in children:
            self.children.append(child)

    fn __copyinit__(out self, other: ASTNode):
        """Copy constructor for ASTNode."""
        self.type = other.type
        self.matching = other.matching
        self.capturing = other.capturing
        self.group_name = other.group_name
        self.min = other.min
        self.max = other.max
        self.children = Deque[ASTNode](capacity=len(other.children))
        for child in other.children:
            self.children.append(child)

    fn __bool__(self) -> Bool:
        """Return True if the node is not None."""
        return True

    fn __as_bool__(self) -> Bool:
        """Return a boolean representation of the node."""
        return self.__bool__()

    fn __eq__(self, other: ASTNode) -> Bool:
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

    fn __ne__(self, other: ASTNode) -> Bool:
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
        if self.type in [ELEMENT, WILDCARD, SPACE, RANGE, START, END]:
            return True
        else:
            return False

    fn is_match(self, value: String, str_i: Int = 0, str_len: Int = 0) -> Bool:
        """Check if the node matches a given value."""
        if self.type == ELEMENT:
            return self.matching == value
        elif self.type == WILDCARD:
            return value != "\n"
        elif self.type == SPACE:
            if len(value) == 1:
                var ch = value
                return ch == " " or ch == "\t" or ch == "\n" or ch == "\r" or ch == "\f"
            return False
        elif self.type == RANGE:
            # For range elements, use XNOR logic for positive/negative matching
            var ch_found = self.matching.find(value) != -1
            return not (ch_found ^ (self.min == 1))  # min=1 means positive logic
        elif self.type == START:
            return str_i == 0
        elif self.type == END:
            return str_i == str_len
        else:
            return False

    fn is_capturing(self) -> Bool:
        """Check if the node is capturing."""
        return self.capturing


fn RENode(
    child: ASTNode, capturing: Bool = False, group_name: String = "RegEx"
) -> ASTNode:
    """Create a RE node with a child."""
    return ASTNode(
        type=RE, children=[child], capturing=capturing, group_name=group_name
    )


fn Element(matching: String) -> ASTNode:
    """Create an Element node with a matching string."""
    return ASTNode(type=ELEMENT, matching=matching, min=1, max=1)


fn WildcardElement() -> ASTNode:
    """Create a WildcardElement node."""
    return ASTNode(type=WILDCARD, matching="anything", min=1, max=1)


fn SpaceElement() -> ASTNode:
    """Create a SpaceElement node."""
    return ASTNode(type=SPACE, matching="", min=1, max=1)


fn RangeElement(match_str: String, is_positive_logic: Bool = True) -> ASTNode:
    """Create a RangeElement node."""
    return ASTNode(
        type=RANGE,
        matching=match_str,
        min=1 if is_positive_logic else 0,  # Use min to store logic type
        max=1,
    )


fn StartElement() -> ASTNode:
    """Create a StartElement node."""
    return ASTNode(type=START, matching="", min=1, max=1)


fn EndElement() -> ASTNode:
    """Create an EndElement node."""
    return ASTNode(type=END, matching="", min=1, max=1)


fn OrNode(left: ASTNode, right: ASTNode) -> ASTNode:
    """Create an OrNode with left and right children."""
    return ASTNode(type=OR, children=[left, right], min=1, max=1)


fn NotNode(child: ASTNode) -> ASTNode:
    """Create a NotNode with a child."""
    return ASTNode(type=NOT, children=[child])


fn GroupNode(
    children: List[ASTNode],
    capturing: Bool = False,
    group_name: String = "",
    group_id: Int = -1,
) -> ASTNode:
    """Create a GroupNode with children."""
    var final_group_name = group_name if group_name != "" else "Group " + String(
        group_id
    )
    return ASTNode(
        type=GROUP,
        children=children,
        capturing=capturing,
        group_name=final_group_name,
        min=1,
        max=1,
    )
