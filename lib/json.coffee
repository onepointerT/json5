
parse = require('./parse')
stringify = require('./stringify')


module.exports.get =  (text) ->
    return parse(text, JsonObject.reviver)

module.exports.getFromFile = (path) ->
    fd = await open path, 'r'
    fc = fd.createReadStream()
    return get fc

module.exports.toFile = (json_obj, path) ->
    fd = await open path, 'rw'
    fc = fd.createWriteStream stringify json_obj, { space: 2, quote: "'" }