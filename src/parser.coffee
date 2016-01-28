
{GrammarFile, Grammar} = require './grammar'

exports.Grammar = Grammar

exports.parse = (tokens, comments) ->
  ts = new TokenStream(tokens, comments)
  AST = new GrammarFile(ts)
  return AST

class TokenStream
  constructor: (tokens, comments) ->
    @tokens = tokens
    @comments = comments
    @goToToken(0)

  next: ->
    return @goToToken(@index+1)

  prev: ->
    return @goToToken(@index-1)

  peek: (delta) ->
    @goToToken(@index + delta)
    token = @current
    @goToToken(@index - delta)
    return token

  goToToken: (index) ->
    @index = index
    if @index >= @tokens.length
      @current =
        type: 'EOF'
        text: ''
        line: 0
        value: ''
    else if @index < 0
      throw 'Not even at the start of the file yet'
    else
      @current = @tokens[@index]
    @type = @current.type
    @text = @current.text
    @value = @current.value
    @line = @current.line
    return @current

