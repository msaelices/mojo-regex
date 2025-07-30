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

alias DIGITS: String = "0123456789"
alias CHAR_TAB = Codepoint.ord("t")
alias CHAR_SPACE = Codepoint.ord("s")
alias CHAR_DIGIT = Codepoint.ord("d")
alias CHAR_DOT = Codepoint.ord(".")
alias CHAR_SLASH = Codepoint.ord("\\")
alias CHAR_LEFT_PAREN = Codepoint.ord("(")
alias CHAR_RIGHT_PAREN = Codepoint.ord(")")
alias CHAR_LEFT_BRACKET = Codepoint.ord("[")
alias CHAR_RIGHT_BRACKET = Codepoint.ord("]")
alias CHAR_LEFT_CURLY = Codepoint.ord("{")
alias CHAR_RIGHT_CURLY = Codepoint.ord("}")
alias CHAR_CIRCUMFLEX = Codepoint.ord("^")
alias CHAR_VERTICAL_BAR = Codepoint.ord("|")
alias CHAR_DASH = Codepoint.ord("-")
alias CHAR_COMMA = Codepoint.ord(",")
alias CHAR_ASTERISK = Codepoint.ord("*")
alias CHAR_PLUS = Codepoint.ord("+")
alias CHAR_QUESTION_MARK = Codepoint.ord("?")
alias CHAR_END = Codepoint.ord("$")


@always_inline
fn _is_digit(ch: Codepoint) -> Bool:
    var ch_int = ch.__int__()
    return ch_int >= ord("0") and ch_int <= ord("9")


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
        var ch_slice = StringSlice(unsafe_from_utf8=regex_bytes[i : i + 1])
        var ch_codepoint = Codepoint.ord(ch_slice)

        if escape_found:
            if ch_codepoint == CHAR_TAB:
                var token = ElementToken(char=Codepoint.ord(StringSlice("\t")))
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
                var inner_ch_slice = StringSlice(
                    unsafe_from_utf8=regex_bytes[i : i + 1]
                )
                var inner_ch_codepoint = Codepoint.ord(inner_ch_slice)
                var inner_ch = String(regex[i])
                if inner_ch == ",":
                    var comma_token = Comma()
                    comma_token.start_pos = i
                    tokens.append(comma_token)
                elif _is_digit(inner_ch_codepoint):
                    var digit_token = ElementToken(char=inner_ch_codepoint)
                    digit_token.start_pos = i
                    tokens.append(digit_token)
                elif inner_ch == "}":
                    var brace_token = RightCurlyBrace()
                    brace_token.start_pos = i
                    tokens.append(brace_token)
                    break
                else:
                    raise Error("Bad token at index " + String(i) + ".")
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
