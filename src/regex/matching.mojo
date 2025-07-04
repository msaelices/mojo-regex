from memory import UnsafePointer


struct Match(Copyable, Movable):
    """Contains the information of a match in a regular expression."""

    var group_id: Int
    var start_idx: Int
    var end_idx: Int
    var text_ptr: UnsafePointer[String, mut=False]
    var name: String

    fn __init__(
        out self,
        group_id: Int,
        start_idx: Int,
        end_idx: Int,
        text: String,
        owned name: String,
    ):
        self.group_id = group_id
        self.name: String = name^
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.text_ptr = UnsafePointer(to=text)

    fn get_match_text(self) -> StringSlice[ImmutableAnyOrigin]:
        """Returns the text that was matched."""
        return self.text_ptr[].as_string_slice()[self.start_idx : self.end_idx]
