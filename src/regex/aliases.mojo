fn _all_except_newline() -> String:
    """Return a string containing all characters except newline."""
    return String("").join([chr(i) for i in range(32, 127) if i != ord("\n")])


alias DIGITS: String = "0123456789"
alias WORD_CHARS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
alias CHAR_LIT_SPACE = ord("s")
alias CHAR_LIT_TAB = ord("t")
alias CHAR_TAB = ord("\t")
alias CHAR_DIGIT = ord("d")
alias CHAR_WORD = ord("w")
alias CHAR_COLON = ord(":")
alias CHAR_DOT = ord(".")
alias CHAR_SLASH = ord("\\")
alias CHAR_LEFT_PAREN = ord("(")
alias CHAR_RIGHT_PAREN = ord(")")
alias CHAR_LEFT_BRACKET = ord("[")
alias CHAR_RIGHT_BRACKET = ord("]")
alias CHAR_LEFT_CURLY = ord("{")
alias CHAR_RIGHT_CURLY = ord("}")
alias CHAR_CIRCUMFLEX = ord("^")
alias CHAR_VERTICAL_BAR = ord("|")
alias CHAR_DASH = ord("-")
alias CHAR_COMMA = ord(",")
alias CHAR_ASTERISK = ord("*")
alias CHAR_PLUS = ord("+")
alias CHAR_QUESTION_MARK = ord("?")
alias CHAR_END = ord("$")
alias CHAR_ZERO = ord("0")
alias CHAR_NINE = ord("9")
alias CHAR_A = ord("a")
alias CHAR_Z = ord("z")
alias CHAR_A_UPPER = ord("A")
alias CHAR_Z_UPPER = ord("Z")
alias CHAR_NEWLINE = ord("\n")

alias ALL_EXCEPT_NEWLINE = _all_except_newline()

alias EMPTY_SLICE = StringSlice[ImmutableAnyOrigin]("")
alias EMPTY_STRING = String("")

# SIMD matcher type constants
alias SIMD_MATCHER_NONE = 0
alias SIMD_MATCHER_WHITESPACE = 1
alias SIMD_MATCHER_DIGITS = 2
alias SIMD_MATCHER_ALPHA_LOWER = 3
alias SIMD_MATCHER_ALPHA_UPPER = 4
alias SIMD_MATCHER_ALPHA = 5
alias SIMD_MATCHER_ALNUM = 6
alias SIMD_MATCHER_ALNUM_LOWER = 7
alias SIMD_MATCHER_ALNUM_UPPER = 8
alias SIMD_MATCHER_CUSTOM = 9

# Specialized matcher type constants
alias SIMD_MATCHER_HEX_DIGITS = 10
alias SIMD_MATCHER_WORD_CHARS = 11
alias SIMD_MATCHER_NON_WORD_CHARS = 12
alias SIMD_MATCHER_PUNCT = 13
alias SIMD_MATCHER_CONTROL = 14
