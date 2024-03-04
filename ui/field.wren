import "math" for Vec
import "graphics" for Canvas
import "./ui/pane" for Pane
import "./ui/events" for TextInputEvent
import "./text" for TextSplitter
import "./palette" for INK

class Field is Pane {
  construct new(pos) {
    super()
    this.pos = pos
    _text = ""
    _t = 0
    _cursorPos = 0
    _placeholder = null
    size = Vec.new(24 * 8, 8)
    border = 0
    padding = 2
  }
  placeholder=(v) { _placeholder = v }
  placeholder { _placeholder }

  process(event) {
    super.process(event)
    if (event is TextInputEvent) {
      _text = event.text
      _cursorPos = event.pos
    }
  }
  update() {
    super.update()
    _t = _t + 1

  }
  content() {
    Canvas.rectfill(-padding, -padding, size.x + padding * 2, size.y + padding * 2, INK["fieldBg"])
    if (_text.count == 0 && _placeholder) {
      Canvas.print(_placeholder, 8, 0, INK["textPlaceholder"])
    } else {
      Canvas.print(_text, 0, 0, INK["text"])
    }
    if ((_t % 120) < 60) {
      Canvas.rectfill(_cursorPos * 8, 0, 8, 8, INK["textCursor"])
    }
  }
}
