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
    super(size, pos)
    text = t
  }

  color=(v) { _color = v }
  color { _color || INK["text"] }
  text { _text || "" }
  text=(v) {
    _text = v.toString
    size = Vec.new(text.count * 8, 8)
  }

  content() {
    Canvas.print(_text, 0, 0, color)
  }
}
