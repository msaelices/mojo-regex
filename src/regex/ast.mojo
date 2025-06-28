alias RE = 0
alias ELEMENT = 1
alias WILDCARD = 2
alias SPACE = 3
alias DIGIT = 4
alias RANGE = 5
alias START = 6
alias END = 7
alias OR = 8
alias NOT = 9
alias GROUP = 10


struct ASTNode(
    Copyable,
    EqualityComparable,
    ImplicitlyBoolable,
    Movable,
    Stringable,
    Writable,
):
    """Struct for all the Regex AST nodes."""

    var type: Int
    var value: String
    var children: List[ASTNode]
    var capturing: Bool
    var group_name: String
    var min: Int
    var max: Int

    fn __init__(
        out self,
        type: Int = 0,
        owned value: String = "",
        capturing: Bool = False,
        owned group_name: String = "",
        min: Int = 0,
        max: Int = 0,
        owned children: List[ASTNode] = [],
    ):
        """Initialize an ASTNode with a specific type and match string."""
        self.type = type
        self.capturing = capturing
        self.value = value^
        self.group_name = group_name^
        self.min = min
        self.max = max
        # TODO: Uncomment when unpacked arguments are supported in Mojo
        # self.children = List[ASTNode[origin]](*children)
        self.children = List[ASTNode](capacity=len(children))
        for child in children:
            self.children.append(child)

    fn __copyinit__(out self, other: ASTNode):
        """Copy constructor for ASTNode."""
        self.type = other.type
        self.value = other.value
        self.capturing = other.capturing
        self.group_name = other.group_name
        self.min = other.min
        self.max = other.max
        # Deep copy children since List[ASTNode] is not directly copyable
        self.children = List[ASTNode](capacity=len(other.children))
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
            and self.value == other.value
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
            ", value=",
            self.value,
            ")",
            sep="",
        )

    fn __str__(self) -> String:
        """Returns a user-friendly string representation of the PhoneNumberDesc.
        """
        return String.write(self)

    @no_inline
    fn write_to[W: Writer, //](self, mut writer: W):
        """Writes a string representation of the PhoneNumberDesc to the writer.

        Parameters:
            W: The type of the writer, conforming to the `Writer` trait.

        Args:
            writer: The writer instance to output the representation to.
        """
        writer.write("ASTNode(type=", self.type, ", value=", self.value, ")")

    fn is_leaf(self) -> Bool:
        """Check if the AST node is a leaf node."""
        if self.type in [ELEMENT, WILDCARD, SPACE, DIGIT, RANGE, START, END]:
            return True
        else:
            return False

    fn is_match(self, value: String, str_i: Int = 0, str_len: Int = 0) -> Bool:
        """Check if the node matches a given value."""
        if self.type == ELEMENT:
            return self.value == value
        elif self.type == WILDCARD:
            return value != "\n"
        elif self.type == SPACE:
            if len(value) == 1:
                var ch = value
                return (
                    ch == " "
                    or ch == "\t"
                    or ch == "\n"
                    or ch == "\r"
                    or ch == "\f"
                )
            return False
        elif self.type == DIGIT:
            if len(value) == 1:
                var ch = value
                return (
                    ch == "0"
                    or ch == "1"
                    or ch == "2"
                    or ch == "3"
                    or ch == "4"
                    or ch == "5"
                    or ch == "6"
                    or ch == "7"
                    or ch == "8"
                    or ch == "9"
                )
            return False
        elif self.type == RANGE:
            # For range elements, use XNOR logic for positive/negative matching
            var ch_found = self.value.find(value) != -1
            return not (
                ch_found ^ (self.min == 1)
            )  # min=1 means positive logic
        elif self.type == START:
            return str_i == 0
        elif self.type == END:
            return str_i == str_len
        else:
            return False

    fn is_capturing(self) -> Bool:
        """Check if the node is capturing."""
        return self.capturing


@always_inline
fn RENode(
    child: ASTNode, capturing: Bool = False, group_name: String = "RegEx"
) -> ASTNode:
    """Create a RE node with a child."""
    return ASTNode(
        type=RE, children=[child], capturing=capturing, group_name=group_name
    )


@always_inline
fn Element(value: String) -> ASTNode:
    """Create an Element node with a value string."""
    return ASTNode(type=ELEMENT, value=value, min=1, max=1)


@always_inline
fn WildcardElement() -> ASTNode:
    """Create a WildcardElement node."""
    return ASTNode(type=WILDCARD, value="anything", min=1, max=1)


@always_inline
fn SpaceElement() -> ASTNode:
    """Create a SpaceElement node."""
    return ASTNode(type=SPACE, value="", min=1, max=1)


@always_inline
fn DigitElement() -> ASTNode:
    """Create a DigitElement node."""
    return ASTNode(type=DIGIT, value="", min=1, max=1)


@always_inline
fn RangeElement(value: String, is_positive_logic: Bool = True) -> ASTNode:
    """Create a RangeElement node."""
    return ASTNode(
        type=RANGE,
        value=value,
        min=1 if is_positive_logic else 0,  # Use min to store logic type
        max=1,
    )


@always_inline
fn StartElement() -> ASTNode:
    """Create a StartElement node."""
    return ASTNode(type=START, value="", min=1, max=1)


@always_inline
fn EndElement() -> ASTNode:
    """Create an EndElement node."""
    return ASTNode(type=END, value="", min=1, max=1)


@always_inline
fn OrNode(left: ASTNode, right: ASTNode) -> ASTNode:
    """Create an OrNode with left and right children."""
    return ASTNode(type=OR, children=[left, right], min=1, max=1)


@always_inline
fn NotNode(child: ASTNode) -> ASTNode:
    """Create a NotNode with a child."""
    return ASTNode(type=NOT, children=[child])


fn GroupNode(
    owned children: List[ASTNode],
    capturing: Bool = False,
    group_name: String = "",
    group_id: Int = -1,
) -> ASTNode:
    """Create a GroupNode with children."""
    var final_group_name = (
        group_name if group_name != "" else "Group " + String(group_id)
    )
    return ASTNode(
        type=GROUP,
        children=children^,
        capturing=capturing,
        group_name=final_group_name,
        min=1,
        max=1,
    )
