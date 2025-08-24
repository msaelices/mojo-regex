from memory import UnsafePointer
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

    var _list: List[Match, hint_trivial_type=True]
    """Internal list storing the matches."""
    var _allocated: Bool
    """Track whether we've done the initial smart allocation."""

    fn __init__(
        out self,
    ):
        """Initialize empty Matches container."""
        self._list = List[Match, hint_trivial_type=True]()
        self._allocated = False

    @always_inline
    fn __copyinit__(
        out self,
        other: Self,
    ):
        """Copy constructor."""
        self._list = other._list
        self._allocated = other._allocated
        # # Comment when debug is done
        # var call_location = __call_location()
        # print("Copying MatchList", call_location)

    fn __moveinit__(
        out self,
        owned other: Self,
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

    fn __len__(self) -> Int:
        """Return the number of matches."""
        return len(self._list)

    fn __getitem__[I: Indexer](ref self, idx: I) -> ref [self._list] Match:
        """Gets the list element at the given index.

        Args:
            idx: The index of the element.

        Parameters:
            I: A type that can be used as an index.

        Returns:
            A reference to the match at the given index.
        """
        return self._list[idx]

    fn clear(
        mut self,
    ):
        """Remove all matches but keep allocated capacity."""
        self._list.clear()
        # Keep _allocated = True to maintain reserved capacity
