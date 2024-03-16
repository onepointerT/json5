util = require('./util')

module.exports = (value, replacer, space) ->
    stack = []
    indent = ''
    propertyList = undefined
    replacerFunc = undefined
    gap = ''
    quote = undefined

    serializeProperty = (key, holder) ->
        `var value`
        value = holder[key]
        if value != null
            if typeof value.toJSON5 == 'function'
                value = value.toJSON5(key)
            else if typeof value.toJSON == 'function'
                value = value.toJSON(key)
        if replacerFunc
            value = replacerFunc.call(holder, key, value)
        if value instanceof Number
            value = Number(value)
        else if value instanceof String
            value = String(value)
        else if value instanceof Boolean
            value = value.valueOf()
        switch value
            when null
                return 'null'
            when true
                return 'true'
            when false
                return 'false'
        if typeof value == 'string'
            return quoteString(value, false)
        if typeof value == 'number'
            return String(value)
        if typeof value == 'object'
            return if Array.isArray(value) then serializeArray(value) else serializeObject(value)
        undefined

    quoteString = (value) ->
        quotes = 
            '\'': 0.1
            '"': 0.2
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
        product = ''
        i = 0
        while i < value.length
            c = value[i]
            switch c
                when '\'', '"'
                    quotes[c]++
                    product += c
                    i++
                    continue
                when '\u0000'
                    if util.isDigit(value[i + 1])
                        product += '\\x00'
                        i++
                        continue
                        break
            if replacements[c]
                product += replacements[c]
                i++
                continue
            if c < ' '
                hexString = c.charCodeAt(0).toString(16)
                product += '\\x' + ('00' + hexString).substring(hexString.length)
                i++
                continue
            product += c
            i++
        quoteChar = quote || Object.keys(quotes).reduce((a, b) => if quotes[a] < quotes[b] then a else b)
        product = product.replace(new RegExp(quoteChar, 'g'), replacements[quoteChar])
        quoteChar + product + quoteChar

    serializeObject = (value) ->
        if stack.indexOf(value) >= 0
            throw TypeError('Converting circular structure to JSON5')
        stack.push value
        stepback = indent
        indent = indent + gap
        keys = propertyList or Object.keys(value)
        partial = []
        for key of keys
            propertyString = serializeProperty(key, value)
            if propertyString != undefined
                member = serializeKey(key) + ':'
                if gap != ''
                    member += ' '
                member += propertyString
                partial.push member
        final = undefined
        if partial.length == 0
            final = '{}'
        else
            properties = undefined
            if gap == ''
                properties = partial.join(',')
                final = '{' + properties + '}'
            else
                separator = ',\n' + indent
                properties = partial.join(separator)
                final = '{\n' + indent + properties + ',\n' + stepback + '}'
        stack.pop()
        indent = stepback
        final

    serializeKey = (key) ->
        if key.length == 0
            return quoteString(key, true)
        firstChar = String.fromCodePoint(key.codePointAt(0))
        if !util.isIdStartChar(firstChar)
            return quoteString(key, true)
        i = firstChar.length
        while i < key.length
            if !util.isIdContinueChar(String.fromCodePoint(key.codePointAt(i)))
                return quoteString(key, true)
            i++
        key

    serializeArray = (value) ->
        `var properties`
        if stack.indexOf(value) >= 0
            throw TypeError('Converting circular structure to JSON5')
        stack.push value
        stepback = indent
        indent = indent + gap
        partial = []
        i = 0
        while i < value.length
            propertyString = serializeProperty(String(i), value)
            partial.push if propertyString != undefined then propertyString else 'null'
            i++
        final = undefined
        if partial.length == 0
            final = '[]'
        else
            if gap == ''
                properties = partial.join(',')
                final = '[' + properties + ']'
            else
                separator = ',\n' + indent
                properties = partial.join(separator)
                final = '[\n' + indent + properties + ',\n' + stepback + ']'
        stack.pop()
        indent = stepback
        final

    if replacer != null and typeof replacer == 'object' and !Array.isArray(replacer)
        space = replacer.space
        quote = replacer.quote
        replacer = replacer.replacer
    if typeof replacer == 'function'
        replacerFunc = replacer
    else if Array.isArray(replacer)
        propertyList = []
        for v of replacer
            item = undefined
            if typeof v == 'string'
                item = v
            else if typeof v == 'number' or v instanceof String or v instanceof Number
                item = String(v)
            if item != undefined and propertyList.indexOf(item) < 0
                propertyList.push item
    if space instanceof Number
        space = Number(space)
    else if space instanceof String
        space = String(space)
    if typeof space == 'number'
        if space > 0
            space = Math.min(10, Math.floor(space))
            gap = '          '.substr(0, space)
    else if typeof space == 'string'
        gap = space.substr(0, 10)
    serializeProperty '', '': value
