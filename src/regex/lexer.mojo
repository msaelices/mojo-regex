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
)

alias DIGITS: String = "0123456789"


@always_inline
def _is_digit(ch: str) -> bool:
    return DIGITS.find(ch) > -1


fn scan(regex: String) -> List[Token]:
    """
    Scans the input regex string and returns a list of tokens.

    Args:
        regex: The regular expression string to scan.
    Returns:
        A list of tokens parsed from the regex string.
    """
    # Placeholder for actual implementation
    # Remove this and implement the actual scanning logic
    return [
        Wildcard(),
        NotToken(char="^"),
        StartToken(char="^"),
    ]
