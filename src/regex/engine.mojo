trait Engine(Copyable, Movable):
    fn match_first(self, text: String, start: Int) -> Optional[Match]:
        """Execute DFA matching against input text.

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
