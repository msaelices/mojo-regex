from regex.lexer import scan
from regex.tokens import (
    Token,
    ElementToken,
    SpaceToken,
    Start,
    End,
    Circumflex,
    LeftParenthesis,
    RightParenthesis,
    LeftBracket,
    RightBracket,
    LeftCurlyBrace,
    RightCurlyBrace,
    QuestionMark,
    Asterisk,
    Plus,
    VerticalBar,
    Dash,
    NotToken,
    Wildcard,
)
from regex.ast import (
    ASTNode,
    RENode,
    Element,
    WildcardElement,
    SpaceElement,
    RangeElement,
    StartElement,
    EndElement,
    OrNode,
    GroupNode,
    RE,
    ELEMENT,
    WILDCARD,
    SPACE,
    RANGE,
    START,
    END,
    OR,
    GROUP,
)


fn get_range_str(start: String, end: String) -> String:
    """Generate a string containing all characters in the range [start, end]."""
    var result = String("")
    var i = ord(start)
    var end_ord = ord(end)
    while i <= end_ord:
        result += chr(i)
        i += 1
    return result


fn parse(regex: String) raises -> ASTNode:
    """Parses a regular expression.

    Parses a regex and returns the corresponding AST.
    If the regex contains errors raises an Exception.

    Args:
        regex: a regular expression

    Returns:
        The root node of the regular expression's AST
    """
    var tokens = scan(regex)
    if len(tokens) == 0:
        raise Error("Empty regex.")

    # Simple implementation for basic parsing
    var elements = List[ASTNode]()
    var i = 0

    while i < len(tokens):
        var token = tokens[i]

        if token.type == Token.START:
            elements.append(StartElement())
        elif token.type == Token.END:
            elements.append(EndElement())
        elif token.type == Token.ELEMENT:
            var elem = Element(token.char)
            # Check for quantifiers
            if i + 1 < len(tokens):
                var next_token = tokens[i + 1]
                if next_token.type == Token.ASTERISK:
                    elem.min = 0
                    elem.max = -1
                    i += 1  # Skip quantifier
                elif next_token.type == Token.PLUS:
                    elem.min = 1
                    elem.max = -1
                    i += 1  # Skip quantifier
                elif next_token.type == Token.QUESTIONMARK:
                    elem.min = 0
                    elem.max = 1
                    i += 1  # Skip quantifier
                elif next_token.type == Token.LEFTCURLYBRACE:
                    # Parse curly brace quantifiers
                    i += 2  # Skip element and {
                    var min_val = String("")
                    var max_val = String("")

                    # Parse min value
                    while i < len(tokens) and tokens[i].type == Token.ELEMENT:
                        min_val += tokens[i].char
                        i += 1

                    elem.min = atol(min_val) if min_val != "" else 0

                    # Check for comma (range) or closing brace (exact)
                    if i < len(tokens) and tokens[i].type == Token.COMMA:
                        i += 1  # Skip comma
                        # Parse max value
                        while i < len(tokens) and tokens[i].type == Token.ELEMENT:
                            max_val += tokens[i].char
                            i += 1
                        elem.max = atol(max_val) if max_val != "" else -1
                    else:
                        # Exact quantifier {n}
                        elem.max = elem.min

                    # Skip closing brace
                    if i < len(tokens) and tokens[i].type == Token.RIGHTCURLYBRACE:
                        i += 1
                    # Don't increment i again - continue processing next token
                    i -= 1  # Compensate for the i += 1 at the end of the loop
            elements.append(elem)
        elif token.type == Token.WILDCARD:
            var elem = WildcardElement()
            # Check for quantifiers
            if i + 1 < len(tokens):
                var next_token = tokens[i + 1]
                if next_token.type == Token.ASTERISK:
                    elem.min = 0
                    elem.max = -1
                    i += 1  # Skip quantifier
                elif next_token.type == Token.PLUS:
                    elem.min = 1
                    elem.max = -1
                    i += 1  # Skip quantifier
                elif next_token.type == Token.QUESTIONMARK:
                    elem.min = 0
                    elem.max = 1
                    i += 1  # Skip quantifier
            elements.append(elem)
        elif token.type == Token.SPACE:
            elements.append(SpaceElement())
        elif token.type == Token.LEFTBRACKET:
            # Simple range parsing
            i += 1
            var range_str = String("")
            var positive_logic = True

            if i < len(tokens) and (
                tokens[i].type == Token.NOTTOKEN or tokens[i].type == Token.CIRCUMFLEX
            ):
                positive_logic = False
                i += 1

            while i < len(tokens) and tokens[i].type != Token.RIGHTBRACKET:
                range_str += tokens[i].char
                i += 1

            if i >= len(tokens):
                raise Error("Missing closing ']'.")

            elements.append(RangeElement(range_str, positive_logic))
        elif token.type == Token.LEFTPARENTHESIS:
            # Handle grouping
            i += 1
            var group_elements = List[ASTNode]()
            var paren_count = 1

            while i < len(tokens) and paren_count > 0:
                if tokens[i].type == Token.LEFTPARENTHESIS:
                    paren_count += 1
                elif tokens[i].type == Token.RIGHTPARENTHESIS:
                    paren_count -= 1
                    if paren_count == 0:
                        break

                # Simple element parsing within parentheses
                if tokens[i].type == Token.ELEMENT:
                    group_elements.append(Element(tokens[i].char))

                i += 1

            if paren_count > 0:
                raise Error("Missing closing parenthesis ')'.")

            elements.append(GroupNode(group_elements, True, "", 0))
        elif token.type == Token.VERTICALBAR:
            # OR handling - create OrNode with left and right parts
            var left_group = GroupNode(elements, True, "", 0)
            i += 1

            # Parse right side
            var right_elements = List[ASTNode]()
            while i < len(tokens):
                if tokens[i].type == Token.ELEMENT:
                    right_elements.append(Element(tokens[i].char))
                i += 1

            var right_group = GroupNode(right_elements, True, "", 0)
            return RENode(OrNode(left_group, right_group))
        else:
            # Check for unescaped special characters
            if token.type == Token.RIGHTPARENTHESIS:
                raise Error("Unescaped closing parenthesis ')'.")
            elif token.type == Token.RIGHTBRACKET:
                raise Error("Unescaped closing bracket ']'.")
            elif token.type == Token.RIGHTCURLYBRACE:
                raise Error("Unescaped closing curly brace '}'.")
            else:
                raise Error("Unexpected token: " + token.char)

        i += 1

    return RENode(GroupNode(elements))
