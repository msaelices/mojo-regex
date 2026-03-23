from regex.aliases import (
    DIGITS,
    CHAR_LIT_TAB,
    CHAR_LIT_SPACE,
    CHAR_DIGIT,
    CHAR_WORD,
    CHAR_COLON,
    CHAR_DOT,
    CHAR_SLASH,
    CHAR_LEFT_PAREN,
    CHAR_RIGHT_PAREN,
    CHAR_LEFT_BRACKET,
    CHAR_RIGHT_BRACKET,
    CHAR_LEFT_CURLY,
    CHAR_RIGHT_CURLY,
    CHAR_CIRCUMFLEX,
    CHAR_VERTICAL_BAR,
    CHAR_DASH,
    CHAR_COMMA,
    CHAR_ASTERISK,
    CHAR_PLUS,
    CHAR_QUESTION_MARK,
    CHAR_END,
    CHAR_ZERO,
    CHAR_NINE,
    CHAR_A,
    CHAR_Z,
    CHAR_A_UPPER,
    CHAR_Z_UPPER,
    CHAR_NEWLINE,
)


struct Token(Boolable, Equatable, ImplicitlyCopyable, Movable):
    """Token struct."""

    var type: Int
    """Type of the token (e.g., ELEMENT, WILDCARD, DIGIT, etc.)."""
    var char: Int
    """The character code associated with this token."""
    var start_pos: Int
    """Position in original pattern where this token starts."""

    comptime ELEMENT = 0
    """Token that are not associated to special meaning."""
    comptime WILDCARD = 1
    """Token using "." as wildcard."""
    comptime SPACE = 2
    """Token of a space."""
    comptime DIGIT = 3
    """Token of a digit."""
    comptime WORD = 4
    """Token of a word character."""
    comptime START = 5
    """Token of match start."""
    comptime END = 6
    """Token of match end."""
    comptime ESCAPE = 7
    """Token of the escape character."""
    comptime COMMA = 8
    """Token of a comma."""
    comptime PARENTHESIS = 9
    """Token of a parenthesis."""
    comptime LEFTPARENTHESIS = 10
    """Left parenthesis token."""
    comptime RIGHTPARENTHESIS = 11
    """Right parenthesis token."""
    comptime CURLYBRACE = 12
    """Curly brace token."""
    comptime LEFTCURLYBRACE = 13
    """Left curly brace token."""
    comptime RIGHTCURLYBRACE = 14
    """Right curly brace token."""
    comptime BRACKET = 15
    """Brackets token."""
    comptime LEFTBRACKET = 16
    """Left bracket token."""
    comptime RIGHTBRACKET = 17
    """Right bracket token."""
    comptime QUANTIFIER = 18
    """Quantifier token."""
    comptime ZEROORMORE = 19
    """Quantifier 'zero or more' token."""
    comptime ONEORMORE = 20
    """Quantifier 'one or more' token."""
    comptime ZEROORONE = 21
    """Quantifier 'zero or one' token."""
    comptime ASTERISK = 22
    """Quantifier 'zero or more' token using character '*'."""
    comptime PLUS = 23
    """Quantifier 'one or more' token using character '+'."""
    comptime QUESTIONMARK = 24
    """Quantifier 'zero or one' token using character '?'."""
    comptime ORTOKEN = 25
    """Token of the or."""
    comptime VERTICALBAR = 26
    """Token of the or using '|'."""
    comptime NOTTOKEN = 27
    """Token of the negation."""
    comptime CIRCUMFLEX = 28
    """Token of the negation using '^'."""
    comptime DASH = 29
    """Token of the dash '-'."""

    def __init__(out self, type: Int):
        var char: Int
        if type == Self.WILDCARD:
            char = CHAR_DOT
        elif type == Self.WORD:
            char = CHAR_WORD
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

    def __init__(out self, type: Int, char: Int):
        """Initialize a Token with a specific type and character.
        Args:
            type: The type of the token.
            char: The character associated with the token.
        """
        self.type = type
        self.char = char
        self.start_pos = 0  # Default to 0, will be set by lexer

    def __init__(out self, type: Int, char: Int, start_pos: Int):
        """Initialize a Token with a specific type, character and position.
        Args:
            type: The type of the token.
            char: The character associated with the token.
            start_pos: Position in original pattern where this token starts.
        """
        self.type = type
        self.char = char
        self.start_pos = start_pos

    def __eq__(self, other: Self) -> Bool:
        """Equality operator for Token."""
        return self.type == other.type and self.char == other.char

    def __ne__(self, other: Self) -> Bool:
        """Inequality operator for Token."""
        return not self.__eq__(other)

    def __bool__(self: Self) -> Bool:
        """Boolean conversion for Token."""
        return self.type != Self.ELEMENT or self.char != Int(0)

    def __as_bool__(self) -> Bool:
        """Get the boolean representation of the value.

        Returns:
            The boolean representation of the value.
        """
        return self.__bool__()


@always_inline
def Asterisk() -> Token:
    """Quantifier 'zero or more' token using character '*'."""
    return Token(Token.ASTERISK)


@always_inline
def Wildcard() -> Token:
    """Token using '.' as wildcard."""
    return Token(Token.WILDCARD)


@always_inline
def NotToken(char: Int) -> Token:
    """Token of the negation."""
    return Token(Token.NOTTOKEN, char=char)


@always_inline
def StartToken(char: Int) -> Token:
    """Token of match start."""
    return Token(Token.START, char=char)


@always_inline
def Start() -> Token:
    """Token using '^' to match start."""
    return Token(Token.START)


@always_inline
def EndToken(char: Int) -> Token:
    """Token of match end."""
    return Token(Token.END, char=char)


@always_inline
def End() -> Token:
    """Token using '$' to match end."""
    return Token(Token.END)


@always_inline
def Escape() -> Token:
    """Token of the escape character."""
    return Token(Token.ESCAPE)


@always_inline
def Comma() -> Token:
    """Token of a comma."""
    return Token(Token.COMMA)


@always_inline
def LeftParenthesis() -> Token:
    """Left parenthesis token."""
    return Token(Token.LEFTPARENTHESIS)


@always_inline
def RightParenthesis() -> Token:
    """Right parenthesis token."""
    return Token(Token.RIGHTPARENTHESIS)


@always_inline
def LeftCurlyBrace() -> Token:
    """Left curly brace token."""
    return Token(Token.LEFTCURLYBRACE)


@always_inline
def RightCurlyBrace() -> Token:
    """Right curly brace token."""
    return Token(Token.RIGHTCURLYBRACE)


@always_inline
def LeftBracket() -> Token:
    """Left bracket token."""
    return Token(Token.LEFTBRACKET)


@always_inline
def RightBracket() -> Token:
    """Right bracket token."""
    return Token(Token.RIGHTBRACKET)


@always_inline
def ZeroOrMore(char: Int) -> Token:
    """Quantifier 'zero or more' token."""
    return Token(type=Token.ZEROORMORE, char=char)


@always_inline
def OneOrMore(char: Int) -> Token:
    """Quantifier 'one or more' token."""
    return Token(type=Token.ONEORMORE, char=char)


@always_inline
def ZeroOrOne(char: Int) -> Token:
    """Quantifier 'zero or one' token."""
    return Token(type=Token.ZEROORONE, char=char)


@always_inline
def Plus() -> Token:
    """Quantifier 'one or more' token using character '+'."""
    return Token(Token.PLUS)


@always_inline
def QuestionMark() -> Token:
    """Quantifier 'zero or one' token using character '?'."""
    return Token(Token.QUESTIONMARK)


@always_inline
def OrToken(char: Int) -> Token:
    """Token of the or."""
    return Token(type=Token.ORTOKEN, char=char)


@always_inline
def VerticalBar() -> Token:
    """Token of the or using '|'."""
    return Token(Token.VERTICALBAR)


@always_inline
def Circumflex() -> Token:
    """Token of the negation using '^'."""
    return Token(Token.CIRCUMFLEX)


@always_inline
def Dash() -> Token:
    """Token of the dash '-'."""
    return Token(Token.DASH)


@always_inline
def ElementToken(char: Int) -> Token:
    """Token that are not associated to special meaning."""
    return Token(type=Token.ELEMENT, char=char)


@always_inline
def SpaceToken(char: Int) -> Token:
    """Token of a space."""
    return Token(type=Token.SPACE, char=char)


@always_inline
def DigitToken(char: Int) -> Token:
    """Token of a digit."""
    return Token(type=Token.DIGIT, char=char)


@always_inline
def WordToken(char: Int) -> Token:
    """Token of a word character."""
    return Token(type=Token.WORD, char=char)
