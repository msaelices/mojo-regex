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


fn parse_token_list(tokens: List[Token]) raises -> ASTNode:
    """Parse a list of tokens into an AST node (used for recursive parsing of groups).
    """
    if len(tokens) == 0:
        return GroupNode(List[ASTNode](), True, "", 0)

    # Simple implementation for now - parse elements and OR
    var elements = List[ASTNode]()
    var i = 0

    while i < len(tokens):
        var token = tokens[i]

        if token.type == Token.ELEMENT:
            elements.append(Element(token.char))
        elif token.type == Token.WILDCARD:
            elements.append(WildcardElement())
        elif token.type == Token.SPACE:
            elements.append(SpaceElement())
        elif token.type == Token.START:
            elements.append(StartElement())
        elif token.type == Token.END:
            elements.append(EndElement())
        elif token.type == Token.LEFTBRACKET:
            # Handle character ranges
            i += 1
            var range_str = String("")
            var positive_logic = True

            if i < len(tokens) and (
                tokens[i].type == Token.NOTTOKEN or tokens[i].type == Token.CIRCUMFLEX
            ):
                positive_logic = False
                i += 1

            while i < len(tokens) and tokens[i].type != Token.RIGHTBRACKET:
                var current_token = tokens[i]
                # Check for range pattern like 'a-z'
                if (
                    i + 2 < len(tokens)
                    and tokens[i + 1].type == Token.DASH
                    and tokens[i + 2].type == Token.ELEMENT
                ):
                    # We have a range like 'a-z'
                    var start_char = current_token.char
                    var end_char = tokens[i + 2].char
                    range_str += get_range_str(start_char, end_char)
                    i += 3  # Skip start, dash, and end
                else:
                    # Single character
                    range_str += current_token.char
                    i += 1

            if i >= len(tokens):
                raise Error("Missing closing ']'.")

            var range_elem = RangeElement(range_str, positive_logic)
            elements.append(range_elem)
        elif token.type == Token.VERTICALBAR:
            # OR handling - create OrNode with left and right parts
            var left_group = GroupNode(elements, True, "", 0)
            i += 1

            # Parse right side recursively
            var right_tokens = List[Token]()
            while i < len(tokens):
                right_tokens.append(tokens[i])
                i += 1

            var right_group_ast = parse_token_list(right_tokens)
            var right_group: ASTNode
            if right_group_ast.type == GROUP:
                right_group = right_group_ast
            else:
                right_group = GroupNode([right_group_ast], True, "", 0)

            return OrNode(left_group, right_group)

        i += 1

    return GroupNode(elements, True, "", 0)


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
            var elem = SpaceElement()
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
                var current_token = tokens[i]
                # Check for range pattern like 'a-z'
                if (
                    i + 2 < len(tokens)
                    and tokens[i + 1].type == Token.DASH
                    and tokens[i + 2].type == Token.ELEMENT
                ):
                    # We have a range like 'a-z'
                    var start_char = current_token.char
                    var end_char = tokens[i + 2].char
                    range_str += get_range_str(start_char, end_char)
                    i += 3  # Skip start, dash, and end
                else:
                    # Single character
                    range_str += current_token.char
                    i += 1

            if i >= len(tokens):
                raise Error("Missing closing ']'.")

            var range_elem = RangeElement(range_str, positive_logic)
            # Check for quantifiers after the range
            if i + 1 < len(tokens):
                var next_token = tokens[i + 1]
                if next_token.type == Token.ASTERISK:
                    range_elem.min = 0
                    range_elem.max = -1
                    i += 1  # Skip quantifier
                elif next_token.type == Token.PLUS:
                    range_elem.min = 1
                    range_elem.max = -1
                    i += 1  # Skip quantifier
                elif next_token.type == Token.QUESTIONMARK:
                    range_elem.min = 0
                    range_elem.max = 1
                    i += 1  # Skip quantifier
                elif next_token.type == Token.LEFTCURLYBRACE:
                    # Parse curly brace quantifiers for ranges
                    i += 2  # Skip range and {
                    var min_val = String("")
                    var max_val = String("")

                    # Parse min value
                    while i < len(tokens) and tokens[i].type == Token.ELEMENT:
                        min_val += tokens[i].char
                        i += 1

                    range_elem.min = atol(min_val) if min_val != "" else 0

                    # Check for comma (range) or closing brace (exact)
                    if i < len(tokens) and tokens[i].type == Token.COMMA:
                        i += 1  # Skip comma
                        # Parse max value
                        while i < len(tokens) and tokens[i].type == Token.ELEMENT:
                            max_val += tokens[i].char
                            i += 1
                        range_elem.max = atol(max_val) if max_val != "" else -1
                    else:
                        # Exact quantifier {n}
                        range_elem.max = range_elem.min

                    # Skip closing brace
                    if i < len(tokens) and tokens[i].type == Token.RIGHTCURLYBRACE:
                        i += 1
                    # Don't increment i again - continue processing next token
                    i -= 1  # Compensate for the i += 1 at the end of the loop
            elements.append(range_elem)
        elif token.type == Token.LEFTPARENTHESIS:
            # Handle grouping
            i += 1
            var group_tokens = List[Token]()
            var paren_count = 1

            # Extract tokens inside the parentheses
            while i < len(tokens) and paren_count > 0:
                if tokens[i].type == Token.LEFTPARENTHESIS:
                    paren_count += 1
                elif tokens[i].type == Token.RIGHTPARENTHESIS:
                    paren_count -= 1
                    if paren_count == 0:
                        break

                group_tokens.append(tokens[i])
                i += 1

            if paren_count > 0:
                raise Error("Missing closing parenthesis ')'.")

            # Recursively parse the tokens inside the group
            var group_ast = parse_token_list(group_tokens)
            var group: ASTNode
            if group_ast.type == GROUP:
                # If it's already a group, use it directly but mark as capturing
                group = group_ast
                group.capturing = True
            else:
                # Otherwise wrap in a group
                group = GroupNode([group_ast], True, "", 0)
            # Check for quantifiers after the group
            if i + 1 < len(tokens):
                var next_token = tokens[i + 1]
                if next_token.type == Token.ASTERISK:
                    group.min = 0
                    group.max = -1
                    i += 1  # Skip quantifier
                elif next_token.type == Token.PLUS:
                    group.min = 1
                    group.max = -1
                    i += 1  # Skip quantifier
                elif next_token.type == Token.QUESTIONMARK:
                    group.min = 0
                    group.max = 1
                    i += 1  # Skip quantifier
            elements.append(group)
        elif token.type == Token.VERTICALBAR:
            # OR handling - create OrNode with left and right parts
            var left_group = GroupNode(elements, True, "", 0)
            i += 1

            # Parse right side
            var right_elements = List[ASTNode]()
            while i < len(tokens):
                ref right_token = tokens[i]

                if right_token.type == Token.START:
                    right_elements.append(StartElement())
                elif right_token.type == Token.END:
                    right_elements.append(EndElement())
                elif right_token.type == Token.ELEMENT:
                    right_elements.append(Element(right_token.char))
                elif right_token.type == Token.WILDCARD:
                    right_elements.append(WildcardElement())
                elif right_token.type == Token.SPACE:
                    right_elements.append(SpaceElement())
                # TODO: Add support for other token types like ranges, groups, etc.
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
