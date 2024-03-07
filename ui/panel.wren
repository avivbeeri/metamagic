import "math" for Vec
import "graphics" for Canvas
import "parcel" for Element

class SizeMode {
  static fixed { "FIXED" }
  static auto { "AUTO" }
}

class Panel is Element {
  construct new() {
    super()
    _pos = Vec.new()
    _size = Vec.new()
    init()
  }
  construct new(size) {
    super()
    _size = size
    _pos = Vec.new()
    init()
  }
  construct new(size, pos) {
    super()
    _pos = pos
    _size = size
    init()
  }

  init() {
    _padding = 8
    _sizeMode = SizeMode.fixed
  }

  padding { _padding }
  padding=(v) { _padding = v }
  sizeMode { _sizeMode }
  sizeMode=(v) { _sizeMode = v }
  addElement(element) {
    super.addElement(element)
    updateSize()
    return element
  }

  alignRight() {
    updateSize()
    var parentSize = parent ? parent.size : Vec.new(Canvas.width, Canvas.height)
    pos.x = (parentSize.x - size.x - padding)
  }
  alignBottom() {
    updateSize()
    var parentSize = parent ? parent.size : Vec.new(Canvas.width, Canvas.height)
    pos.y = (parentSize.y - size.y - padding)
  }

  centerHorizontally() {
    updateSize()
    var parentSize = parent ? parent.size : Vec.new(Canvas.width, Canvas.height)
    pos.x = (parentSize.x - size.x) / 2
  }
  centerVertically() {
    updateSize()
    var parentSize = parent ? parent.size : Vec.new(Canvas.width, Canvas.height)
    pos.y = (parentSize.y - size.y) / 2
  }
  center() {
    updateSize()
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
      System.print(current.pos)
      result = result + current.pos
      current = current.parent
    }
    return result
  }

  updateSize() {
    if (sizeMode == SizeMode.auto) {
      var current = Vec.new()
      for (element in elements) {
        current.x = current.x.max(element.pos.x + element.size.x)
        current.y = current.y.max(element.pos.y + element.size.y)
      }
      _size = current
    }
  }

  update() {
    super.update()
    updateSize()
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
