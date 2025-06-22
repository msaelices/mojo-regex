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
        ref ch = regex[i]

        if escape_found:
            if ch == "t":
                tokens.append(ElementToken(char="\t"))
            elif ch == "s":
                tokens.append(SpaceToken(char=ch))
            else:
                tokens.append(ElementToken(char=ch))
        elif ch == "\\":
            escape_found = True
            i += 1
            continue
        elif ch == ".":
            tokens.append(Wildcard())
        elif ch == "(":
            tokens.append(LeftParenthesis())
        elif ch == ")":
            tokens.append(RightParenthesis())
        elif ch == "[":
            tokens.append(LeftBracket())
        elif ch == "-":
            tokens.append(Dash())
        elif ch == "]":
            tokens.append(RightBracket())
        elif ch == "{":
            tokens.append(LeftCurlyBrace())
            i += 1
            while i < len(regex):
                ch = regex[i]
                if ch == ",":
                    tokens.append(Comma())
                elif _is_digit(ch):
                    tokens.append(ElementToken(char=ch))
                elif ch == "}":
                    tokens.append(RightCurlyBrace())
                    break
                else:
                    raise Error("Bad token at index " + String(i) + ".")
                i += 1
        elif ch == "^":
            if i == 0:
                tokens.append(Start())
            else:
                tokens.append(Circumflex())
        elif ch == "$":
            tokens.append(End())
        elif ch == "?":
            tokens.append(QuestionMark())
        elif ch == "*":
            tokens.append(Asterisk())
        elif ch == "+":
            tokens.append(Plus())
        elif ch == "|":
            tokens.append(VerticalBar())
        elif ch == "}":
            tokens.append(RightCurlyBrace())
        else:
            tokens.append(ElementToken(char=ch))

        escape_found = False
        i += 1

    return tokens
