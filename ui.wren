import "graphics" for Color, Canvas, SpriteSheet, ImageData
import "math" for Vec
import "input" for Mouse
import "./parcel" for
  Config,
  Element,
  Event,
  Entity,
  ChangeZoneEvent,
  Palette
import "messages" for Pronoun
import "./entities" for Player
import "groups" for Components
import "./items" for Item, EquipmentSlot

import "./palette" for INK
import "./ui/gauge" for Gauge
import "./ui/pane" for Pane
import "./ui/panel" for SizeMode
import "./ui/label" for Label
import "./ui/events" for
  HoverEvent,
  TargetEvent,
  TargetBeginEvent,
  TargetEndEvent

import "./inputs" for VI_SCHEME as INPUT
import "./text" for TextSplitter


class HintText is Pane {
  construct new(pos) {
    super()
    this.pos = pos
    _text = "press F1 or '/' for help"
    addElement(Label.new(Vec.new(0, 0), _text))
    _t = 0
    sizeMode = SizeMode.auto
    centerHorizontally()
    alignBottom()
  }
  construct new(pos, message) {
    _pos = pos
    _text = message
    addElement(Label.new(Vec.new(0, 0), _text))
    _t = 0
  }

  update() {
    _t = _t + 1
    if (_t > 10 * 60) {
      removeSelf()
    }
  }

  process(event) {
    if (event is ChangeZoneEvent && event.floor > 0) {
      removeSelf()
    }
    super.process(event)
  }

  content() {
    if (_text) {
      Canvas.print(_text, 0, 0, INK["text"])
    }
  }
}

class HoverText is Element {
  construct new(pos) {
    super()
    _pos = pos
    _align = "right"
    _text = ""
  }

  update() {
    _world = parent.world
  }

  process(event) {
    if (event is HoverEvent) {
      if (event.target && event.target is Entity) {
        _text = event.target.name
        if (event.target is Player) {
          _text = TextSplitter.capitalize(Pronoun.you.subject)
        }
        if (event.target["killed"]) {
          _text = "Body of %(event.target.name)"
        }
      } else if (event.target is Item) {
        _text = event.target.name
      } else if (event.target is String) {
        _text = event.target
      } else {
        _text = ""
      }
    }
    super.process(event)
  }

  draw() {
    var offset = Canvas.offset
    Canvas.offset(_pos.x,_pos.y)

    var start = 0
    if (_align == "right") {
      start = - (_text.count * 8)
    }
    if (_text) {
      Canvas.print(_text, start, 0, INK["text"])
    }

    Canvas.offset(offset.x, offset.y)
  }
}

class HistoryViewer is Element {
  construct new(pos, size, log) {
    super()
    _pos = pos
    _size = size
    _scroll = 0
    _log = log
    _height = (size.y / 10).floor
    _viewer = addElement(LogViewer.new(pos + Vec.new(4, 4), log, _height, false))
    _viewer.full = true
  }

  update() {
    /*
    if (SCROLL_BEGIN.firing) {
      _scroll = 0
    }
    if (SCROLL_END.firing) {
      _scroll = _log.count - 1
    }
    */
    if (INPUT["scrollUp"].firing) {
      _scroll = _scroll - 1
    }
    if (INPUT["scrollDown"].firing) {
      _scroll = _scroll + 1
    }
    _scroll = _scroll.clamp(0, _log.count - _height)
    _viewer.start = _scroll
    super.update()
    _scroll = _viewer.start
  }
  draw() {
    Canvas.rectfill(_pos.x, _pos.y, _size.x, _size.y, INK["bg"])
    Canvas.rect(_pos.x, _pos.y, _size.x, _size.y, INK["border"])
    super.draw()
  }
}

class LineViewer is Element {
  construct new(pos, log, size, lines) {
    super()
    _pos = pos
    _messageLog = log
    _max = size
    _lines = lines || []
  }
  pos { _pos }
  lines=(v) { _lines = v }
  lines { _lines }

  static getWidth(lines) {
    var max = 0
    for (line in lines) {
      if (line.count > max) {
        max = line.count
      }
    }
    return max
  }

  draw() {
    var offset = Canvas.offset
    Canvas.offset(_pos.x,_pos.y)

    var dir = 1
    var start = 0

    var startLine = 0
    var endLine = _lines.count

    var line = 0
    var width = Canvas.width
    var glyphWidth = 8
    var lineHeight = 10
    for (i in startLine...endLine) {
      var text = _lines[i]
      var x = 0
      var words = text.split(" ")
      for (word in words) {
        if (width - x * glyphWidth < word.count * glyphWidth) {
          x = 0
          line = line + 1
        }
        var y = start + dir * lineHeight * line
        if (y >= 0 && y + lineHeight <= Canvas.height) {
          Canvas.print(word, x * glyphWidth, start + dir * lineHeight * line, INK["text"])
        } else {
          break
        }
        x = x + (word.count + 1)
      }

      line = line + 1
      x = 0
    }

    Canvas.offset(offset.x, offset.y)
  }
}
class LogViewer is Element {
  construct new(pos, log, fade) {
    super()
    init(pos, log, 5, fade)
  }
  construct new(pos, log, size, fade) {
    super()
    init(pos, log, size, fade)
  }

  init(pos, log, size, fade)  {
    _full = false
    _pos = pos
    _messageLog = log
    _max = size
    _start = 0
    _messages = _messageLog.previous(_max) || []
    _fade = fade
  }

  start { _start }
  start=(v) { _start = v }
  full=(v) { _full = v }
  full { _full }

  update() {
    _start = _start.clamp(0, _messageLog.count - _max)
    if (_messageLog.count < _max) {
      _start = 0
    }
    if (_full) {
      _messages = _messageLog.history(_start, _max) || []
    } else {
      _messages = _messageLog.previous(_max) || []
    }
  }

  draw() {
    var a = 1.0
    var offset = Canvas.offset
    Canvas.offset(_pos.x,_pos.y)

    var dir = 1
    var start = 0

    var startLine = 0
    var endLine = _messages.count

    var line = 0
    var width = Canvas.width
    var glyphWidth = 8
    var lineHeight = 10
    for (i in startLine...endLine) {
      var message = _messages[i]
      var x = 0
      var text = message.text
      if (message.count > 1) {
        text = "%(text) (x%(message.count))"
      }
      var words = text.split(" ")
      for (word in words) {
        if (width - x * glyphWidth < word.count * glyphWidth) {
          x = 0
          line = line + 1
        }
        var y = start + dir * lineHeight * line
        if (y >= 0 && y + lineHeight <= Canvas.height) {
          var color = message.color * 1
          if (_fade) {
            color.a = color.a * a
            a = a * 0.97
          }
          Canvas.print(word, x * glyphWidth, start + dir * lineHeight * line, color)
        } else {
          break
        }
        x = x + (word.count + 1)
      }

      line = line + 1
      x = 0
    }

    Canvas.offset(offset.x, offset.y)
  }
}

class MapZone is Element {
  construct new(pos, cursor, area, range) {
    super()
    _pos = pos
    _cursor = cursor
    _area = area
    _range = range
  }

  process(event) {
    if (event is TargetEndEvent) {
      removeSelf()
    }
  }
  draw() {
    var offset = Canvas.offset
    Canvas.offset(_pos.x,_pos.y)
    var dist = _range + _area
    var x = (_cursor.x - dist) * 16
    var y = (_cursor.y - dist) * 16
    var w = (dist * 2 + 1) * 16
    // Canvas.rectfill(x, y, w, w, INK["targetAreaBg"])
    Canvas.rect(x - 1, y - 1, w + 2, w + 2, INK["targetAreaBorder"])

    Canvas.offset(offset.x, offset.y)
  }

}
class Cursor is Element {
  construct new(pos, cursor, area) {
    super()
    _pos = pos
    _cursor = cursor
    _area = area
  }

  process(event) {
    if (event is TargetEvent) {
      _cursor = event.pos
    } else if (event is TargetEndEvent) {
      removeSelf()
    }
  }

  draw() {
    var offset = Canvas.offset
    Canvas.offset(_pos.x,_pos.y)

    var dist = _area
    for (dy in (-dist)..(dist)) {
      for (dx in (-dist)..(dist)) {
        var x = (_cursor.x + dx) * 16
        var y = (_cursor.y + dy) * 16
        if (dx == dy && dx == 0) {
          Canvas.rectfill(x, y, 16, 16, INK["targetCursor"])
          Canvas.rect(x, y, 16, 16, INK["targetBorder"])
          continue
        }
        Canvas.rectfill(x, y, 16, 16, INK["targetArea"])
        Canvas.rect(x, y, 16, 16, INK["targetBorder"])
      }
    }

    Canvas.offset(offset.x, offset.y)
  }

}

class HealthBar is Element {
  construct new(pos, entity) {
    super()
    _pos = pos
    _entity = entity
    _gauge = addElement(Gauge.new(_pos, "HP", 5, 5, 10))
  }

  process(event) {
    if (event is Components.events.attack && event.target.id == _entity.id) {
      updateValue()
    }
    if (event is Components.events.heal && event.target.id == _entity.id) {
      updateValue()
    }
  }

  updateValue() {
    var stats = _world.getEntityById(_entity)["stats"]
    var hp = stats.get("hp")
    var hpMax = stats.get("hpMax")
    _gauge.animateValues(hp, hpMax)
  }

  update() {
    super.update()
    if (!_world) {
      _world = parent.world
      var stats = _world.getEntityById(_entity)["stats"]
      var hp = stats.get("hp")
      var hpMax = stats.get("hpMax")
      _gauge.maxValue = hpMax
      _gauge.value = hp
    }
  }

  draw() {
    var offset = Canvas.offset
    Canvas.offset(_pos.x,_pos.y)
    super.draw()

    var floor = _world.zoneIndex + 1
    Canvas.print("Floor: %(floor)", (10 + 1) * 16, 4, INK["barText"])

    Canvas.offset(offset.x, offset.y)
  }
}
class ManaBar is Element {
  construct new(pos, entity) {
    super()
    _pos = pos
    _entity = entity
  }

  process(event) {
    if (event is Components.events.regen && event.target.id == _entity.id) {
      updateValue()
    }
    if (event is Components.events.cast && event.src.id == _entity.id) {
      updateValue()
    }
    if (event is Components.events.recover && event.target.id == _entity.id) {
      updateValue()
    }
  }

  updateValue() {
    var stats = _world.getEntityById(_entity)["stats"]
    var value = stats.get("mp")
    var max = stats.get("mpMax")
    _gauge.animateValues(value, max)
  }

  onAdd() {
    _world = parent.world
    var stats = _world.getEntityById(_entity)["stats"]
    _gauge = addElement(Gauge.new(_pos, "MP", stats["mp"], stats["mpMax"], 10))
    _gauge.fg = INK["manaBarFilled"]
    _gauge.bg = INK["manaBarEmpty"]
    _gauge.mirror = true
  }

  update() {
    super.update()
    if (!_world) {
      _world = parent.world
      var stats = _world.getEntityById(_entity)["stats"]
      var value = stats.get("mp")
      var max = stats.get("mpMax")
      _gauge.maxValue = max
      _gauge.value = value
    }
  }

  draw() {
    var offset = Canvas.offset
    Canvas.offset(_pos.x,_pos.y)
    super.draw()
    Canvas.offset(offset.x, offset.y)
  }
}

