import "math" for Vec
import "graphics" for Canvas
import "./ui/panel" for Panel
import "./ui/events" for TextInputEvent
import "./text" for TextSplitter
import "./palette" for INK

class Field is Panel {
  construct new(pos) {
    super()
    this.pos = pos
    _text = ""
    _cursorPos = 0
  }
  process(event) {
    super.process(event)
    if (event is TextInputEvent) {
      _text = event.text
      _cursorPos = event.pos
    }
  }
  content() {
    Canvas.print(_text, 0, 0, INK["text"])
    Canvas.rectfill(_cursorPos * 8, 0, 8, 8, INK["textCursor"])
  }
}
