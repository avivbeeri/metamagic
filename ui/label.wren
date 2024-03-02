import "math" for Vec
import "graphics" for Canvas
import "./ui/panel" for Panel
import "./palette" for INK

class Label is Panel {
  construct new(pos, t) {
    // TODO: handle font size
    _text = t
    size = Vec.new(_text.count * 8, 8)

    super(size, pos)
  }
  text { _text }
  text=(v) { _text = v }

  content() {
    Canvas.print(_text, 0, 0, INK["text"])
  }
}
