parse = require('./parse')
stringify = require('./stringify')
json = require('./json')
JSON5 = 
    json: json
    parse: parse
    stringify: stringify
module.exports = JSON5
