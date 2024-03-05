import "jukebox" for Jukebox
import "dome" for Process, Log, StringUtils
import "graphics" for Canvas, Color
import "input" for Keyboard, Mouse
import "math" for Vec
import "parcel" for
  Stateful,
  DIR_EIGHT,
  Scene,
  State,
  World,
  Entity,
  Line,
  DataFile,
  TextInputReader

import "./palette" for INK
import "./inputs" for VI_SCHEME as INPUT
import "./messages" for MessageLog, Pronoun
import "./ui/events" for TargetEvent, TargetBeginEvent, TargetEndEvent, HoverEvent, TextInputEvent
import "./ui/scene" for SceneState
import "./ui/field" for Field
import "./text" for TextSplitter

import "./ui/renderer" for Renderer
import "./ui/label" for Label
import "./ui/pane" for Pane
import "./ui/panel" for SizeMode
import "./ui/dialog" for Dialog
import "./ui" for
  HealthBar,
  ManaBar,
  LineViewer,
  LogViewer,
  HistoryViewer,
  HoverText,
  HintText

import "./generator" for WorldGenerator
import "./combat" for AttackResult
import "./spells" for SpellUtils

class InventoryWindowState is SceneState {
  construct new() {
    super()
  }

  onEnter() {
    _action = arg(0) || "use"
    _title = _action == "drop" ? "(to drop)" : ""
    _selectedIndex = null

    var border = 24
    var world = scene.world
    var worldItems = world["items"]

    var player = scene.world.getEntityByTag("player")
    var playerItems = player["inventory"]
    var i = 0
    var items = playerItems.map {|entry|
      i = i + 1
      var label = ""
      var letter = getKey(i)
      if (worldItems[entry.id].slot) {
        var item = worldItems[entry.id]
        if (player["equipment"][item.slot] == entry.id) {
          label = "(equipped)"
        }
      }
      return "%(letter)) %(entry.qty)x %(worldItems[entry.id].name) %(label)"
    }.toList
    items.insert(0, "")
    var max = 0
    for (line in items) {
      if (line.count > max) {
        max = line.count
      }
    }

    var title = ""
    max = max.max(13)
    var width = ((max - 7) / 2).ceil
    for (i in 0...width) {
      title = "%(title)-"
    }
    title = "%(title) ITEMS %(title)"
    items.insert(0, title)
    if (_title) {
      items.insert(1, "%(_title)")
    }
    var x = Canvas.width - (max * 8 + 8)
    _window = LineViewer.new(Vec.new(x, border), Vec.new(Canvas.width - border*2, Canvas.height - border*2), items.count, items)
    scene.addElement(_window)
    _previousMouse = Mouse.pos
  }
  onExit() {
    scene.removeElement(_window)
    if (_dialog) {
      scene.removeElement(_dialog)
    }
  }
  getKey(i) {
    var letter = i.toString
    if (i > 9) {
      letter = String.fromByte(97 + (i - 10))
    }
    if (i > 9 + 26) {
      Fiber.abort("inventory is huge")
    }
    return letter
  }
  update() {
    var player = scene.world.getEntityByTag("player")
    var playerItems = player["inventory"]

    var mouse = Mouse.pos
    if (mouse != _previousMouse) {
      _mouseIndex = ((mouse.y - (_window.pos.y + 30)) / 10).floor
      if (_mouseIndex < 0 || _mouseIndex >= playerItems.count || mouse.x < _window.pos.x) {
        _mouseIndex = null
      }
      _selectedIndex = _mouseIndex
    }
    _previousMouse = mouse
    var i = 1
    for (entry in playerItems) {
      var item = scene.world["items"][entry.id]
      var letter = getKey(i)
      if (Keyboard[letter].justPressed) {
        _keyboardIndex = i - 1
        _selectedIndex = _keyboardIndex
      }
      i = i + 1
    }
    if (_dialog) {
      scene.removeElement(_dialog)
      _dialog = null
    }
    if (_selectedIndex) {
      var entry = playerItems[_selectedIndex]
      var item = scene.world["items"][entry.id]
      _dialog = scene.addElement(Dialog.new([ item.name, "", item.description ]))
      _dialog.center = false
    }
    if (_selectedIndex) {
      var entry = playerItems[_selectedIndex]
      var item = scene.world["items"][entry.id]
      if (INPUT["drop"].firing) {
        _action = "drop"
      } else if (INPUT["confirm"].firing || Mouse["left"].justPressed) {
        _action = "use"
      } else {
        _action = null
      }
      if (_action == "drop") {
        player.pushAction(Components.actions.drop.new(entry.id))
        return PlayerInputState.new()
      } else if (_action == "use") {
        var query = item.query(item["default"])
        if (query == null) {
          // Item has no uses, do nothing
          return this
        }
        var actionSpec = {}
        Stateful.assign(actionSpec, query)
        actionSpec["item"] = entry.id
        if (!item["effects"].isEmpty) {
          if (item["effects"].any{|effect| effect.count > 1 && effect[1]["target"] == "area" }) {
            actionSpec["target"] = "area"
          }
        }
        actionSpec["origin"] = player.pos

        if (actionSpec["target"] == "area") {
          return TargetQueryState.new().with(actionSpec)
        } else {
          player.pushAction(Components.actions.item.new(entry.id, actionSpec))
          return PlayerInputState.new()
        }
      }
      // TODO
    }
    if (INPUT["reject"].firing || INPUT["confirm"].firing) {
      return scene.world.complete ? previous : PlayerInputState.new()
    }
    return this
  }
}

class SpellQueryState is SceneState {
  construct new() {
    super()
  }

  onEnter() {
    var player = scene.world.getEntityByTag("player")
    _spell = arg(0)

    _ui = scene.addElement(Pane.new(Vec.new()))
    _ui.sizeMode = SizeMode.auto
    var phrase = _spell.phrase.list.map {|token|
      var proficiencyEntry = player["proficiency"][token.lexeme]
      return proficiencyEntry["gameUsed"] ? token.lexeme : "???"
    }

    var incantation = _spell.phrase.list.map {|token| SpellUtils.getWordFromToken(token) }.join(" ")
    var plainText = phrase.join(" ")
    var lines = [
      _ui.addElement(Label.new(Vec.new(0, 0), "Targeting...")),
      _ui.addElement(Label.new(Vec.new(0, 12), "%(plainText)")),
      _ui.addElement(Label.new(Vec.new(0, 20), "%(incantation)"))
    ]

    lines.each{|line| line.centerHorizontally() }

    _ui.pos.y = 20
    _ui.alignRight()

    _origin = player.pos
    _cursorPos = player.pos
    _hoverPos = null

    // Compute spell target parameters
    var query = _targetQuery = _spell.target()
    _range = query["range"]
    _area = query["area"] || 0
    _allowSolid = query.containsKey("allowSolid") ? query["allowSolid"] : false
    _needEntity = query.containsKey("needEntity") ? query["needEntity"] : true
    _needSight = query.containsKey("needSight") ? query["needSight"] : true
    scene.process(TargetBeginEvent.new(_cursorPos, _area, _range))
  }
  onExit() {
    if (_ui) {
      scene.removeElement(_ui)
    }
    scene.process(TargetEndEvent.new())
  }
  process(event) {
    if (event is HoverEvent &&
        event.target &&
        event.target is Entity &&
        cursorValid(_origin, event.target.pos)) {
      _hoverPos = event.target.pos
    }
  }
  targetValid(origin, position) {
      // check next
    var map = scene.world.zone.map
    if (!_allowSolid && map[position]["solid"]) {
      return false
    }
    if (_needSight && map[position]["visible"] != true) {
      return false
    }
    if (_range && Line.chebychev(position, origin) > _range) {
      return false
    }

    if (_needEntity && scene.world.getEntitiesAtPosition(position).isEmpty) {
      return false
    }

    return true
  }
  cursorValid(origin, position) {
      // check next
    var map = scene.world.zone.map
    if (!_allowSolid && map[position]["solid"]) {
      return false
    }
    if (_needSight && map[position]["visible"] != true) {
      return false
    }
    if (_range && Line.chebychev(position, origin) > _range) {
      return false
    }

    return true
  }
  update() {
    if (INPUT["reject"].firing) {
      return PlayerInputState.new()
    }
    if ((INPUT["confirm"].firing || Mouse["left"].justPressed) && targetValid(_origin, _cursorPos)) {
      var player = scene.world.getEntityByTag("player")
      _targetQuery["origin"] = _cursorPos
      player.pushAction(Components.actions.cast.new().withArgs({ "spell": _spell, "target": _targetQuery }))
      return PlayerInputState.new()
    }

    // TODO handle mouse targeting

    var i = 0
    var next = null
    for (input in INPUT.list("dir")) {
      if (input.firing) {
        next = _cursorPos + DIR_EIGHT[i]
      }
      i = i + 1
    }

    if (_hoverPos) {
      _cursorPos = _hoverPos
      scene.process(TargetEvent.new(_cursorPos))
    }
    if (next && cursorValid(_origin, next)) {
      _cursorPos = next
      scene.process(TargetEvent.new(_cursorPos))
    }

    return this
  }
}
class TargetQueryState is SceneState {
  construct new() {
    super()
  }

  onEnter() {
    var query = arg(0)
    var player = scene.world.getEntityByTag("player")
    _origin = player.pos
    _cursorPos = player.pos
    _hoverPos = null

    _query = Stateful.copyValue(query)
    _range = query["range"]
    _area = query["area"] || 0
    _allowSolid = query.containsKey("allowSolid") ? query["allowSolid"] : false
    _needEntity = query.containsKey("needEntity") ? query["needEntity"] : true
    _needSight = query.containsKey("needSight") ? query["needSight"] : true
    scene.process(TargetBeginEvent.new(_cursorPos, _area, _range))
  }
  onExit() {
    scene.process(TargetEndEvent.new())
  }
  process(event) {
    if (event is HoverEvent &&
        event.target &&
        event.target is Entity &&
        cursorValid(_origin, event.target.pos)) {
      _hoverPos = event.target.pos
    }
  }
  targetValid(origin, position) {
      // check next
    var map = scene.world.zone.map
    if (!_allowSolid && map[position]["solid"]) {
      return false
    }
    if (_needSight && map[position]["visible"] != true) {
      return false
    }
    if (_range && Line.chebychev(position, origin) > _range) {
      return false
    }

    if (_needEntity && scene.world.getEntitiesAtPosition(position).isEmpty) {
      return false
    }

    return true
  }
  cursorValid(origin, position) {
      // check next
    var map = scene.world.zone.map
    if (!_allowSolid && map[position]["solid"]) {
      return false
    }
    if (_needSight && map[position]["visible"] != true) {
      return false
    }
    if (_range && Line.chebychev(position, origin) > _range) {
      return false
    }

    return true
  }
  update() {
    if (INPUT["reject"].firing) {
      return previous
    }
    if ((INPUT["confirm"].firing || Mouse["left"].justPressed) && targetValid(_origin, _cursorPos)) {
      var player = scene.world.getEntityByTag("player")
      var query = _query
      query["origin"] = _cursorPos
      player.pushAction(Components.actions.item.new(_query["item"], query))
      return PlayerInputState.new()
    }

    // TODO handle mouse targeting

    var i = 0
    var next = null
    for (input in INPUT.list("dir")) {
      if (input.firing) {
        next = _cursorPos + DIR_EIGHT[i]
      }
      i = i + 1
    }

    if (_hoverPos) {
      _cursorPos = _hoverPos
      scene.process(TargetEvent.new(_cursorPos))
    }
    if (next && cursorValid(_origin, next)) {
      _cursorPos = next
      scene.process(TargetEvent.new(_cursorPos))
    }

    return this
  }
}

class ConfirmState is SceneState {
  construct new() {
    super()
  }
  update() {
    if (INPUT["confirm"].firing) {
      Process.exit()
      return
    } else if (INPUT["reject"].firing) {
      return previous
    }
    return this
  }
}

class ModalWindowState is SceneState {
  construct new() {
    super()
  }

  window { _window }
  window=(v) {
    if (_window) {
      scene.removeElement(_window)
    }
    _window = v
    scene.addElement(_window)
  }
  onEnter() {
    var windowType = arg(0)
    var border = 24
    if (windowType == "history") {
      window = HistoryViewer.new(Vec.new(border, border), Vec.new(Canvas.width - border*2, Canvas.height - border*2), scene.messages)
    }
  }
  onExit() {
    scene.removeElement(_window)
  }
  update() {
    if (INPUT["reject"].firing || INPUT["confirm"].firing) {
      return previous
    }
    return this
  }
}
class CastState is ModalWindowState {
  construct new() {
    super()
  }

  onEnter() {
    window = scene.addElement(Pane.new(Vec.new(Canvas.width / 4, 32)))
    window.sizeMode = SizeMode.auto
    var title = window.addElement(Label.new(Vec.new(0, 0), "Speak an incantation"))
    _costLabel = window.addElement(Label.new(Vec.new(0, 28), "[ ??? MP ]"))
    _phraseLabel = window.addElement(Label.new(Vec.new(0, 36), ""))
    var field = window.addElement(Field.new(Vec.new(0, 14)))
    field.placeholder = "<type incantation>"

    _costLabel.centerHorizontally()
    _phraseLabel.centerHorizontally()
    window.center()
    title.centerHorizontally()
    _reader = TextInputReader.new()
    _reader.max = 23
    _reader.enable()
    _spell = {}
    _incantation = ""

  }
  onExit() {
    scene.removeElement(window)
    _reader.disable()
    super.onExit()
  }
  update() {
    if (INPUT["reject"].firing) {
      return PlayerInputState.new()
    } else if (INPUT["confirm"].firing) {
      // calculate spell here from input
      var player = scene.world.getEntityByTag("player")
      _spell = SpellUtils.parseSpell(_incantation)
      if (_spell.valid) {
        if (_spell.target()["target"] == "self") {
          player.pushAction(Components.actions.cast.new().withArgs({
            "spell": _spell
          }))
          return PlayerInputState.new()
        } else {
          return SpellQueryState.new().with([ _spell ])
        }
      } else {
        _incantation = ""
        _reader.clear()
        _reader.enable()
        scene.process(TextInputEvent.new(_reader.text, _reader.pos))
      }
    }
    _reader.update()
    if (_reader.changed) {
      scene.process(TextInputEvent.new(_reader.text, _reader.pos))
      _incantation = StringUtils.toLowercase(_reader.text)
      var spell = SpellUtils.parseSpell(_incantation)
      var player = scene.world.getEntityByTag("player")
      if (spell.valid) {
        _costLabel.text = "[ %(spell.cost(player)) MP ]"
        _costLabel.centerHorizontally()
      } else {
        _costLabel.text = "[ ??? MP ]"
      }
      var phrase = spell.phrase.list.map {|token|
        var proficiencyEntry = player["proficiency"][token.lexeme]
        if (proficiencyEntry) {
          return proficiencyEntry["gameUsed"] ? token.lexeme : "???"
        }
        return "???"
      }.join(" ")
      System.print(phrase)
      _phraseLabel.text = phrase
      _phraseLabel.centerHorizontally()
      _costLabel.centerHorizontally()
    }
    return this
  }
}
class HelpState is ModalWindowState {
  construct new() {
    super()
  }

  onEnter() {
    var message = [
      "'Confirm' - Return",
      "'Reject' - Escape",
      "Move - HJKLYUNB, WASDQECZ, Arrow Keys, Numpad",
      "Rest - Space",
      "",
      "Coup-de-grace - 'x'",
      "Pick-up item - 'g'",
      "Descend to the next floor - ','",
      "",
      "Other commands",
      "Inventory - 'i', then number to use/equip/unequip",
      "Open Log - 'v'",
      "Drop from Inventory - 'r' then number"
    ]

    window = Dialog.new(message)
    window.center = false
  }
  onExit() {
    scene.removeElement(_pane)
    super.onExit()
  }
  update() {
    if (INPUT["reject"].firing || INPUT["confirm"].firing) {
      return previous
    }
    return this
  }
}

var Dialogue = DataFile.load("dialogue", "data/dialogue.json")
class DialogueState is ModalWindowState {
  construct new() {
    super()
  }
  onEnter() {
    var moment = arg(0)
    _dialogue = Dialogue[moment]
    _index = 0
    super.onEnter()
    window = Dialog.new(_dialogue[_index] + ["", "Press 'confirm' to continue..."])
  }
  onExit() {
    super.onExit()
  }
  update() {
    if (INPUT["reject"].firing || INPUT["confirm"].firing) {
      if (_index < _dialogue.count - 1) {
        _index = _index + 1
        window.setMessage(_dialogue[_index])
      } else {
        return PlayerInputState.new()
      }
    }
    return this
  }
}
class GameEndState is ModalWindowState {
  construct new() {
    super()
  }

  onEnter() {
    _world = scene.world
    _message = arg(0)
    _restart = arg(1)
    _state = null
    if (!_restart) {
      _pane = scene.addElement(Vec.new(Canvas.width, Canvas.height))
    }
    window = Dialog.new(_message)
  }
  changeState(nextState) {
    if (_state) {
      _state.onExit()
    }
    if (nextState) {
      nextState.withScene(scene).from(this).onEnter()
    }
    _state = nextState
  }

  update() {
    if (_state) {
      var result = _state.update()
      if (result == this) {
        changeState(null)
      } else if (_state != result) {
        changeState(_state)
      }
      return this
    }
    if (INPUT["inventory"].firing) {
      changeState(InventoryWindowState.new().with("readonly"))
    }
    if (INPUT["log"].firing) {
      changeState(ModalWindowState.new().with("history"))
    }
    if (INPUT["help"].firing) {
      changeState(HelpState.new())
    }
    if (INPUT["reject"].firing || INPUT["confirm"].firing) {
      scene.game.push(_restart ? "game" : "start")
    }
    return this
  }
}

class PlayerInputState is SceneState {

  construct new() {
    super()
  }
  onEnter() {
    _world = scene.world
  }

  update() {
    if (INPUT["inventory"].firing) {
      return InventoryWindowState.new()
    }
    if (INPUT["log"].firing) {
      return ModalWindowState.new().with("history")
    }
    if (INPUT["help"].firing) {
      return HelpState.new()
    }
    if (INPUT["cast"].firing) {
      return CastState.new()
    }

    if (_world.complete) {
      if (INPUT["confirm"].firing) {
        scene.game.push(GameScene)
      }
      return this
    }

    var player = _world.getEntityByTag("player")
    var i = 0
    for (input in INPUT.list("dir")) {
      if (input.firing) {
        player.pushAction(Components.actions.playerBump.new(DIR_EIGHT[i]))
      }
      i = i + 1
    }
    if (INPUT["drop"].firing) {
      return InventoryWindowState.new().with("drop")
    }
    if (INPUT["cast"].firing) {
      player.pushAction(Components.actions.cast.new().withArgs({}))
    }
    if (INPUT["pickup"].firing) {
      player.pushAction(Components.actions.pickup.new())
    }
    if (INPUT["descend"].justPressed) {
      player.pushAction(Components.actions.descend.new())
    }

    return this
  }
}

class GameScene is Scene {
  data { _data }
  construct new(args) {
    super(args)
    _t = 0
    _data = {}
    _messages = MessageLog.new()

    var world = _world = WorldGenerator.create()
    var player = world.getEntityByTag("player")
    changeState(PlayerInputState.new())
    _renderer = addElement(Renderer.new(Vec.new((Canvas.width - (32 * 16))/2, 26)))
    // _renderer = addElement(Renderer.new(Vec.new(8, 28)))
    if (player) {
      var left = Canvas.width / 2
      addElement(HealthBar.new(Vec.new(left + 2, 4), player.ref))
      addElement(ManaBar.new(Vec.new(left - 10 * 16 - 2, 4), player.ref))
    }
    addElement(HoverText.new(Vec.new(Canvas.width - 8, 8)))
    addElement(LogViewer.new(Vec.new(4, Canvas.height - 5 * 10), _messages))
    addElement(HintText.new(Vec.new(Canvas.width / 2, Canvas.height * 0.75)))
    //addElement(LogViewer.new(Vec.new(0, Canvas.height - 12 * 7), _messages))

    for (event in _world.events) {
      process(event)
    }
  }

  world { _world }
  messages { _messages }
  events { _state.events }

  process(event) {
    _state.process(event)
    super.process(event)

    if (event is Components.events.gameEnd) {
      var message
      var restart = true
      if (event.win) {
        restart = false
        message = "You have succeeded where others have failed. Return to your home, and reflect on your deeds."
      } else {
        message = "You have fallen, but perhaps others will take up your cause."
      }
      _messages.add(message, INK["playerDie"], false)
      changeState(GameEndState.new().with([ [ message, "", "Press 'confirm' to try again" ], restart ]))
    }
    if (event is Components.events.story) {
      if (event.moment.startsWith("dialogue:")) {
        changeState(DialogueState.new().with(event.moment[9..-1]))
      }
    }
    if (event is Components.events.changeZone && event.floor == 1) {
      _messages.add("Welcome to the dungeon.", INK["welcome"], false)
    }
    if (event is Components.events.cast) {
      var srcName = event.src.name
      var target = null
      var targetName = null
      if (event.target.count == 1) {
        target = event.target[0]
        targetName = target.name
      }
      if (event.src is Player) {
        srcName = TextSplitter.capitalize(Pronoun.you.subject)
      }
      if (event.target is Player) {
        targetName = Pronoun.you.subject
      }
      if (target) {
        _messages.add("%(srcName) cast \"%(event.spell.incantation())\" at %(targetName)", INK["blue"], true)
      } else {
        _messages.add("%(srcName) cast \"%(event.spell.incantation())\"", INK["blue"], true)
      }
    }
    if (event is Components.events.attack) {
      var srcName = event.src.name
      var noun = srcName
      if (event.src is Player) {
        noun = Pronoun.you.subject
        srcName = TextSplitter.capitalize(Pronoun.you.subject)
      }
      var targetName = event.target.name
      if (event.target is Player) {
        targetName = Pronoun.you.subject
      }
      if (event.result == AttackResult.invulnerable) {
        _messages.add("%(srcName) attacked the %(targetName) but it seems unaffected.", INK["orange"], true)

      } else if (event.result == AttackResult.blocked) {
        _messages.add("%(srcName) hit the %(targetName) but %(noun) wasn't powerful enough.", INK["orange"], true)
      } else if (event.src is Player && event.result == AttackResult.overkill) {
        _messages.add("%(targetName) is no more, by your hand.", INK["enemyAtk"], true)
      } else {
        _messages.add("%(srcName) attacked the %(targetName) for %(event.damage) damage.", INK["enemyAtk"], true)
      }
    }
    if (event is Components.events.lightning) {
      _messages.add("%(event.target) was struck by lightning.", INK["playerAtk"], false)
    }
    if (event is Components.events.kill) {
      _messages.add("%(event.target) was killed.", INK["text"], false)
    }
    if (event is Components.events.heal) {
      _messages.add("%(event.target) was healed for %(event.amount)", INK["healthRecovered"], false)
    }
    if (event is Components.events.rest) {
      _messages.add("%(event.src) rests.", INK["text"], true)
    }
    if (event is Components.events.unequipItem) {
      var itemName = _world["items"][event.item]["name"]
      _messages.add("%(event.src) removed the %(itemName)", INK["text"], false)
    }
    if (event is Components.events.equipItem) {
      var itemName = _world["items"][event.item]["name"]
      _messages.add("%(event.src) equipped the %(itemName)", INK["text"], false)
    }
    if (event is Components.events.pickup) {
      var itemName = _world["items"][event.item]["name"]
      if (event.qty == 1) {
        _messages.add("%(event.src) picked up the %(itemName)", INK["text"], true)
      } else {
        _messages.add("%(event.src) picked up %(event.qty) %(itemName)", INK["text"], true)
      }
    }
    if (event is Components.events.useItem) {
      var itemName = _world["items"][event.item]["name"]
      _messages.add("%(event.src) used %(itemName)", INK["text"], false)
    }
    if (event is Components.events.inflictCondition) {
      _messages.add("%(event.target) became confused.", INK["text"], false)
    }
    if (event is Components.events.extendCondition) {
      _messages.add("%(event.target)'s confusion was extended.", INK["text"], false)
    }
    if (event is Components.events.clearCondition) {
      _messages.add("%(event.target) recovered from %(event.condition).", INK["text"], false)
    }
    if (event is Components.events.descend) {
      _messages.add("You descend down the stairs.", INK["text"], false)
    }
  }

  update() {
    if (INPUT["toggleTiles"].firing) {
      _renderer.next()
    }
    if (INPUT["volUp"].firing) {
      Jukebox.volumeUp()
    }
    if (INPUT["volDown"].firing) {
      Jukebox.volumeDown()
    }
    if (INPUT["mute"].firing) {
      if (Jukebox.playing) {
        Jukebox.stopMusic()
      } else {
        // Jukebox.playMusic("soundTrack")
      }
    }
    super.update()
    // Global animation timer
    _t = _t + 1

    _state.events.clear()
    var nextState = _state.update()

    if (nextState != _state) {
      changeState(nextState)
    }

    _world.advance()
    for (event in _world.events) {
      process(event)
    }
    if (_world.complete) {
      _world.events.clear()
    }
  }

  previous { _previousState }

  changeState(nextState) {
    if (_state) {
      _state.onExit()
    }
    _previousState = _state || nextState
    nextState.withScene(this).onEnter()
    _state = nextState
  }

  draw() {
    var color = INK["black"]
    Canvas.cls(color)
    Canvas.offset()
    super.draw()
  }
}
import "./entities" for Player
import "./groups" for Components
