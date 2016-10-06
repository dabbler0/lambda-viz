# This is a different kind of runtime.
# Each iteration involves a beta-reduction of the AST until we reach a destination form.

# There are only three types of nodes in our language: atoms, function calls, and function definitions.
# Everybody knows how to perform a substitution on themselves.

# What we want to do:
# 1. Make each tree node unique so that we can store pointers to describe information
# 2. Have reduce() store pointers to the old nodes in the old tree and the new nodes in the new tree.
# 3. Trees render with pointers to their render images, so that we can post-manipulate and do handlers and stuff.
# 4. Have atoms point to the lambda definitions that create them, to show scoping.

_id = 0

class Atom
  constructor: (@name) ->
    @id = _id++

  substitute: (name, value, record, excludes = []) ->
    if name is @name and name not in excludes
      newValue = value.clone()

      record.changes.push {
        old: @,
        new: newValue
      }

      return newValue

    else
      return new Atom @name

  serialize: ->
    result = @name
    return result

  render: ->
    @element = document.createElement 'div'
    @element.className = 'atom'
    @element.innerText = @name
    return @element

  reduce: -> return @

  reducible: -> false

  clone: -> new Atom @name

class CallNode
  constructor: (@fn, @arg) ->
    @id = _id++

  render: ->
    @element = document.createElement 'div'
    @element.className = 'call-node'
    @element.appendChild @fn.render()
    @element.appendChild @arg.render()
    return @element

  substitute: (name, value, record, excludes = []) ->
    return new CallNode @fn.substitute(name, value, record, excludes), @arg.substitute(name, value, record, excludes)

  # We beta-reduce the topmost call node
  reduce: (record) ->
    if @fn instanceof DefineNode
      record.resolved = @
      record.result = @fn.body.substitute(@fn.param, @arg, record)
      return record.result
    else if @fn instanceof CallNode
      return new CallNode @fn.reduce(record), @arg
    else
      return new CallNode @fn, @arg.reduce(record)

  reducible: ->
    if @fn instanceof DefineNode
      return true
    else if @fn instanceof CallNode
      return true
    else
      return @arg.reducible()

  serialize: ->
    result = "(#{@fn.serialize()} #{@arg.serialize()})"
    return result

  clone: -> new CallNode @fn.clone(), @arg.clone()

class DefineNode
  constructor: (@param, @body) ->
    @id = _id++

  render: ->
    @element = document.createElement 'div'
    @element.className = 'define-node'

    @paramElement = document.createElement 'div'
    @paramElement.className = 'param'
    @paramElement.innerText = @param

    @element.appendChild @paramElement

    @element.appendChild @body.render()

    return @element

  substitute: (name, value, record, excludes = []) ->
    return new DefineNode @param, @body.substitute(name, value, record, excludes.concat([@param]))

  serialize: ->
    result = "\u03BB#{@param}.#{@body.serialize()}"
    return result

  # Bubble down until we find a topmost call node to beta-reduce.
  reduce: (record)->
    return new DefineNode @param, @body.reduce(record)

  reducible: -> @body.reducible()

  clone: -> new DefineNode @param, @body.clone()

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

###
evaluate = (node) ->
  while node.reducible()
    console.log node.serialize()
    node = node.clearFlags()
    node = node.reduce()
  console.log node.serialize()

evaluate parse '(lsucc.(succ (succ (succ lx.ly.y))) ln.lf.lx.(f ((n f) x)))'.replace(/l/g, '\u03BB')
###

document.getElementById('go').addEventListener 'click', ->
  text = document.getElementById('input').value
  tree = parse text.replace /l/g, '\u03BB'

  output = document.getElementById('output')
  output.innerHTML = ''

  div = document.createElement 'div'
  div.className = 'output-row'
  div.appendChild tree.render()
  output.appendChild div

  output.appendChild document.createElement 'hr'

  tick = ->
    record = {changes: [], resolved: null, result: null}

    if tree.reducible()
      tree = tree.clone()

      div = document.createElement 'div'
      div.className = 'output-row'
      div.appendChild tree.render()
      output.appendChild div

      newtree = tree.reduce(record)

      div = document.createElement 'div'
      div.className = 'output-row'
      div.appendChild newtree.render()
      output.appendChild div

      for el, i in record.changes
        el.old.element.className += ' old'
        el.new.element.className += ' new'

      record.resolved.element.className += ' resolved-parent'
      record.resolved.fn.body.element.className += ' resolved'
      record.resolved.arg.element.className += ' new'
      record.result.element.className += ' resolved'

      output.appendChild document.createElement 'hr'

      tree = newtree

      setTimeout tick, 100

  do tick
