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
    DigitElement,
    RangeElement,
    StartElement,
    EndElement,
    OrNode,
    GroupNode,
    RE,
    ELEMENT,
    WILDCARD,
    SPACE,
    DIGIT,
    RANGE,
    START,
    END,
    OR,
    GROUP,
)


@always_inline
fn check_for_quantifiers(
    mut i: Int, mut elem: ASTNode, read tokens: List[Token]
) raises:
    """Check for quantifiers after an element and set min/max accordingly."""
    var next_token = tokens[i + 1]
    if next_token.type == Token.ASTERISK:
        elem.min = 0
        elem.max = -1  # -1 means unlimited
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


fn get_range_str(start: String, end: String) -> String:
    """Generate a string containing all characters in the range [start, end]."""
    var start_ord = ord(start)
    var end_ord = ord(end)
    var range_size = end_ord - start_ord + 1

    # Pre-allocate result to avoid repeated reallocations
    var result = String()
    for i in range(range_size):
        result += chr(start_ord + i)
    return result


fn parse_token_list(
    owned tokens: List[Token],
) raises -> ASTNode[MutableAnyOrigin]:
    """Parse a list of tokens into an AST node (used for recursive parsing of groups).
    """
    if len(tokens) == 0:
        var empty_str = String("")
        return GroupNode(
            List[ASTNode[MutableAnyOrigin]](),
            value=empty_str,
            capturing=True,
            group_id=0,
        )._origin_cast[origin=MutableAnyOrigin]()

    # Handle OR at the top level by finding the first OR token outside of groups
    var paren_depth = 0
    for k in range(len(tokens)):
        if tokens[k].type == Token.LEFTPARENTHESIS:
            paren_depth += 1
        elif tokens[k].type == Token.RIGHTPARENTHESIS:
            paren_depth -= 1
        elif tokens[k].type == Token.VERTICALBAR and paren_depth == 0:
            # Split into left and right parts (only when not inside parentheses)
            var left_tokens = tokens[:k]
            var right_tokens = tokens[k + 1 :]

            # Parse both sides
            var left_ast: ASTNode[MutableAnyOrigin]
            if len(left_tokens) > 0:
                left_ast = parse_token_list(left_tokens^)
            else:
                left_ast = GroupNode(
                    List[ASTNode[MutableAnyOrigin]](),
                    value="",
                    capturing=True,
                    group_id=0,
                )._origin_cast[origin=MutableAnyOrigin]()

            var right_ast: ASTNode[MutableAnyOrigin]
            if len(right_tokens) > 0:
                right_ast = parse_token_list(right_tokens^)
            else:
                right_ast = GroupNode(
                    List[ASTNode[MutableAnyOrigin]](),
                    value="",
                    capturing=True,
                    group_id=0,
                )._origin_cast[origin=MutableAnyOrigin]()

            var or_value = String("")
            return OrNode(left_ast, right_ast, value=or_value)._origin_cast[
                origin=MutableAnyOrigin
            ]()

    # No OR found, parse elements sequentially
    var elements = List[ASTNode[MutableAnyOrigin]](capacity=len(tokens))
    var i = 0

    while i < len(tokens):
        var token = tokens[i]

        if token.type == Token.ELEMENT:
            var elem = Element(token.char)
            # Check for quantifiers after the element
            if i + 1 < len(tokens):
                check_for_quantifiers(i, elem, tokens)
            elements.append(elem._origin_cast[origin=MutableAnyOrigin]())
        elif token.type == Token.WILDCARD:
            var elem = WildcardElement(value="")
            # Check for quantifiers after the wildcard
            if i + 1 < len(tokens):
                check_for_quantifiers(i, elem, tokens)
            elements.append(elem._origin_cast[origin=MutableAnyOrigin]())
        elif token.type == Token.SPACE:
            var elem = SpaceElement(value="")
            # Check for quantifiers after the space
            if i + 1 < len(tokens):
                check_for_quantifiers(i, elem, tokens)
            elements.append(elem._origin_cast[origin=MutableAnyOrigin]())
        elif token.type == Token.DIGIT:
            var elem = DigitElement(value="")
            # Check for quantifiers after the digit
            if i + 1 < len(tokens):
                check_for_quantifiers(i, elem, tokens)
            elements.append(elem._origin_cast[origin=MutableAnyOrigin]())
        elif token.type == Token.START:
            elements.append(
                StartElement(value="")._origin_cast[origin=MutableAnyOrigin]()
            )
        elif token.type == Token.END:
            elements.append(
                EndElement(value="")._origin_cast[origin=MutableAnyOrigin]()
            )
        elif token.type == Token.LEFTBRACKET:
            # Handle character ranges
            i += 1
            var range_str = String("")
            var positive_logic = True

            if i < len(tokens) and (
                tokens[i].type == Token.NOTTOKEN
                or tokens[i].type == Token.CIRCUMFLEX
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
                check_for_quantifiers(i, range_elem, tokens^)
            elements.append(range_elem._origin_cast[origin=MutableAnyOrigin]())
        elif token.type == Token.LEFTPARENTHESIS:
            # Handle nested grouping - check for non-capturing group (?:...)
            i += 1
            var is_capturing = True

            # Check if this is a non-capturing group (?:...)
            if (
                i + 1 < len(tokens)
                and tokens[i].type == Token.QUESTIONMARK
                and tokens[i + 1].type == Token.ELEMENT
                and tokens[i + 1].char == ":"
            ):
                is_capturing = False
                i += 2  # Skip ? and :

            var group_tokens = List[Token](capacity=len(tokens) - i)
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
            var group: ASTNode[MutableAnyOrigin]
            if group_ast.type == GROUP:
                # If it's already a group, use it directly
                group = group_ast
                group.capturing = is_capturing
            else:
                # Otherwise wrap in a group
                group = GroupNode(
                    List[ASTNode[MutableAnyOrigin]](
                        group_ast._origin_cast[origin=MutableAnyOrigin]()
                    ),
                    value="",
                    capturing=is_capturing,
                    group_id=0,
                )._origin_cast[origin=MutableAnyOrigin]()
            # Check for quantifiers after the group
            if i + 1 < len(tokens):
                check_for_quantifiers(i, group, tokens)
            elements.append(group._origin_cast[origin=MutableAnyOrigin]())

        i += 1

    return GroupNode(
        elements^, value="", capturing=True, group_id=0
    )._origin_cast[origin=MutableAnyOrigin]()


fn parse(regex: String) raises -> ASTNode[MutableAnyOrigin]:
    """Parses a regular expression.

    Parses a regex and returns the corresponding AST.
    If the regex contains errors raises an Exception.

    Args:
        regex: A regular expression.

    Returns:
        The root node of the regular expression's AST.
    """
    var tokens = scan(regex)
    if len(tokens) == 0:
        # Empty pattern - create an empty RE node
        var empty_str = String("")
        return ASTNode[MutableAnyOrigin](type=RE, value=empty_str)

    # Simple implementation for basic parsing
    var elements = List[ASTNode[MutableAnyOrigin]](capacity=len(tokens))
    var i = 0

    while i < len(tokens):
        var token = tokens[i]

        if token.type == Token.START:
            elements.append(
                StartElement(value="")._origin_cast[origin=MutableAnyOrigin]()
            )
        elif token.type == Token.END:
            elements.append(
                EndElement(value="")._origin_cast[origin=MutableAnyOrigin]()
            )
        elif token.type == Token.ELEMENT:
            var elem = Element(token.char)
            # Check for quantifiers
            if i + 1 < len(tokens):
                check_for_quantifiers(i, elem, tokens)
            elements.append(elem._origin_cast[origin=MutableAnyOrigin]())
        elif token.type == Token.WILDCARD:
            var elem = WildcardElement(value="")
            # Check for quantifiers
            if i + 1 < len(tokens):
                check_for_quantifiers(i, elem, tokens)
            elements.append(elem._origin_cast[origin=MutableAnyOrigin]())
        elif token.type == Token.SPACE:
            var elem = SpaceElement(value="")
            # Check for quantifiers
            if i + 1 < len(tokens):
                check_for_quantifiers(i, elem, tokens)
            elements.append(elem._origin_cast[origin=MutableAnyOrigin]())
        elif token.type == Token.DIGIT:
            var elem = DigitElement(value="")
            # Check for quantifiers
            if i + 1 < len(tokens):
                check_for_quantifiers(i, elem, tokens)
            elements.append(elem._origin_cast[origin=MutableAnyOrigin]())
        elif token.type == Token.LEFTBRACKET:
            # Simple range parsing
            i += 1
            var range_str = String("")
            var positive_logic = True

            if i < len(tokens) and (
                tokens[i].type == Token.NOTTOKEN
                or tokens[i].type == Token.CIRCUMFLEX
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
                check_for_quantifiers(i, range_elem, tokens)
            elements.append(range_elem._origin_cast[origin=MutableAnyOrigin]())
        elif token.type == Token.LEFTPARENTHESIS:
            # Handle grouping - check for non-capturing group (?:...)
            i += 1
            var is_capturing = True

            # Check if this is a non-capturing group (?:...)
            if (
                i + 1 < len(tokens)
                and tokens[i].type == Token.QUESTIONMARK
                and tokens[i + 1].type == Token.ELEMENT
                and tokens[i + 1].char == ":"
            ):
                is_capturing = False
                i += 2  # Skip ? and :

            var group_tokens = List[Token](capacity=len(tokens) - i)
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
            var group: ASTNode[MutableAnyOrigin]
            if group_ast.type == GROUP:
                # If it's already a group, use it directly
                group = group_ast
                group.capturing = is_capturing
            else:
                # Otherwise wrap in a group
                group = GroupNode(
                    List[ASTNode[MutableAnyOrigin]](
                        group_ast._origin_cast[origin=MutableAnyOrigin]()
                    ),
                    value="",
                    capturing=is_capturing,
                    group_id=0,
                )._origin_cast[origin=MutableAnyOrigin]()
            # Check for quantifiers after the group
            if i + 1 < len(tokens):
                check_for_quantifiers(i, group, tokens)
            elements.append(group._origin_cast[origin=MutableAnyOrigin]())
        elif token.type == Token.VERTICALBAR:
            # OR handling - create OrNode with left and right parts
            var left_group = GroupNode(
                elements^,
                value="",
                capturing=True,
                group_id=0,
            )._origin_cast[origin=MutableAnyOrigin]()
            i += 1

            # Parse right side - collect remaining tokens
            var right_tokens = List[Token](capacity=len(tokens) - i)
            while i < len(tokens):
                right_tokens.append(tokens[i])
                i += 1

            # Recursively parse the right side
            var right_group_ast = parse_token_list(right_tokens^)
            var right_group: ASTNode[MutableAnyOrigin]
            if right_group_ast.type == GROUP:
                right_group = right_group_ast
            else:
                right_group = GroupNode(
                    List[ASTNode[MutableAnyOrigin]](
                        right_group_ast._origin_cast[origin=MutableAnyOrigin]()
                    ),
                    value="",
                    capturing=True,
                    group_id=0,
                )._origin_cast[origin=MutableAnyOrigin]()

            return RENode(
                OrNode(left_group, right_group, value=""), value=""
            )._origin_cast[origin=MutableAnyOrigin]()
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
    return RENode(
        GroupNode(elements^, value="", capturing=True, group_id=0),
        value="",
    )._origin_cast[origin=MutableAnyOrigin]()
