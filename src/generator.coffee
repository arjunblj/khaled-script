
fs = require 'fs'

KEYWORD_TRANSLATE =
  'IS':'==='
  'ISNT':'!=='
  'AND':'&&'
  'OR':'||'
  'NOT':'!'

exports.load = (grammar) ->
  generator.apply(grammar)

generator = ->
  i = ''

  # 2 space indent/dedent
  indent = -> i += '  '
  dedent = -> i = i[0..-3]

  scopes = []
  scope = {}

  snippets = {}

  pushScope = ->
    scopes.push(scope)
    newScope = {}
    for k, v of scope
      if v is 'closureAllowed' or v is 'argument' or v is 'function'
        newScope[k] = 'closure'
      else if v is 'closure'
        newScope[k] = 'closure'
    scope = newScope

  popScope = (code, force_closed, wrap) ->

    ## gets the process, either khaledc or khaled
    compiling = /[^/]*$/.exec(process.argv[1])[0]
    wrap = false if compiling is 'khaledc'

    rv = i
    varNames = (varName for varName, type of scope when type not in ['closure', 'argument', 'function'])
    if wrap
      rv += '(function () {\n'
      indent()
      code = i + code.replace /\n/g, '\n  '
    if varNames.length > 0

      rv += '  var ' + varNames.join(', ') + ';\n' if varNames.length > 0
    rv += code
    if wrap
      dedent()
      rv += "\n#{i}})()\n"
    scope = scopes.pop() if scopes isnt []
    return rv

  self = @

  @File::js = ->
    i = ''
    scope = {}
    scopes = []
    snippets = {}
    code = (statement.js() for statement in @statements).join '\n'
    snip = (snippet for key, snippet of snippets).join('\n')
    rv = [snip, code].join '\n'
    comment.written = undefined for comment in @ts.comments
    return popScope(rv, yes, yes)

  @Statement::js = ->
    rv = ''
    for comment in @ts.comments when comment.line <= @line and not comment.written
      comment.written = yes
      rv += i + '/*' + comment.value + '*/'
    rv += i + @statement.js()
    return rv

  @ReturnStatement::js = ->
    return "return #{@expr.js()};"

  @ExpressionStatement::js = ->
    return "#{@expr.js()};"

  @Expression::js = ->
    return "#{@left.js()}" unless @op?
    opjs = @op.js()
    if opjs is 'in'
      unless snippets['in']?
        snippets['in'] = snippets['in']
        subscope['$kindexof'] = 'closure' for subscope in scopes
        scope['$kindexof'] = 'closure'
      return "$kindexof.call(#{@right.js()}, #{@left.js()}) >= 0"
    else
      return "#{@left.js()} #{opjs} #{@right.js()}"

  @UnaryExpression::js = ->
    rv = ''
    rv += KEYWORD_TRANSLATE[@preop.value] if @preop?.value?
    if @base.type is 'IDENTIFIER'
      rv += KEYWORD_TRANSLATE[@base.value] or @base.value
      scope[@base.value] = 'closureAllowed' unless scope[@base.value]? or not @is_lvalue()
    else
      rv += @base.js()
    rv += accessor.js() for accessor in @accessors
    return rv

  @PropertyAccess::js = ->
    if @expr.type is 'IDENTIFIER'
      rv = @expr.value
    else
      rv = @expr.js()
    return ".#{rv}"

  @AssignmentStatement::js = ->
    return "#{@lvalue.js()} #{@assignOp.value} #{@rvalue.js()};"

  @NumberConstant::js = ->
    return "#{@token.text}"

  @StringConstant::js = ->
    rv = @token.value
    if @token.value[0] is '"'
      r = /#{.*?}/g
      m = r.exec rv
      while m
        rv = rv[0...m.index] + '" + ' + rv[m.index+2...m.index+m[0].length-1] + ' + "' + rv[m.index+m[0].length..]
        m = r.exec rv
    return rv

  @BinOp::js = ->
    return KEYWORD_TRANSLATE[@op.value] or @op.value;

  @IfStatement::js = ->
    rv = "if (#{@conditional.js()}) {\n#{@trueBlock.js()}\n#{i}}"
    rv += @elseBlock.js() if @elseBlock?
    return rv

  @ElseStatement::js = ->
    if @falseBlock instanceof self.Statement and @falseBlock.statement instanceof self.IfStatement
      return " else #{@falseBlock.js()}"
    else
      return " else {\n#{@falseBlock.js()}\n#{i}}"

  @BlankStatement::js = ->
    return ''

  for_depth = 1
  @ForStatement::js = ->
    iterator   = "ki$#{for_depth}"
    terminator = "kobj$#{for_depth}"
    scope[iterator] = 'no closures'
    scope[terminator] = 'no closures'
    rv = "#{terminator} = #{@iterable.js()};\n#{i}for (#{iterator} = 0; #{iterator} < #{terminator}.length; #{iterator}++) {\n"
    indent()
    for_depth += 1
    rv += "#{i}#{@iterant.js()} = #{terminator}[#{iterator}];\n"
    rv += @loopBlock.js()
    for_depth -= 1
    dedent()
    rv += "\n#{i}}"
    return rv

  @WhileStatement::js = ->
    rv = "while (#{@expr.js()}) {\n"
    indent()
    rv += @block.js()
    dedent()
    rv += "\n#{i}}"
    return rv

  @Block::js = ->
    indent()
    rv = (statement.js() for statement in @statements).join '\n'
    dedent()
    return rv

  @ParenExpression::js = ->
    return "(#{@expr.js()})"

  @IndexExpression::js = ->
    return "[#{@expr.js()}]"

  @ListExpression::js = ->
    rv = (item.js() for item in @items).join(', ')
    return "[#{rv}]"

  @MapItem::js = ->
    return "#{@key.js()}: #{@val.js()}"

  @MapExpression::js = ->
    rv = (item.js() for item in @items).join(', ')
    return "{ #{rv} }"

  @FunctionExpression::js = ->
    rv = "function "
    if @name?
      rv += @name.value
      scope[@name.value] = 'function'
    arg_names = (argument.name.value for argument in @arguments)
    rv += "(#{arg_names.join(', ')}) {\n"
    pushScope()
    scope[arg_name] = 'argument' for arg_name in arg_names
    block_code = @block.js()
    block_code = popScope(block_code, false, false)
    rv += "#{block_code}\n#{i}}"

  @FunctionCall::js = ->
    rv = (argument.js() for argument in @arguments).join ', '
    return "(#{rv})"

  @FunctionCallArgument::js = ->
    return @val.js()

  snippets =
    'in': 'var $kindexof = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };'

