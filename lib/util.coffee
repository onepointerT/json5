unicode = require('../lib/unicode')
module.exports =
    isSpaceSeparator: (c) ->
        typeof c == 'string' and unicode.Space_Separator.test(c)
    isIdStartChar: (c) ->
        typeof c == 'string' and (c >= 'a' and c <= 'z' or c >= 'A' and c <= 'Z' or c == '$' or c == '_' or unicode.ID_Start.test(c))
    isIdContinueChar: (c) ->
        typeof c == 'string' and (c >= 'a' and c <= 'z' or c >= 'A' and c <= 'Z' or c >= '0' and c <= '9' or c == '$' or c == '_' or c == '‌' or c == '‍' or unicode.ID_Continue.test(c))
    isDigit: (c) ->
        typeof c == 'string' and /[0-9]/.test(c)
    isHexDigit: (c) ->
        typeof c == 'string' and /[0-9A-Fa-f]/.test(c)
