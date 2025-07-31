from memory import UnsafePointer


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
