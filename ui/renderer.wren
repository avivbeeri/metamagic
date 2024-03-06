import "graphics" for Color, Canvas, SpriteSheet, ImageData
import "math" for Vec
import "input" for Mouse
import "./parcel" for
  Config,
  Scheduler,
  Element,
  Event,
  Entity,
  ChangeZoneEvent,
  Palette
import "./palette" for INK
import "./ui/events" for
  HoverEvent,
  TargetBeginEvent,
  TargetEndEvent

import "./items" for EquipmentSlot
import "./ui" for Cursor, MapZone

var DEBUG = false

class Renderer is Element {
  construct new(pos) {
    super()
    _renderers = [
      AsciiRenderer.new(pos),
      TileRenderer.new(pos)
    ]
    _index = Config["tiles"] ? 1 : 0
  }
  parent=(v) {
    for (renderer in _renderers) {
      renderer.parent = v
    }
  }
  next() {
    _index = (_index + 1) % _renderers.count
  }
  update() {
    _renderers[_index].update()
  }
  process(event) {
    _renderers[_index].process(event)
  }
  draw() {
    _renderers[_index].draw()
  }


}
class AsciiRenderer is Element {
  construct new(pos) {
    super()
    _pos = pos
    _bg = INK["bg"] * 1
    _bg.a = 128
  }
  process(event) {
    if (event is TargetBeginEvent) {
      addElement(Cursor.new(_pos, event.pos, event.area))
      var player = _world.getEntityByTag("player")
      if (player) {
        addElement(MapZone.new(_pos, player.pos, event.area, event.range))
      }
    }
    super.process(event)
  }

  update() {
    _world = parent.world
    var hover = (Mouse.pos - _pos) / 16
    hover.x = hover.x.floor
    hover.y = hover.y.floor
    var found = false
    var tile = _world.zone.map[hover]
    if (tile["visible"] == true) {
      for (entity in _world.entities()) {
        if (entity.pos == null) {
          continue
        }
        if (hover == entity.pos) {
          found = true
          top.process(HoverEvent.new(entity))
        }
      }
    }
    if (!found && tile["visible"]) {
      if (!found && tile["items"] && !tile["items"].isEmpty) {
        found = true
        var itemId = tile["items"][0].id
        var item = _world["items"][itemId]
        top.process(HoverEvent.new(item))
      }
      if (!found && tile["statue"]) {
        found = true
        top.process(HoverEvent.new("Statue"))
      }
      if (!found && tile["altar"]) {
        found = true
        top.process(HoverEvent.new("Altar"))
      }
      if (!found && tile["stairs"]) {
        found = true
        top.process(HoverEvent.new(tile["stairs"] == "down" ? "Stairs Down" : "Stairs Up"))
      }
      if (!found && tile["blood"]) {
        found = true
        top.process(HoverEvent.new("Pool of blood"))
      }
      if (!found && tile["grass"]) {
        found = true
        top.process(HoverEvent.new("Grass"))
      }
      if (!found && tile["water"]) {
        found = true
        if (tile["chilled"] && tile["chilled"] > 0) {
          top.process(HoverEvent.new("Ice"))
        } else {
          top.process(HoverEvent.new("Water"))
        }
      }
      if (!found && tile["burning"] && tile["burning"] > 0) {
        found = true
        top.process(HoverEvent.new("Fire"))
      }
    }
    if (!found) {
      top.process(HoverEvent.new(null))
    }
  }

  world { _world }
  pos { _pos }

  draw() {
    var offset = Canvas.offset
    Canvas.offset(_pos.x,_pos.y)
    var map = _world.zone.map
    var player = _world.getEntityByTag("player")

    for (y in map.yRange) {
      for (x in map.xRange) {
        if (!map[x, y]["visible"]) {
          continue
        }
        var color = INK["default"]
        if (map[x, y]["blood"]) {
          color = INK["blood"]
        }
        if (map[x, y]["burning"] && map[x, y]["burning"] > 0) {
          color = INK["fire"]
        }
        if (map[x, y]["grass"]) {
          color = INK["grass"]
        }
        if (map[x, y]["water"]) {
          if (map[x,y]["chilled"] && map[x,y]["chilled"] > 0) {
            color = INK["ice"]
          } else {
            color = INK["water"]
          }
        }
        if (map[x, y]["visible"] == "maybe") {
          color = INK["obscured"]
        }
        if (DEBUG) {
          if (map[x, y]["seen"]) {
            color = Color.red
          }
          if (map[x, y]["cost"]) {
            printSymbolBg(map[x, y]["cost"].toString, x, y, INK["burgandy"])
            printSymbol(map[x, y]["cost"].toString, x, y, color)
          }
        }
        if (map[x, y]["void"]) {
        } else if (map[x, y]["solid"]) {
          if (map[x, y]["altar"]) {
            printSymbolBg("^", x, y, INK["altarBg"])
            printSymbol("^", x, y, INK["altar"])
          } else if (map[x, y]["statue"]) {
            var bg = INK["lilac"] * 1
            bg.a = 128
            printSymbolBg("£", x, y, bg)
            printSymbol("£", x, y, color)
          } else {
            printSymbolBg("#", x, y, INK["wallBg"])
            printSymbol("#", x, y, INK["wall"])
          }
        } else if (map[x, y]["stairs"]) {
          if (map[x, y]["stairs"] == "down") {
            printSymbol(">", x, y, INK["downstairs"])
          }
          if (map[x, y]["stairs"] == "up") {
            printSymbol("<", x, y, INK["upstairs"])
          }
        } else if (map[x, y]["burning"] && map[x, y]["burning"] > 0) {
          printSymbolBg("~", x, y, INK["fireBg"])
          printSymbol("^", x, y, color)
        } else if (map[x, y]["grass"]) {
          printSymbol("\"", x, y, color)
        } else if (map[x, y]["water"]) {
          if (map[x, y]["chilled"] && map[x,y]["chilled"] > 0) {
            printSymbolBg("~", x, y, INK["iceBg"])
          } else {
            printSymbolBg("~", x, y, INK["waterBg"])
          }
          printSymbol("~", x, y, color)
        } else {
          printSymbolBg(".", x, y, INK["floorStone"])
          printSymbol(".", x, y, color)
        }

        var items = map[x, y]["items"]
        if (items && items.count > 0) {
          var bg = INK["bg"] * 1
          bg.a = 128
          Canvas.rectfill(x * 16, y * 16, 16, 16, bg)
          var color = INK["treasure"]
          var symbolMap = {
            "food": ";",
            "potion": "!",
            "scroll": "~",
            "wand": "~",
            "sword": "/",
            "shield": "}",
            "armor": "[",
          }
          var kind = _world["items"][items[0].id].kind
          printSymbol(symbolMap[kind], x, y, color)
        }
      }
    }

    var tileEntities = _world.entities().sort {|a, b|
      if (a["killed"] && !b["killed"]) {
        return true
      }
      if (!a["killed"] && b["killed"]) {
        return false
      }
      return a["killed"]
    }
    if (player) {
      tileEntities = tileEntities + [ player ]
    }

    for (entity in tileEntities) {
      if (!entity.pos) {
        continue
      }

      entity.spaces.where {|space| map[space]["visible"] == true }.each {|space|
        var symbol = entity["symbol"] || entity.name && entity.name[0] || "?"
        var color = INK["creature"]

        if (entity["killed"]) {
          color = (color * 1)
          color.a = 192
          symbol = "\%"
        }
        if (entity["frozen"]) {
          color = INK["wall"]
          symbol = "£"
          var bg = INK["bg"] * 1
          bg.a = 128
          printSymbolBg("£", space.x, space.y, bg)
        }
        //Canvas.print(symbol, space.x * 16 + 4, space.y * 16 + 4, Color.white)
        if (entity["conditions"].containsKey("burning")) {
          color = INK["fireBg"]
        }
        printEntity(symbol, space, color)
      }
    }
    super.draw()

    Canvas.offset(offset.x, offset.y)
  }

  printSymbolBg(symbol, x, y, bg) {
    Canvas.rectfill(x * 16, y * 16, 15, 15, bg)
  }
  printSymbol(symbol, x, y, color) {
    var top = y * 16 + 4
    if (symbol == "~") {
      top = top + 4
      Canvas.print(symbol, x * 16 + 4, top, color)
      return
    }
    if (symbol == "\"") {
      top = top + 5
      Canvas.print(symbol, x * 16 + 4, top-2, color)
    }
    Canvas.print(symbol, x * 16 + 4, top, color)
  }

  printEntity(symbol, pos, color) {
    var colorBg = (INK["black"] * 1)
    colorBg.a = 64
    printSymbolBg(symbol, pos.x, pos.y, colorBg)
    printSymbol(symbol, pos.x, pos.y, color)
  }

  // TODO: is this still needed?
  printArea(symbol, start, size, color, bg) {
    var corner = start + size
    var maxX = corner.x - 1
    var maxY = corner.y - 1
    for (y in start.y..maxY) {
      for (x in start.x..maxX) {
        printEntity(symbol, Vec.new(x, y), color, bg)
      }
    }
  }
}

class TileRenderer is AsciiRenderer {
  construct new(pos) {
    super(pos)
    _sheet = SpriteSheet.load("res/img/tiles-1bit.png", 16)
    _caves = SpriteSheet.load("res/img/caves.png", 16)
    //  _crystal = ImageData.load("res/img/crystal.png")
    // _protag = SpriteSheet.load("res/img/protagonist.png", 16)
    _bg = INK["bg"] * 1
    _bg.a = 128
    _sheet.bg = _bg
  }

  /*
  drawPlayer(x, y, color) {
    Canvas.rectfill(x * 16, y * 16, 16, 16, _bg)
    var player = world.getEntityByTag("player")
    if (!player) {
      return
    }
    var sx = x * 16
    var sy = y * 16
    // _protag.fg = color
    var armor = player["equipment"][EquipmentSlot.armor]
    var weapon = player["equipment"][EquipmentSlot.weapon]
    var shield = player["equipment"][EquipmentSlot.offhand]

    // Head (armor)
    if (!armor) {
      _protag.draw(12, sx, sy)
    } else if (armor == "leather armor") {
      _protag.draw(15, sx, sy)
    } else if (armor == "chainmail") {
      _protag.draw(13, sx, sy)
    } else if (armor == "platemail") {
      _protag.draw(14, sx, sy)
    }

    // right arm
    if (!weapon) {
      _protag.draw(5, sx, sy)
    } else if (weapon == "dagger") {
      _protag.draw(4, sx, sy)
    } else if (weapon == "shortsword") {
      _protag.draw(8, sx, sy)
    } else if (weapon == "longsword") {
      _protag.draw(9, sx, sy)
    }
    // Left arm
    if (!shield) {
      _protag.draw(0, sx, sy)
    } else {
      _protag.draw(2, sx, sy)
    }
  }
  */

  printSymbolBg(symbol, x, y, color) {}
  printSymbol(symbol, x, y, color) {
    _sheet.fg = color
    _caves.fg = color
    var sx = x * 16
    var sy = y * 16
    var sheetWidth = 49
    if (symbol == "@") {
      // drawPlayer(x, y, color)
      return super.printSymbol(symbol, x, y, color)
    } else if (symbol == "z") {
      _sheet.drawFrom(28, 6, sx, sy)
    } else if (symbol == "r") {
      _sheet.drawFrom(31, 8, sx, sy)
    } else if (symbol == "d") {
      _sheet.drawFrom(31, 7, sx, sy)
    } else if (symbol == "G") {
      _sheet.drawFrom(27, 3, sx, sy)
    } else if (symbol == "D") {
    } else if (symbol == "£") {
      _sheet.drawFrom(26, 3, sx, sy)
    } else if (symbol == "\%") {
      _sheet.drawFrom(0, 15, sx, sy)
    } else if (symbol == ">") {
      _sheet.drawFrom(3, 6, sx, sy)
    } else if (symbol == "<") {
      _sheet.drawFrom(2, 6, sx, sy)
    } else if (symbol == "^") {
      _sheet.drawFrom(4, 12, sx, sy,{ "background": Color.none })
    } else if (symbol == "~") {
      _sheet.drawFrom(34, 15, sx, sy)
    } else if (symbol == "!") {
      _sheet.drawFrom(33, 13, sx, sy)
    } else if (symbol == "/") {
      _sheet.drawFrom(32, 8, sx, sy)
    } else if (symbol == "[") {
      _sheet.drawFrom(32, 1, sx, sy)
    } else if (symbol == "}") {
      _sheet.drawFrom(37, 4, sx, sy)
    } else if (world.zoneIndex < 3) {
      if (symbol == ".") {
        _floor = color * 0.33
        _floor.a = 255
        _sheet.drawFrom(16, 0, sx, sy, { "foreground": _floor})
        if (color == INK["blood"]) {
          _sheet.drawFrom(5, 2, sx, sy)
        }
      } else if (symbol == "#") {
        _sheet.drawFrom(10, 17, sx, sy)
      }
    } else if (world.zoneIndex < 7) {
      if (symbol == ".") {
        _floor = color * 0.33
        _floor.a = 255
        _sheet.drawFrom(2, 0, sx, sy, { "foreground": _floor})
        if (color == INK["blood"]) {
          _sheet.drawFrom(5, 2, sx, sy)
        }
      } else if (symbol == "#") {
        var tileX = 0 // starts at (0, 20)
        var tileY = 0
        var map = world.zone.map
        var north = map[x, y - 1]["solid"] || map[x, y - 1]["void"] ? 0 : 1
        var south = map[x, y + 1]["solid"] || map[x, y + 1]["void"] ? 0 : 1
        var east = map[x + 1, y]["solid"] || map[x + 1, y]["void"] ? 0 : 1
        var west = map[x - 1, y]["solid"] || map[x - 1, y]["void"] ? 0 : 1
        var index = (west << 3) | (south << 2) | (east << 1) | north
        //Canvas.print(index, sx, sy, color)
        _caves.draw(index, sx, sy)
        //_sheet.drawFrom((17 * sheetWidth) + 10, sx, sy)
      }
    } else {
      return super.printSymbol(symbol, x, y, color)
    }
  }

  draw() {
    var sheetWidth = 49
    super.draw()
    var offset = Canvas.offset
    Canvas.offset(pos.x, pos.y)
    var demons = world.entities().where {|entity| entity["kind"] == "demon" }.toList
    if (!demons.isEmpty) {
      var color = INK["creature"]
      for (demon in demons) {
        var center = demon.pos + (demon.size) / 3
        _sheet.fg = color
        var sx = center.x * 16
        var sy = center.y * 16
        if (demon["conditions"].containsKey("invulnerable")) {
          // _crystal.draw(demon.pos.x * 16, demon.pos.y*16)
          printSymbolBg(demon["symbol"], center.x, center.y, INK["bg"])
          _sheet.fg = INK["deeppurple"]
        } else {
          printSymbolBg(demon["symbol"], center.x, center.y, INK["bg"])
          _sheet.drawFrom(31, 6, demon.pos.x * 16, demon.pos.y * 16)
        }
      }
    }
    Canvas.offset(offset.x, offset.y)
  }
}

