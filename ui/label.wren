import "math" for Vec
import "graphics" for Canvas
import "./ui/panel" for Panel
import "./palette" for INK

class Label is Panel {
  construct new(t) {
    // TODO: handle font size
    super(Vec.new(), Vec.new())
    text = t
  }

  construct new(pos, t) {
    // TODO: handle font size
    _text = t
    size = Vec.new(_text.count * 8, 8)

    super(size, pos)
  }

  color=(v) { _color = v }
  color { _color || INK["text"] }
  text { _text }
  text=(v) {
    _text = v
    size = Vec.new(_text.count * 8, 8)
  }

  content() {
    System.print(_text)
    Canvas.print(_text, 0, 0, color)
  }
}
