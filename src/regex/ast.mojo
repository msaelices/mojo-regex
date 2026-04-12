from std.memory import Pointer, UnsafePointer, memcpy, alloc
from std.os import abort

from regex.aliases import (
    CHAR_ZERO,
    CHAR_NINE,
    CHAR_A,
    CHAR_Z,
    CHAR_A_UPPER,
    CHAR_Z_UPPER,
    CHAR_NEWLINE,
    CHAR_SPACE,
    CHAR_TAB_CHAR,
    CHAR_CR,
    CHAR_FF,
    CHAR_UNDERSCORE,
    CHAR_CIRCUMFLEX,
    CHAR_DASH,
    WORD_CHARS,
    byte_in_string,
)


comptime RE = 0
comptime ELEMENT = 1
comptime WILDCARD = 2
comptime SPACE = 3
comptime DIGIT = 4
comptime WORD = 5
comptime RANGE = 6
comptime START = 7
comptime END = 8
comptime OR = 9
comptime NOT = 10
comptime GROUP = 11

# Range classification tags, precomputed at AST build time so that
# _match_range / _apply_quantifier_simd can switch on an Int instead
# of doing per-character string comparisons.
comptime RANGE_KIND_NONE = 0  # not a RANGE node
comptime RANGE_KIND_LOWERCASE = 1  # [a-z]
comptime RANGE_KIND_UPPERCASE = 2  # [A-Z]
comptime RANGE_KIND_DIGITS = 3  # [0-9]
comptime RANGE_KIND_ALNUM = 4  # [a-zA-Z0-9]
comptime RANGE_KIND_ALPHA = 5  # [a-zA-Z]
comptime RANGE_KIND_COMPLEX_ALNUM = 6  # [a-zA-Z0-9...] with extra chars
comptime RANGE_KIND_OTHER = 7  # anything else

# Threshold for complex character class patterns (e.g. [a-zA-Z0-9._%+-]).
# Shared between classify_range_kind() and nfa.mojo's _match_range fallback.
comptime COMPLEX_CHAR_CLASS_THRESHOLD = 10

comptime LEAF_ELEMS: SIMD[DType.int8, 8] = [
    Int8(ELEMENT),
    Int8(WILDCARD),
    Int8(SPACE),
    Int8(DIGIT),
    Int8(WORD),
    Int8(RANGE),
    Int8(START),
    Int8(END),
]
comptime SIMD_QUANTIFIERS: SIMD[DType.int8, 4] = [
    Int8(SPACE),
    Int8(DIGIT),
    Int8(WORD),
    Int8(RANGE),
]

comptime ChildrenIndexes = List[UInt8]


@always_inline
def _make_children_indexes(*values: UInt8) -> ChildrenIndexes:
    """Helper to create a ChildrenIndexes list from variadic UInt8 values."""
    var result = ChildrenIndexes(capacity=len(values))
    for i in range(len(values)):
        result.append(values[i])
    return result^


struct Regex[origin: Origin](Copyable, Equatable, Movable, Writable):
    comptime ImmOrigin = ImmutOrigin(Self.origin)
    comptime Immutable = Regex[origin=Self.ImmOrigin]
    var pattern: String
    var children_ptr: UnsafePointer[ASTNode[ImmutAnyOrigin], MutAnyOrigin]
    var children_len: Int
    """Regex struct for representing a regular expression pattern."""

    def __init__(out self, ref[Self.origin] pattern: String):
        """Initialize a Regex with a pattern."""
        self.pattern = pattern
        self.children_len = 0
        self.children_ptr = alloc[ASTNode[ImmutAnyOrigin]](
            len(pattern) * 2
        )  # Allocate enough space for children

    @always_inline
    def __eq__[o: Origin](self, other: Regex[origin=o]) -> Bool:
        """Check if two Regex instances are equal."""
        return self.pattern == other.pattern

    @always_inline
    def __ne__[o: Origin](self, other: Regex[origin=o]) -> Bool:
        """Check if two Regex instances are not equal."""
        return self.pattern != other.pattern

    # @always_inline
    # fn __copyinit__(out self, copy: Self):
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
    def write_to[W: Writer, //](self, mut writer: W):
        """Writes a string representation of the Regex to the writer.

        Parameters:
            W: The type of the writer, conforming to the `Writer` trait.

        Args:
            writer: The writer instance to output the representation to.
        """
        writer.write("Regex(pattern=", self.pattern, ")")

    @always_inline
    def get_immutable(self) -> Self.Immutable:
        """Return an immutable version of this `Span`.

        Returns:
            An immutable version of the same `Span`.
        """
        return rebind[Self.Immutable](self).copy()

    @always_inline
    def get_child(self, i: Int) -> ASTNode[ImmutAnyOrigin]:
        """Get the child ASTNode at index `i`."""
        return self.children_ptr[i]

    @always_inline
    def get_children_len(self) -> Int:
        """Get the number of children in the Regex."""
        return self.children_len

    @always_inline
    def append_child(mut self, var child: ASTNode[ImmutAnyOrigin]):
        """Append a child ASTNode to the Regex."""
        # print(
        #     "Appending child to Regex at ",
        #     __call_location(),
        #     ": ",
        #     child,
        # )
        (self.children_ptr + self.children_len).init_pointee_move(child^)
        self.children_len += 1


struct ASTNode[regex_origin: ImmutOrigin](
    Boolable,
    Equatable,
    ImplicitlyCopyable,
    Movable,
    Writable,
):
    """Struct for all the Regex AST nodes."""

    # Mark that is trivially copyable in lists
    comptime __copy_ctor_is_trivial = True
    comptime max_children = 256

    var type: Int
    """The type of AST node (e.g., ELEMENT, GROUP, RANGE, etc.)."""
    var regex_ptr: UnsafePointer[Regex[ImmutAnyOrigin], ImmutAnyOrigin]
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
    var range_kind: Int
    """Precomputed RANGE_KIND_* tag for RANGE nodes. Eliminates per-character
    string comparisons in _match_range / _apply_quantifier_simd."""

    @always_inline
    def __init__(
        out self,
        type: Int,
        regex_ptr: UnsafePointer[Regex[ImmutAnyOrigin], ImmutAnyOrigin],
        start_idx: Int,
        end_idx: Int,
        capturing_group: Bool = False,
        min: Int = 0,
        max: Int = 0,
        positive_logic: Bool = True,
        range_kind: Int = RANGE_KIND_NONE,
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
        self.range_kind = range_kind
        self.children_indexes = SIMD[DType.uint8, Self.max_children](
            0
        )  # Initialize with all bits set to 0
        self.children_len = 0

    def __init__(
        out self,
        regex_ptr: UnsafePointer[Regex[ImmutAnyOrigin], ImmutAnyOrigin],
        type: Int,
        child_index: UInt8,
        start_idx: Int,
        end_idx: Int,
        capturing_group: Bool = False,
        min: Int = 0,
        max: Int = 0,
        positive_logic: Bool = True,
        range_kind: Int = RANGE_KIND_NONE,
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
        self.range_kind = range_kind
        self.children_indexes = SIMD[DType.uint8, Self.max_children](0)
        self.children_indexes[0] = child_index  # Set the first child index
        self.children_len = 1

    def __init__(
        out self,
        regex_ptr: UnsafePointer[Regex[ImmutAnyOrigin], ImmutAnyOrigin],
        type: Int,
        children_indexes: ChildrenIndexes,
        start_idx: Int,
        end_idx: Int,
        capturing_group: Bool = False,
        min: Int = 0,
        max: Int = 0,
        positive_logic: Bool = True,
        range_kind: Int = RANGE_KIND_NONE,
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
        self.range_kind = range_kind
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
    def __copyinit__(out self, copy: ASTNode[Self.regex_origin]):
        """Copy constructor for ASTNode."""
        self.type = copy.type
        self.regex_ptr = copy.regex_ptr
        self.capturing_group = copy.capturing_group
        self.start_idx = copy.start_idx
        self.end_idx = copy.end_idx
        self.min = copy.min
        self.max = copy.max
        self.positive_logic = copy.positive_logic
        self.range_kind = copy.range_kind
        self.children_indexes = copy.children_indexes
        self.children_len = copy.children_len
        # var call_location = __call_location()
        # print("Copying ASTNode:", self, "in ", call_location)

    @always_inline
    def __bool__(self) -> Bool:
        """Return True if the node is not None."""
        return True

    def __as_bool__(self) -> Bool:
        """Return a boolean representation of the node."""
        return self.__bool__()

    def __eq__(self, other: ASTNode[Self.regex_origin]) -> Bool:
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

    def __ne__(self, other: ASTNode[Self.regex_origin]) -> Bool:
        """Check if two AST nodes are not equal."""
        return not self.__eq__(other)

    @no_inline
    def write_to[W: Writer, //](self, mut writer: W):
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
    def is_leaf(self) -> Bool:
        """Check if the AST node is a leaf node."""
        if LEAF_ELEMS.eq(self.type).reduce_or():
            return True
        else:
            return False

    @always_inline
    def is_simd_optimizable(self, min_matches: Int, max_matches: Int) -> Bool:
        """Check if the AST node would benefit from SIMD quantifier optimization.

        Only use SIMD for patterns that will truly benefit, avoiding overhead
        for simple cases that can be handled more efficiently by regular matching.
        """
        if not SIMD_QUANTIFIERS.eq(Int8(self.type)).reduce_or():
            return False

        if min_matches == 1 and max_matches == 1:
            return False  # No quantifier

        # Only use SIMD for complex patterns or significant repetition
        if max_matches == -1:  # Unlimited quantifiers like *, +
            # Predefined types (DIGIT, WORD, SPACE) use cached SIMD matchers
            # so the overhead is minimal even for small min_matches
            if self.type == DIGIT or self.type == WORD or self.type == SPACE:
                return min_matches >= 1
            # For RANGE and other types, require more repetition to justify SIMD
            return min_matches > 3
        elif max_matches > 8:  # Large bounded quantifiers {9,} or {5,20}
            return True
        elif self.type == RANGE and self.get_value():
            # Complex character classes benefit more from SIMD
            return (
                len(self.get_value().value()) > 8
            )  # Complex patterns like [a-zA-Z0-9._%+-]
        else:
            return False  # Simple quantifiers use regular matching

    def is_match(self, value: String, str_i: Int = 0, str_len: Int = 0) -> Bool:
        """Check if the node matches a given value."""
        if self.type == START:
            return str_i == 0
        elif self.type == END:
            return str_i == str_len
        elif len(value) == 1:
            return self.is_match_char(ord(value), str_i, str_len)
        elif self.type == ELEMENT:
            return self.get_value() and (self.get_value().value() == value)
        return False

    @always_inline
    def is_match_char(
        self, ch_code: Int, str_i: Int = 0, str_len: Int = 0
    ) -> Bool:
        """Check if the node matches a character code without allocating."""
        if self.type == ELEMENT:
            var value = self.get_value()
            if value:
                ref val = value.value()
                return len(val) == 1 and Int(val.unsafe_ptr()[0]) == ch_code
            return False
        elif self.type == WILDCARD:
            return ch_code != CHAR_NEWLINE
        elif self.type == SPACE:
            return (
                ch_code == CHAR_SPACE
                or ch_code == CHAR_TAB_CHAR
                or ch_code == CHAR_NEWLINE
                or ch_code == CHAR_CR
                or ch_code == CHAR_FF
            )
        elif self.type == DIGIT:
            return CHAR_ZERO <= ch_code <= CHAR_NINE
        elif self.type == WORD:
            # O(1) range checks instead of O(n) string search
            return (
                (CHAR_A <= ch_code <= CHAR_Z)
                or (CHAR_A_UPPER <= ch_code <= CHAR_Z_UPPER)
                or (CHAR_ZERO <= ch_code <= CHAR_NINE)
                or ch_code == CHAR_UNDERSCORE
            )
        elif self.type == RANGE:
            var ch_found = False
            var value = self.get_value()
            if value:
                ref range_pattern = value.value()
                ch_found = self._is_char_in_range_by_code(
                    ch_code, range_pattern
                )
            return not (ch_found ^ self.positive_logic)
        elif self.type == START:
            return str_i == 0
        elif self.type == END:
            return str_i == str_len
        else:
            return False

    def _is_char_in_range_by_code(
        self,
        ch_code: Int,
        range_pattern: StringSlice[origin_of(self.regex_ptr[].pattern)],
    ) -> Bool:
        """Check if a character code is in a range pattern. Zero-allocation
        version of _is_char_in_range."""
        if range_pattern.startswith("["):
            var inner_pattern = range_pattern[byte=1:-1]
            return self._char_code_matches_range(ch_code, inner_pattern)
        else:
            # Expanded string, check if char is in it
            return byte_in_string(ch_code, range_pattern)

    def _char_code_matches_range(
        self,
        ch_code: Int,
        range_syntax: StringSlice[origin_of(self.regex_ptr[].pattern)],
    ) -> Bool:
        """Check if a character code matches range syntax like 'a-z'."""
        var rs_ptr = range_syntax.unsafe_ptr()
        var i = 0
        if len(range_syntax) > 0 and Int(rs_ptr[0]) == CHAR_CIRCUMFLEX:
            i = 1

        while i < len(range_syntax):
            if i + 2 < len(range_syntax) and Int(rs_ptr[i + 1]) == CHAR_DASH:
                var start_code = Int(rs_ptr[i])
                var end_code = Int(rs_ptr[i + 2])
                if start_code <= ch_code <= end_code:
                    return True
                i += 3
            else:
                if Int(rs_ptr[i]) == ch_code:
                    return True
                i += 1
        return False

    def _is_char_in_range(
        self,
        ch: StringSlice,
        range_pattern: StringSlice[origin_of(self.regex_ptr[].pattern)],
    ) -> Bool:
        """Check if a character is in a range pattern. Delegates to the
        int-based version."""
        return self._is_char_in_range_by_code(ord(ch), range_pattern)

    def _char_matches_range_syntax(
        self,
        ch: StringSlice,
        range_syntax: StringSlice[origin_of(self.regex_ptr[].pattern)],
    ) -> Bool:
        """Check if a character matches range syntax. Delegates to the
        int-based version."""
        return self._char_code_matches_range(ord(ch), range_syntax)

    def is_capturing(self) -> Bool:
        """Check if the node is capturing."""
        return self.capturing_group

    @always_inline
    def get_children_len(self) -> Int:
        return self.children_len

    @always_inline
    def has_children(self) -> Bool:
        return self.get_children_len() > 0

    @always_inline
    def get_child(self, i: Int) -> ASTNode[ImmutAnyOrigin]:
        """Get the children of the AST node."""
        return self.regex_ptr[].get_child(Int(self.children_indexes[i] - 1))

    @always_inline
    def get_value(
        self,
    ) -> Optional[StringSlice[origin_of(self.regex_ptr[].pattern)]]:
        if self.start_idx == self.end_idx:
            return None
        return StringSlice(
            unsafe_from_utf8=Span[Byte, origin_of(self.regex_ptr[].pattern)](
                ptr=self.regex_ptr[].pattern.unsafe_ptr() + self.start_idx,
                length=self.end_idx - self.start_idx,
            )
        )


@always_inline
def Element[
    regex_origin: MutOrigin,
](
    ref[regex_origin] regex: Regex[ImmutAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[ImmutAnyOrigin]:
    """Create an Element node with a value string."""
    var regex_ptr = UnsafePointer(to=regex).as_any_origin()
    return ASTNode[ImmutAnyOrigin](
        type=ELEMENT,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
def WildcardElement[
    regex_origin: ImmutOrigin,
](
    ref[regex_origin] regex: Regex[ImmutAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create a WildcardElement node."""
    var regex_ptr = UnsafePointer(to=regex).as_any_origin()
    return ASTNode[regex_origin](
        type=WILDCARD,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
def SpaceElement[
    regex_origin: ImmutOrigin,
](
    ref[regex_origin] regex: Regex[ImmutAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create a SpaceElement node."""
    var regex_ptr = UnsafePointer(to=regex).as_any_origin()
    return ASTNode[regex_origin](
        type=SPACE,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
def DigitElement[
    regex_origin: ImmutOrigin,
](
    ref[regex_origin] regex: Regex[ImmutAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create a DigitElement node."""
    var regex_ptr = UnsafePointer(to=regex).as_any_origin()
    return ASTNode[regex_origin](
        type=DIGIT,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
def WordElement[
    regex_origin: ImmutOrigin,
](
    ref[regex_origin] regex: Regex[ImmutAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create a WordElement node."""
    var regex_ptr = UnsafePointer(to=regex).as_any_origin()
    return ASTNode[regex_origin](
        type=WORD,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
def classify_range_kind(pattern: StringSlice) -> Int:
    """Classify a RANGE pattern into a RANGE_KIND_* tag at build time.

    This runs once when the AST is constructed so that per-character matching
    can switch on an Int instead of doing string comparisons.
    """
    if pattern == "[a-z]":
        return RANGE_KIND_LOWERCASE
    if pattern == "[A-Z]":
        return RANGE_KIND_UPPERCASE
    if pattern == "[0-9]":
        return RANGE_KIND_DIGITS
    if pattern == "[a-zA-Z0-9]" or pattern == "[0-9a-zA-Z]":
        return RANGE_KIND_ALNUM
    if pattern == "[a-zA-Z]":
        return RANGE_KIND_ALPHA
    # Check for complex alphanumeric patterns like [a-zA-Z0-9._%+-]
    if pattern.startswith("[") and pattern.endswith("]"):
        var inner = pattern[byte=1:-1]
        if (
            "a-z" in inner
            and "A-Z" in inner
            and "0-9" in inner
            and len(inner) > COMPLEX_CHAR_CLASS_THRESHOLD
        ):
            return RANGE_KIND_COMPLEX_ALNUM
    return RANGE_KIND_OTHER


@always_inline
def RangeElement[
    regex_origin: ImmutOrigin,
](
    ref[regex_origin] regex: Regex[ImmutAnyOrigin],
    start_idx: Int,
    end_idx: Int,
    is_positive_logic: Bool = True,
) -> ASTNode[regex_origin]:
    """Create a RangeElement node."""
    var regex_ptr = UnsafePointer(to=regex).as_any_origin()
    # Classify the range pattern once at build time.
    var kind = RANGE_KIND_OTHER
    if start_idx < end_idx:
        var pat = StringSlice(
            unsafe_from_utf8=Span[Byte, origin_of(regex.pattern)](
                ptr=regex.pattern.unsafe_ptr() + start_idx,
                length=end_idx - start_idx,
            )
        )
        kind = classify_range_kind(pat)
    return ASTNode[regex_origin](
        type=RANGE,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
        positive_logic=is_positive_logic,
        range_kind=kind,
    )


@always_inline
def StartElement[
    regex_origin: ImmutOrigin,
](
    ref[regex_origin] regex: Regex[ImmutAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create a StartElement node."""
    var regex_ptr = UnsafePointer(to=regex).as_any_origin()
    return ASTNode[regex_origin](
        type=START,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
def EndElement[
    regex_origin: ImmutOrigin
](
    ref[regex_origin] regex: Regex[ImmutAnyOrigin],
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create an EndElement node."""
    var regex_ptr = UnsafePointer(to=regex).as_any_origin()
    return ASTNode[regex_origin](
        type=END,
        regex_ptr=regex_ptr,
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
def OrNode[
    regex_origin: ImmutOrigin
](
    ref[regex_origin] regex: Regex[ImmutAnyOrigin],
    left_child_index: UInt8,
    right_child_index: UInt8,
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create an OrNode with left and right children."""
    var regex_ptr = UnsafePointer(to=regex).as_any_origin()
    return ASTNode[regex_origin](
        type=OR,
        regex_ptr=regex_ptr,
        children_indexes=_make_children_indexes(
            left_child_index, right_child_index
        ),
        start_idx=start_idx,
        end_idx=end_idx,
        min=1,
        max=1,
    )


@always_inline
def NotNode[
    regex_origin: ImmutOrigin,
](
    ref[regex_origin] regex: Regex[ImmutAnyOrigin],
    child_index: UInt8,
    start_idx: Int,
    end_idx: Int,
) -> ASTNode[regex_origin]:
    """Create a NotNode with a child."""
    var regex_ptr = UnsafePointer(to=regex).as_any_origin()
    return ASTNode[regex_origin](
        type=NOT,
        regex_ptr=regex_ptr,
        children_indexes=_make_children_indexes(child_index),
        start_idx=start_idx,
        end_idx=end_idx,
    )


@always_inline
def GroupNode[
    regex_origin: ImmutOrigin,
](
    ref[regex_origin] regex: Regex[ImmutAnyOrigin],
    children_indexes: ChildrenIndexes,
    start_idx: Int,
    end_idx: Int,
    capturing_group: Bool = False,
    group_id: Int = -1,
) -> ASTNode[regex_origin]:
    """Create a GroupNode with children."""
    var regex_ptr = UnsafePointer(to=regex).as_any_origin()
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
