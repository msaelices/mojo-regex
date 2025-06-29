trait Engine(Copyable, Movable):
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

    fn match_all(self, text: String) -> List[Match]:
        """Find all non-overlapping matches using DFA.

        Args:
            text: Input text to search.

        Returns:
            List of all matches found.
        """
        ...
