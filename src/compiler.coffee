
fs = require 'fs'
path = require 'path'

{tokenize} = require './lexer'
{parse, Grammar} = require './parser'
{load} = require './generator'

getCompiledPath = (filePath, extname) ->
  pathExtension = path.extname filePath
  endIndex = filePath.length - pathExtension.length
  return filePath.substring(0, endIndex) + '.' + extname

exports.compile = ->
  code = fs.readFileSync process.argv[2] if process.argv[2]?
  [tokens, comments] = tokenize(code)
  node = parse(tokens, comments)
  load(Grammar)
  eval(node.js())

exports.writeToJS = ->
  compilePath = process.argv[2]
  code = fs.readFileSync compilePath if compilePath?
  [tokens, comments] = tokenize(code)
  node = parse(tokens, comments)
  load(Grammar)
  js = node.js()
  if fs.existsSync process.argv[2]
    # Compile .dj -> .js
    jsPath = getCompiledPath compilePath, 'js'
    fs.writeFileSync jsPath, js
    console.log "They don't want us to write khaled-script so we gonna write *more*.\n(#{compilePath}) -> (#{jsPath})"
  else
    console.log 'File does not exist - ' + compilePath
