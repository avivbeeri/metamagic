import "meta" for Meta
import "dome" for Window, Process, Platform, Log
import "graphics" for Canvas, Color, Font
import "text" for TextSplitter
import "collections" for PriorityQueue, Queue, Set, HashMap, Stack
import "math" for Vec, Elegant, M
import "json" for Json
import "random" for Random
import "jukebox" for Jukebox
import "input" for Keyboard, Clipboard

// This checks by time tick first, and then the lower ID goes first, to preserve turn order
// If entities are not sorted in a stable manner they might get double-moves
var TURN_ORDER_COMPARATOR = Fn.new {|a, b| a[0][0] < b[0][0] || (a[0][0] == b[0][0] && a[1] < b[1]) }

class Scheduler {
  static init() {
    if (__deferred) {
      return
    }
    __deferred = PriorityQueue.min()
    __tick = 0
  }

  static defer(fn) {
    if (__tick == null) {
      Scheduler.init()
    }
    __deferred.add(Fiber.new {
      fn.call()
      runNext()
    }, __tick + 1)
  }

  static deferBy(tick, fn) {
    if (__tick == null) {
      Scheduler.init()
    }
    __deferred.add(Fiber.new {
      fn.call()
      runNext()
    }, (__tick + tick).max(__tick + 1))
  }

  static runNext() {
    if (!__deferred.isEmpty && __deferred.peekPriority() <= __tick) {
      var fiber = __deferred.remove()
      fiber.call()
      if (!fiber.isDone) {
        __deferred.add(fiber, __tick + 1)
      }
    }
  }

  static runUntilEmpty() {
    while (!__deferred.isEmpty && __deferred.peekPriority() <= __tick) {
      var fiber = __deferred.remove()
      fiber.call()
      if (!fiber.isDone) {
        __deferred.add(fiber, __tick + 1)
      }
    }
  }

  static tick() {
    __tick = __tick + 1
    runNext()
  }
}

var SCALE = 1
var MAX_TURN_SIZE = 30

class Stateful {
  construct new() {
    _data = {}
  }
  construct new(data) {
    _data = {}
    for (key in data.keys) {
      _data[key] = data[key]
    }
  }

  assign(other) {
    if (other is Stateful) {
      other = other.data
    }
    if (!(other is Map)) {
      Fiber.abort("Cannot assign %(other) to %(this)")
    }

    for (entry in other) {
      data[entry.key] = Stateful.copyValue(entry.value)
    }
  }

  static assign(first, other) {
    if (first is Stateful) {
      first = first.data
    }
    if (other is Stateful) {
      other = other.data
    }
    for (entry in other) {
      first[entry.key] = Stateful.copyValue(entry.value)
    }
  }

  static copyValue(value) {
    if (value is Map) {
      var copy = {}
      for (key in value.keys) {
        copy[key] = Stateful.copyValue(value[key])
      }
      return copy
    }
    if (value is List) {
      return value.map {|entry| Stateful.copyValue(entry) }.toList
    }
    return value
  }

  data { _data }
  [key] { _data[key] }
  [key]=(v) { _data[key] = v }
  has(prop) { _data.containsKey(prop) && _data[prop] != null }
  serialize() { _data }
  deserialize(data) {
    _data = data
  }
}

class Parcel is Stateful {
  static create(name, members, isReadOnly) {
    if (name.type != String || name == "") Fiber.abort("Name must be a non-empty string.")
    if (!members) {
      members = []
    }
    var originalName = name
    name = TextSplitter.capitalize(name + "_")
    var args = members.join(", ")
    var s = ""
    s = s + "class %(name) is Parcel {\n"
    s = s + "  construct new() {\n"
    s = s + "    super() \n"
    s = s + "  }\n"
    for (member in members) {
      s = s + "  %(member) { data[\"%(member)\"] }\n"
      if (!isReadOnly) {
        s = s + "  %(member)=(v) { data[\"%(member)\"] = v }\n"
      }
    }
    s = s + "}\n"
    // System.print(s)
    s = s + "return %(name)\n"
    return Meta.compile(s).call()
  }
}

class Event is Stateful {
  construct new() {
    super()
    _cancelled = false
    // lower is better
    _priority = 1
    _turn = null
  }
  priority=(v) { _priority = v }
  priority { _priority }
  turn=(v) { _turn = v }
  turn { _turn }

  cancel() {
    _cancelled = true
  }
  cancelled { _cancelled }
  // Creates a class for the Enum (with an underscore after the name to avoid duplicate definition)
  // and returns a reference to it.
  static create(name, members) {
    if (name.type != String || name == "") Fiber.abort("Name must be a non-empty string.")
    if (!members) {
      members = []
    }
    var originalName = name
    name = TextSplitter.capitalize(name +  "Event_")
    var args = members.join(", ")
    var s = ""
    s = s + "#!component(id=\"%(originalName)\", group=\"event\")\n"
    s = s + "class %(name) is Event {\n"
    s = s + "  construct new(%(args)) {\n"
    s = s + "    super() \n"
    for (member in members) {
      s = s + "    data[\"%(member)\"] = %(member)\n"
    }
    s = s + "  }\n"
    for (member in members) {
      s = s + "  %(member) { data[\"%(member)\"] }\n"
    }
    s = s + "}\n"
    s = s + "return %(name)\n"
    return Meta.compile(s).call()
  }
}
// Generate events for general use
var TurnEvent = Event.create("turn", ["turn"])
var GameEndEvent = Event.create("gameEnd", ["win"])
var ChangeZoneEvent = Event.create("changeZone", ["floor"])
var EntityAddedEvent = Event.create("entityAdded", ["entity"])
var EntityRemovedEvent = Event.create("entityRemoved", ["entity"])


class EntityState {
  static active { 2 }
  static inactive { 1 }
  static removed { 0 }
}
class Entity is Stateful {
  construct new() {
    super()
    state = EntityState.active
    pos = Vec.new()
    size = Vec.new(1, 1)
    zone = 0
    _actions = Queue.new()
    _events = Queue.new()
    _lastTurn = 0
    _lastCost = 0
  }

  nextTime { _lastTurn + _lastCost * speed }
  pushAction(action) { _actions.add(action) }

  bind(ctx, id) {
    data["id"] = id
    _ctx = ctx
    return this
  }

  id { data["id"] }
  ctx { _ctx }
  events { _events }

  state { data["state"] }
  state=(v) { data["state"] = v }
  zone { data["zone"] }
  zone=(v) { data["zone"] = v }
  pos { data["pos"] }
  pos=(v) { data["pos"] = v }
  size { data["size"] }
  size=(v) { data["size"] = v }
  speed { 1 }
  lastTurn { _lastTurn }
  lastTurn=(v) { _lastTurn = v }
  lastCost { _lastCost }
  lastCost=(v) { _lastCost = v }

  // Entities don't update themselves
  // They supply the next action they want to perform
  // and the "world" applies it.
  hasActions() { !_actions.isEmpty }
  getAction() {
    return _actions.dequeue() || Action.none
  }
  endTurn() {}

  spaces {
    var result = []
    var d = Vec.new()
    for (dy in 0...size.y) {
      for (dx in 0...size.x) {
        d.x = dx
        d.y = dy
        result.add(pos + d)
      }
    }
    return result
  }
  occupies(vec) { occupies(vec.x, vec.y) }
  occupies(x, y) {
    return pos != null &&
           pos.x <= x &&
           x <= pos.x + size.x - 1 &&
           pos.y <= y &&
           y <= pos.y + size.y - 1
  }

  name { data["name"] }
  toString { name ? name : "%(this.type.name) (id: %(id))" }

  ref { EntityRef.new(ctx, id) }
}

class BehaviourEntity is Entity {
  construct new() {
    super()
    _behaviours = Stack.new()
  }
  behaviours { _behaviours }
  removeBehaviour(b) {
    var temp = Stack.new()
    while (!_behaviours.isEmpty) {
      var behaviour = _behaviours.remove()
      if (b == behaviour) {
        continue
      }
      temp.add(behaviour)
    }
    while (!temp.isEmpty) {
      _behaviours.add(temp.remove())
    }
  }

  getAction() {
    // behaviours can push their own actions onto the queue
    // Variants could use a priority queue to do the
    // most critical thing if there's multiple options
    for (behaviour in _behaviours) {
      var result = behaviour.update(ctx, this)
      if (result == true) {
        break
      }
    }
    return super.getAction()
  }
}


class State is Stateful {
  construct new() {
    _events = Queue.new()
  }
  events { _events }
  process(event) {}
  onEnter() {}
  update() { this }
  onExit() {}
}


// ==================================

class ActionResult {
  static success { ActionResult.new(true) }
  static failure { ActionResult.new(false) }
  static valid { ActionResult.new(true, false) }
  static invalid { ActionResult.new(false, true) }

  construct new(success) {
    _success = success
    _invalid = false
    _alt = null
  }
  construct new(success, invalid) {
    _success = success
    _invalid = invalid
    _alt = null
  }

  construct alternate(action) {
    _success = true
    _invalid = false
    _alt = action
  }

  alternate { _alt }
  succeeded { _success }
  invalid { _invalid }
  toString { "ActionResult [%(succeeded), %(alternate)]"}
}
// ==================================

class Action is Stateful {
  static none { NoAction }
  construct new() {
    super()
  }
  withArgs(args) {
    for (entry in args) {
      if (!data.containsKey(entry.key)) {
        data[entry.key] = entry.value
      }
    }
    return this
  }

  bind(entity) {
    _source = entity
    return this
  }

  evaluate() {
    return ActionResult.success
  }
  perform() {
    return ActionResult.success
  }
  cost() { MAX_TURN_SIZE }

  ctx { _source.ctx }
  src { _source }
  source { _source }
  toString { (this.type == Action) ? "<no action>" : "<%(this.type.name)>" }
}
var NoAction = Action.new()

class TargetGroup is Stateful {
  construct new(spec) {
    super()
    data["exclude"] = []
    assign(spec)
  }

  area { data["area"] || 0 }
  area=(v) { data["area"] = v }
  origin { data["origin"] }
  origin=(v) { data["origin"] = v }
  mode { data["target"] }
  mode=(v) { data["target"] }
  exclude { data["exclude"] }
  needSight { data["needSight"] }

  requireSelection { mode == "area" }

  spaces() {
    // Return valid spaces for this target group
    var spaces = []
    for (dy in (-area)..(area)) {
      for (dx in (-area)..(area)) {
        var x = (origin.x + dx)
        var y = (origin.y + dy)
        var pos = Vec.new(x, y)
        if (exclude.contains(pos)) {
          continue
        }
        if (needSight && !ctx.zone.map["visible"]) {
          continue
        }
        spaces.add(pos)
      }
    }
    return spaces
  }

  distance(entity) {
    if (entity == null) {
      return Num.infinity
    }
    return Line.chebychev(origin, entity.pos)
  }

  entities(ctx, src) {
    var tileEntities = []
    var tiles = [ src.pos ]
    if (mode == "area" || mode == "nearest") {
      tiles = spaces()
    } else if (mode == "random") {
      tiles = [ RNG.sample(spaces()) ]
    }

    for (space in tiles) {
      tileEntities.addAll(ctx.getEntitiesAtPosition(space))
    }
    if (mode == "nearest") {
      var nearestTarget = tileEntities.reduce(null) {|acc, item|
        if (item == src) {
          return acc
        }
        if (item == null || distance(acc) > distance(item)) {
          return item
        }
        return acc
      }
      if (nearestTarget) {
        tileEntities = [ nearestTarget ]
      } else {
        tileEntities = []
      }
    }

    var targets = HashMap.new()
    for (target in tileEntities) {
      targets[target.id] = target
    }

    return targets.values.toList
  }
}

class Turn is Entity {
  construct new() {
    super()
    pos = null
    _turn = 1
    lastTurn = 0
  }
  name { "Turn Marker" }
  getAction() {
    return DeclareTurnAction.new(_turn)
  }
  endTurn() {
    _turn = _turn + 1
  }
}

class DeclareTurnAction is Action {
  construct new(turn) {
    super()
    _turn = turn
  }
  perform() {
    Log.i("=====  TURN %(_turn) =====")
    ctx.addEvent(TurnEvent.new(_turn))
    return ActionResult.success
  }
  cost() { MAX_TURN_SIZE }
}

// Weak reference
class EntityRef {
  construct new(ctx, id) {
    _id = id
    _ctx = ctx
  }
  id { _id }
  hash() { _id }
  pushAction(action) {
    var actor = _ctx.getEntityById(_id)
    if (actor != null) {
      actor.pushAction(action)
    }
  }

  pos {
    var actor = _ctx.getEntityById(_id)
    if (actor != null) {
      return actor.pos
    }
    return Vec.new()
  }
  pos=(v) {
    var actor = _ctx.getEntityById(_id)
    if (actor != null) {
      actor.pos = v
    }
  }

  serialize() {
    return ({ "id": _id })
  }
}

class Zone is Stateful {
  construct new(map) {
    super()
    _map = map
  }
  map { _map }
  ctx { _ctx }
  ctx=(v) { _ctx = v }
  serialize() {
    var out = Stateful.copyValue(data)
    out["map"] = _map.serialize()
    return out
  }

  cost(a, b) {
    if (ctx.getEntitiesAtPosition(b).isEmpty) {
      return _map.cost(a, b)
    }
    return 100
  }

}

class World is Stateful {
  construct new() {
    super()
    _started = false
    _complete = false
    _entities = {}
    _ghosts = {}
    _tagged = {}
    _nextId = 1
    _zones = []
    _zoneIndex = 0
    _step = 1
    _events = Queue.new()
    _queue = PriorityQueue.new(TURN_ORDER_COMPARATOR)
    _systems = []
    _turn = 0
    addEntity("turnMarker", Turn.new())
  }

  start() {
    _started = true
    systems.each{|system| system.start(this) }

    for (event in _events) {
      process(event)
    }
  }

  printQueue() {
    System.print("Queue contains:")
    for (id in _queue) {
      System.write(getEntityById(id).name + ", ")
    }

    System.print("")
  }

  systems { _systems }
  events { _events }

  // The size of a single timestep
  step { _step }
  step=(v) { _step = v }


  // Does not guarantee an order
  allEntities { _entities.values.toList }
  otherEntities() { _entities.values.where{|entity| entity.zone != _zoneIndex }.toList  }
  entities() { _entities.values.where{|entity| entity.pos == null || entity.zone == _zoneIndex }.toList  }

  complete { _complete }
  complete=(v) { _complete = v }

  zoneIndex { _zoneIndex }

  changeZone(newZone) {
    _queue.clear()
    _zoneIndex = newZone
    for (entity in entities()) {
      _queue.add(entity.id, entity.lastTurn)
    }
    addEvent(ChangeZoneEvent.new(_zoneIndex))
  }

  nextId() {
    var id = _nextId
    _nextId = _nextId + 1
    return id
  }

  generator { _generator }
  generator=(v) { _generator = v }

  loadZone(i) { loadZone(i, null) }
  loadZone(i, start) {
    var generated = false
    var zone
    if (_zones.count == 0 || i >= _zones.count || _zones[i] == null) {
      if (i > _zones.count) {
        for (x in ((_zones.count - 1).max(0))...i) {
          _zones.add(null)
        }
      }
      zone = addZone(_generator.generate(this, [ i, start ]))
    }
    changeZone(i)
    return _zones[i]
  }

  zone { _zones[_zoneIndex] }

  addZone(zone) {
    _zones.add(zone)
    zone.ctx = this
    return this
  }

  getEntityById(id) { _entities[getId(id)] || _ghosts[getId(id)] }
  getEntityByTag(tag) { _entities[_tagged[tag]] }
  getEntitiesAtPosition(x, y) { getEntitiesAtPosition(Vec.new(x, y)) }
  getEntitiesAtPosition(vec) { entities().where {|entity| entity.occupies(vec) }.toList }

  addEvents(events) {
    _events.addAll(events)
    for (event in events) {
      event.turn = _turn
      if (_started) {
        process(event)
      }
    }
  }

  addEvent(event) {
    _events.add(event)
    event.turn = _turn
    if (_started) {
      process(event)
    }
  }

  process(event) {
    systems.each{|system| system.process(this, event) }
    entities().each{|entity| entity.events.add(event) }
  }

  addEntity(tag, entity) {
    var ref = addEntity(entity)
    _tagged[tag] = entity.id
    return ref
  }

  addEntity(entity) {
    var id = nextId()
    entity.zone = _zoneIndex
    _entities[id] = entity.bind(this, id)
    var t = _turn
    if (_started && _queue.count > 0) {
      t = _queue.peekPriority()
      t = t + MAX_TURN_SIZE * entity.speed
    }
    /*
    if (_started && _queue.count > 0) {
      var remaining = MAX_TURN_SIZE - (_queue.peekPriority() % MAX_TURN_SIZE)
      Log.d("Remaining %(remaining / MAX_TURN_SIZE)")
      t = _queue.peekPriority()
      t = (t + remaining)
    }
    */
    Log.d("Adding %(entity) at time %(t)")

    _queue.add(id, t)
    entity.lastTurn = t
    entity.lastCost = 0
    addEvent(EntityAddedEvent.new(id))
    return EntityRef.new(this, entity.id)
  }

  getId(ref) {
    var id
    if (ref is Entity || ref is EntityRef) {
      id = ref.id
    }
    if (ref is Num) {
      id = ref
    }
    return id
  }

  removeEntity(ref) {
    var id = getId(ref)
    var entity

    entity = _entities.remove(id)
    if (entity == null) {
      // we've already removed it or it doesn't exist
      return
    }

    _ghosts[id] = entity
    entity.state = 1

    // remove all tags for entity
    var entityTags = []
    for (tag in _tagged.keys) {
      if (_tagged[tag] == id) {
        entityTags.add(tag)
        break
      }
    }
    entityTags.each {|tag| _tagged.remove(tag) }
    addEvent(EntityRemovedEvent.new(id))
  }

  // Attempt to advance the world by one turn
  // returns true if something changed
  advance() {
    processTurn()
  }

  skipTo(entityType) {
    var actor = null
    var actorId
    var turn
    while (!(actor is entityType)) {
      turn = _queue.peekPriority()
      actorId = _queue.peek()
      actor = getEntityById(actorId)
      if (actor is entityType) {
        break
      }
      _queue.add(_queue.remove(), turn)
    }
  }

  recalculateQueue() {
    var newQueue = PriorityQueue.new()
    while (!_queue.isEmpty) {
      var actorId = _queue.get()
      var actor = getEntityById(actorId)
      var turn = actor.nextTime
      newQueue.add(_queue.remove(), turn)
    }
    _queue = newQueue
  }

  processTurn() {
    if (!_started) {
      Fiber.abort("Attempting to advance the world before start() has been called")
    }
    if (complete) {
      events.clear()
      return
    }
    var actor = null
    var actorId
    var turn
    var action
    while (_queue.count > 0 && actor == null) {
      turn = _queue.peekPriority()
      actorId = _queue.peek()
      actor = getEntityById(actorId)
      if (_queue.isEmpty) {
        actor = null
        break
      }
      if (actor.state < 2) {
        actor = null
        _queue.remove()
        continue
      }
      if (actor.nextTime > turn) {
        // If this entity needs to recalculate
        //Log.i("%(actor) %(actor.id) last acted %(actor.lastTurn), recalculating next turn from %(turn) to %(actor.nextTime + 1)")
        Log.i("%(actor) %(actor.id) last acted %(actor.lastTurn), recalculating...")
        _queue.add(_queue.remove(), actor.nextTime)

        // actor.pushAction(Action.none)
        // We add 1 here so that the turn order is maintained, otherwise
        // there can be a slippage.
        //recalculateQueue()
        actor = null
        continue
      }
      events.clear()
      // Check systems first to clear conditions
      systems.each{|system| system.preUpdate(this, actor) }
      action = actor.getAction()
      if (action == null) {
          // Actor isn't ready to provide action (player)
          return false
      }
      actorId = _queue.remove()
    }
    if (actor == null) {
      // No actors, no actions to perform
      return false
    }

    Log.d("%(actor) (%(actor.id)) begins turn %(turn)")
    var result
    while (true) {
      Log.d("%(actor) evaluate: %(action)")
      result = action.bind(actor).evaluate()
      if (result.invalid) {
        // Action wasn't successful, allow retry
        _queue.add(actorId, turn)
        Log.d("%(actor): rejected, retry")
        return false
      }
      if (!result.alternate) {
        Log.d("%(actor): accepted")
        // No more actions to consider
        break
      }
      Log.d("%(actor): alternate")
      action = result.alternate
    }

    // Update the current turn count
    _turn = turn
    Log.i("%(actor): performing %(action)")
    actor.events.clear()
    var originalZone = _zoneIndex
    result = action.perform()
    actor.endTurn()
    actor.lastTurn = turn
    //if (actor.state == EntityState.active || actor.pos == null || actor.zone == originalZone) {
    if (actor.pos == null || actor.zone == originalZone && actor.state == EntityState.active) {
      Log.d("%(actor): Action cost was %(action.cost() * actor.speed)")
      Log.d("%(actor): next turn is %(turn + action.cost() * actor.speed)")
      actor.lastCost = action.cost()
      _queue.add(actorId, turn + action.cost() * actor.speed)
    }

    var outcome = result.succeeded
    if (!result.succeeded) {
      // Action wasn't successful, allow retry
      Log.i("%(actor): failed, time loss")
    } else {
      Log.i("%(actor): success")
    }
    systems.each{|system| system.postUpdate(this, actor) }

    return outcome
  }

  serialize() {
    var out = Stateful.copyValue(data)
    out["zones"] = _zones.map {|zone| zone.serialize() }.toList
    out["entities"] = allEntities.map {|entity| entity.serialize() }.toList
    out["tags"] = _tagged
    out["queue"] = _queue.toTupleList
    out["nextId"] = _nextId
    out["zoneIndex"] = _zoneIndex
    return out
  }
}

class GameSystem {
  construct new() {}
  start(ctx) {}
  preUpdate(ctx, actor) {}
  update(ctx, actor) {}
  postUpdate(ctx, actor) {}
  process(ctx, event) {}
}

// Generic UI element
class Element {
  construct new() {
    _elements = []
    _z = 0
  }

  z { _z }
  z=(v) { _z = v }
  top { (_parent ? _parent.top : this) }
  parent { _parent }
  parent=(v) { _parent = v }
  elements { _elements }

  update() {
    for (element in _elements) {
      element.update()
    }
  }
  process(events) {
    for (element in _elements) {
      element.process(events)
    }
  }
  draw() {
    for (element in _elements) {
      element.draw()
    }
  }

  addElement(element) {
    element.z = _elements.count
    _elements.add(element)
    element.parent = this
    _elements.sort {|a, b| a.z < b.z}
    return element
  }
  removeSelf() {
    if (parent) {
      parent.removeElement(this)
    }
  }
  removeElement(element) {
    _elements.remove(element)
  }
}

class Scene is Element {
  construct new(args) {
    super()
  }

  game { _game }
  game=(v) { _game = v }
}

class ParcelMain {
  construct new(scene) {
    Window.integerScale = Config["integer"]
    Window.title = Config["title"]
    Canvas.resize(Config["width"], Config["height"])
    _initial = scene
    _args = []
    _scenes = {}
  }

  registerScene(name, scene) {
    _scenes[name] = scene
  }

  construct new(scene, args) {
    Window.integerScale = Config["integer"]
    Canvas.resize(Config["width"], Config["height"])
    Window.title = Config && Config["title"] || "Parcel"
    _initial = scene
    _args = args
  }

  init() {
    Window.lockstep = true
    Window.resize(Canvas.width * SCALE, Canvas.height * SCALE)

    Scheduler.init()
    push(_initial, _args)
    Scheduler.runUntilEmpty()
  }

  update() {
    if (Keyboard["F12"].justPressed) {
      Process.exit()
      return
    }
    if (_nextScene) {
      _scene = _nextScene
      _nextScene = null
    }
    if (_scene == null) {
      Process.exit()
      return
    }
    Jukebox.update()
    Scheduler.tick()
    _scene.update()
  }
  draw(dt) {
    if (_scene != null) {
      _scene.draw()
    }
  }

  push(scene) { push(scene, []) }
  push(scene, args) {
    _nextScene = _scenes[scene].new(args)
    _nextScene.game = this
  }
}

class Tile is Stateful {
  static void() {
    return Tile.new({ "void": true })
  }
  construct new() {
    super({})
  }
  construct new(data) {
    super(data)
  }

  toString { "Tile: %(data)" }
}


var DIR_FOUR = [
  Vec.new(-1, 0), // left
  Vec.new(0, -1), // up
  Vec.new(1, 0), // right
  Vec.new(0, 1) // down
]
var DIR_EIGHT = [
  Vec.new(0, -1), // N
  Vec.new(1, 0), // E
  Vec.new(0, 1), // S
  Vec.new(-1, 0), // W
  Vec.new(-1, -1), // NW
  Vec.new(1, -1), // NE
  Vec.new(1, 1), // SE
  Vec.new(-1, 1) // SW
]

class Graph {
  neighbours(pos) {}
  allNeighbours(pos) {}
  cost(aPos, bPos) { 1 }
}

class TileMap is Graph {
  construct new() {
    _tiles = {}
    _default = { "void": true }
    _undefTile = Tile.new(_default)
    _min = Vec.new()
    _max = Vec.new()
    _xRange = 0..0
    _yRange = 0..0
  }

  default { _default }
  default=(v) { _default = v }

  clearAll() { _tiles = {} }
  clear(vec) { clear(vec.x, vec.y) }
  clear(x, y) {
    var pair = Elegant.pair(x, y)
    _tiles[pair] = null
  }

  report() {
    for (key in _tiles.keys) {
      System.print(Elegant.unpair(key))
    }
  }

  [vec] {
    return this[vec.x, vec.y]
  }

  [vec]=(tile) {
    this[vec.x.floor, vec.y.floor] = tile
  }

  [x, y] {
    var pair = Elegant.pair(x, y)
    if (!_tiles[pair]) {
      return _undefTile
    }
    return _tiles[pair]
  }

  [x, y]=(tile) {
    _min.x = _min.x.min(x)
    _min.y = _min.y.min(y)
    _max.x = _max.x.max(x)
    _max.y = _max.y.max(y)
    _xRange = _min.x.._max.x
    _yRange = _min.y.._max.y
    var pair = Elegant.pair(x.floor, y.floor)
    _tiles[pair] = tile
  }

  inBounds(vec) { inBounds(vec.x, vec.y) }
  inBounds(x, y) { !this[x, y]["void"] }
  isBlocking(vec) { isBlocking(vec.x, vec.y) }
  isBlocking(x, y) { !inBounds(x, y) || this[x, y]["blocking"] }
  isSolid(vec) { isSolid(vec.x, vec.y) }
  isSolid(x, y) { !inBounds(x, y) || this[x, y]["solid"] }
  isFloor(vec) { isFloor(vec.x, vec.y) }
  isFloor(x, y) { inBounds(x, y) && !this[x, y]["solid"] }

  tiles { _tiles }
  xRange { _xRange }
  yRange { _yRange }
  width { _max.x - _min.x + 1 }
  height { _max.y - _min.y + 1 }

  serialize() {
    var everything = {}
    for (entry in tiles) {
      everything[entry.key] = entry.value.data
    }
    return everything
  }
}

class TileMap4 is TileMap {
  construct new() { super() }
  neighbours(pos) {
    return DIR_FOUR.map {|dir| pos + dir }.where{|pos| !this.isSolid(pos) }.toList
  }
  allNeighbours(pos) {
    return DIR_FOUR.map {|dir| pos + dir }.where{|pos| this.inBounds(pos) }.toList
  }
}
class TileMap8 is TileMap {
  construct new() {
    super()
    _cardinal = 2
    _diagonal = 3
  }
  neighbours(pos) {
    return DIR_EIGHT.map {|dir| pos + dir }.where{|next|
      var dx = M.mid(-1, next.x - pos.x, 1)
      var dy = M.mid(-1, next.y - pos.y, 1)

      if (this.isSolid(next)) {
        return false
      }

      if (dx != 0 && dy != 0) {
        return !(isSolid(pos.x + dx, pos.y) || isSolid(pos.x, pos.y + dy))
      }
      return true
    }.toList
  }
  allNeighbours(pos) {
    return DIR_EIGHT.map {|dir| pos + dir }.where{|pos| this.inBounds(pos) }.toList
  }
  cost(a, b) {
    if (a.x == b.x || a.y == b.y) {
      return _cardinal
    }
    return _diagonal
  }

  successor(node, current, start, end) {
    var dx = M.mid(-1, node.x - current.x, 1)
    var dy = M.mid(-1, node.y - current.y, 1)
    if (isSolid(node)) {
      return null
    }
    if (dx != 0 && dy != 0) {
      // we are going diagonal
      if (isSolid(current.x + dx, current.y) || isSolid(current.x, current.y + dy)) {
        return null
      }
    }

    var jumpPoint = jump(current.x, current.y, dx, dy, start, end)
    if (jumpPoint) {
      return jumpPoint
    }
  }

  jump(cx, cy, dx, dy, start, end) {
    var next = Vec.new(cx + dx, cy + dy)

    // Blocked, no jump
    if (isSolid(next)) {
      return null
    }

    // We can jump to goal
    if (next == end) {
      return next
    }

    // diagonal
    if (dx != 0 && dy != 0) {
      if ((isFloor(cx - dx, cy + dy) && isSolid(cx - dx, cy)) ||
          (isFloor(cx + dx, cy - dy) && isSolid(cx, cy - dy))) {
        return next
      }

      // Check horizonstal and vertical neighbours
      if (jump(next.x, next.y, dx, 0, start, end) != null ||
          jump(next.x, next.y, 0, dy, start, end) != null) {

        return next
      }
    } else {
      // horizontal
      if (dx != 0) {
        if ((isFloor(cx + dx, cy + 1) && isSolid(cx, cy + 1)) ||
            (isFloor(cx + dx, cy - 1) && isSolid(cx, cy - 1))) {
          return next
        }
      } else {
        if ((isFloor(cx + 1, cy + dy) && isSolid(cx + 1, cy)) ||
            (isFloor(cx - 1, cy + dy) && isSolid(cx - 1, cy))) {
          return next
        }
      }
    }
    if (isFloor(cx + dx, cy) || isFloor(cx, cy + dy)) {
      return jump(next.x, next.y, dx, dy, start, end)
    }
    return null
  }
}

class BreadthFirst {
  static search(map, start, goal) {
    var cameFrom = HashMap.new()
    var frontier = Queue.new()
    if (!(start is Sequence)) {
      start = [ start ]
    }
    for (pos in start) {
      frontier.add(pos)
      cameFrom[pos] = null
    }
    while (!frontier.isEmpty) {
      var current = frontier.remove()
      if (current == goal) {
        break
      }
      for (next in map.neighbours(current)) {
        if (!cameFrom.containsKey(next)) {
          cameFrom[next] = current
          map[next]["cost"] = 0
          frontier.add(next)
        }
      }
    }
    var current = goal
    if (cameFrom[goal] == null) {
      return null // There is no valid path
    }

    var path = []
    while (!start.contains(current)) {
      path.insert(0, current)
      current = cameFrom[current]
    }
    path.insert(0, current)
    for (pos in path) {
      map[pos]["seen"] = true
    }
    return path
  }
}

class Dijkstra {
  static search(map, start, goal) {
    var frontier = PriorityQueue.min()
    var cameFrom = HashMap.new()
    var costSoFar = HashMap.new()
    if (!(start is Sequence)) {
      start = [ start ]
    }
    for (pos in start) {
      frontier.add(pos, 0)
      cameFrom[pos] = null
      costSoFar[pos] = 0
    }
    while (!frontier.isEmpty) {
      var current = frontier.remove()
      if (current == goal) {
        break
      }
      var currentCost = costSoFar[current]
      for (next in map.neighbours(current)) {
        var newCost = currentCost + map.cost(current, next)
        if (!costSoFar.containsKey(next) || newCost < costSoFar[next]) {
          costSoFar[next] = newCost
          map[next]["cost"] = newCost
          var priority = newCost
          frontier.add(next, newCost)
          cameFrom[next] = current
        }
      }
    }

    var current = goal
    if (cameFrom[goal] == null) {
      return null // There is no valid path
    }

    var path = []
    while (!start.contains(current)) {
      path.insert(0, current)
      current = cameFrom[current]
    }
    path.insert(0, current)
    for (pos in path) {
      map[pos]["seen"] = true
    }

    return path
  }
  static map(map, start) {
    var frontier = Queue.new()
    var cameFrom = HashMap.new()
    var costSoFar = HashMap.new()
    if (!(start is Sequence)) {
      start = [ start ]
    }
    for (pos in start) {
      frontier.add(pos)
      cameFrom[pos] = null
      costSoFar[pos] = 0
    }
    while (!frontier.isEmpty) {
      var current = frontier.remove()
      var currentCost = costSoFar[current]
      var newCost = currentCost + 1
      for (next in (DIR_EIGHT.map{|dir| dir + current}.where {|pos| !map.isSolid(pos) })) {
        if (!cameFrom.containsKey(next) || newCost < costSoFar[next]) {
          costSoFar[next] = newCost
          frontier.add(next)
          cameFrom[next] = current
        }
      }
    }
    return [costSoFar, cameFrom]
  }
}


class AStar {
  static heuristic(a, b) {
    return (b - a).manhattan
  }
  static search(zone, start, goal) {
    var map
    if (zone is TileMap) {
      map = zone
    } else if (zone is Zone) {
      map = zone.map
    }
    if (goal == null) {
      Fiber.abort("AStarSearch doesn't work without a goal")
    }
    var frontier = PriorityQueue.min()
    var cameFrom = HashMap.new()
    var costSoFar = HashMap.new()
    if (!(start is Sequence)) {
      start = [ start ]
    }
    for (pos in start) {
      frontier.add(pos, 0)
      cameFrom[pos] = null
      costSoFar[pos] = 0
    }
    while (!frontier.isEmpty) {
      var current = frontier.remove()
      if (current == goal) {
        break
      }
      var currentCost = costSoFar[current]
      for (next in map.neighbours(current)) {
        var newCost = currentCost + map.cost(current, next)
        if (!costSoFar.containsKey(next) || newCost < costSoFar[next]) {
          map[next]["cost"] = newCost
          var priority = newCost + AStar.heuristic(next, goal)
          costSoFar[next] = newCost
          frontier.add(next, priority)
          cameFrom[next] = current
        }
      }
    }

    var current = goal
    if (cameFrom[goal] == null) {
      return null // There is no valid path
    }

    var path = []
    while (!start.contains(current)) {
      path.insert(0, current)
      current = cameFrom[current]
    }
    path.insert(0, current)
    for (pos in path) {
      map[pos]["seen"] = true
    }
    return path
  }
}

class Line {
  static walk(p0, p1) {
    var dx = p1.x-p0.x
    var dy = p1.y-p0.y
    var nx = dx.abs
    var ny = dy.abs
    var sign_x = dx > 0? 1 : -1
    var sign_y = dy > 0? 1 : -1

    var p = Vec.new(p0.x, p0.y)
    var points = [ Vec.new(p.x, p.y) ]
    var ix = 0
    var iy = 0
    while (ix < nx || iy < ny) {
      if ((1 + 2*ix) * ny < (1 + 2*iy) * nx) {
       // next step is horizontal
        p.x = p.x + sign_x
        ix = ix + 1
      } else {
        // next step is vertical
        p.y = p.y + sign_y
        iy = iy + 1
      }
      points.add(Vec.new(p.x, p.y))
    }
    return points
  }

  static linear(p0, p1) {
   var points = []
    var n = chebychev(p0,p1)
    for (step in 0..n) {
      var t = (n == 0) ? 0.0 : step / n
      points.add(vecRound(vecLerp(p0, t, p1)))
    }
    return points
  }

  static chebychev(v0, v1) {
    return M.max((v1.x-v0.x).abs, (v1.y-v0.y).abs)
  }

  static vecRound(vec){
    return Vec.new(vec.x.round, vec.y.round, vec.z)
  }
  static vecLerp(v0, p, v1){
    return Vec.new(M.lerp(v0.x, p, v1.x), M.lerp(v0.y, p, v1.y))
  }
}


class DefaultFont {
  static getArea(text) {
    return Vec.new(text.count * 8, 8)
  }
}
class TextUtils {
  static print(text, settings) {
    text = text is String ? text : text.toString
    var color = settings["color"] || Color.black
    var align = settings["align"] || "left"
    var position = settings["position"] || Vec.new()
    // TODO vertical size?
    var size = settings["size"] || Vec.new(Canvas.width, Canvas.height)
    var font = settings["font"] || Font.default
    var fontObj = Font[settings["font"]] || DefaultFont
    var overflow = settings["overflow"] || false

    var lines = []
    var words = text.split(" ")
    var maxWidth = size.x
    var nextLine
    var lineDims = []
    var currentLine

    while (true) {
      currentLine = words.join(" ")
      var area = fontObj.getArea(currentLine)
      nextLine = []
      while (area.x > maxWidth && words.count > 1) {
        // remove the last word, add it to the start of the nextLine
        nextLine.insert(0, words.removeAt(-1))
        currentLine = words.join(" ")
        // compute the current line's area now
        area = fontObj.getArea(currentLine)
        // and recheck
      }

      lineDims.add(area)
      lines.add(currentLine)
      if (nextLine.count == 0) {
        break
      }
      words = nextLine
    }

    if (!overflow) {
      Canvas.clip(position.x, position.y, size.x, size.y)
    }

    var x
    var y = position.y
    for (lineNumber in 0...lines.count) {
      if (align == "left") {
        x = position.x
      } else if (align == "center") {
        x = ((size.x + position.x) - lineDims[lineNumber].x) / 2
      } else if (align == "right") {
        x = position.x + size.x - lineDims[lineNumber].x
      } else {
        Fiber.abort("invalid text alignment: %(align)")
      }
      Canvas.print(lines[lineNumber], x, y, color, font)
      y = y + lineDims[lineNumber].y
    }

    if (!overflow) {
      Canvas.clip()
    }
    return Vec.new(size.x, y - position.y)
  }
}


// ==================================
var RNG
class DataFile {
  construct load(name, path) {
    init_(name, path, {}, false)
  }

  construct load(name, path, default) {
    init_(name, path, default, false)
  }
  construct load(name, path, default, optional) {
    init_(name, path, default, optional)
  }

  toString { _data.toString }
  init_(name, path, default, optional) {
    if (!__cache) {
      __cache = {}
    }
    var fiber = Fiber.new {
      _data = default
      __cache[name] = this
      var file = Json.load(path)
      for (entry in file) {
        _data[entry.key] = entry.value
      }
    }
    var error = fiber.try()
    if (!optional && fiber.error) {
      Log.e("Error loading data file %(path): %(fiber.error)")
    }
  }
  data { _data }
  keys { _data.keys }
  values { _data.values }
  [key] { _data[key] }

  static [name] { __cache[name] }
}

class ConfigData is DataFile {
  construct load() {
    super("config", "config.json", {
      "logLevel": "DEBUG",
      "seed": Platform.time,
      "title": "Parcel",
      "scale": 2,
      "width": 768,
      "height": 576,
      "integer": false,
      "mute": false
    })
    var override = DataFile.load("overrides", "config-override.json", {}, true)
    Stateful.assign(data, override.data)

    Log.level = this["logLevel"]
    var Seed = this["seed"]
    Log.d("RNG Seed: %(Seed)")
    RNG = Random.new(Seed)
    SCALE = this["scale"]
  }
}
var Config = ConfigData.load()
// ==================================
class Palette {

  construct new() {
    _palette = {}
    _keys = {}
  }

  addColor(name, color) {
    _palette[name] = color
  }
  setPurpose(purpose, colorName) {
    _keys[purpose] = colorName
  }

  [key] { _palette[_keys[key]] || (_palette[key] is Color ? _palette[key] : Color.white) }
}
// ==================================

class TextInputReader {
  construct new() {
    _enabled = false
    _text = ""
    _pos = 0
  }

  pos { _pos }
  text { _text }
  changed { _changed }
  enabled { _enabled }
  clear() {
    _pos = 0
    _text = ""
    Keyboard.handleText = false
  }

  enable() {
    _enabled = true
    Keyboard.handleText = true
  }
  disable() {
    _enabled = false
    Keyboard.handleText = false
  }

  splitText(before, insert, after) {
    var codePoints = _text.codePoints
    _text = ""
    for (point in codePoints.take(before)) {
      _text = _text + String.fromCodePoint(point)
    }
    if (insert != null) {
      _text = _text + insert
    }
    for (point in codePoints.skip(after)) {
      _text = _text + String.fromCodePoint(point)
    }
  }

  update() {
    if (!_enabled) {
      return
    }

    if (Keyboard["left"].justPressed) {
      _pos = (_pos - 1).clamp(0, _text.count)
    }
    if (Keyboard["right"].justPressed) {
      _pos = (_pos + 1).clamp(0, _text.count)
    }

    if (Keyboard.text.count > 0) {
      splitText(_pos, Keyboard.text, _pos)
      _pos = _pos + Keyboard.text.count
    }

    if (!Keyboard.compositionText && Keyboard["backspace"].justPressed && _text.count > 0) {
      var codePoints = _text.codePoints
      splitText(_pos - 1, null, _pos)
      _pos = (_pos - 1).clamp(0, _text.count)
    }
    if (!Keyboard.compositionText && Keyboard["delete"].justPressed && _text.count > 0) {
      var codePoints = _text.codePoints
      splitText(_pos, null, _pos+1)
      _pos = (_pos).clamp(0, _text.count)
    }
    // TODO handle text region for CJK

    if ((Keyboard["left ctrl"].down || Keyboard["right ctrl"].down) && Keyboard["c"].justPressed) {
      Clipboard.content = _text
    }
    if ((Keyboard["left ctrl"].down || Keyboard["right ctrl"].down) && Keyboard["v"].justPressed) {
      _text = _text + Clipboard.content
    }
  }
}


var RE = null
var RE_args = null
var RE_value = null
class Reflect {
  static get(receiver, name) {
    RE = receiver
    return Meta.compileExpression("RE.%(name)").call()
  }
  static set(receiver, name, value) {
    RE = receiver
    RE_value = value
    return Meta.compileExpression("RE.%(name) = RE_value").call()
  }
  static call(receiver, name) {
    RE = receiver
    return Meta.compileExpression("RE.%(name)()").call()
  }
  static call(receiver, name, args) {
    RE = receiver
    RE_args = args
    return Meta.compileExpression("RE.%(name)(RE_args)").call()
  }
  static isType(derived, base) {
    if ((derived is Class) && (base is Class)) {
      var current = derived
      while (current != Object && current != base) {
        current = current.supertype
      }
      return current == base
    }
    return false
  }
}

