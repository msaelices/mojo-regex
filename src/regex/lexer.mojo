from regex.aliases import (
    CHAR_ASTERISK,
    CHAR_CIRCUMFLEX,
    CHAR_COMMA,
    CHAR_DASH,
    CHAR_DIGIT,
    CHAR_DOT,
    CHAR_END,
    CHAR_LEFT_BRACKET,
    CHAR_LEFT_CURLY,
    CHAR_LEFT_PAREN,
    CHAR_NINE,
    CHAR_PLUS,
    CHAR_QUESTION_MARK,
    CHAR_RIGHT_BRACKET,
    CHAR_RIGHT_CURLY,
    CHAR_RIGHT_PAREN,
    CHAR_SLASH,
    CHAR_SPACE,
    CHAR_TAB,
    CHAR_VERTICAL_BAR,
    CHAR_ZERO,
    DIGITS,
)
from regex.tokens import (
    Token,
    Wildcard,
    NotToken,
    StartToken,
    Start,
    EndToken,
    End,
    Escape,
    Comma,
    LeftParenthesis,
    RightParenthesis,
    LeftBracket,
    RightBracket,
    LeftCurlyBrace,
    RightCurlyBrace,
    Dash,
    Circumflex,
    QuestionMark,
    Asterisk,
    Plus,
    VerticalBar,
    ElementToken,
    SpaceToken,
    DigitToken,
)


@always_inline
fn _is_digit(ch: Int) -> Bool:
    return ch >= CHAR_ZERO and ch <= CHAR_NINE


fn scan(regex: String) raises -> List[Token]:
    """
    Scans the input regex string and returns a list of tokens.

    Args:
        regex: The regular expression string to scan.
    Returns:
        A list of tokens parsed from the regex string.
    """
    var tokens = List[Token](capacity=len(regex))
    var i = 0
    var escape_found = False
    var regex_bytes = regex.as_bytes()

    while i < len(regex):
        var ch_codepoint = Int(regex_bytes[i])

        if escape_found:
            if ch_codepoint == CHAR_TAB:
                var token = ElementToken(char=ord(StringSlice("\t")))
                token.start_pos = i - 1  # -1 because escape char is at i-1
                tokens.append(token)
            elif ch_codepoint == CHAR_SPACE:
                var token = SpaceToken(char=ch_codepoint)
                token.start_pos = i - 1  # -1 because escape char is at i-1
                tokens.append(token)
            elif ch_codepoint == CHAR_DIGIT:
                var token = DigitToken(char=ch_codepoint)
                token.start_pos = i - 1  # -1 because escape char is at i-1
                tokens.append(token)
            else:
                var token = ElementToken(char=ch_codepoint)
                token.start_pos = i - 1  # -1 because escape char is at i-1
                tokens.append(token)
        elif ch_codepoint == CHAR_SLASH:
            escape_found = True
            i += 1
            continue
        elif ch_codepoint == CHAR_DOT:
            var token = Wildcard()
            token.start_pos = i
            tokens.append(token)
        elif ch_codepoint == CHAR_LEFT_PAREN:
            var token = LeftParenthesis()
            token.start_pos = i
            tokens.append(token)
        elif ch_codepoint == CHAR_RIGHT_PAREN:
            var token = RightParenthesis()
            token.start_pos = i
            tokens.append(token)
        elif ch_codepoint == CHAR_LEFT_BRACKET:
            var token = LeftBracket()
            token.start_pos = i
            tokens.append(token)
        elif ch_codepoint == CHAR_DASH:
            var token = Dash()
            token.start_pos = i
            tokens.append(token)
        elif ch_codepoint == CHAR_RIGHT_BRACKET:
            var token = RightBracket()
            token.start_pos = i
            tokens.append(token)
        elif ch_codepoint == CHAR_LEFT_CURLY:
            var token = LeftCurlyBrace()
            token.start_pos = i
            tokens.append(token)
            i += 1
            while i < len(regex):
                var inner_ch_codepoint = Int(regex_bytes[i])
                if inner_ch_codepoint == CHAR_COMMA:
                    var comma_token = Comma()
                    comma_token.start_pos = i
                    tokens.append(comma_token)
                elif _is_digit(inner_ch_codepoint):
                    var digit_token = ElementToken(char=inner_ch_codepoint)
                    digit_token.start_pos = i
                    tokens.append(digit_token)
                elif inner_ch_codepoint == CHAR_RIGHT_CURLY:
                    var brace_token = RightCurlyBrace()
                    brace_token.start_pos = i
                    tokens.append(brace_token)
                    break
                else:
                    raise Error(
                        "Bad token at index ", i, ".", chr(ch_codepoint)
                    )
                i += 1
        elif ch_codepoint == CHAR_CIRCUMFLEX:
            if i == 0:
                var token = Start()
                token.start_pos = i
                tokens.append(token)
            else:
                var token = Circumflex()
                token.start_pos = i
                tokens.append(token)
        elif ch_codepoint == CHAR_END:
            var token = End()
            token.start_pos = i
            tokens.append(token)
        elif ch_codepoint == CHAR_QUESTION_MARK:
            var token = QuestionMark()
            token.start_pos = i
            tokens.append(token)
        elif ch_codepoint == CHAR_ASTERISK:
            var token = Asterisk()
            token.start_pos = i
            tokens.append(token)
        elif ch_codepoint == CHAR_PLUS:
            var token = Plus()
            token.start_pos = i
            tokens.append(token)
        elif ch_codepoint == CHAR_VERTICAL_BAR:
            var token = VerticalBar()
            token.start_pos = i
            tokens.append(token)
        elif ch_codepoint == CHAR_RIGHT_CURLY:
            var token = RightCurlyBrace()
            token.start_pos = i
            tokens.append(token)
        else:
            var token = ElementToken(char=ch_codepoint)
            token.start_pos = i
            tokens.append(token)

        escape_found = False
        i += 1

    return tokens
