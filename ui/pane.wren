import "math" for Vec
import "graphics" for Canvas
import "palette" for INK
import "parcel" for Element
import "ui/panel" for Panel

class Pane is Panel {
  construct new() {
    super()
    init()
  }
  construct new(size) {
    super(size)
    init()
  }
  construct new(size, pos) {
    super(size, pos)
    init()
  }

  init() {
    _padding = 8
    _border = 4
  }

  padding { _padding }
  padding=(v) { _padding = v }
  border { _border }
  border=(v) { _border = v }

  draw() {
    Canvas.offset(offset.x, offset.y)
    Canvas.rectfill(-padding, -padding, size.x + padding * 2, size.y + padding * 2, INK["bg"])
    for (i in 0...(border)) {
      var j = i + padding + 1
      Canvas.rect(-j, -j, size.x + 2 * j, size.y + 2 * j, INK["border"])
    }
    content()
    super.draw()
    Canvas.offset(parent.offset.x, parent.offset.y)
  }
}
