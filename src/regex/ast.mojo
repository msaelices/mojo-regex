from memory import Pointer, UnsafePointer, memcpy
from builtin._location import __call_location
from memory import UnsafePointer
from os import abort

from regex.aliases import CHAR_ZERO, CHAR_NINE, WORD_CHARS


alias RE = 0
alias ELEMENT = 1
alias WILDCARD = 2
alias SPACE = 3
alias DIGIT = 4
alias WORD = 5
alias RANGE = 6
alias START = 7
alias END = 8
alias OR = 9
alias NOT = 10
alias GROUP = 11

alias LEAF_ELEMS: SIMD[DType.int8, 8] = [
    ELEMENT,
    WILDCARD,
    SPACE,
    DIGIT,
    WORD,
    RANGE,
    START,
    END,
]
alias SIMD_QUANTIFIERS: SIMD[DType.int8, 4] = [
    SPACE,
    DIGIT,
    WORD,
    RANGE,
]

alias ChildrenIndexes = List[UInt8]


struct Regex[origin: Origin](
    Copyable, EqualityComparable, Movable, Stringable, Writable
):
    alias ImmOrigin = ImmutableOrigin.cast_from[origin]
    alias Immutable = Regex[origin = Self.ImmOrigin]
    var pattern: String
    var children_ptr: UnsafePointer[ASTNode[ImmutableAnyOrigin]]
    var children_len: Int
    """Regex struct for representing a regular expression pattern."""

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

    # @always_inline
    # fn __copyinit__(out self, other: Self):
    #     """Copy constructor for ASTNode."""
    #     self.pattern = other.pattern
    #     self.children_ptr = other.children_ptr
    #     self.children_len = other.children_len
    #     var call_location = __call_location()
    #     print("Copying Regex:", self, "in ", call_location)

    # @always_inline
    # fn __del__(var self):
    #     """Destroy all the children and free its memory."""
    #     var call_location = __call_location()
    #     print("Deleting Regex:", self, "in ", call_location)

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
        return rebind[Self.Immutable](self).copy()

    @always_inline
    fn get_child(self, i: Int) -> ASTNode[ImmutableAnyOrigin]:
        """Get the child ASTNode at index `i`."""
        return self.children_ptr[i]

    @always_inline
    fn get_children_len(self) -> Int:
        """Get the number of children in the Regex."""
        return self.children_len

    @always_inline
    fn append_child(mut self, var child: ASTNode[ImmutableAnyOrigin]):
        """Append a child ASTNode to the Regex."""
        # print(
        #     "Appending child to Regex at ",
        #     __call_location(),
        #     ": ",
        #     child,
        # )
        (self.children_ptr + self.children_len).init_pointee_move(child^)
        self.children_len += 1


struct ASTNode[regex_origin: ImmutableOrigin](
    EqualityComparable,
    ImplicitlyBoolable,
    ImplicitlyCopyable,
    Movable,
    Stringable,
    Writable,
):
    """Struct for all the Regex AST nodes."""

    # Mark that is trivially copyable in lists
    alias __copyinit__is_trivial = True
    alias max_children = 256

    var type: Int
    """The type of AST node (e.g., ELEMENT, GROUP, RANGE, etc.)."""
    var regex_ptr: UnsafePointer[
        Regex[ImmutableAnyOrigin], mut=False, origin=regex_origin
    ]
    """Pointer to the parent regex object containing the pattern string."""
    var start_idx: Int
    """Starting position of this node in the original pattern string."""
    var end_idx: Int
    """Ending position of this node in the original pattern string."""
    var capturing_group: Bool
    """Whether this node represents a capturing group."""
    var children_indexes: SIMD[DType.uint8, Self.max_children]
    """Bit vector for each ASCII character, used for efficient character class lookups."""
    var children_len: Int
    """Number of child nodes this AST node contains."""
    var min: Int
    """Minimum number of matches for quantifiers (e.g., 0 for *, 1 for +)."""
    var max: Int
    """Maximum number of matches for quantifiers (-1 for unlimited)."""
    var positive_logic: Bool
    """For character ranges: True for [abc], False for [^abc]."""

    @always_inline
    fn __init__(
        out self,
        type: Int,
        regex_ptr: UnsafePointer[Regex[ImmutableAnyOrigin]],
        start_idx: Int,
        end_idx: Int,
        capturing_group: Bool = False,
        min: Int = 0,
        max: Int = 0,
        positive_logic: Bool = True,
    ):
        """Initialize an ASTNode with a specific type and match string."""
        self.type = type
        self.regex_ptr = regex_ptr
        self.capturing_group = capturing_group
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.min = min
        self.max = max
        self.positive_logic = positive_logic
        self.children_indexes = SIMD[DType.uint8, Self.max_children](
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
        capturing_group: Bool = False,
        min: Int = 0,
        max: Int = 0,
        positive_logic: Bool = True,
    ):
        """Initialize an ASTNode with a specific type and match string."""
        self.regex_ptr = regex_ptr
        self.type = type
        self.capturing_group = capturing_group
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.min = min
        self.max = max
        self.positive_logic = positive_logic
        self.children_indexes = SIMD[DType.uint8, Self.max_children](0)
        self.children_indexes[0] = child_index  # Set the first child index
        self.children_len = 1

    fn __init__(
        out self,
        regex_ptr: UnsafePointer[Regex[ImmutableAnyOrigin]],
        type: Int,
        children_indexes: ChildrenIndexes,
        start_idx: Int,
        end_idx: Int,
        capturing_group: Bool = False,
        min: Int = 0,
        max: Int = 0,
        positive_logic: Bool = True,
    ):
        """Initialize an ASTNode with a specific type and match string."""
        self.regex_ptr = regex_ptr
        self.type = type
        self.capturing_group = capturing_group
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.min = min
        self.max = max
        self.positive_logic = positive_logic
        self.children_indexes = SIMD[DType.uint8, Self.max_children](0)
        for i in range(len(children_indexes)):
            self.children_indexes[i] = children_indexes[i]
        self.children_len = len(children_indexes)

    # @always_inline
    # fn __del__(var self):
    #     """Destroy all the children and free its memory."""
    #     var call_location = __call_location()
    #     print("Deleting ASTNode:", self, "in ", call_location)

    @always_inline
    fn __copyinit__(out self, other: ASTNode[regex_origin]):
        """Copy constructor for ASTNode."""
        self.type = other.type
        self.regex_ptr = other.regex_ptr
        self.capturing_group = other.capturing_group
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

    fn __eq__(self, other: ASTNode[regex_origin]) -> Bool:
        """Check if two AST nodes are equal."""
        return (
            self.type == other.type
            and self.capturing_group == other.capturing_group
            and self.min == other.min
            and self.max == other.max
            and self.positive_logic == other.positive_logic
            and self.children_len == other.children_len
            and self.children_indexes == other.children_indexes
        )

    fn __ne__(self, other: ASTNode[regex_origin]) -> Bool:
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

    @always_inline
    fn is_leaf(self) -> Bool:
        """Check if the AST node is a leaf node."""
        if LEAF_ELEMS.eq(self.type).reduce_or():
            return True
        else:
            return False

    @always_inline
    fn is_simd_optimizable(self, min_matches: Int, max_matches: Int) -> Bool:
        """Check if the AST node would benefit from SIMD quantifier optimization.

        Only use SIMD for patterns that will truly benefit, avoiding overhead
        for simple cases that can be handled more efficiently by regular matching.
        """
        if not SIMD_QUANTIFIERS.eq(self.type).reduce_or():
            return False

        if min_matches == 1 and max_matches == 1:
            return False  # No quantifier

        # Only use SIMD for complex patterns or significant repetition
        if max_matches == -1:  # Unlimited quantifiers like *, +
            # For unlimited quantifiers, only use SIMD if min > 3
            # Simple patterns like [0-9]+ (min=1) should use regular matching
            return min_matches > 3
        elif max_matches > 8:  # Large bounded quantifiers {9,} or {5,20}
            return True
        elif self.type == RANGE and self.get_value():
            # Complex character classes benefit more from SIMD
            ref range_pattern = String(self.get_value().value())
            return (
                len(range_pattern) > 8
            )  # Complex patterns like [a-zA-Z0-9._%+-]
        else:
            return False  # Simple quantifiers use regular matching

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
                return CHAR_ZERO <= ch_code <= CHAR_NINE
            return False
        elif self.type == WORD:
            if len(value) == 1:
                return value in WORD_CHARS
            return False
        elif self.type == RANGE:
            # For range elements, use XNOR logic for positive/negative matching
            var ch_found = False
            if self.get_value():
                ref range_pattern = self.get_value().value()
                ch_found = self._is_char_in_range(value, range_pattern)
            return not (
                ch_found ^ self.positive_logic
            )  # positive_logic determines if it's [abc] or [^abc]
        elif self.type == START:
            return str_i == 0
        elif self.type == END:
            return str_i == str_len
        else:
            return False

    fn _is_char_in_range(
        self,
        ch: StringSlice,
        range_pattern: StringSlice[__origin_of(self.regex_ptr[].pattern)],
    ) -> Bool:
        """Check if a character is in a range pattern like '[a-z]' or 'abcxyz'.
        """
        # If the range_pattern starts with '[', it's the original pattern like "[a-z]"
        # We need to parse it. Otherwise, it's already expanded like "abcdefghijklmnopqrstuvwxyz"
        if range_pattern.startswith("["):
            # Remove brackets and parse the range
            var inner_pattern = range_pattern[1:-1]  # Remove [ and ]
            return self._char_matches_range_syntax(ch, inner_pattern)
        else:
            # It's already expanded, just check if char is in the string
            return range_pattern.find(ch) != -1

    fn _char_matches_range_syntax(
        self,
        ch: StringSlice,
        range_syntax: StringSlice[__origin_of(self.regex_ptr[].pattern)],
    ) -> Bool:
        """Check if a character matches range syntax like 'a-z' or 'abc'."""
        var i = 0
        # Skip negation character if present
        if len(range_syntax) > 0 and range_syntax[0] == "^":
            i = 1

        while i < len(range_syntax):
            # Check for range pattern like 'a-z'
            if i + 2 < len(range_syntax) and range_syntax[i + 1] == "-":
                var start_char = range_syntax[i]
                var end_char = range_syntax[i + 2]
                var ch_ord = ord(ch)
                if ord(start_char) <= ch_ord <= ord(end_char):
                    return True
                i += 3  # Skip start, dash, and end
            else:
                # Single character match
                if range_syntax[i] == ch:
                    return True
                i += 1
        return False

    fn is_capturing(self) -> Bool:
        """Check if the node is capturing."""
        return self.capturing_group

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
            length=UInt(self.end_idx - self.start_idx),
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
        target_mut=False, target_origin=ImmutableAnyOrigin
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
        target_mut=False, target_origin=ImmutableAnyOrigin
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
        target_mut=False, target_origin=ImmutableAnyOrigin
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
        target_mut=False, target_origin=ImmutableAnyOrigin
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
fn WordElement[
    regex_origin: ImmutableOrigin,
](
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create a WordElement node."""
    var regex_ptr = UnsafePointer(to=regex).origin_cast[
        target_mut=False, target_origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=WORD,
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
        target_mut=False, target_origin=ImmutableAnyOrigin
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
        target_mut=False, target_origin=ImmutableAnyOrigin
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
        target_mut=False, target_origin=ImmutableAnyOrigin
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
        target_mut=False, target_origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=OR,
        regex_ptr=regex_ptr,
        children_indexes=ChildrenIndexes(left_child_index, right_child_index),
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
        target_mut=False, target_origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=NOT,
        regex_ptr=regex_ptr,
        children_indexes=ChildrenIndexes(child_index),
        start_idx=start_idx,
        end_idx=end_idx,
    )


@always_inline
fn GroupNode[
    regex_origin: ImmutableOrigin,
](
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    children_indexes: ChildrenIndexes,
    start_idx: Int,
    end_idx: Int,
    capturing_group: Bool = False,
    group_id: Int = -1,
) -> ASTNode[regex_origin]:
    """Create a GroupNode with children."""
    var regex_ptr = UnsafePointer(to=regex).origin_cast[
        target_mut=False, target_origin=ImmutableAnyOrigin
    ]()
    return ASTNode[regex_origin](
        type=GROUP,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        children_indexes=children_indexes,
        capturing_group=capturing_group,
        min=1,
        max=1,
    )
