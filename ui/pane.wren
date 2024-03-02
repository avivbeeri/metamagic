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

  /*
  center() {
    size = Vec.new(((width + 4) * 8).min(maxWidth), (2 + _message.count) * _height)
    pos = (Vec.new(Canvas.width, Canvas.height) - size) / 2
  }
  */

  draw() {
    var border = 4
    Canvas.offset(offset.x, offset.y)
    Canvas.rectfill(0, 0, size.x, size.y, INK["bg"])
    for (i in 1..border) {
      Canvas.rect(-i, -i, size.x + 2 * i, size.y + 2 * i, INK["border"])
    }
    content()
    super.draw()
    Canvas.offset(parent.offset.x, parent.offset.y)
  }
}
