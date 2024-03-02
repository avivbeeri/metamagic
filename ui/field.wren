import "math" for Vec
import "graphics" for Canvas
import "./parcel" for Element
import "./ui/events" for TextInputEvent
import "./text" for TextSplitter
import "./palette" for INK

class Field is Element {
  construct new(pos) {
    super()
    _text = ""
    _pos = pos
    _cursorPos = 0
  }
  process(event) {
    if (event is TextInputEvent) {
      _text = event.text
      _cursorPos = event.text.count
    }
  }
  update() {}
  draw() {
    var offset = Canvas.offset
    Canvas.offset(parent.pos.x + _pos.x, parent.pos.y + _pos.y)
    Canvas.print(_text, 0, 0, INK["text"])
    Canvas.rectfill(_cursorPos * 8, 0, 8, 8, INK["textCursor"])
    Canvas.offset(offset.x, offset.y)

  }
}
