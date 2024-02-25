import "math" for Vec
import "graphics" for Canvas
import "palette" for INK
import "parcel" for Element

class Pane is Element {
  construct new() {
    super()
    _pos = Vec.new()
    _size = Vec.new()
  }
  construct new(pos, size) {
    super()
    _pos = pos
    _size = size
  }

  content() {}
  size { _size }
  size=(v) {
    _size = v
  }

  pos { _pos }
  pos=(v) {
    _pos = v
  }

  draw() {
    var border = 4
    var offset = Canvas.offset
    Canvas.offset(_pos.x,_pos.y)

    Canvas.rectfill(0, 0, _size.x, _size.y, INK["bg"])
    for (i in 1..border) {
      Canvas.rect(-i, -i, _size.x + 2 * i, _size.y + 2 * i, INK["border"])
    }
    content()
    super.draw()
    Canvas.offset(offset.x, offset.y)
  }
}
