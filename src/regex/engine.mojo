from regex.matching import Match, MatchList


trait Engine(Copyable, Movable):
    fn get_pattern[o: ImmutableOrigin](ref [o]self) -> Span[Byte, o]:
        """Returns a contiguous slice of the pattern bytes.

        Returns:
            A contiguous slice pointing to the bytes owned by the pattern.
        """
        ...

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
