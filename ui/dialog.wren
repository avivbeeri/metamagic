import "math" for Vec
import "graphics" for Canvas
import "./ui/pane" for Pane
import "./text" for TextSplitter
import "./palette" for INK

/*
  A pane that will display a list of strings
  The text can be left or center aligned.
  The pane is always at the center of the screen
*/

class Dialog is Pane {
  construct new(message) {
    super()
    _center = true
    _height = 10
    setMessage(message)
  }

  center=(v) { _center = v }
  center { _center }

  setMessage(message) {
    if (!(message is List)) {
      message = [ message ]
    }
    var width = TextSplitter.getWidth(message)
    var maxWidth = ((Canvas.width / 2)).ceil - 8
    _message = TextSplitter.split(message, maxWidth)
    size = Vec.new(((width + 4) * 8).min(maxWidth), (2 + _message.count) * _height)
    pos = (Vec.new(Canvas.width, Canvas.height) - size) / 2
  }

  content() {
    for (i in 0..._message.count) {
      var x = _center ? (size.x - (_message[i].count * 8)) / 2: 8
      Canvas.print(_message[i], x, ((size.y - _message.count * _height) / 2) + i * _height, INK["gameover"])
    }
  }
}

