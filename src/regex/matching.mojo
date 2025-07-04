from memory import UnsafePointer


struct Match(Copyable, Movable):
    """Contains the information of a match in a regular expression."""

    var group_id: Int
    var start_idx: Int
    var end_idx: Int
    var text_ptr: UnsafePointer[String, mut=False]

    fn __init__(
        out self,
        group_id: Int,
        start_idx: Int,
        end_idx: Int,
        text: String,
    ):
        print(
            "Match.__init__ called with group_id:",
            group_id,
            "start_idx:",
            start_idx,
            "end_idx:",
            end_idx,
        )
        self.group_id = group_id
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.text_ptr = UnsafePointer(to=text)

    fn get_match_text(self) -> StringSlice[ImmutableAnyOrigin]:
        """Returns the text that was matched."""
        return self.text_ptr[].as_string_slice()[self.start_idx : self.end_idx]
