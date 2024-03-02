import "math" for Vec
import "graphics" for Canvas
import "./parcel" for Element
import "./ui/events" for TextInputEvent
import "./text" for TextSplitter
import "./palette" for INK

class Label is Element {
  construct new(pos, text) {
    super()
    _text = text
    _pos = pos
  }
  process(event) {}
  update() {}
  draw() {
    var offset = Canvas.offset
    Canvas.offset(parent.pos.x + _pos.x, parent.pos.y + _pos.y)
    Canvas.print(_text, 0, 0, INK["text"])
    Canvas.offset(offset.x, offset.y)
  }
}
