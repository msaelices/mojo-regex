struct Token(Copyable, EqualityComparable, ImplicitlyBoolable, Movable):
    """Token struct."""

    var type: Int
    var char: String

    alias ELEMENT = 0
    """Token that are not associated to special meaning."""
    alias WILDCARD = 1
    """Token using "." as wildcard."""
    alias SPACE = 2
    """Token of a space."""
    alias DIGIT = 3
    """Token of a digit."""
    alias START = 4
    """Token of match start."""
    alias END = 5
    """Token of match end."""
    alias ESCAPE = 6
    """Token of the escape character."""
    alias COMMA = 7
    """Token of a comma."""
    alias PARENTHESIS = 8
    """Token of a parenthesis."""
    alias LEFTPARENTHESIS = 9
    """Left parenthesis token."""
    alias RIGHTPARENTHESIS = 10
    """Right parenthesis token."""
    alias CURLYBRACE = 11
    """Curly brace token."""
    alias LEFTCURLYBRACE = 12
    """Left curly brace token."""
    alias RIGHTCURLYBRACE = 13
    """Right curly brace token."""
    alias BRACKET = 14
    """Brackets token."""
    alias LEFTBRACKET = 15
    """Left bracket token."""
    alias RIGHTBRACKET = 16
    """Right bracket token."""
    alias QUANTIFIER = 17
    """Quantifier token."""
    alias ZEROORMORE = 18
    """Quantifier 'zero or more' token."""
    alias ONEORMORE = 19
    """Quantifier 'one or more' token."""
    alias ZEROORONE = 20
    """Quantifier 'zero or one' token."""
    alias ASTERISK = 21
    """Quantifier 'zero or more' token using character '*'."""
    alias PLUS = 22
    """Quantifier 'one or more' token using character '+'."""
    alias QUESTIONMARK = 23
    """Quantifier 'zero or one' token using character '?'."""
    alias ORTOKEN = 24
    """Token of the or."""
    alias VERTICALBAR = 25
    """Token of the or using '|'."""
    alias NOTTOKEN = 26
    """Token of the negation."""
    alias CIRCUMFLEX = 27
    """Token of the negation using '^'."""
    alias DASH = 28
    """Token of the dash '-'."""

    fn __init__(out self, type: Int):
        var char: String
        if type == Self.WILDCARD:
            char = "."
        elif type == Self.START:
            char = "^"
        elif type == Self.END:
            char = "$"
        elif type == Self.ESCAPE:
            char = "\\"
        elif type == Self.COMMA:
            char = ","
        elif type == Self.LEFTPARENTHESIS:
            char = "("
        elif type == Self.RIGHTPARENTHESIS:
            char = ")"
        elif type == Self.LEFTCURLYBRACE:
            char = "{"
        elif type == Self.RIGHTCURLYBRACE:
            char = "}"
        elif type == Self.LEFTBRACKET:
            char = "["
        elif type == Self.RIGHTBRACKET:
            char = "]"
        elif type == Self.ASTERISK:
            char = "*"
        elif type == Self.PLUS:
            char = "+"
        elif type == Self.QUESTIONMARK:
            char = "?"
        elif type == Self.VERTICALBAR:
            char = "|"
        elif type == Self.CIRCUMFLEX:
            char = "^"
        elif type == Self.DASH:
            char = "-"
        elif type == Self.ORTOKEN:
            char = "|"
        else:
            char = ""
        self.type = type
        self.char = char

    fn __init__(out self, type: Int, char: String):
        """Initialize a Token with a specific type and character.
        Args:
            type: The type of the token.
            char: The character associated with the token.
        """
        self.type = type
        self.char = char

    fn __eq__(self, other: Self) -> Bool:
        """Equality operator for Token."""
        return self.type == other.type and self.char == other.char

    fn __ne__(self, other: Self) -> Bool:
        """Inequality operator for Token."""
        return not self.__eq__(other)

    fn __bool__(self: Self) -> Bool:
        """Boolean conversion for Token."""
        return self.type != Self.ELEMENT or self.char != ""

    fn __as_bool__(self) -> Bool:
        """Get the boolean representation of the value.

        Returns:
            The boolean representation of the value.
        """
        return self.__bool__()


@always_inline
fn Asterisk() -> Token:
    """Quantifier 'zero or more' token using character '*'."""
    return Token(Token.ASTERISK)


@always_inline
fn Wildcard() -> Token:
    """Token using '.' as wildcard."""
    return Token(Token.WILDCARD)


@always_inline
fn NotToken(char: String) -> Token:
    """Token of the negation."""
    return Token(Token.NOTTOKEN, char=char)


@always_inline
fn StartToken(char: String) -> Token:
    """Token of match start."""
    return Token(Token.START, char=char)


@always_inline
fn Start() -> Token:
    """Token using '^' to match start."""
    return Token(Token.START)


@always_inline
fn EndToken(char: String) -> Token:
    """Token of match end."""
    return Token(Token.END, char=char)


@always_inline
fn End() -> Token:
    """Token using '$' to match end."""
    return Token(Token.END)


@always_inline
fn Escape() -> Token:
    """Token of the escape character."""
    return Token(Token.ESCAPE)


@always_inline
fn Comma() -> Token:
    """Token of a comma."""
    return Token(Token.COMMA)


@always_inline
fn LeftParenthesis() -> Token:
    """Left parenthesis token."""
    return Token(Token.LEFTPARENTHESIS)


@always_inline
fn RightParenthesis() -> Token:
    """Right parenthesis token."""
    return Token(Token.RIGHTPARENTHESIS)


@always_inline
fn LeftCurlyBrace() -> Token:
    """Left curly brace token."""
    return Token(Token.LEFTCURLYBRACE)


@always_inline
fn RightCurlyBrace() -> Token:
    """Right curly brace token."""
    return Token(Token.RIGHTCURLYBRACE)


@always_inline
fn LeftBracket() -> Token:
    """Left bracket token."""
    return Token(Token.LEFTBRACKET)


@always_inline
fn RightBracket() -> Token:
    """Right bracket token."""
    return Token(Token.RIGHTBRACKET)


@always_inline
fn ZeroOrMore(char: String) -> Token:
    """Quantifier 'zero or more' token."""
    return Token(type=Token.ZEROORMORE, char=char)


@always_inline
fn OneOrMore(char: String) -> Token:
    """Quantifier 'one or more' token."""
    return Token(type=Token.ONEORMORE, char=char)


@always_inline
fn ZeroOrOne(char: String) -> Token:
    """Quantifier 'zero or one' token."""
    return Token(type=Token.ZEROORONE, char=char)


@always_inline
fn Plus() -> Token:
    """Quantifier 'one or more' token using character '+'."""
    return Token(Token.PLUS)


@always_inline
fn QuestionMark() -> Token:
    """Quantifier 'zero or one' token using character '?'."""
    return Token(Token.QUESTIONMARK)


@always_inline
fn OrToken(char: String) -> Token:
    """Token of the or."""
    return Token(type=Token.ORTOKEN, char=char)


@always_inline
fn VerticalBar() -> Token:
    """Token of the or using '|'."""
    return Token(Token.VERTICALBAR)


@always_inline
fn Circumflex() -> Token:
    """Token of the negation using '^'."""
    return Token(Token.CIRCUMFLEX)


@always_inline
fn Dash() -> Token:
    """Token of the dash '-'."""
    return Token(Token.DASH)


@always_inline
fn ElementToken(char: String) -> Token:
    """Token that are not associated to special meaning."""
    return Token(type=Token.ELEMENT, char=char)


@always_inline
fn SpaceToken(char: String) -> Token:
    """Token of a space."""
    return Token(type=Token.SPACE, char=char)


@always_inline
fn DigitToken(char: String) -> Token:
    """Token of a digit."""
    return Token(type=Token.DIGIT, char=char)
