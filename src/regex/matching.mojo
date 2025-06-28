struct Match(Copyable, Movable):
    """Contains the information of a match in a regular expression."""

    var group_id: Int
    var start_idx: Int
    var end_idx: Int
    var match_text: String
    var name: String

    fn __init__(
        out self,
        group_id: Int,
        start_idx: Int,
        end_idx: Int,
        text: String,
        name: String,
    ):
        self.group_id = group_id
        self.name: String = name
        self.start_idx = start_idx
        self.end_idx = end_idx
        self.match_text = text[start_idx:end_idx]
