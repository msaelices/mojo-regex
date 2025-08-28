from memory import UnsafePointer, memcpy
from builtin._location import __call_location


@register_passable("trivial")
struct Match(Copyable, Movable):
    """Contains the information of a match in a regular expression."""

    var group_id: Int
    """The ID of the capturing group (0 for the whole match)."""
    var start_idx: Int
    """Starting position of the match in the text."""
    var end_idx: Int
    """Ending position of the match in the text (exclusive)."""
    var text_ptr: UnsafePointer[String, mut=False]
    """Pointer to the original text being matched."""

    fn __init__(
        out self,
        group_id: Int,
        start_idx: Int,
        end_idx: Int,
        text: String,
    ):
        self.group_id = group_id
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.text_ptr = UnsafePointer(to=text)

    fn get_match_text(self) -> StringSlice[ImmutableAnyOrigin]:
        """Returns the text that was matched."""
        return self.text_ptr[].as_string_slice()[self.start_idx : self.end_idx]


struct MatchList(Copyable, Movable, Sized):
    """Smart container for regex matches with lazy allocation and optimal reservation.

    This struct provides zero allocation until the first match is added, then
    reserves a small amount of capacity to avoid malloc churn for common cases.
    Provides List-compatible interface for easy integration with existing code.
    """

    alias DEFAULT_RESERVE_SIZE = 8
    """Default number of matches to reserve on first allocation."""

    var _data: UnsafePointer[Match]
    """Internal list storing the matches."""
    var _len: Int
    var _capacity: Int

    fn __init__(
        out self,
        capacity: Int = 0,
    ):
        """Initialize empty Matches container."""
        self._data = UnsafePointer[Match]()
        self._capacity = capacity
        self._len = 0
        if capacity > 0:
            self._realloc(capacity)

    @always_inline
    fn __copyinit__(
        out self,
        other: Self,
    ):
        """Copy constructor."""
        self = Self(capacity=other._capacity)
        for i in range(len(other)):
            self.append(other[i])
        self._len = other._len
        self._capacity = other._capacity
        # # Comment when debug is done
        # var call_location = __call_location()
        # print("Copying MatchList", call_location)

    fn __del__(owned self):
        """Destructor to free allocated memory."""
        if self._data:
            self._data.free()

    fn __moveinit__(
        out self,
        deinit other: Self,
    ):
        """Move constructor."""
        self._list = other._list^
        self._allocated = other._allocated

    fn append(
        mut self,
        m: Match,
    ):
        """Add a match to the container, reserving capacity on first use."""
        if not self._allocated:
            self._list.reserve(Self.DEFAULT_RESERVE_SIZE)
            self._allocated = True
        self._list.append(m)

    @always_inline
    fn __len__(self) -> Int:
        """Return the number of matches."""
        return self._len

    fn __getitem__[I: Indexer](ref self, idx: I) -> ref [self] Match:
        """Gets the list element at the given index.

        Args:
            idx: The index of the element.

        Parameters:
            I: A type that can be used as an index.

        Returns:
            A reference to the match at the given index.
        """
        return self._data[idx]

    @no_inline
    fn _realloc(mut self, new_capacity: Int):
        var new_data = UnsafePointer[Match].alloc(new_capacity)

        memcpy(new_data, self._data, len(self))

        if self._data:
            self._data.free()
        self._data = new_data
        self._capacity = new_capacity

    fn append(
        mut self,
        m: Match,
    ):
        """Add a match to the container, reserving capacity on first use."""
        if not self._data:
            self._realloc(self._capacity + self.DEFAULT_RESERVE_SIZE)
        self._data[self._len] = m
        self._len += 1

    fn clear(
        mut self,
    ):
        """Remove all matches but keep allocated capacity."""
        if self._data:
            self._data.free()
