alias ZERO_CODE = ord("0")
alias NINE_CODE = ord("9")


fn _all_except_newline() -> String:
    """Return a string containing all characters except newline."""
    return String("").join([chr(i) for i in range(32, 127) if i != ord("\n")])


alias ALL_EXCEPT_NEWLINE = _all_except_newline()
