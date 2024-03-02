import "math" for Vec
import "graphics" for Canvas
import "parcel" for Element

class Panel is Element {
  construct new() {
    super()
    _pos = Vec.new()
    _size = Vec.new()
  }
  construct new(size) {
    super()
    _size = size
    _pos = Vec.new()
  }
  construct new(size, pos) {
    super()
    _pos = pos
    _size = size
  }

  center() {
    var parentSize = parent ? parent.size : Vec.new(Canvas.width, Canvas.height)
    pos = (parentSize - size) / 2
  }

  size { _size }
  size=(v) {
    _size = v
  }

  pos { _pos }
  pos=(v) {
    _pos = v
  }

  offset {
    var current = this
    var result = Vec.new()
    while (current != null) {
      result = result + current.pos
      current = current.parent
    }
    return result
  }

  content() {}
  draw() {
    var off = offset
    Canvas.offset(off.x, off.y)
    content()
    super.draw()
    off = parent.offset
    Canvas.offset(off.x, off.y)
  }
}
