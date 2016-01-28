
{ASTBase} = require './ast'

KEYWORDS = ['true','false', 'is']

Nodes = [
  # @todo: Port over Babel's name formatting.

  class File extends ASTBase
    parse: ->
      @lock()
      @statements = @optionalMultipleValues(Statement)
      @req 'EOF'

  class Block extends ASTBase
    parse: ->
      @req 'NEWLINE'
      @req 'INDENT'
      @lock()
      @statements = @optionalMultipleValues(Statement)
      @req 'DEDENT'

  class Statement extends ASTBase
    parse: ->
      @statement = @req(ReturnStatement, IfStatement, WhileStatement, ForStatement,
                        DeclarationStatement, AssignmentStatement, ExpressionStatement, BlankStatement)

  class IfStatement extends ASTBase
    parse: ->
      @requiredValue('IF')
      @lock()
      @conditional = @req Expression
      @trueBlock = @req Block, Statement
      @elseBlock = @opt ElseStatement

  class ElseStatement extends ASTBase
    parse: ->
      @requiredValue('ELSE')
      @lock()
      @falseBlock = @req Block, Statement

  class ReturnStatement extends ASTBase
    parse: ->
      # Because sometimes one of those flows better than the other /shrug.
      @requiredValue('BUTWEGONNA', 'WEGONNA')
      @lock()
      @expr = @opt Expression
      @req 'NEWLINE'

  class WhileStatement extends ASTBase
    parse: ->
      @requiredValue('BLESSUP')
      @lock()
      @expr = @req Expression
      @block = @req Block

  class ForStatement extends ASTBase
    parse: ->
      @requiredValue('ANOTHER')
      @lock()
      @iterant = @req UnaryExpression
      @requiredValue('IN')
      @iterable = @req Expression
      @loopBlock = @req Block

  class DeclarationStatement extends ASTBase
  class AssignmentStatement extends ASTBase
    parse: ->
      @requiredValue('MAJORKEY')
      @lvalue = @req UnaryExpression
      @assignOp = @req 'LITERAL'
      if @assignOp.value in ['+','-','*','/']
        @requiredValue '='
        @assignOp.value += '='
      else if @assignOp.value isnt '='
        @error "not a valid assignment operator: #{assignOp.value}" if @assignOp.value not in ['=']
      @lock()
      @error 'invalid assignment - the left side must be assignable' unless @lvalue.is_lvalue()
      @rvalue   = @req Expression
      @req 'NEWLINE'


  class ExpressionStatement extends ASTBase
    parse: ->
      @expr = @req Expression


  class BlankStatement extends ASTBase
    parse: ->
      @req 'NEWLINE'


  class BinOp extends ASTBase
    parse: ->
      @op = @req 'IDENTIFIER', 'LITERAL'
      if @op.type is 'LITERAL'
        @error "unexpected operator #{@op.value}" if @op.value in [')',']','}',';',':',',']
        @lock()
        @error "unexpected operator #{@op.value}" if @op.value not in ['+','-','*','/','>','<']
      else
        @error "unexpected operator #{@op.value}" if @op.value not in ['AND','OR','XOR','IN','IS','ISNT', 'DONTALK']


  class Expression extends ASTBase
    parse: ->
      @left  = @req UnaryExpression
      @op    = @opt BinOp
      if @op?
        @lock()
        @right = @req Expression


  class UnaryExpression extends ASTBase
    is_lvalue: ->
      return false if @base.constructor in [NumberConstant, StringConstant]
      return false if @base.value in KEYWORDS
      for accessor in @accessors
        return false if accessor instanceof FunctionCall
      return true
    parse: ->
      @preop = @optionalValue 'not'
      @base = @req ParenExpression, ListExpression, MapExpression, FunctionExpression, NumberConstant, StringConstant, 'IDENTIFIER'
      @accessors = @optionalMultipleValues(IndexExpression, FunctionCall, PropertyAccess)


  class NumberConstant extends ASTBase
    parse: ->
      @token = @req 'NUMBER'


  class StringConstant extends ASTBase
    parse: ->
      @token = @req 'STRING'


  class IndexExpression extends ASTBase
    parse: ->
      @requiredValue '['
      @lock()
      @expr = @req Expression
      @requiredValue ']'


  class PropertyAccess extends ASTBase
    parse: ->
      @requiredValue '.'
      @lock()
      @expr = @req FunctionExpression, 'IDENTIFIER'


  class FunctionCallArgument extends ASTBase
    parse: ->
      @val = @req Expression
      @lock()
      if @requiredValue(',',')').value is ')'
        @ts.prev()


  class FunctionCall extends ASTBase
    parse: ->
      @requiredValue '('
      @lock()
      @arguments = @optionalMultipleValues(FunctionCallArgument)
      @requiredValue ')'


  class ParenExpression extends ASTBase
    parse: ->
      @requiredValue '('
      @lock()
      @expr = @req Expression
      @requiredValue ')'


  class ListExpression extends ASTBase
    parse: ->
      @requiredValue '['
      @lock()
      @items = []
      item = @opt Expression
      while item
        @items.push item
        if @optionalValue ','
          item = @opt Expression
        else
          item = null
      @requiredValue ']'


  class MapItem extends ASTBase
    parse: ->
      @key = @req Expression
      @requiredValue(':')
      @lock()
      @val = @req Expression
      @end_token = @requiredValue ',', '}'
      if @end_token.value is '}'
        @ts.prev()


  class MapExpression extends ASTBase
    parse: ->
      @requiredValue '{'
      @lock()
      @items = @optionalMultipleValues(MapItem)
      @requiredValue '}'


  class FunctionDefArgument extends ASTBase
    parse: ->
      @name = @req 'IDENTIFIER'
      @lock()
      if @requiredValue(',',')').value is ')'
        @ts.prev()

  class FunctionExpression extends ASTBase
    parse: ->
      @specifier = @requiredValue 'THEYDONTWANTUSTO'
      @lock()
      @name = @opt 'IDENTIFIER'
      @requiredValue '('
      @arguments = @optionalMultipleValues(FunctionDefArgument)
      @requiredValue ')'
      @block = @req Block
]

exports.Grammar = {}
exports.Grammar[v.name] = v for v in Nodes when v.__super__?.constructor is ASTBase
exports.GrammarFile = exports.Grammar.File
