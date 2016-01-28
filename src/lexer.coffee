
exports.tokenize = (code) ->
  """Pass the code to the Lexer and tokenize it."""
  lex = new Lexer(code)
  return [lex.tokens, lex.comments]

exports.Lexer = class Lexer
  constructor: (code, lineNumber) ->
    @code = code
    @line = lineNumber or 1

    # @todo when it's not 3am -- figure out a better way of parsing indents...
    @indent = 0
    @indents = []
    @tokenize()

  tokenize: ->
    """The most important bit of code in the program, this is where code is
       tokenized and 'types' are determined.

       This is done with the bit of RegEx at the bottom which pattern matches to
       specific types. From there, tokens are generated.
    """
    @tokens = []
    @comments = []
    lastTokenType = null
    index = 0

    while index < @code?.length
      chunk = @code[index..]
      for [regex, type] in tokenTypes
        text = regex.exec(chunk)?[0]
        if text?
          @type = type
          break

      @error "Not a valid token." unless text?

      value = parseTokens[@type](text)

      # @todo: test against tabs, but like, who's dumb enough to use tabs?
      if lastTokenType is 'NEWLINE'
        @handleIndentation(type, text)

      if type is 'COMMENT'
        @comments.push(text:text, line:@line, value:value, type:type)
      else if type isnt 'WHITESPACE'
        @tokens.push(text:text, line:@line, value:value, type:type)

      index += text.length

      @line += /\n/.exec(text)?[0].length or 0
      lastTokenType = type

    # For pesky indents at the end of a file.
    @handleIndentation('NEWLINE', '')

  handleIndentation: (type, text) ->
    """Because we like whitespace!"""
    indentation = if type is 'WHITESPACE' then text.length else 0

    if indentation > @indent
      @indents.push(@indent)
      @indent = indentation
      @tokens.push(text:text, line:@line, value:'', type:'INDENT')
    else if indentation < @indent
      while @indents.length > 0 and indentation < @indent
        @indent = @indents.pop()
        @error 'Misaligned indentation.' if indentation > @indent
        @tokens.push(text:text, line:@line, value:'', type:'DEDENT')
      @error 'Misaligned indentation.' if indentation isnt @indent

  error: (message) ->
    throw message


parseTokens =
  NUMBER: (text) -> return Number(text)
  STRING: (text) -> return text
  IDENTIFIER: (text) -> return text
  NEWLINE: (text) -> return ''
  WHITESPACE: (text) -> return ' '
  COMMENT: (text) -> return (if text[1] is '#' then text[3..-4] else text[1..-1]).replace /(\/\*)|(\*\/)/g, '**'
  LITERAL: (text) -> return text.replace /[\f\r\t\v\u00A0\u2028\u2029 ]/, ''


tokenTypes = [
  [/^###([^#][\s\S]*?)(?:###[^\n\S]*|(?:###)?$)|^(?:\s*#(?!##[^#]).*)+/, 'COMMENT'],
  [/^0x[a-f0-9]+/i, 'NUMBER'],
  [/^[0-9]+(\.[0-9]+)?(e[+-]?[0-9]+)?/i, 'NUMBER'],
  [/^'([^']*(\\'))*[^']*'/, 'STRING'],
  [/^"([^"]*(\\"))*[^"]*"/, 'STRING'],
  [/^[$A-Za-z_\x7f-\uffff][$\w\x7f-\uffff]*/, 'IDENTIFIER'],
  [/^(\r*\n\r*)+/, 'NEWLINE'],
  [/^[\f\r\t\v\u00A0\u2028\u2029 ]+/, 'WHITESPACE'],
  [/^[\+\-\*\/\^\=\.><\(\)\[\]\,\.\{\}\:]/, 'LITERAL']
]

