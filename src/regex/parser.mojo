from regex.ast import ASTNode, RENode, Element


fn parse(regex: String) -> ASTNode:
    """Parses a regular expression.

    Parses a regex and returns the corresponding AST.
    If the regex contains errors raises an Exception.

    Args:
        regex: a regular expression

    Returns:
        The root node of the regular expression's AST
    """
    # TODO: Implement the actual parsing logic.
    return RENode(child=Element(value=regex))
