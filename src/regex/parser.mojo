from regex.constants import CHAR_COLON
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
    ChildrenIndexes,
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
        var min_val = String(
            capacity=String.INLINE_CAPACITY
        )  # Pre-allocate for min value
        var max_val = String(
            capacity=String.INLINE_CAPACITY
        )  # Pre-allocate for max value

        # Parse min value
        while i < len(tokens) and tokens[i].type == Token.ELEMENT:
            min_val += String(chr(tokens[i].char))
            i += 1

        elem.min = atol(min_val) if min_val != "" else 0

        # Check for comma (range) or closing brace (exact)
        if i < len(tokens) and tokens[i].type == Token.COMMA:
            i += 1  # Skip comma
            # Parse max value
            while i < len(tokens) and tokens[i].type == Token.ELEMENT:
                max_val += String(chr(tokens[i].char))
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
    ref [regex_origin]regex: Regex[ImmutableAnyOrigin],
    owned tokens: List[Token],
) raises -> ASTNode[MutableAnyOrigin]:
    """Parse a list of tokens into an AST node (used for recursive parsing of groups).
    """
    if len(tokens) == 0:
        var group_node = GroupNode[ImmutableAnyOrigin](
            regex=regex,
            children_indexes=ChildrenIndexes(),
            start_idx=0,
            end_idx=0,
            capturing=True,
            group_id=0,
        )
        return group_node

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
                var empty_group = GroupNode[ImmutableAnyOrigin](
                    regex=regex,
                    children_indexes=ChildrenIndexes(),
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
                var empty_group_2 = GroupNode[ImmutableAnyOrigin](
                    regex=regex,
                    children_indexes=ChildrenIndexes(),
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

            var or_node = OrNode[ImmutableAnyOrigin](
                regex=regex,
                left_child_index=left_index,
                right_child_index=right_index,
                start_idx=0,
                end_idx=len(regex.pattern),
            )
            return or_node

    # Validate tokens for unescaped closing brackets and parentheses
    var bracket_depth = 0
    var paren_depth_validation = 0
    for validation_i in range(len(tokens)):
        var validation_token = tokens[validation_i]
        if validation_token.type == Token.LEFTBRACKET:
            bracket_depth += 1
        elif validation_token.type == Token.RIGHTBRACKET:
            bracket_depth -= 1
            if bracket_depth < 0:
                raise Error(
                    "Unescaped closing bracket ']' at position "
                    + String(validation_token.start_pos)
                )
        elif validation_token.type == Token.LEFTPARENTHESIS:
            paren_depth_validation += 1
        elif validation_token.type == Token.RIGHTPARENTHESIS:
            paren_depth_validation -= 1
            if paren_depth_validation < 0:
                raise Error(
                    "Unescaped closing parenthesis ')' at position "
                    + String(validation_token.start_pos)
                )

    # No OR found, parse elements sequentially
    var elements = List[ASTNode[MutableAnyOrigin], hint_trivial_type=True](
        capacity=len(tokens)
    )
    var i = 0

    while i < len(tokens):
        var token = tokens[i]

        if token.type == Token.ELEMENT:
            var elem = Element[regex_origin](
                regex=regex,
                start_idx=token.start_pos,
                end_idx=token.start_pos + 1,  # Single codepoint
            )
            # Check for quantifiers after the element
            if i + 1 < len(tokens):
                check_for_quantifiers[ImmutableAnyOrigin](i, elem, tokens)
            elements.append(elem^)
        elif token.type == Token.WILDCARD:
            var elem = WildcardElement[ImmutableAnyOrigin](
                regex=regex,
                start_idx=token.start_pos,
                end_idx=token.start_pos + 1,
            )
            # Check for quantifiers after the wildcard
            if i + 1 < len(tokens):
                check_for_quantifiers[ImmutableAnyOrigin](i, elem, tokens)
            elements.append(elem^)
        elif token.type == Token.SPACE:
            var elem = SpaceElement[ImmutableAnyOrigin](
                regex=regex,
                start_idx=token.start_pos,
                end_idx=token.start_pos
                + 2,  # Space tokens like \s are 2 characters
            )
            # Check for quantifiers after the space
            if i + 1 < len(tokens):
                check_for_quantifiers[ImmutableAnyOrigin](i, elem, tokens)
            elements.append(elem^)
        elif token.type == Token.DIGIT:
            var elem = DigitElement[ImmutableAnyOrigin](
                regex=regex,
                start_idx=token.start_pos,
                end_idx=token.start_pos
                + 2,  # Digit tokens like \d are 2 characters
            )
            # Check for quantifiers after the digit
            if i + 1 < len(tokens):
                check_for_quantifiers[ImmutableAnyOrigin](i, elem, tokens)
            elements.append(elem^)
        elif token.type == Token.START:
            var start_elem = StartElement[ImmutableAnyOrigin](
                regex=regex,
                start_idx=token.start_pos,
                end_idx=token.start_pos + 1,
            )
            elements.append(start_elem^)
        elif token.type == Token.END:
            var end_elem = EndElement[ImmutableAnyOrigin](
                regex=regex,
                start_idx=token.start_pos,
                end_idx=token.start_pos + 1,
            )
            elements.append(end_elem^)
        elif token.type == Token.LEFTBRACKET:
            # Handle character ranges
            var bracket_start_pos = token.start_pos
            i += 1
            var positive_logic = True

            if i < len(tokens) and (
                tokens[i].type == Token.NOTTOKEN
                or tokens[i].type == Token.CIRCUMFLEX
            ):
                positive_logic = False
                i += 1

            while i < len(tokens) and tokens[i].type != Token.RIGHTBRACKET:
                # Check for range pattern like 'a-z'
                if (
                    i + 2 < len(tokens)
                    and tokens[i + 1].type == Token.DASH
                    and tokens[i + 2].type == Token.ELEMENT
                ):
                    # We have a range like 'a-z'
                    i += 3  # Skip start, dash, and end
                else:
                    # Single character
                    i += 1

            if i >= len(tokens):
                raise Error("Missing closing ']'.")

            # Calculate proper end position - should be after the closing bracket
            var bracket_end_pos = tokens[i].start_pos + 1

            var range_elem = RangeElement[ImmutableAnyOrigin](
                regex=regex,
                start_idx=bracket_start_pos,
                end_idx=bracket_end_pos,
                is_positive_logic=positive_logic,
            )
            # Check for quantifiers after the range
            if i + 1 < len(tokens):
                check_for_quantifiers[ImmutableAnyOrigin](i, range_elem, tokens)
            elements.append(range_elem^)
        elif token.type == Token.LEFTPARENTHESIS:
            # Handle nested grouping - check for non-capturing group (?:...)
            var paren_start_pos = token.start_pos
            i += 1
            var is_capturing = True
            var group_content_start_pos = paren_start_pos + 1

            # Check if this is a non-capturing group (?:...)
            if (
                i + 1 < len(tokens)
                and tokens[i].type == Token.QUESTIONMARK
                and tokens[i + 1].type == Token.ELEMENT
                and tokens[i + 1].char == CHAR_COLON
            ):
                is_capturing = False
                i += 2  # Skip ? and :
                group_content_start_pos = paren_start_pos + 3  # After (?:

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

            # Calculate proper end position - should be just before the closing parenthesis
            var paren_end_pos = tokens[i].start_pos

            # Recursively parse the tokens inside the group
            var group_ast = parse_token_list(regex, group_tokens^)
            var group: ASTNode[MutableAnyOrigin]
            if group_ast.type == GROUP:
                # If it's already a group, use it directly
                group = rebind[ASTNode[MutableAnyOrigin]](group_ast)
                group.capturing = is_capturing
                group.start_idx = group_content_start_pos
                group.end_idx = paren_end_pos
            else:
                # Otherwise wrap in a group - add to regex.get_children_len() and create group node
                var group_ast_mut = rebind[ASTNode[MutableAnyOrigin]](group_ast)
                var child_index = UInt8(
                    regex.get_children_len() + 1
                )  # +1 because we use 1-based indexing
                regex.append_child(group_ast_mut^)

                var group_node = GroupNode[ImmutableAnyOrigin](
                    regex=regex,
                    children_indexes=ChildrenIndexes(child_index),
                    start_idx=group_content_start_pos,
                    end_idx=paren_end_pos,
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
    var children_indexes = ChildrenIndexes(capacity=len(elements))
    for ref element in elements:
        children_indexes.append(
            UInt8(regex.get_children_len() + 1)
        )  # +1 because we use 1-based indexing
        regex.append_child(element)

    var final_group = GroupNode[ImmutableAnyOrigin](
        regex=regex,
        children_indexes=children_indexes,
        start_idx=0,
        end_idx=len(regex.pattern),
        capturing=True,
        group_id=0,
    )
    return final_group^


fn parse(pattern: String) raises -> ASTNode[ImmutableAnyOrigin]:
    """Parses a regular expression.

    Parses a regex and returns the corresponding AST.
    If the regex contains errors raises an Exception.

    Args:
        pattern: A regular expression pattern string.

    Returns:
        The root node of the regular expression's AST.
    """
    # Create a persistent Regex object to hold the pattern and children
    # Allocate on heap to ensure it survives function return
    var regex_ptr = UnsafePointer[Regex[ImmutableAnyOrigin]].alloc(1)
    regex_ptr.init_pointee_move(Regex[ImmutableAnyOrigin](pattern))

    # Tokenize the pattern
    var tokens = scan(pattern)

    # Use parse_token_list to do the actual parsing
    var parsed_ast = parse_token_list[MutableAnyOrigin](regex_ptr[], tokens^)

    var children_len = regex_ptr[].get_children_len()

    # Create a RE root node that wraps the parsed result
    # The tests expect the root to be of type RE with a GROUP child
    var parsed_ast_immutable = rebind[ASTNode[ImmutableAnyOrigin]](parsed_ast)
    var root_child_index = UInt8(
        children_len + 1
    )  # +1 because we use 1-based indexing
    regex_ptr[].append_child(parsed_ast_immutable)

    # Use the heap-allocated regex pointer directly
    var re_root = ASTNode[ImmutableAnyOrigin](
        type=RE,
        regex_ptr=regex_ptr,
        start_idx=0,
        end_idx=len(pattern),
        children_indexes=ChildrenIndexes(root_child_index),
    )

    return re_root
