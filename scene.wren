import "jukebox" for Jukebox
import "dome" for Process, Log, StringUtils
import "graphics" for Canvas, Color, ImageData
import "input" for Keyboard, Mouse
import "math" for Vec
import "parcel" for
  DEBUG,
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
import "./ui/textbox" for TextBox
import "./ui/image" for ImagePanel
import "./ui/pane" for Pane
import "./ui/line" for Line as UiLine
import "./ui/panel" for SizeMode, Panel
import "./ui/dialog" for Dialog
import "./ui" for
  HealthBar,
  ManaBar,
  LineViewer,
  LogViewer,
  HistoryViewer,
  HoverText,
  HintText

import "./generator" for WorldGenerator, Seed
import "./combat" for AttackResult, DamageType
import "./spells" for SpellUtils, AllWords

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
      _ui.addElement(Label.new(Vec.new(0, 22), "%(incantation)"))
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
    if (windowType == "food") {
      var injured = arg(1)
      var consumedFood = arg(2)
      window = Pane.new(Vec.new(Canvas.width, Canvas.height))
      window.center()
      window.bg = INK["black"]
      var image = window.addElement(ImagePanel.new(ImageData.load("res/img/campfire.png")))
      image.center()
      System.print("pos: %(image.pos)")
      var pane = window.addElement(Pane.new(Vec.new()))
      pane.sizeMode = SizeMode.auto
      var messageLabel = pane.addElement(TextBox.new("", Canvas.width * 0.6 ))
      var label = pane.addElement(Label.new(Vec.new(0, 24), "Press \"ENTER\" to continue" ))

      label.centerHorizontally()
      if (injured && consumedFood) {
        messageLabel.text = "You descend to the lower levels.\n You recover yourself with the help of some food."
      } else if (injured && !consumedFood) {
        messageLabel.text = "You descend to the lower levels.\n You recover yourself with the help of some food."
        // window = Dialog.new("You descend to the lower levels. You recover yourself with the help of some food.")
      } else {
        messageLabel.text = "You descend to the lower levels, resting inbetween."
        // window = Dialog.new("You descend to the lower levels. You have no food to bolster yourself with.")
      }
      messageLabel.centerHorizontally()
      pane.alignBottom()
      pane.centerHorizontally()
      pane.pos.y = pane.pos.y - 48
    }
    if (windowType == "error") {
      window = Dialog.new("Not enough MP to cast this spell.")
    }
  }
  onExit() {
    scene.removeElement(window)
  }
  update() {
    if (INPUT["reject"].firing || INPUT["confirm"].firing) {
      return previous
    }
    return this
  }
}
class LexiconState is SceneState {
  construct new() {
    super()
  }

  window { _window }
  window=(v) {
    if (_window) {
      scene.removeElement(_window)
    }
    _window = v
    if (_window) {
      scene.addElement(_window)
    }
  }

  onEnter() {

    window = Pane.new(Vec.new(Canvas.width * 0.6, Canvas.height * 0.6))
    window.padding = 0
    window.border = 4
    window.borderColor = INK["bookBorder"]
    window.bg = INK["bookBg"]
    window.center()
    var line = window.addElement(UiLine.new())
    line.start = Vec.new(window.size.x / 2, 0)
    line.end = Vec.new(window.size.x / 2, window.size.y)
    line.thickness = 3
    var left = _leftPanel = window.addElement(Panel.new(Vec.new(window.size.x / 2 - 8, window.size.y - 8)))
    var right = _rightPanel = window.addElement(Panel.new(Vec.new(window.size.x / 2 - 12, window.size.y - 8)))
    left.pos.x = 8
    left.padding = 4
    left.centerVertically()
    right.padding = 4
    right.alignRight()
    right.centerVertically()

    _leftPageLabels = []
    _rightPageLabels = []


    addLabel(_leftPageLabels, left, "0")
    var label
    label = addLabel(_leftPageLabels, left, "")
    label.pos.y = left.size.y / 4
    label = addLabel(_leftPageLabels, left, "")
    label.pos.y = left.size.y / 4 + label.size.y * 2
    label = addLabel(_leftPageLabels, left, "")
    label.pos.y = left.size.y * 0.6
    label = addLabel(_leftPageLabels, left, "")
    label.pos.y = left.size.y * 0.75

    var textBox = right.addElement(TextBox.new("", right.size.x - 8))
    textBox.alignRight()
    _rightPageTextBox = textBox
    textBox.color = INK["bookText"]
    textBox.pos.y = left.size.y * 0.6

    addLabel(_rightPageLabels, right, "0")
    label = addLabel(_rightPageLabels, right, "")
    label.pos.y = left.size.y / 4
    label = addLabel(_rightPageLabels, right, "")
    label.pos.y = left.size.y / 4 + label.size.y * 2
    label = addLabel(_rightPageLabels, right, "")
    label.pos.y = left.size.y * 0.6
    label = addLabel(_rightPageLabels, right, "")
    label.pos.y = left.size.y * 0.75

    _page = 0

    _dialog = scene.addElement(Pane.new(Vec.new()))
    _dialog.sizeMode = SizeMode.auto
    var title = _dialog.addElement(Label.new(Vec.new(0, 0), "Your Lexicon"))
    _dialog.centerHorizontally()
    _dialog.pos.y = window.pos.y - 30

    _hint = scene.addElement(Pane.new(Vec.new()))
    _hint.sizeMode = SizeMode.auto
    _hint.addElement(Label.new(Vec.new(0, 0), "Press LEFT or RIGHT to change pages"))
    _hint.centerHorizontally()
    _hint.pos.y = window.pos.y + window.size.y + 20
  }

  addLabel(list, parent, text) {
    var label = parent.addElement(Label.new(text))
    list.add(label)
    label.color = INK["bookText"]
    return label
  }

  onExit() {
    scene.removeElement(window)
    scene.removeElement(_dialog)
    scene.removeElement(_hint)
    window = null
  }

  update() {
    var player = scene.world.getEntityByTag("player")
    var truePage = 0

    if (_page > 0) {
      _leftPageLabels[0].text = (_page * 2)
      _leftPageLabels[0].alignBottom()
    } else {
      _leftPageLabels[0].text = ""
    }
    _rightPageLabels[0].text = (_page * 2) + 1
    _rightPageLabels[0].alignRight()
    _rightPageLabels[0].alignBottom()

    var order = player["learningOrder"]
    var maxPageCount = (AllWords.count / 2).floor + 1
    var pageCount = (order.count / 2).floor

    var leftInput = INPUT.list("dir")[3]
    var rightInput = INPUT.list("dir")[1]

    if (leftInput.firing) {
      _page = (_page - 1).max(0)
    }
    if (rightInput.firing) {
      _page = (_page + 1).min(maxPageCount)
    }

    if (INPUT["reject"].firing || INPUT["confirm"].firing) {
      return scene.world.complete ? previous : PlayerInputState.new()
    }

    if (_page == 0) {
      _leftPageLabels.skip(1).each {|label| label.text = "" }
      _rightPageLabels.skip(1).each {|label| label.text = "" }
      _rightPageLabels[1].text = "Veralethi"
      _rightPageLabels[1].centerHorizontally()
      _rightPageLabels[2].text = "Grammar and Lexicon"
      _rightPageLabels[2].centerHorizontally()

      _rightPageTextBox.text = "Spells spoken in Veralethi are composed in the following structure:\n\n<VERB> <SUBJECT> <OBJECT>.\n\n The <OBJECT> may be followed by a <MODIFIER>."
      return this
    } else {
      _rightPageTextBox.text = ""
    }

    truePage = _page - 1


    var leftWord = null
    var rightWord = null
    // there's at least one item
    // not the last page
    // orderCount % 2 != 0

    if (order.count >= 1 && (truePage < pageCount || (truePage == pageCount && (order.count % 2) != 0))) {
      leftWord = order[(truePage * 2)]
    }
    // at least 2 items
    // not the last page
    // or the last page and there's a multiple of two items
    if (order.count >= 2 && (truePage <= pageCount - 1 || (truePage == pageCount - 1 && (order.count % 2) == 0))) {
      rightWord = order[(truePage * 2) + 1]
    }

    if (leftWord) {
      var leftLex = SpellUtils.getWordFromToken(leftWord)
      _leftPageLabels[1].text = "%(leftWord.lexeme)"
      _leftPageLabels[1].centerHorizontally()
      _leftPageLabels[2].text = "<%(leftWord.category)>"
      _leftPageLabels[2].centerHorizontally()
      _leftPageLabels[3].text = "\"%(leftLex)\""
      _leftPageLabels[3].centerHorizontally()
      _leftPageLabels[4].text = "\"%(leftWord.description)\""
      _leftPageLabels[4].centerHorizontally()
    } else {
      _leftPageLabels.skip(1).each {|label| label.text = "" }
    }
    if (rightWord) {
      var rightLex = SpellUtils.getWordFromToken(rightWord)
      _rightPageLabels[1].text = "%(rightWord.lexeme)"
      _rightPageLabels[1].centerHorizontally()
      _rightPageLabels[2].text = "<%(rightWord.category)>"
      _rightPageLabels[2].centerHorizontally()
      _rightPageLabels[3].text = "\"%(rightLex)\""
      _rightPageLabels[3].centerHorizontally()
      _rightPageLabels[4].text = "\"%(rightWord.description)\""
      _rightPageLabels[4].centerHorizontally()
    } else {
      _rightPageLabels.skip(1).each {|label| label.text = "" }
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
    _phraseLabel = window.addElement(Label.new(Vec.new(0, 38), ""))
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
        var cost = _spell.cost(player)
        if (cost > player["stats"]["mp"]) {
          return ModalWindowState.new().withArgs([
            "error",
            "Not enough MP to cast this spell."
          ])
        } else if (_spell.target()["target"] == "self") {
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
        var cost = spell.cost(player)
        _costLabel.text = "[ %(cost) MP ]"
        _costLabel.centerHorizontally()
        if (cost > player["stats"]["mp"]) {
          _costLabel.color = INK["orange"]
        } else {
          _costLabel.color = INK["text"]
        }
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
      "'Confirm' - Enter",
      "'Reject' - Escape",
      "",
      "Move - HJKLYUNB, WASDQECZ, Arrow Keys, Numpad",
      "Cast a spell - Space",
      "View your lexicon - 'l'",
      "",
      "Other commands",
      "Inventory - 'i', press number to use",
      "Open Log - 'v'"
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
var ConditionNames = DataFile.load("dialogue", "data/conditions.json")
var ModifierNames = DataFile.load("dialogue", "data/modifiers.json")
class DialogueState is ModalWindowState {
  construct new() {
    super()
  }
  onEnter() {
    var moment = arg(0)
    _dialogue = Dialogue[moment]
    _index = 0
    super.onEnter()
    window = Dialog.new(_dialogue[_index] + ["", "Press 'ENTER' to continue..."])
  }
  onExit() {
    super.onExit()
  }

  dialogue { _dialogue }
  index { _index }

  update() {
    if (INPUT["reject"].firing || INPUT["confirm"].firing) {
      if (_index < _dialogue.count - 1) {
        _index = _index + 1
        window.setMessage(_dialogue[_index] + ["", "Press 'ENTER' to continue..."])
      } else {
        return PlayerInputState.new()
      }
    }
    return this
  }
}
class IntroDialogueState is DialogueState {
  construct new() { super() }
  onExit() {
    super.onExit()
    scene.addElement(HintText.new(Vec.new(Canvas.width / 2, Canvas.height * 0.8)))
  }
  update() {
    var next = super.update()
    if (index == dialogue.count - 1 && next == this) {
      if (INPUT["lexicon"].firing) {
        return LexiconState.new()
      }
      if (INPUT["cast"].firing) {
        return CastState.new()
      }
    }
    return next
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
      // _pane = scene.addElement(Pane.new(Vec.new(Canvas.width, Canvas.height)))
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
    if (INPUT["lexicon"].firing) {
      changeState(LexiconState.new())
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
    if (INPUT["lexicon"].firing) {
      return LexiconState.new()
    }
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
    addElement(LogViewer.new(Vec.new(4, Canvas.height - 5 * 10), _messages, true))
    if (DEBUG) {
      addElement(Label.new(Vec.new(0, 0), Seed))
    }

    _conditionLabels = {}
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

    if (event is Components.events.gameStart) {
      System.print("Game started!")
      changeState(IntroDialogueState.new().with(["gameStart"]))
    }
    if (event is Components.events.gameEnd) {
      var message
      var restart = true
      if (event.win) {
        restart = false
        message = "You have defeated the archmage, who hoards secrets in this place. You leave with your treasure and go out into the world. But that is a tale for another time."
      } else {
        message = "You have perished, but your descendants may yet succeed."
      }
      _messages.add(message, INK["playerDie"], false)
      changeState(GameEndState.new().with([ [ message, "", "Press 'ENTER' to try again" ], restart ]))
    }
    if (event is Components.events.story) {
      if (event.moment.startsWith("dialogue:")) {
        changeState(DialogueState.new().with(event.moment[9..-1]))
      }
    }
    if (event is Components.events.changeZone && event.floor == 1) {
      _messages.add("Welcome to the dungeon.", INK["welcome"], false)
    }
    if (event is Components.events.push) {
      var srcName = event.src.name
      var target = event.target.name
      _messages.add("%(srcName) pushed %(target) away.", INK["text"], true)
    }
    if (event is Components.events.learn) {
      var srcName = event.src.name
      var prep = "their"
      if (event.src is Player) {
        srcName = Pronoun.you.subject
        prep = "your"
      }
      srcName = TextSplitter.capitalize(srcName)
      var wordText = "\"%(SpellUtils.getWordFromToken(event.word))\" <%(event.word.lexeme)>"
      _messages.add("%(srcName) added %(wordText) to %(prep) lexicon.", INK["gold"], false)
    }
    if (event is Components.events.summon) {
      var srcName = event.src.name
      var targetName = event.target.name
      var prep = "a"
      var post = ""
      if (event.qty > 1) {
        prep = "%(event.qty)"
        post = "s"
      }
      _messages.add("%(srcName) summons %(prep) %(targetName)%(post) illusions!", INK["text"], true)
    }
    if (event is Components.events.cast) {
      var srcName = event.src.name
      var target = null
      var targetName = null
      var directive = "at"
      if (event.target.count == 1) {
        target = event.target[0]
        targetName = target.name
      }
      if (event.src is Player) {
        srcName = Pronoun.you.subject
      }
      if (target is Player) {
        targetName = Pronoun.you.subject
        if (event.src is Player) {
          directive = "on"
          targetName = "yourself"
        }
      }
      srcName = TextSplitter.capitalize(srcName)
      if (target) {
        _messages.add("%(srcName) cast \"%(event.spell.incantation())\" %(directive) %(targetName)", INK["blue"], true)
      } else {
        _messages.add("%(srcName) cast \"%(event.spell.incantation())\"", INK["blue"], true)
      }
    }
    if (event is Components.events.attack) {
      var srcName = event.src.name
      var noun = srcName
      if (event.src is Player) {
        noun = Pronoun.you.subject
        srcName = Pronoun.you.subject
      }
      var targetName = event.target.name
      if (event.target is Player) {
        targetName = Pronoun.you.subject
      } else {
        targetName = "the " + targetName
      }
      srcName = TextSplitter.capitalize(srcName)
      var verb = "attacked"
      if (event.result == AttackResult.invulnerable) {
        _messages.add("%(srcName) attacked %(targetName) but it seems unaffected.", INK["orange"], true)

      } else if (event.result == AttackResult.blocked) {
        _messages.add("%(srcName) hit %(targetName) but %(noun) wasn't powerful enough.", INK["orange"], true)
      } else {
        if (event.damage.type == DamageType.fire) {
          verb = "burned"
        }
        if (event.damage.type == DamageType.ice) {
          verb = "chilled"
        }
        _messages.add("%(srcName) %(verb) %(targetName) for %(event.damage.amount) damage.", INK["enemyAtk"], true)
      }
    }
    if (event is Components.events.lightning) {
      _messages.add("%(event.target) was struck by lightning.", INK["playerAtk"], false)
    }
    if (event is Components.events.kill) {
      var targetName = TextSplitter.capitalize(event.target.name)
      _messages.add("%(targetName) was killed.", INK["text"], false)
    }
    if (event is Components.events.heal) {
      var targetName = TextSplitter.capitalize(event.target.name)
      _messages.add("%(targetName) was healed for %(event.amount)", INK["healthRecovered"], false)
    }
    if (event is Components.events.rest) {
      var srcName = TextSplitter.capitalize(event.src.name)
      _messages.add("%(srcName) rests.", INK["text"], true)
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
    if (event is Components.events.stuck) {
      var srcName = event.src.name
      var modifier = "was"
      if (event.src is Player) {
        srcName = Pronoun.you.subject
        modifier = "are"
      }
      srcName = TextSplitter.capitalize(srcName)
      _messages.add("%(srcName) %(modifier) stuck and couldn't do anything.", INK["text"], true)
    }
    if (event is Components.events.clearModifier) {
      var config = ModifierNames[event.modifier]
      if (config) {
        var name = config["name"]
        _messages.add("%(event.target) is no longer %(name).", INK["text"], false)
        removeConditionLabel(event.modifier)
      }
    }
    if (event is Components.events.clearTag) {
      var config = ModifierNames[event.tag]
      if (config) {
        var name = config["name"]
        _messages.add("%(event.target) is no longer %(name).", INK["text"], false)
        removeConditionLabel(event.tag)
      }
    }
    if (event is Components.events.applyTag) {
      var config = ModifierNames[event.tag]
      if (config) {
        var name = config["name"]
        _messages.add("%(event.target) is granted %(name).", INK["text"], false)
        addConditionLabel(event.tag, name)
      }
    }
    if (event is Components.events.applyModifier) {
      var config = ModifierNames[event.modifier]
      if (config) {
        var name = config["name"]
        _messages.add("%(event.target) is granted %(name).", INK["text"], false)
        addConditionLabel(event.modifier, name)
      }
    }
    if (event is Components.events.inflictCondition) {
      var name = ConditionNames[event.condition]["name"]
      var verb = ConditionNames[event.condition]["inflictVerb"] || "became"

      _messages.add("%(event.target) %(verb) %(name).", INK["text"], false)
      if (event.target is Player) {
        name = TextSplitter.capitalize(name)
        addConditionLabel(event.condition, name)
      }
    }
    if (event is Components.events.extendCondition) {
      var name = ConditionNames[event.condition]["name"]
      _messages.add("%(event.target)'s %(name) was extended.", INK["text"], false)
    }
    if (event is Components.events.clearCondition) {
      var name = ConditionNames[event.condition]["name"]
      var verb = ConditionNames[event.condition]["recoverVerb"] || "recovered from"
      _messages.add("%(event.target) %(verb) %(name).", INK["text"], false)
      removeConditionLabel(event.condition)
    }
    if (event is Components.events.descend) {
      _messages.add("You descend down the stairs.", INK["text"], false)
    }
    if (event is Components.events.campfire) {
      changeState(ModalWindowState.new().with(["food", event.injured, event.consumedFood]))
    }
  }

  removeConditionLabel(id) {
    if (_conditionLabels[id]) {
      removeElement(_conditionLabels[id])
      _conditionLabels.remove(id)
      recomputeConditionLabels()
    }
  }
  addConditionLabel(id, label) {
    if (!_conditionLabels[id]) {
      _conditionLabels[id] = addElement(Label.new(Vec.new(0, Canvas.height - 28), label))
      _conditionLabels[id].alignRight()
      recomputeConditionLabels()
    }

  }
  recomputeConditionLabels() {
    var y = (Canvas.height - (_conditionLabels.count * 8) + ((_conditionLabels.count - 1) * 12)) / 2
    for (label in _conditionLabels.values) {
      label.pos.y = y
      y = y - 12
    }
  }

  update() {
    /*
    if (INPUT["toggleTiles"].firing) {
      _renderer.next()
    }
    */
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
