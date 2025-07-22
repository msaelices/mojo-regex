from memory import Pointer, UnsafePointer, memcpy
from builtin._location import __call_location
from memory import UnsafePointer
from os import abort

from regex.constants import ZERO_CODE, NINE_CODE


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


@fieldwise_init
struct ASTNode[mut: Bool, //, value_origin: Origin[mut]](
    Copyable,
    EqualityComparable,
    ImplicitlyBoolable,
    Movable,
    Stringable,
    Writable,
):
    """Struct for all the Regex AST nodes."""

    var type: Int
    var value_ptr: UnsafePointer[String, mut=mut, origin=value_origin]
    var children_ptr: UnsafePointer[ASTNode[MutableAnyOrigin]]
    var children_len: Int
    var capturing: Bool
    var group_name: String
    var min: Int
    var max: Int
    var positive_logic: Bool  # For character ranges: True for [abc], False for [^abc]

    @always_inline
    fn __init__(
        out self,
        type: Int,
        ref [value_origin]value: String = "",
        capturing: Bool = False,
        owned group_name: String = "",
        min: Int = 0,
        max: Int = 0,
        positive_logic: Bool = True,
    ):
        """Initialize an ASTNode with a specific type and match string."""
        self.type = type
        self.capturing = capturing
        self.group_name = group_name^
        self.min = min
        self.max = max
        self.positive_logic = positive_logic
        self.value_ptr = UnsafePointer[String, mut=mut, origin=value_origin](
            to=value
        )
        self.children_ptr = UnsafePointer[ASTNode[MutableAnyOrigin]]()
        self.children_len = 0

    fn __init__[
        child_origin: Origin,
        child_value_origin: Origin,
    ](
        out self,
        type: Int,
        ref [child_origin]child: ASTNode[child_value_origin],
        ref [value_origin]value: String = "",
        capturing: Bool = False,
        owned group_name: String = "",
        min: Int = 0,
        max: Int = 0,
        positive_logic: Bool = True,
    ):
        """Initialize an ASTNode with a specific type and match string."""
        self.type = type
        self.capturing = capturing
        self.value_ptr = UnsafePointer[String, mut=mut, origin=value_origin](
            to=value
        )
        self.group_name = group_name^
        self.min = min
        self.max = max
        self.positive_logic = positive_logic
        self.children_len = 1
        self.children_ptr = UnsafePointer[ASTNode[MutableAnyOrigin]](
            to=child._origin_cast[origin=MutableAnyOrigin](),
        )

    fn __init__(
        out self,
        type: Int,
        owned children: List[ASTNode[MutableAnyOrigin]],
        ref [value_origin]value: String = "",
        capturing: Bool = False,
        owned group_name: String = "",
        min: Int = 0,
        max: Int = 0,
        positive_logic: Bool = True,
    ):
        """Initialize an ASTNode with a specific type and match string."""
        self.type = type
        self.capturing = capturing
        self.value_ptr = UnsafePointer[String, mut=mut, origin=value_origin](
            to=value
        )
        self.group_name = group_name^
        self.min = min
        self.max = max
        self.positive_logic = positive_logic
        self.children_len = len(children)

        self.children_ptr = children.unsafe_ptr()

        __disable_del children

        # Slower alternative
        # self.children_ptr = UnsafePointer[ASTNode].alloc(self.children_len)
        #
        # for i in range(self.children_len):
        #     var src = UnsafePointer(to=children[i])
        #     var dst = UnsafePointer(to=self.children_ptr[i])
        #     src.move_pointee_into(dst)

    # @always_inline
    # fn __del__(owned self):
    #     """Destroy all the children and free its memory."""
    #     var call_location = __call_location()
    #     print("Deleting ASTNode:", self, "in ", call_location)
    #     # TODO: This is causing the parsing to hang
    #     # for i in range(self.children_len):
    #     #     (self.children_ptr + i).destroy_pointee()
    #     # self.children_ptr.free()

    @always_inline
    fn __copyinit__(out self, other: ASTNode[value_origin]):
        """Copy constructor for ASTNode."""
        self.type = other.type
        self.capturing = other.capturing
        self.group_name = other.group_name
        self.min = other.min
        self.max = other.max
        self.positive_logic = other.positive_logic
        self.children_len = other.children_len

        # TODO: Check if we can substitute this with the following commented block
        self.children_ptr = other.children_ptr
        self.value_ptr = other.value_ptr

        # TODO: This is causing core dumps
        # if not other.children_ptr:
        #     self.children_ptr = UnsafePointer[ASTNode, mut=False]()
        # else:
        #     # Allocate memory for children and copy them
        #     self.children_ptr = UnsafePointer[ASTNode].alloc(other.children_len)
        #     memcpy(self.children_ptr, other.children_ptr, other.children_len)

        # var call_location = __call_location()
        # print("Copying ASTNode:", self, "in ", call_location)

    fn __bool__(self) -> Bool:
        """Return True if the node is not None."""
        return True

    fn __as_bool__(self) -> Bool:
        """Return a boolean representation of the node."""
        return self.__bool__()

    fn __eq__(self, other: ASTNode[value_origin]) -> Bool:
        """Check if two AST nodes are equal."""
        return (
            self.type == other.type
            and self.value_ptr == other.value_ptr
            and self.capturing == other.capturing
            and self.group_name == other.group_name
            and self.min == other.min
            and self.max == other.max
            and self.positive_logic == other.positive_logic
            and self.children_ptr == other.children_ptr
        )

    fn __ne__(self, other: ASTNode[value_origin]) -> Bool:
        """Check if two AST nodes are not equal."""
        return not self.__eq__(other)

    fn __repr__(self) -> String:
        """Return a string representation of the PhoneNumberDesc."""
        return String(
            "ASTNode(type=",
            self.type,
            ", value=",
            self.get_value(),
            ")",
            sep="",
        )

    fn __str__(self) -> String:
        """Returns a user-friendly string representation of the PhoneNumberDesc.
        """
        return String.write(self)

    # Thanks to @martinvuyk for this trick
    @always_inline
    fn _origin_cast[origin: Origin](owned self) -> ASTNode[origin]:
        var result = ASTNode[origin](
            type=self.type,
            value_ptr=self.value_ptr.origin_cast[
                mut = origin.mut, origin=origin
            ](),
            children_ptr=self.children_ptr,
            children_len=self.children_len,
            capturing=self.capturing,
            group_name=self.group_name,
            min=self.min,
            max=self.max,
            positive_logic=self.positive_logic,
        )
        # We stole the elements, don't destroy them.
        __disable_del self
        return result^

    @no_inline
    fn write_to[W: Writer, //](self, mut writer: W):
        """Writes a string representation of the PhoneNumberDesc to the writer.

        Parameters:
            W: The type of the writer, conforming to the `Writer` trait.

        Args:
            writer: The writer instance to output the representation to.
        """
        if self.get_value():
            writer.write(
                "ASTNode(type=",
                self.type,
                ", value=",
                self.get_value().value(),
                ")",
            )
        else:
            writer.write("ASTNode(type=", self.type, ", value=None)")

    fn is_leaf(self) -> Bool:
        """Check if the AST node is a leaf node."""
        if self.type in [ELEMENT, WILDCARD, SPACE, DIGIT, RANGE, START, END]:
            return True
        else:
            return False

    fn is_match(self, value: String, str_i: Int = 0, str_len: Int = 0) -> Bool:
        """Check if the node matches a given value."""
        if self.type == ELEMENT:
            return self.get_value() and (self.get_value().value() == value)
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
                var ch_code = ord(value)
                return ZERO_CODE <= ch_code <= NINE_CODE
            return False
        elif self.type == RANGE:
            # For range elements, use XNOR logic for positive/negative matching
            var ch_found = (
                self.get_value() and self.get_value().value().find(value) != -1
            )
            return not (
                ch_found ^ self.positive_logic
            )  # positive_logic determines if it's [abc] or [^abc]
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
    fn get_children_len(self) -> Int:
        return self.children_len

    @always_inline
    fn has_children(self) -> Bool:
        return self.get_children_len() > 0

    @always_inline
    fn get_child(self, i: Int) -> ASTNode[MutableAnyOrigin]:
        """Get the children of the AST node."""
        return self.children_ptr[i]

    @always_inline
    fn get_value(self) -> Optional[String]:
        if not self.value_ptr:
            return None
        return self.value_ptr[]


@always_inline
fn RENode[
    value_origin: Origin,
    child_origin: Origin,
    child_value_origin: Origin,
](
    ref [child_origin]child: ASTNode[child_value_origin],
    ref [value_origin]value: String,
    capturing: Bool = False,
    group_name: String = "RegEx",
) -> ASTNode[value_origin]:
    """Create a RE node with a child."""
    return ASTNode[value_origin](
        type=RE,
        value=value,
        child=child,
        capturing=capturing,
        group_name=group_name,
    )


@always_inline
fn Element[
    value_origin: Origin
](ref [value_origin]value: String) -> ASTNode[value_origin]:
    """Create an Element node with a value string."""
    return ASTNode[value_origin](type=ELEMENT, value=value, min=1, max=1)


@always_inline
fn WildcardElement[
    value_origin: Origin,
](ref [value_origin]value: String = "anything",) -> ASTNode[value_origin]:
    """Create a WildcardElement node."""
    return ASTNode[value_origin](type=WILDCARD, value=value, min=1, max=1)


@always_inline
fn SpaceElement[
    value_origin: Origin,
](ref [value_origin]value: String = "",) -> ASTNode[value_origin]:
    """Create a SpaceElement node."""
    return ASTNode[value_origin](type=SPACE, value=value, min=1, max=1)


@always_inline
fn DigitElement[
    value_origin: Origin,
](ref [value_origin]value: String = "",) -> ASTNode[value_origin]:
    """Create a DigitElement node."""
    return ASTNode[value_origin](type=DIGIT, value=value, min=1, max=1)


@always_inline
fn RangeElement[
    value_origin: Origin
](ref [value_origin]value: String, is_positive_logic: Bool = True) -> ASTNode[
    value_origin
]:
    """Create a RangeElement node."""
    return ASTNode[value_origin](
        type=RANGE,
        value=value,
        min=1,
        max=1,
        positive_logic=is_positive_logic,
    )


@always_inline
fn StartElement[
    value_origin: Origin
](ref [value_origin]value: String = "",) -> ASTNode[value_origin]:
    """Create a StartElement node."""
    return ASTNode[value_origin](type=START, value=value, min=1, max=1)


@always_inline
fn EndElement[
    value_origin: Origin
](ref [value_origin]value: String = "",) -> ASTNode[value_origin]:
    """Create an EndElement node."""
    return ASTNode[value_origin](type=END, value=value, min=1, max=1)


@always_inline
fn OrNode[
    value_origin: Origin,
    left_origin: Origin,
    right_origin: Origin,
    left_value_origin: Origin,
    right_value_origin: Origin,
](
    ref [left_origin]left: ASTNode[left_value_origin],
    ref [right_origin]right: ASTNode[right_value_origin],
    ref [value_origin]value: String,
) -> ASTNode[value_origin]:
    """Create an OrNode with left and right children."""

    var left_casted = left._origin_cast[origin=MutableAnyOrigin]()
    var right_casted = right._origin_cast[origin=MutableAnyOrigin]()

    return ASTNode[value_origin](
        type=OR,
        children=List[ASTNode[MutableAnyOrigin]](left_casted, right_casted),
        value=value,
        min=1,
        max=1,
    )


@always_inline
fn NotNode[
    value_origin: Origin,
    child_origin: Origin,
    child_value_origin: Origin,
](
    ref [child_origin]child: ASTNode[child_value_origin],
    ref [value_origin]value: String,
) -> ASTNode[value_origin]:
    """Create a NotNode with a child."""
    return ASTNode[value_origin](
        type=NOT,
        child=child,
        value=value,
    )


@always_inline
fn GroupNode[
    value_origin: Origin
](
    owned children: List[ASTNode[MutableAnyOrigin]],
    ref [value_origin]value: String,
    capturing: Bool = False,
    group_name: String = "",
    group_id: Int = -1,
) -> ASTNode[value_origin]:
    """Create a GroupNode with children."""
    var final_group_name = (
        group_name if group_name != "" else "Group " + String(group_id)
    )
    return ASTNode[value_origin](
        type=GROUP,
        value=value,
        children=children,
        capturing=capturing,
        group_name=final_group_name,
        min=1,
        max=1,
    )
