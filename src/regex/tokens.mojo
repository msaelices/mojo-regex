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
        elif type == Self.DASH:
            char = '-'
        elif type == Self.ORTOKEN:
            char = '|'
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


@always_inline
fn StartToken(char: String) -> Token[type=Token.START]:
    """Token of match start."""
    return Token[Token.START](char=char)


@always_inline
fn Start() -> Token[type=Token.START]:
    """Token using '^' to match start."""
    return Token[Token.START]()


@always_inline
fn EndToken(char: String) -> Token[type=Token.END]:
    """Token of match end."""
    return Token[Token.END](char=char)


@always_inline
fn End() -> Token[type=Token.END]:
    """Token using '$' to match end."""
    return Token[Token.END]()


@always_inline
fn Escape() -> Token[type=Token.ESCAPE]:
    """Token of the escape character."""
    return Token[Token.ESCAPE]()


@always_inline
fn Comma() -> Token[type=Token.COMMA]:
    """Token of a comma."""
    return Token[Token.COMMA]()


@always_inline
fn LeftParenthesis() -> Token[type=Token.LEFTPARENTHESIS]:
    """Left parenthesis token."""
    return Token[Token.LEFTPARENTHESIS]()


@always_inline
fn RightParenthesis() -> Token[type=Token.RIGHTPARENTHESIS]:
    """Right parenthesis token."""
    return Token[Token.RIGHTPARENTHESIS]()


@always_inline
fn LeftCurlyBrace() -> Token[type=Token.LEFTCURLYBRACE]:
    """Left curly brace token."""
    return Token[Token.LEFTCURLYBRACE]()


@always_inline
fn RightCurlyBrace() -> Token[type=Token.RIGHTCURLYBRACE]:
    """Right curly brace token."""
    return Token[Token.RIGHTCURLYBRACE]()


@always_inline
fn LeftBracket() -> Token[type=Token.LEFTBRACKET]:
    """Left bracket token."""
    return Token[Token.LEFTBRACKET]()


@always_inline
fn RightBracket() -> Token[type=Token.RIGHTBRACKET]:
    """Right bracket token."""
    return Token[Token.RIGHTBRACKET]()


@always_inline
fn ZeroOrMore(char: String) -> Token[type=Token.ZEROORMORE]:
    """Quantifier 'zero or more' token."""
    return Token[Token.ZEROORMORE](char=char)


@always_inline
fn OneOrMore(char: String) -> Token[type=Token.ONEORMORE]:
    """Quantifier 'one or more' token."""
    return Token[Token.ONEORMORE](char=char)


@always_inline
fn ZeroOrOne(char: String) -> Token[type=Token.ZEROORONE]:
    """Quantifier 'zero or one' token."""
    return Token[Token.ZEROORONE](char=char)


@always_inline
fn Plus() -> Token[type=Token.PLUS]:
    """Quantifier 'one or more' token using character '+'."""
    return Token[Token.PLUS]()


@always_inline
fn QuestionMark() -> Token[type=Token.QUESTIONMARK]:
    """Quantifier 'zero or one' token using character '?'."""
    return Token[Token.QUESTIONMARK]()


@always_inline
fn OrToken(char: String) -> Token[type=Token.ORTOKEN]:
    """Token of the or."""
    return Token[Token.ORTOKEN](char=char)


@always_inline
fn VerticalBar() -> Token[type=Token.VERTICALBAR]:
    """Token of the or using '|'."""
    return Token[Token.VERTICALBAR]()


@always_inline
fn Circumflex() -> Token[type=Token.CIRCUMFLEX]:
    """Token of the negation using '^'."""
    return Token[Token.CIRCUMFLEX]()


@always_inline
fn Dash() -> Token[type=Token.DASH]:
    """Token of the dash '-'."""
    return Token[Token.DASH]()
