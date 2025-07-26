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
    Regex,
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
fn check_for_quantifiers[
    regex_origin: ImmutableOrigin
](mut i: Int, mut elem: ASTNode[regex_origin], read tokens: List[Token]) raises:
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


fn parse_token_list[
    regex_origin: Origin[mut=True]
](
    ref [regex_origin]regex: Regex[regex_origin],
    owned tokens: List[Token],
) raises -> ASTNode[ImmutableOrigin.cast_from[regex_origin]]:
    """Parse a list of tokens into an AST node (used for recursive parsing of groups).
    """
    var regex_immutable: Regex[ImmutableAnyOrigin]
    if len(tokens) == 0:
        regex_immutable = rebind[Regex[ImmutableAnyOrigin]](regex)
        var group_node = GroupNode[ImmutableAnyOrigin](
            regex=regex_immutable,
            children_indexes=List[UInt8](),
            start_idx=0,
            end_idx=0,
            capturing=True,
            group_id=0,
        )
        return rebind[ASTNode[ImmutableOrigin.cast_from[regex_origin]]](
            group_node
        )

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
                var left_result = parse_token_list(regex, left_tokens^)
                left_ast = rebind[ASTNode[MutableAnyOrigin]](left_result)
            else:
                regex_immutable = rebind[Regex[ImmutableAnyOrigin]](regex)
                var empty_group = GroupNode[ImmutableAnyOrigin](
                    regex=regex_immutable,
                    children_indexes=List[UInt8](),
                    start_idx=0,
                    end_idx=0,
                    capturing=True,
                    group_id=0,
                )
                left_ast = rebind[ASTNode[MutableAnyOrigin]](empty_group)

            var right_ast: ASTNode[MutableAnyOrigin]
            if len(right_tokens) > 0:
                var right_result = parse_token_list(regex, right_tokens^)
                right_ast = rebind[ASTNode[MutableAnyOrigin]](right_result)
            else:
                regex_immutable = rebind[Regex[ImmutableAnyOrigin]](regex)
                var empty_group_2 = GroupNode[ImmutableAnyOrigin](
                    regex=regex_immutable,
                    children_indexes=List[UInt8](),
                    start_idx=0,
                    end_idx=0,
                    capturing=True,
                    group_id=0,
                )
                right_ast = rebind[ASTNode[MutableAnyOrigin]](empty_group_2)

            # Add children to regex and get their indices
            var left_index = UInt8(
                regex.get_children_len() + 1
            )  # +1 because we use 1-based indexing
            regex.append_child(left_ast)
            var right_index = UInt8(
                regex.get_children_len() + 1
            )  # +1 because we use 1-based indexing
            regex.append_child(right_ast)

            regex_immutable = rebind[Regex[ImmutableAnyOrigin]](regex)
            var or_node = OrNode[ImmutableAnyOrigin](
                regex=regex_immutable,
                left_child_index=left_index,
                right_child_index=right_index,
                start_idx=0,
                end_idx=len(regex.pattern),
            )
            return rebind[ASTNode[ImmutableOrigin.cast_from[regex_origin]]](
                or_node
            )

    # No OR found, parse elements sequentially
    var elements = List[ASTNode[MutableAnyOrigin], hint_trivial_type=True](
        capacity=len(tokens)
    )
    var i = 0

    while i < len(tokens):
        var token = tokens[i]

        regex_immutable = rebind[Regex[ImmutableAnyOrigin]](regex)
        if token.type == Token.ELEMENT:
            var elem = Element[ImmutableAnyOrigin](
                regex=regex_immutable,
                start_idx=i,  # Placeholder - would need proper token position tracking
                end_idx=i + 1,
            )
            # Check for quantifiers after the element
            if i + 1 < len(tokens):
                check_for_quantifiers[ImmutableAnyOrigin](i, elem, tokens)
            elements.append(rebind[ASTNode[MutableAnyOrigin]](elem))
        elif token.type == Token.WILDCARD:
            var elem = WildcardElement[ImmutableAnyOrigin](
                regex=regex_immutable,
                start_idx=i,
                end_idx=i + 1,
            )
            # Check for quantifiers after the wildcard
            if i + 1 < len(tokens):
                check_for_quantifiers[ImmutableAnyOrigin](i, elem, tokens)
            elements.append(rebind[ASTNode[MutableAnyOrigin]](elem))
        elif token.type == Token.SPACE:
            var elem = SpaceElement[ImmutableAnyOrigin](
                regex=regex_immutable,
                start_idx=i,
                end_idx=i + 2,  # Space tokens like \s are 2 characters
            )
            # Check for quantifiers after the space
            if i + 1 < len(tokens):
                check_for_quantifiers[ImmutableAnyOrigin](i, elem, tokens)
            elements.append(rebind[ASTNode[MutableAnyOrigin]](elem))
        elif token.type == Token.DIGIT:
            var elem = DigitElement[ImmutableAnyOrigin](
                regex=regex_immutable,
                start_idx=i,
                end_idx=i + 2,  # Digit tokens like \d are 2 characters
            )
            # Check for quantifiers after the digit
            if i + 1 < len(tokens):
                check_for_quantifiers[ImmutableAnyOrigin](i, elem, tokens)
            elements.append(rebind[ASTNode[MutableAnyOrigin]](elem))
        elif token.type == Token.START:
            var start_elem = StartElement[ImmutableAnyOrigin](
                regex=regex_immutable,
                start_idx=i,
                end_idx=i + 1,
            )
            elements.append(rebind[ASTNode[MutableAnyOrigin]](start_elem))
        elif token.type == Token.END:
            var end_elem = EndElement[ImmutableAnyOrigin](
                regex=regex_immutable,
                start_idx=i,
                end_idx=i + 1,
            )
            elements.append(rebind[ASTNode[MutableAnyOrigin]](end_elem))
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

            var range_elem = RangeElement[ImmutableAnyOrigin](
                regex=regex_immutable,
                start_idx=i,
                end_idx=i + len(range_str),
                is_positive_logic=positive_logic,
            )
            # Check for quantifiers after the range
            if i + 1 < len(tokens):
                check_for_quantifiers[ImmutableAnyOrigin](i, range_elem, tokens)
            elements.append(rebind[ASTNode[MutableAnyOrigin]](range_elem))
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
            var group_ast = parse_token_list(regex, group_tokens^)
            var group: ASTNode[MutableAnyOrigin]
            if group_ast.type == GROUP:
                # If it's already a group, use it directly
                group = rebind[ASTNode[MutableAnyOrigin]](group_ast)
                group.capturing = is_capturing
            else:
                # Otherwise wrap in a group - add to regex.get_children_len() and create group node
                var group_ast_mut = rebind[ASTNode[MutableAnyOrigin]](group_ast)
                var child_index = UInt8(
                    regex.get_children_len() + 1
                )  # +1 because we use 1-based indexing
                regex.append_child(group_ast_mut)

                var group_node = GroupNode[ImmutableAnyOrigin](
                    regex=regex_immutable,
                    children_indexes=List[UInt8](child_index),
                    start_idx=0,
                    end_idx=len(regex.pattern),
                    capturing=is_capturing,
                    group_id=0,
                )
                group = rebind[ASTNode[MutableAnyOrigin]](group_node)
            # Check for quantifiers after the group
            if i + 1 < len(tokens):
                check_for_quantifiers[MutableAnyOrigin](i, group, tokens)
            elements.append(group)

        i += 1

    # Add all elements to regex.get_children_len() and collect indices
    var children_indexes = List[UInt8](capacity=len(elements))
    for element in elements:
        children_indexes.append(
            UInt8(regex.get_children_len() + 1)
        )  # +1 because we use 1-based indexing
        regex.append_child(element)

    regex_immutable = rebind[Regex[ImmutableAnyOrigin]](regex)
    var final_group = GroupNode[ImmutableAnyOrigin](
        regex=regex_immutable,
        children_indexes=children_indexes,
        start_idx=0,
        end_idx=len(regex.pattern),
        capturing=True,
        group_id=0,
    )
    return rebind[ASTNode[ImmutableOrigin.cast_from[regex_origin]]](final_group)


fn parse(pattern: String) raises -> ASTNode[ImmutableAnyOrigin]:
    """Parses a regular expression.

    Parses a regex and returns the corresponding AST.
    If the regex contains errors raises an Exception.

    Args:
        pattern: A regular expression pattern string.

    Returns:
        The root node of the regular expression's AST.
    """
    # Create a Regex object to hold the pattern and children
    # Use MutableOrigin since parse_token_list requires Origin[mut=True]
    var pattern_copy = pattern
    var regex = Regex[MutableAnyOrigin](pattern_copy)

    # Tokenize the pattern
    var tokens = scan(pattern)

    # Use parse_token_list to do the actual parsing
    var parsed_ast = parse_token_list[MutableAnyOrigin](regex, tokens^)

    # Create a RE root node that wraps the parsed result
    # The tests expect the root to be of type RE with a GROUP child
    var parsed_ast_immutable = rebind[ASTNode[ImmutableAnyOrigin]](parsed_ast)
    var root_child_index = UInt8(
        regex.get_children_len() + 1
    )  # +1 because we use 1-based indexing
    regex.append_child(parsed_ast_immutable)

    var regex_immutable = rebind[Regex[ImmutableAnyOrigin]](regex)
    var re_root = ASTNode[ImmutableAnyOrigin](
        type=RE,
        regex=regex_immutable,
        start_idx=0,
        end_idx=len(pattern),
        children_indexes=List[UInt8](root_child_index),
    )

    print("regex.get_children_len() count:", regex.get_children_len())
    for i in range(regex.get_children_len()):
        ref child = regex.get_child(i)
        print(
            "Child",
            i + 1,
            String(child),
        )
    return re_root
