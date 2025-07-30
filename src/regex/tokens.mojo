alias DIGITS: String = "0123456789"
alias CHAR_TAB = ord("t")
alias CHAR_SPACE = ord("s")
alias CHAR_DIGIT = ord("d")
alias CHAR_COLON = ord(":")
alias CHAR_DOT = ord(".")
alias CHAR_SLASH = ord("\\")
alias CHAR_LEFT_PAREN = ord("(")
alias CHAR_RIGHT_PAREN = ord(")")
alias CHAR_LEFT_BRACKET = ord("[")
alias CHAR_RIGHT_BRACKET = ord("]")
alias CHAR_LEFT_CURLY = ord("{")
alias CHAR_RIGHT_CURLY = ord("}")
alias CHAR_CIRCUMFLEX = ord("^")
alias CHAR_VERTICAL_BAR = ord("|")
alias CHAR_DASH = ord("-")
alias CHAR_COMMA = ord(",")
alias CHAR_ASTERISK = ord("*")
alias CHAR_PLUS = ord("+")
alias CHAR_QUESTION_MARK = ord("?")
alias CHAR_END = ord("$")
alias CHAR_ZERO = ord("0")
alias CHAR_NINE = ord("9")
alias CHAR_A = ord("a")
alias CHAR_Z = ord("z")
alias CHAR_A_UPPER = ord("A")
alias CHAR_Z_UPPER = ord("Z")


struct Token(Copyable, EqualityComparable, ImplicitlyBoolable, Movable):
    """Token struct."""

    var type: Int
    var char: Int
    var start_pos: Int  # Position in original pattern where this token starts

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
        var char: Int
        if type == Self.WILDCARD:
            char = CHAR_DOT
        elif type == Self.START:
            char = CHAR_CIRCUMFLEX
        elif type == Self.END:
            char = CHAR_END
        elif type == Self.ESCAPE:
            char = CHAR_SLASH
        elif type == Self.COMMA:
            char = CHAR_COMMA
        elif type == Self.LEFTPARENTHESIS:
            char = CHAR_LEFT_PAREN
        elif type == Self.RIGHTPARENTHESIS:
            char = CHAR_RIGHT_PAREN
        elif type == Self.LEFTCURLYBRACE:
            char = CHAR_LEFT_CURLY
        elif type == Self.RIGHTCURLYBRACE:
            char = CHAR_RIGHT_CURLY
        elif type == Self.LEFTBRACKET:
            char = CHAR_LEFT_BRACKET
        elif type == Self.RIGHTBRACKET:
            char = CHAR_RIGHT_BRACKET
        elif type == Self.ASTERISK:
            char = CHAR_ASTERISK
        elif type == Self.PLUS:
            char = CHAR_PLUS
        elif type == Self.QUESTIONMARK:
            char = CHAR_QUESTION_MARK
        elif type == Self.VERTICALBAR:
            char = CHAR_VERTICAL_BAR
        elif type == Self.CIRCUMFLEX:
            char = CHAR_CIRCUMFLEX
        elif type == Self.DASH:
            char = CHAR_DASH
        elif type == Self.ORTOKEN:
            char = CHAR_VERTICAL_BAR
        else:
            char = 0  # Null codepoint
        self.type = type
        self.char = char
        self.start_pos = 0  # Default to 0, will be set by lexer

    fn __init__(out self, type: Int, char: Int):
        """Initialize a Token with a specific type and character.
        Args:
            type: The type of the token.
            char: The character associated with the token.
        """
        self.type = type
        self.char = char
        self.start_pos = 0  # Default to 0, will be set by lexer

    fn __init__(out self, type: Int, char: Int, start_pos: Int):
        """Initialize a Token with a specific type, character and position.
        Args:
            type: The type of the token.
            char: The character associated with the token.
            start_pos: Position in original pattern where this token starts.
        """
        self.type = type
        self.char = char
        self.start_pos = start_pos

    fn __eq__(self, other: Self) -> Bool:
        """Equality operator for Token."""
        return self.type == other.type and self.char == other.char

    fn __ne__(self, other: Self) -> Bool:
        """Inequality operator for Token."""
        return not self.__eq__(other)

    fn __bool__(self: Self) -> Bool:
        """Boolean conversion for Token."""
        return self.type != Self.ELEMENT or self.char != Int(0)

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
fn NotToken(char: Int) -> Token:
    """Token of the negation."""
    return Token(Token.NOTTOKEN, char=char)


@always_inline
fn StartToken(char: Int) -> Token:
    """Token of match start."""
    return Token(Token.START, char=char)


@always_inline
fn Start() -> Token:
    """Token using '^' to match start."""
    return Token(Token.START)


@always_inline
fn EndToken(char: Int) -> Token:
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
fn ZeroOrMore(char: Int) -> Token:
    """Quantifier 'zero or more' token."""
    return Token(type=Token.ZEROORMORE, char=char)


@always_inline
fn OneOrMore(char: Int) -> Token:
    """Quantifier 'one or more' token."""
    return Token(type=Token.ONEORMORE, char=char)


@always_inline
fn ZeroOrOne(char: Int) -> Token:
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
fn OrToken(char: Int) -> Token:
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
fn ElementToken(char: Int) -> Token:
    """Token that are not associated to special meaning."""
    return Token(type=Token.ELEMENT, char=char)


@always_inline
fn SpaceToken(char: Int) -> Token:
    """Token of a space."""
    return Token(type=Token.SPACE, char=char)


@always_inline
fn DigitToken(char: Int) -> Token:
    """Token of a digit."""
    return Token(type=Token.DIGIT, char=char)
