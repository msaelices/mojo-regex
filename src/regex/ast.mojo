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


struct Regex[origin: Origin](
    Copyable, EqualityComparable, Movable, Stringable, Writable
):
    alias ImmOrigin = ImmutableOrigin.cast_from[origin]
    alias Immutable = Regex[origin = Self.ImmOrigin]
    var pattern: String
    var children_ptr: UnsafePointer[ASTNode[ImmutableAnyOrigin],]
    var children_len: Int
    """Immutable Regex struct for representing a regular expression pattern."""

    fn __init__(out self, ref [origin]pattern: String):
        """Initialize a Regex with a pattern."""
        self.pattern = pattern
        self.children_len = 0
        self.children_ptr = UnsafePointer[ASTNode[ImmutableAnyOrigin]].alloc(
            len(pattern) * 2
        )  # Allocate enough space for children

    fn __str__(self) -> String:
        """Return a string representation of the Regex."""
        return String("Regex(pattern=", self.pattern, ")")

    fn __repr__(self) -> String:
        """Return a string representation of the Regex."""
        return String("Regex(pattern=", self.pattern, ")")

    @always_inline
    fn __eq__(self, other: Regex[origin=origin]) -> Bool:
        """Check if two Regex instances are equal."""
        return self.pattern == other.pattern

    @always_inline
    fn __ne__(self, other: Regex[origin=origin]) -> Bool:
        """Check if two Regex instances are not equal."""
        return not self.__eq__(other)

    @always_inline
    fn __copyinit__(out self, other: Self):
        """Copy constructor for ASTNode."""
        self.pattern = other.pattern
        self.children_ptr = other.children_ptr
        self.children_len = other.children_len
        var call_location = __call_location()
        print("Copying Regex:", self, "in ", call_location)

    @always_inline
    fn __del__(owned self):
        """Destroy all the children and free its memory."""
        var call_location = __call_location()
        print("Deleting Regex:", self, "in ", call_location)

    @no_inline
    fn write_to[W: Writer, //](self, mut writer: W):
        """Writes a string representation of the Regex to the writer.

        Parameters:
            W: The type of the writer, conforming to the `Writer` trait.

        Args:
            writer: The writer instance to output the representation to.
        """
        writer.write("Regex(pattern=", self.pattern, ")")

    @always_inline
    fn get_immutable(self) -> Self.Immutable:
        """Return an immutable version of this `Span`.

        Returns:
            An immutable version of the same `Span`.
        """
        return rebind[Self.Immutable](self)

    @always_inline
    fn get_child(self, i: Int) -> ASTNode[ImmutableAnyOrigin]:
        """Get the child ASTNode at index `i`."""
        return self.children_ptr[i]

    @always_inline
    fn get_children_len(self) -> Int:
        """Get the number of children in the Regex."""
        return self.children_len

    @always_inline
    fn append_child(mut self, owned child: ASTNode[ImmutableAnyOrigin]):
        """Append a child ASTNode to the Regex."""
        print(
            "Appending child to Regex at ",
            __call_location(),
            ": ",
            child,
        )
        (self.children_ptr + self.children_len).init_pointee_move(child^)
        self.children_len += 1


struct ASTNode[regex_origin: ImmutableOrigin, max_children: Int = 256,](
    Copyable,
    EqualityComparable,
    ImplicitlyBoolable,
    Movable,
    Stringable,
    Writable,
):
    """Struct for all the Regex AST nodes."""

    var type: Int
    var regex_ptr: UnsafePointer[
        Regex[ImmutableAnyOrigin], mut=False, origin=regex_origin
    ]
    var start_idx: Int
    var end_idx: Int
    var capturing: Bool
    var children_indexes: SIMD[
        DType.uint8, max_children
    ]  # Bit vector for each ASCII character
    var children_len: Int
    var min: Int
    var max: Int
    var positive_logic: Bool  # For character ranges: True for [abc], False for [^abc]

    @always_inline
    fn __init__(
        out self,
        type: Int,
        regex_ptr: UnsafePointer[Regex[ImmutableAnyOrigin]],
        start_idx: Int,
        end_idx: Int,
        capturing: Bool = False,
        min: Int = 0,
        max: Int = 0,
        positive_logic: Bool = True,
    ):
        """Initialize an ASTNode with a specific type and match string."""
        self.type = type
        self.regex_ptr = regex_ptr
        self.capturing = capturing
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.min = min
        self.max = max
        self.positive_logic = positive_logic
        self.children_indexes = SIMD[DType.uint8, max_children](
            0
        )  # Initialize with all bits set to 0
        self.children_len = 0

    fn __init__(
        out self,
        regex_ptr: UnsafePointer[Regex[ImmutableAnyOrigin]],
        type: Int,
        child_index: UInt8,
        start_idx: Int,
        end_idx: Int,
        capturing: Bool = False,
        min: Int = 0,
        max: Int = 0,
        positive_logic: Bool = True,
    ):
        """Initialize an ASTNode with a specific type and match string."""
        self.regex_ptr = regex_ptr
        self.type = type
        self.capturing = capturing
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.min = min
        self.max = max
        self.positive_logic = positive_logic
        self.children_indexes = SIMD[DType.uint8, max_children](0)
        self.children_indexes[0] = child_index  # Set the first child index
        self.children_len = 1

    fn __init__(
        out self,
        regex_ptr: UnsafePointer[Regex[ImmutableAnyOrigin]],
        type: Int,
        owned children_indexes: List[UInt8],
        start_idx: Int,
        end_idx: Int,
        capturing: Bool = False,
        min: Int = 0,
        max: Int = 0,
        positive_logic: Bool = True,
    ):
        """Initialize an ASTNode with a specific type and match string."""
        self.regex_ptr = regex_ptr
        self.type = type
        self.capturing = capturing
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.min = min
        self.max = max
        self.positive_logic = positive_logic
        self.children_indexes = SIMD[DType.uint8, max_children](0)
        for i in range(len(children_indexes)):
            self.children_indexes[i] = children_indexes[i]
        self.children_len = len(children_indexes)

    @always_inline
    fn __del__(owned self):
        """Destroy all the children and free its memory."""
        var call_location = __call_location()
        print("Deleting ASTNode:", self, "in ", call_location)

    @always_inline
    fn __copyinit__(out self, other: ASTNode[regex_origin, max_children]):
        """Copy constructor for ASTNode."""
        self.type = other.type
        self.regex_ptr = other.regex_ptr
        self.capturing = other.capturing
        self.start_idx = other.start_idx
        self.end_idx = other.end_idx
        self.min = other.min
        self.max = other.max
        self.positive_logic = other.positive_logic
        self.children_indexes = other.children_indexes
        self.children_len = other.children_len
        # var call_location = __call_location()
        # print("Copying ASTNode:", self, "in ", call_location)

    @always_inline
    fn __bool__(self) -> Bool:
        """Return True if the node is not None."""
        return True

    fn __as_bool__(self) -> Bool:
        """Return a boolean representation of the node."""
        return self.__bool__()

    fn __eq__(self, other: ASTNode[regex_origin, max_children]) -> Bool:
        """Check if two AST nodes are equal."""
        return (
            self.type == other.type
            and self.capturing == other.capturing
            and self.min == other.min
            and self.max == other.max
            and self.positive_logic == other.positive_logic
            and self.children_len == other.children_len
            and (self.children_indexes == other.children_indexes).reduce_and()
        )

    fn __ne__(self, other: ASTNode[regex_origin, max_children]) -> Bool:
        """Check if two AST nodes are not equal."""
        return not self.__eq__(other)

    fn __repr__(self) -> String:
        """Return a string representation of the PhoneNumberDesc."""
        return String(
            "ASTNode(type=",
            self.type,
            ", value=",
            String(self.get_value().value()) if self.get_value() else "None",
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
    fn get_child(self, i: Int) -> ASTNode[ImmutableAnyOrigin]:
        """Get the children of the AST node."""
        return self.regex_ptr[].get_child(Int(self.children_indexes[i] - 1))

    @always_inline
    fn get_value(
        self,
    ) -> Optional[StringSlice[__origin_of(self.regex_ptr[].pattern)]]:
        if self.start_idx == self.end_idx:
            return None
        return StringSlice[__origin_of(self.regex_ptr[].pattern)](
            ptr=self.regex_ptr[].pattern.unsafe_ptr() + self.start_idx,
            length=self.end_idx - self.start_idx,
        )


@always_inline
fn Element[
    regex_origin: MutableOrigin,
](
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[ImmutableAnyOrigin]:
    """Create an Element node with a value string."""
    var regex_ptr = UnsafePointer(to=regex).origin_cast[
        mut=False, origin=ImmutableAnyOrigin
    ]()
    return ASTNode[ImmutableAnyOrigin](
        type=ELEMENT,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
fn WildcardElement[
    regex_origin: ImmutableOrigin,
](
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create a WildcardElement node."""
    var regex_ptr = UnsafePointer(to=regex).origin_cast[
        mut=False, origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=WILDCARD,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
fn SpaceElement[
    regex_origin: ImmutableOrigin,
](
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create a SpaceElement node."""
    var regex_ptr = UnsafePointer(to=regex).origin_cast[
        mut=False, origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=SPACE,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
fn DigitElement[
    regex_origin: ImmutableOrigin,
](
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create a DigitElement node."""
    var regex_ptr = UnsafePointer(to=regex).origin_cast[
        mut=False, origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=DIGIT,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
fn RangeElement[
    regex_origin: ImmutableOrigin,
](
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    start_idx: Int,
    end_idx: Int,
    is_positive_logic: Bool = True,
) -> ASTNode[regex_origin]:
    """Create a RangeElement node."""
    var regex_ptr = UnsafePointer(to=regex).origin_cast[
        mut=False, origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=RANGE,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
        positive_logic=is_positive_logic,
    )


@always_inline
fn StartElement[
    regex_origin: ImmutableOrigin,
](
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create a StartElement node."""
    var regex_ptr = UnsafePointer(to=regex).origin_cast[
        mut=False, origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=START,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
fn EndElement[
    regex_origin: ImmutableOrigin
](
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create an EndElement node."""
    var regex_ptr = UnsafePointer(to=regex).origin_cast[
        mut=False, origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=END,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
fn OrNode[
    regex_origin: ImmutableOrigin
](
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    left_child_index: UInt8,
    right_child_index: UInt8,
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create an OrNode with left and right children."""
    var regex_ptr = UnsafePointer(to=regex).origin_cast[
        mut=False, origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=OR,
        regex_ptr=regex_ptr,
        children_indexes=List[UInt8](left_child_index, right_child_index),
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
fn NotNode[
    regex_origin: ImmutableOrigin,
](
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    child_index: UInt8,
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create a NotNode with a child."""
    var regex_ptr = UnsafePointer(to=regex).origin_cast[
        mut=False, origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=NOT,
        regex_ptr=regex_ptr,
        children_indexes=List[UInt8](child_index),
        start_idx=start_idx,
        end_idx=end_idx,
    )


@always_inline
fn GroupNode[
    regex_origin: ImmutableOrigin,
](
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    children_indexes: List[UInt8],
    start_idx: Int,
    end_idx: Int,
    capturing: Bool = False,
    group_id: Int = -1,
) -> ASTNode[regex_origin]:
    """Create a GroupNode with children."""
    var regex_ptr = UnsafePointer(to=regex).origin_cast[
        mut=False, origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=GROUP,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        children_indexes=children_indexes,
        capturing=capturing,
        min=1,
        max=1,
    )
