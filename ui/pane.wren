import "math" for Vec
import "graphics" for Canvas
import "palette" for INK
import "parcel" for Element
import "ui/panel" for Panel

class Pane is Panel {
  construct new() {
    super()
  }
  construct new(size) {
    super(size)
  }
  construct new(size, pos) {
    super(size, pos)
  }

  init() {
    super.init()
    _border = 4
    _bg = INK["dialogBg"]
    _borderColor = INK["border"]
  }

  bg { _bg }
  bg=(v) { _bg = v }

  border { _border }
  border=(v) { _border = v }

  borderColor { _borderColor }
  borderColor=(v) { _borderColor = v }

  alignRight() {
    super.alignRight()
    pos.x = pos.x - border
  }
  alignBottom() {
    super.alignBottom()
    pos.y = pos.y - border
  }

  draw() {
    Canvas.offset(offset.x, offset.y)
    Canvas.rectfill(-padding, -padding, size.x + padding * 2, size.y + padding * 2, bg)
    for (i in 0...(border)) {
      var j = i + padding + 1
      Canvas.rect(-j, -j, size.x + 2 * j, size.y + 2 * j, borderColor)
    }
    content()
    super.draw()
    Canvas.offset(parent.offset.x, parent.offset.y)
  }
}
