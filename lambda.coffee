# This is a different kind of runtime.
# Each iteration involves a beta-reduction of the AST until we reach a destination form.

# There are only three types of nodes in our language: atoms, function calls, and function definitions.
# Everybody knows how to perform a substitution on themselves.

# What we want to do:
# 1. Make each tree node unique so that we can store pointers to describe information
# 2. Have reduce() store pointers to the old nodes in the old tree and the new nodes in the new tree.
# 3. Trees render with pointers to their render images, so that we can post-manipulate and do handlers and stuff.
# 4. Have atoms point to the lambda definitions that create them, to show scoping.

class Atom
  constructor: (@name, @new = false) ->

  substitute: (name, value, excludes = []) ->
    if name is @name and name not in excludes
      return value.flagNew()
    else
      return new Atom @name

  serialize: ->
    result = @name
    if @new
      result = "<span class='new'>#{result}</span>"
    return result

  reduce: -> return @

  reducible: -> false

  flagNew: -> new Atom @name, true
  clearFlags: -> new Atom @name, false

class CallNode
  constructor: (@fn, @arg, @new = false) ->

  substitute: (name, value, excludes = []) ->
    return new CallNode @fn.substitute(name, value), @arg.substitute(name, value)

  # We beta-reduce the topmost call node
  reduce: ->
    if @fn instanceof DefineNode
      return @fn.body.substitute(@fn.param, @arg)
    else if @fn instanceof CallNode
      return new CallNode @fn.reduce(), @arg
    else
      return new CallNode @fn, @arg.reduce()

  reducible: ->
    if @fn instanceof DefineNode
      return true
    else if @fn instanceof CallNode
      return true
    else
      return @arg.reducible()

  serialize: ->
    result = "(#{@fn.serialize()} #{@arg.serialize()})"
    if @new
      result = "<span class='new'>#{result}</span>"
    return result

  flagNew: -> new CallNode(@fn, @arg, true)

  clearFlags: -> new CallNode @fn.clearFlags(), @arg.clearFlags(), false

class DefineNode
  constructor: (@param, @body, @new = false) ->

  substitute: (name, value, excludes = []) ->
    return new DefineNode @param, @body.substitute(name, value, excludes.concat[@param])

  serialize: ->
    result = "\u03BB#{@param}.#{@body.serialize()}"
    if @new
      result = "<span class='new'>#{result}</span>"
    return result

  # Bubble down until we find a topmost call node to beta-reduce.
  reduce: ->
    return new DefineNode @param, @body.reduce()

  reducible: -> @body.reducible()

  flagNew: -> new DefineNode @param, @body, true

  clearFlags: -> new DefineNode @param, @body.clearFlags(), false

evaluate = (node) ->
  while node.reducible()
    console.log node.serialize()
    node = node.clearFlags()
    node = node.reduce()
  console.log node.serialize()

parse = (str) ->
  str = str.trim()

  # Call node
  if str[0] is '('
    depth = 0; i = 1
    until depth is 0 and str[i] is ' '
      if str[i] is ')' then depth += -1
      if str[i] is '(' then depth += 1
      i += 1

    prefix = str[1...i]
    suffix = str[i + 1...-1]

    return new CallNode parse(prefix), parse(suffix)

  # Define node
  else if str[0] is '\u03BB'

    param = str[1...str.indexOf('.')]
    body = str[str.indexOf('.') + 1..]

    return new DefineNode param, parse(body)

  # Atom
  else
    return new Atom str

evaluate parse '(lsucc.(succ (succ (succ lx.ly.y))) ln.lf.lx.(f ((n f) x)))'.replace(/l/g, '\u03BB')
