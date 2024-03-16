util = require('./util')
source = undefined
parseState = undefined
stack = undefined
pos = undefined
line = undefined
column = undefined
token = undefined
key = undefined
root = undefined

internalize = (holder, name, reviver) ->
    `var key`
    value = holder[name]
    if value != null and typeof value == 'object'
        for key of value
            replacement = internalize(value, key, reviver)
            if replacement == undefined
                delete value[key]
            else
                value[key] = replacement
    reviver.call holder, name, value

lex = ->
    `var token`
    lexState = 'default'
    buffer = ''
    doubleQuote = false
    sign = 1
    loop
        c = peek()
        # This code is unreachable.
        # if (!lexStates[lexState]) {
        #     throw invalidLexState(lexState)
        # }
        token = lexStates[lexState]()
        if token
            return token
    return

peek = ->
    if source[pos]
        return String.fromCodePoint(source.codePointAt(pos))
    return

read = ->
    c = peek()
    if c == '\n'
        line++
        column = 0
    else if c
        column += c.length
    else
        column++
    if c
        pos += c.length
    c

newToken = (type, value) ->
    {
        type: type
        value: value
        line: line
        column: column
    }

literal = (s) ->
    for c of s
        p = peek()
        if p != c
            throw invalidChar(read())
        read()
    return

escape = ->
    c = peek()
    switch c
        when 'b'
            read()
            return '\u0008'
        when 'f'
            read()
            return '\u000c'
        when 'n'
            read()
            return '\n'
        when 'r'
            read()
            return '\u000d'
        when 't'
            read()
            return '\u0009'
        when 'v'
            read()
            return '\u000b'
        when '0'
            read()
            if util.isDigit(peek())
                throw invalidChar(read())
            return '\u0000'
        when 'x'
            read()
            return hexEscape()
        when 'u'
            read()
            return unicodeEscape()
        when '\n', '\u2028', '\u2029'
            read()
            return ''
        when '\u000d'
            read()
            if peek() == '\n'
                read()
            return ''
        when '1', '2', '3', '4', '5', '6', '7', '8', '9'
            throw invalidChar(read())
        when undefined
            throw invalidChar(read())
    read()

hexEscape = ->
    buffer = ''
    c = peek()
    if !util.isHexDigit(c)
        throw invalidChar(read())
    buffer += read()
    c = peek()
    if !util.isHexDigit(c)
        throw invalidChar(read())
    buffer += read()
    String.fromCodePoint parseInt(buffer, 16)

unicodeEscape = ->
    buffer = ''
    count = 4
    while count-- > 0
        c = peek()
        if !util.isHexDigit(c)
            throw invalidChar(read())
        buffer += read()
    String.fromCodePoint parseInt(buffer, 16)

push = ->
    value = undefined
    switch token.type
        when 'punctuator'
            switch token.value
                when '{'
                    value = {}
                when '['
                    value = []
        when 'null', 'boolean', 'numeric', 'string'
            value = token.value
        # This code is unreachable.
        # default:
        #     throw invalidToken()
    if root == undefined
        root = value
    else
        parent = stack[stack.length - 1]
        if Array.isArray(parent)
            parent.push value
        else
            parent[key] = value
    if value != null and typeof value == 'object'
        stack.push value
        if Array.isArray(value)
            parseState = 'beforeArrayValue'
        else
            parseState = 'beforePropertyName'
    else
        current = stack[stack.length - 1]
        if current == null
            parseState = 'end'
        else if Array.isArray(current)
            parseState = 'afterArrayValue'
        else
            parseState = 'afterPropertyValue'
    return

pop = ->
    stack.pop()
    current = stack[stack.length - 1]
    if current == null
        parseState = 'end'
    else if Array.isArray(current)
        parseState = 'afterArrayValue'
    else
        parseState = 'afterPropertyValue'
    return

# This code is unreachable.
# function invalidParseState () {
#     return new Error("JSON5: invalid parse state '${parseState}'")
# }
# This code is unreachable.
# function invalidLexState (state) {
#     return new Error("JSON5: invalid lex state '${state}'")
# }

invalidChar = (c) ->
    if c == undefined
        return syntaxError('JSON5: invalid end of input at ${line}:${column}')
    syntaxError 'JSON5: invalid character \'${formatChar(c)}\' at ${line}:${column}'

invalidEOF = ->
    syntaxError 'JSON5: invalid end of input at ${line}:${column}'

# This code is unreachable.
# function invalidToken () {
#     if (token.type === 'eof') {
#         return syntaxError("JSON5: invalid end of input at ${line}:${column}")
#     }
#     const c = String.fromCodePoint(token.value.codePointAt(0))
#     return syntaxError("JSON5: invalid character '${formatChar(c)}' at ${line}:${column}")
# }

invalidIdentifier = ->
    column -= 5
    syntaxError 'JSON5: invalid identifier character at ${line}:${column}'

separatorChar = (c) ->
    console.warn 'JSON5: \'${formatChar(c)}\' in strings is not valid ECMAScript; consider escaping'
    return

formatChar = (c) ->
    replacements = 
        '\'': '\\\''
        '"': '\"'
        '\\': '\\\\'
        '\u0008': '\\b'
        '\u000c': '\\f'
        '\n': '\\n'
        '\u000d': '\\r'
        '\u0009': '\\t'
        '\u000b': '\\v'
        '\u0000': '\\0'
        '\u2028': '\\u2028'
        '\u2029': '\\u2029'
    if replacements[c]
        return replacements[c]
    if c < ' '
        hexString = c.charCodeAt(0).toString(16)
        return '\\x' + ('00' + hexString).substring(hexString.length)
    c

syntaxError = (message) ->
    err = new SyntaxError(message)
    err.lineNumber = line
    err.columnNumber = column
    err

module.exports = (text, reviver) ->
    source = String(text)
    parseState = 'start'
    stack = []
    pos = 0
    line = 1
    column = 0
    token = undefined
    key = undefined
    root = undefined
    loop
        token = lex()
        # This code is unreachable.
        # if (!parseStates[parseState]) {
        #     throw invalidParseState()
        # }
        parseStates[parseState]()
        unless token.type != 'eof'
            break
    if typeof reviver == 'function'
        return internalize({ '': root }, '', reviver)
    root

lexState = undefined
buffer = undefined
doubleQuote = undefined
sign = undefined
c = undefined
lexStates = 
    default: ->
        switch c
            when '\u0009', '\u000b', '\u000c', ' ', ' ', '\ufeff', '\n', '\u000d', '\u2028', '\u2029'
                read()
                return
            when '/'
                read()
                lexState = 'comment'
                return
            when undefined
                read()
                return newToken('eof')
        if util.isSpaceSeparator(c)
            read()
            return
        # This code is unreachable.
        # if (!lexStates[parseState]) {
        #     throw invalidLexState(parseState)
        # }
        lexStates[parseState]()
    comment: ->
        switch c
            when '*'
                read()
                lexState = 'multiLineComment'
                return
            when '/'
                read()
                lexState = 'singleLineComment'
                return
        throw invalidChar(read())
        return
    multiLineComment: ->
        switch c
            when '*'
                read()
                lexState = 'multiLineCommentAsterisk'
                return
            when undefined
                throw invalidChar(read())
        read()
        return
    multiLineCommentAsterisk: ->
        switch c
            when '*'
                read()
                return
            when '/'
                read()
                lexState = 'default'
                return
            when undefined
                throw invalidChar(read())
        read()
        lexState = 'multiLineComment'
        return
    singleLineComment: ->
        switch c
            when '\n', '\u000d', '\u2028', '\u2029'
                read()
                lexState = 'default'
                return
            when undefined
                read()
                return newToken('eof')
        read()
        return
    value: ->
        switch c
            when '{', '['
                return newToken('punctuator', read())
            when 'n'
                read()
                literal 'ull'
                return newToken('null', null)
            when 't'
                read()
                literal 'rue'
                return newToken('boolean', true)
            when 'f'
                read()
                literal 'alse'
                return newToken('boolean', false)
            when '-', '+'
                if read() == '-'
                    sign = -1
                lexState = 'sign'
                return
            when '.'
                buffer = read()
                lexState = 'decimalPointLeading'
                return
            when '0'
                buffer = read()
                lexState = 'zero'
                return
            when '1', '2', '3', '4', '5', '6', '7', '8', '9'
                buffer = read()
                lexState = 'decimalInteger'
                return
            when 'I'
                read()
                literal 'nfinity'
                return newToken('numeric', Infinity)
            when 'N'
                read()
                literal 'aN'
                return newToken('numeric', NaN)
            when '"', '\''
                doubleQuote = read() == '"'
                buffer = ''
                lexState = 'string'
                return
        throw invalidChar(read())
        return
    identifierNameStartEscape: ->
        if c != 'u'
            throw invalidChar(read())
        read()
        u = unicodeEscape()
        switch u
            when '$', '_'
            else
                if !util.isIdStartChar(u)
                    throw invalidIdentifier()
                break
        buffer += u
        lexState = 'identifierName'
        return
    identifierName: ->
        switch c
            when '$', '_', '‌', '‍'
                buffer += read()
                return
            when '\\'
                read()
                lexState = 'identifierNameEscape'
                return
        if util.isIdContinueChar(c)
            buffer += read()
            return
        newToken 'identifier', buffer
    identifierNameEscape: ->
        if c != 'u'
            throw invalidChar(read())
        read()
        u = unicodeEscape()
        switch u
            when '$', '_', '‌', '‍'
            else
                if !util.isIdContinueChar(u)
                    throw invalidIdentifier()
                break
        buffer += u
        lexState = 'identifierName'
        return
    sign: ->
        switch c
            when '.'
                buffer = read()
                lexState = 'decimalPointLeading'
                return
            when '0'
                buffer = read()
                lexState = 'zero'
                return
            when '1', '2', '3', '4', '5', '6', '7', '8', '9'
                buffer = read()
                lexState = 'decimalInteger'
                return
            when 'I'
                read()
                literal 'nfinity'
                return newToken('numeric', sign * Infinity)
            when 'N'
                read()
                literal 'aN'
                return newToken('numeric', NaN)
        throw invalidChar(read())
        return
    zero: ->
        switch c
            when '.'
                buffer += read()
                lexState = 'decimalPoint'
                return
            when 'e', 'E'
                buffer += read()
                lexState = 'decimalExponent'
                return
            when 'x', 'X'
                buffer += read()
                lexState = 'hexadecimal'
                return
        newToken 'numeric', sign * 0
    decimalInteger: ->
        switch c
            when '.'
                buffer += read()
                lexState = 'decimalPoint'
                return
            when 'e', 'E'
                buffer += read()
                lexState = 'decimalExponent'
                return
        if util.isDigit(c)
            buffer += read()
            return
        newToken 'numeric', sign * Number(buffer)
    decimalPointLeading: ->
        if util.isDigit(c)
            buffer += read()
            lexState = 'decimalFraction'
            return
        throw invalidChar(read())
        return
    decimalPoint: ->
        switch c
            when 'e', 'E'
                buffer += read()
                lexState = 'decimalExponent'
                return
        if util.isDigit(c)
            buffer += read()
            lexState = 'decimalFraction'
            return
        newToken 'numeric', sign * Number(buffer)
    decimalFraction: ->
        switch c
            when 'e', 'E'
                buffer += read()
                lexState = 'decimalExponent'
                return
        if util.isDigit(c)
            buffer += read()
            return
        newToken 'numeric', sign * Number(buffer)
    decimalExponent: ->
        switch c
            when '+', '-'
                buffer += read()
                lexState = 'decimalExponentSign'
                return
        if util.isDigit(c)
            buffer += read()
            lexState = 'decimalExponentInteger'
            return
        throw invalidChar(read())
        return
    decimalExponentSign: ->
        if util.isDigit(c)
            buffer += read()
            lexState = 'decimalExponentInteger'
            return
        throw invalidChar(read())
        return
    decimalExponentInteger: ->
        if util.isDigit(c)
            buffer += read()
            return
        newToken 'numeric', sign * Number(buffer)
    hexadecimal: ->
        if util.isHexDigit(c)
            buffer += read()
            lexState = 'hexadecimalInteger'
            return
        throw invalidChar(read())
        return
    hexadecimalInteger: ->
        if util.isHexDigit(c)
            buffer += read()
            return
        newToken 'numeric', sign * Number(buffer)
    string: ->
        switch c
            when '\\'
                read()
                buffer += escape()
                return
            when '"'
                if doubleQuote
                    read()
                    return newToken('string', buffer)
                buffer += read()
                return
            when '\''
                if !doubleQuote
                    read()
                    return newToken('string', buffer)
                buffer += read()
                return
            when '\n', '\u000d'
                throw invalidChar(read())
            when '\u2028', '\u2029'
                separatorChar c
            when undefined
                throw invalidChar(read())
        buffer += read()
        return
    start: ->
        switch c
            when '{', '['
                return newToken('punctuator', read())
            # This code is unreachable since the default lexState handles eof.
            # case undefined:
            #     return newToken('eof')
        lexState = 'value'
        return
    beforePropertyName: ->
        switch c
            when '$', '_'
                buffer = read()
                lexState = 'identifierName'
                return
            when '\\'
                read()
                lexState = 'identifierNameStartEscape'
                return
            when '}'
                return newToken('punctuator', read())
            when '"', '\''
                doubleQuote = read() == '"'
                lexState = 'string'
                return
        if util.isIdStartChar(c)
            buffer += read()
            lexState = 'identifierName'
            return
        throw invalidChar(read())
        return
    afterPropertyName: ->
        if c == ':'
            return newToken('punctuator', read())
        throw invalidChar(read())
        return
    beforePropertyValue: ->
        lexState = 'value'
        return
    afterPropertyValue: ->
        switch c
            when ',', '}'
                return newToken('punctuator', read())
        throw invalidChar(read())
        return
    beforeArrayValue: ->
        if c == ']'
            return newToken('punctuator', read())
        lexState = 'value'
        return
    afterArrayValue: ->
        switch c
            when ',', ']'
                return newToken('punctuator', read())
        throw invalidChar(read())
        return
    end: ->
        # This code is unreachable since it's handled by the default lexState.
        # if (c === undefined) {
        #     read()
        #     return newToken('eof')
        # }
        throw invalidChar(read())
        return
parseStates = 
    start: ->
        if token.type == 'eof'
            throw invalidEOF()
        push()
        return
    beforePropertyName: ->
        switch token.type
            when 'identifier', 'string'
                key = token.value
                parseState = 'afterPropertyName'
                return
            when 'punctuator'
                # This code is unreachable since it's handled by the lexState.
                # if (token.value !== '}') {
                #     throw invalidToken()
                # }
                pop()
                return
            when 'eof'
                throw invalidEOF()
        # This code is unreachable since it's handled by the lexState.
        # throw invalidToken()
        return
    afterPropertyName: ->
        # This code is unreachable since it's handled by the lexState.
        # if (token.type !== 'punctuator' || token.value !== ':') {
        #     throw invalidToken()
        # }
        if token.type == 'eof'
            throw invalidEOF()
        parseState = 'beforePropertyValue'
        return
    beforePropertyValue: ->
        if token.type == 'eof'
            throw invalidEOF()
        push()
        return
    beforeArrayValue: ->
        if token.type == 'eof'
            throw invalidEOF()
        if token.type == 'punctuator' and token.value == ']'
            pop()
            return
        push()
        return
    afterPropertyValue: ->
        # This code is unreachable since it's handled by the lexState.
        # if (token.type !== 'punctuator') {
        #     throw invalidToken()
        # }
        if token.type == 'eof'
            throw invalidEOF()
        switch token.value
            when ','
                parseState = 'beforePropertyName'
                return
            when '}'
                pop()
        # This code is unreachable since it's handled by the lexState.
        # throw invalidToken()
        return
    afterArrayValue: ->
        # This code is unreachable since it's handled by the lexState.
        # if (token.type !== 'punctuator') {
        #     throw invalidToken()
        # }
        if token.type == 'eof'
            throw invalidEOF()
        switch token.value
            when ','
                parseState = 'beforeArrayValue'
                return
            when ']'
                pop()
        # This code is unreachable since it's handled by the lexState.
        # throw invalidToken()
        return
    end: ->
        # This code is unreachable since it's handled by the lexState.
        # if (token.type !== 'eof') {
        #     throw invalidToken()
        # }
        return
