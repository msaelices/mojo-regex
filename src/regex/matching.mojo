from std.memory import UnsafePointer, memcpy, alloc

from regex.aliases import ImmSlice


struct Match(Copyable, Movable, TrivialRegisterPassable):
    """Contains the information of a match in a regular expression."""

    # Trivially copyable in lists
    comptime __copy_ctor_is_trivial = True

    var group_id: Int
    """The ID of the capturing group (0 for the whole match)."""
    var start_idx: Int
    """Starting position of the match in the text."""
    var end_idx: Int
    """Ending position of the match in the text (exclusive)."""
    var text: ImmSlice
    """View of the original text being matched. Does not own memory; the
    caller must keep the backing storage alive for the lifetime of the match.
    """

    def __init__(
        out self,
        group_id: Int,
        start_idx: Int,
        end_idx: Int,
        text: ImmSlice,
    ):
        self.group_id = group_id
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.text = text

    def get_match_text(self) -> ImmSlice:
        """Returns the text that was matched."""
        return self.text[byte = self.start_idx : self.end_idx]


struct MatchList(Copyable, Movable, Sized):
    """Smart container for regex matches with lazy allocation and optimal reservation.

    This struct provides zero allocation until the first match is added, then
    reserves a small amount of capacity to avoid malloc churn for common cases.
    Provides List-compatible interface for easy integration with existing code.
    """

    comptime DEFAULT_RESERVE_SIZE = 8
    """Default number of matches to reserve on first allocation."""

    var _data: UnsafePointer[Match, MutAnyOrigin]
    """Internal list storing the matches."""
    var _len: Int
    var _capacity: Int

    def __init__(
        out self,
        capacity: Int = 0,
    ):
        """Initialize empty Matches container."""
        self._data = UnsafePointer[Match, MutAnyOrigin]()
        self._capacity = capacity
        self._len = 0
        if capacity > 0:
            self._realloc(capacity)

    @always_inline
    def __copyinit__(
        out self,
        copy: Self,
    ):
        """Copy constructor."""
        self._data = UnsafePointer[Match, MutAnyOrigin]()
        self._len = 0
        self._capacity = 0
        if copy._len > 0:
            self._realloc(copy._capacity)
            memcpy(dest=self._data, src=copy._data, count=copy._len)
            self._len = copy._len
        # # Comment when debug is done
        # var call_location = __call_location()
        # print("Copying MatchList", call_location)

    def __del__(deinit self):
        """Destructor to free allocated memory."""
        if self._data:
            self._data.free()

    @always_inline
    def __len__(self) -> Int:
        """Return the number of matches."""
        return self._len

    def __getitem__[I: Indexer](ref self, idx: I) -> ref[self] Match:
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
    def _realloc(mut self, new_capacity: Int):
        var new_data = alloc[Match](new_capacity)

        memcpy(dest=new_data, src=self._data, count=len(self))

        if self._data:
            self._data.free()
        self._data = new_data
        self._capacity = new_capacity

    def append(
        mut self,
        m: Match,
    ):
        """Add a match to the container, reserving capacity on first use."""
        if not self._data or self._len >= self._capacity:
            var new_capacity = max(
                self._capacity * 2, self.DEFAULT_RESERVE_SIZE
            )
            self._realloc(new_capacity)
        self._data[self._len] = m
        self._len += 1

    def clear(
        mut self,
    ):
        """Remove all matches but keep allocated capacity."""
        self._len = 0
