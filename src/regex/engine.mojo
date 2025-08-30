from regex.matching import Match, MatchList


trait Engine(Copyable, Movable):
    # Commented out because Mojo currently is not compiling, throwing error:
    # cannot return 'self's origin, because it might expand to a @register_passable type
    # fn get_pattern(self) -> Span[Byte, __origin_of(self)]:
    #     """Returns a contiguous slice of the pattern bytes.
    #
    #     Returns:
    #         A contiguous slice pointing to the bytes owned by the pattern.
    #     """
    #     ...

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Execute DFA matching against input text. To be Python compatible,
        it will not match if the start position is not at the beginning of a line.

        Args:
            text: Input text to match against.
            start: Starting position in text.

        Returns:
            Optional Match if pattern matches, None otherwise.
        """
        ...

    fn match_all(self, text: String) -> MatchList:
        """Find all non-overlapping matches using Engine.

        Args:
            text: Input text to search.

        Returns:
            MatchList container with all matches found.
        """
        ...
