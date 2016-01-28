
class ASTBase
  """A base AST class that's used to construct a syntax tree."""

  constructor: (ts) ->

    # Used to throw syntax errors.
    @locked = false
    @ts = ts
    @line = ts.line
    @parse()

  opt: ->
    """Generate the appropriate expression from the token stream.
    """
    rv = null
    originalIndex = @ts.index
    for cls in arguments
      if typeof cls is 'string'
        if @ts.type is cls
          rv = @ts.current
          @ts.next()
          return rv
      else
        try
          rv = new cls @ts
          return rv
        catch e
          @ts.goToToken(originalIndex)
          throw e if e instanceof SyntaxError

  req: ->
    """For required values, i.e. if statements always have to start with an
       `if`. This is always going to be implemented where this is subclassed.
    """
    rv = @opt.apply(@, arguments)
    return rv if rv?

    list = (cls.name or cls for cls in arguments)
    if list.length is 1
      message = "Expected #{list[0]}"
    else
      message = "Expected one of #{list.join(', ')}"
    @error("#{message}")

  optionalValue: ->
    if @ts.value in arguments
      rv = @ts.current
      @ts.next()
      return rv
    else
      return null

  requiredValue: ->
    rv = @optionalValue.apply(@, arguments)
    return rv if rv?
    @error("Expected #{(v for v in arguments).join(' or ')}")

  optionalMultipleValues: ->
    cls = @opt.apply(@, arguments)
    return [] unless cls?
    rv = [cls]
    while cls?
      cls = @opt.apply(@, arguments)
      rv.push cls if cls?
    return rv

  # Some (very basic) error handling.
  parse: -> @error "Bruh no way to parse #{@constructor.name} yet."
  js: -> @error "#{@constructor.name} lol good try"
  error: (msg) ->
    if @locked
      throw new SyntaxError msg
    else
      throw new ParseFailed msg

  lock: -> @locked = true

class ParseFailed extends Error
  constructor: (@message) -> super

class SyntaxError extends ParseFailed

module.exports =
  SyntaxError: SyntaxError
  ASTBase: ASTBase
