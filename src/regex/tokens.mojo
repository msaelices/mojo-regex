struct Token[type: Int](Copyable, Movable, EqualityComparable, ImplicitlyBoolable):
    """Token struct."""
    var char: String

    alias ELEMENT = Int(0)
    """Token that are not associated to special meaning."""
    alias WILDCARD = Int(1)
    """Token using "." as wildcard."""
    alias SPACE = Int(2)
    """Token of a space."""
    alias START = Int(3)
    """Token of match start."""
    alias END = Int(4)
    """Token of match end."""
    alias ESCAPE = Int(5)
    """Token of the escape character."""
    alias COMMA = Int(6)
    """Token of a comma."""
    alias PARENTHESIS = Int(7)
    """Token of a parenthesis."""
    alias LEFTPARENTHESIS = Int(8)
    """Left parenthesis token."""
    alias RIGHTPARENTHESIS = Int(9)
    """Right parenthesis token."""
    alias CURLYBRACE = Int(10)
    """Curly brace token."""
    alias LEFTCURLYBRACE = Int(11)
    """Left curly brace token."""
    alias RIGHTCURLYBRACE = Int(12)
    """Right curly brace token."""
    alias BRACKET = Int(13)
    """Brackets token."""
    alias LEFTBRACKET = Int(14)
    """Left bracket token."""
    alias RIGHTBRACKET = Int(15)
    """Right bracket token."""
    alias QUANTIFIER = Int(16)
    """Quantifier token."""
    alias ZEROORMORE = Int(17)
    """Quantifier 'zero or more' token."""
    alias ONEORMORE = Int(18)
    """Quantifier 'one or more' token."""
    alias ZEROORONE = Int(19)
    """Quantifier 'zero or one' token."""
    alias ASTERISK = Int(20)
    """Quantifier 'zero or more' token using character '*'."""
    alias PLUS = Int(21)
    """Quantifier 'one or more' token using character '+'."""
    alias QUESTIONMARK = Int(22)
    """Quantifier 'zero or one' token using character '?'."""
    alias ORTOKEN = Int(23)
    """Token of the or."""
    alias VERTICALBAR = Int(24)
    """Token of the or using '|'."""
    alias NOTTOKEN = Int(25)
    """Token of the negation."""
    alias CIRCUMFLEX = Int(26)
    """Token of the negation using '^'."""
    alias DASH = Int(27)
    """Token of the dash '-'."""

    fn __init__(out self):
        var char: String
        if type == Self.WILDCARD:
            char = '.'
        elif type == Self.START:
            char = '^'
        elif type == Self.END:
            char = '$'
        elif type == Self.ESCAPE:
            char = '\\'
        elif type == Self.COMMA:
            char = ','
        elif type == Self.LEFTPARENTHESIS:
            char = '('
        elif type == Self.RIGHTPARENTHESIS:
            char = ')'
        elif type == Self.LEFTCURLYBRACE:
            char = '{'
        elif type == Self.RIGHTCURLYBRACE:
            char = '}'
        elif type == Self.LEFTBRACKET:
            char = '['
        elif type == Self.RIGHTBRACKET:
            char = ']'
        elif type == Self.ASTERISK:
            char = '*'
        elif type == Self.PLUS:
            char = '+'
        elif type == Self.QUESTIONMARK:
            char = '?'
        elif type == Self.VERTICALBAR:
            char = '|'
        elif type == Self.CIRCUMFLEX:
            char = '^'
        else:
            char = ''
        self.char = char 

    fn __init__(out self, char: String):
        self.char = char 

    fn __eq__(self, other: Self) -> Bool:
        """Equality operator for Token."""
        return self.char == other.char

    fn __ne__(self, other: Self) -> Bool:
        """Inequality operator for Token."""
        return not self.__eq__(other)

    fn __bool__(self: Self) -> Bool:
        """Boolean conversion for Token."""
        return self.type != Self.ELEMENT or self.char != ''

    fn __as_bool__(self) -> Bool:
        """Get the boolean representation of the value.

        Returns:
            The boolean representation of the value.
        """
        return self.__bool__()

@always_inline
fn Asterisk() -> Token[type=Token.ASTERISK]:
    """Quantifier 'zero or more' token using character '*'."""
    return Token[Token.ASTERISK]()


@always_inline
fn Wildcard() -> Token[type=Token.WILDCARD]:
    """Token using '.' as wildcard."""
    return Token[Token.WILDCARD]()


@always_inline
fn NotToken(char: String) -> Token[type=Token.NOTTOKEN]:
    """Token of the negation."""
    return Token[Token.NOTTOKEN](char=char)

