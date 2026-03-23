def _all_except_newline() -> String:
    """Return a string containing all characters except newline."""
    return String("").join([chr(i) for i in range(32, 127) if i != ord("\n")])


comptime DIGITS: String = "0123456789"
comptime WORD_CHARS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
comptime CHAR_LIT_SPACE = ord("s")
comptime CHAR_LIT_TAB = ord("t")
comptime CHAR_TAB = ord("\t")
comptime CHAR_DIGIT = ord("d")
comptime CHAR_WORD = ord("w")
comptime CHAR_COLON = ord(":")
comptime CHAR_DOT = ord(".")
comptime CHAR_SLASH = ord("\\")
comptime CHAR_LEFT_PAREN = ord("(")
comptime CHAR_RIGHT_PAREN = ord(")")
comptime CHAR_LEFT_BRACKET = ord("[")
comptime CHAR_RIGHT_BRACKET = ord("]")
comptime CHAR_LEFT_CURLY = ord("{")
comptime CHAR_RIGHT_CURLY = ord("}")
comptime CHAR_CIRCUMFLEX = ord("^")
comptime CHAR_VERTICAL_BAR = ord("|")
comptime CHAR_DASH = ord("-")
comptime CHAR_COMMA = ord(",")
comptime CHAR_ASTERISK = ord("*")
comptime CHAR_PLUS = ord("+")
comptime CHAR_QUESTION_MARK = ord("?")
comptime CHAR_END = ord("$")
comptime CHAR_ZERO = ord("0")
comptime CHAR_NINE = ord("9")
comptime CHAR_A = ord("a")
comptime CHAR_Z = ord("z")
comptime CHAR_A_UPPER = ord("A")
comptime CHAR_Z_UPPER = ord("Z")
comptime CHAR_NEWLINE = ord("\n")
comptime CHAR_SPACE = ord(" ")
comptime CHAR_TAB_CHAR = ord("\t")
comptime CHAR_CR = ord("\r")
comptime CHAR_FF = ord("\f")
comptime CHAR_UNDERSCORE = ord("_")

comptime ALL_EXCEPT_NEWLINE = _all_except_newline()

comptime EMPTY_SLICE = StringSlice[ImmutAnyOrigin]("")
comptime EMPTY_STRING = String("")

# SIMD matcher type constants
comptime SIMD_MATCHER_NONE = 0
comptime SIMD_MATCHER_WHITESPACE = 1
comptime SIMD_MATCHER_DIGITS = 2
comptime SIMD_MATCHER_ALPHA_LOWER = 3
comptime SIMD_MATCHER_ALPHA_UPPER = 4
comptime SIMD_MATCHER_ALPHA = 5
comptime SIMD_MATCHER_ALNUM = 6
comptime SIMD_MATCHER_ALNUM_LOWER = 7
comptime SIMD_MATCHER_ALNUM_UPPER = 8
comptime SIMD_MATCHER_CUSTOM = 9

# Specialized matcher type constants
comptime SIMD_MATCHER_HEX_DIGITS = 10
comptime SIMD_MATCHER_WORD_CHARS = 11
comptime SIMD_MATCHER_NON_WORD_CHARS = 12
comptime SIMD_MATCHER_PUNCT = 13
comptime SIMD_MATCHER_CONTROL = 14
