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


@always_inline
fn _is_digit(ch: String) -> Bool:
    return DIGITS.find(ch) > -1


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

    while i < len(regex):
        var ch = String(regex[i])

        if escape_found:
            if ch == "t":
                var token = ElementToken(char="\t")
                token.start_pos = i - 1  # -1 because escape char is at i-1
                tokens.append(token)
            elif ch == "s":
                var token = SpaceToken(char=ch)
                token.start_pos = i - 1  # -1 because escape char is at i-1
                tokens.append(token)
            elif ch == "d":
                var token = DigitToken(char=ch)
                token.start_pos = i - 1  # -1 because escape char is at i-1
                tokens.append(token)
            else:
                var token = ElementToken(char=ch)
                token.start_pos = i - 1  # -1 because escape char is at i-1
                tokens.append(token)
        elif ch == "\\":
            escape_found = True
            i += 1
            continue
        elif ch == ".":
            var token = Wildcard()
            token.start_pos = i
            tokens.append(token)
        elif ch == "(":
            var token = LeftParenthesis()
            token.start_pos = i
            tokens.append(token)
        elif ch == ")":
            var token = RightParenthesis()
            token.start_pos = i
            tokens.append(token)
        elif ch == "[":
            var token = LeftBracket()
            token.start_pos = i
            tokens.append(token)
        elif ch == "-":
            var token = Dash()
            token.start_pos = i
            tokens.append(token)
        elif ch == "]":
            var token = RightBracket()
            token.start_pos = i
            tokens.append(token)
        elif ch == "{":
            var token = LeftCurlyBrace()
            token.start_pos = i
            tokens.append(token)
            i += 1
            while i < len(regex):
                ch = String(regex[i])
                if ch == ",":
                    var comma_token = Comma()
                    comma_token.start_pos = i
                    tokens.append(comma_token)
                elif _is_digit(ch):
                    var digit_token = ElementToken(char=ch)
                    digit_token.start_pos = i
                    tokens.append(digit_token)
                elif ch == "}":
                    var brace_token = RightCurlyBrace()
                    brace_token.start_pos = i
                    tokens.append(brace_token)
                    break
                else:
                    raise Error("Bad token at index " + String(i) + ".")
                i += 1
        elif ch == "^":
            if i == 0:
                var token = Start()
                token.start_pos = i
                tokens.append(token)
            else:
                var token = Circumflex()
                token.start_pos = i
                tokens.append(token)
        elif ch == "$":
            var token = End()
            token.start_pos = i
            tokens.append(token)
        elif ch == "?":
            var token = QuestionMark()
            token.start_pos = i
            tokens.append(token)
        elif ch == "*":
            var token = Asterisk()
            token.start_pos = i
            tokens.append(token)
        elif ch == "+":
            var token = Plus()
            token.start_pos = i
            tokens.append(token)
        elif ch == "|":
            var token = VerticalBar()
            token.start_pos = i
            tokens.append(token)
        elif ch == "}":
            var token = RightCurlyBrace()
            token.start_pos = i
            tokens.append(token)
        else:
            var token = ElementToken(char=ch)
            token.start_pos = i
            tokens.append(token)

        escape_found = False
        i += 1

    return tokens
