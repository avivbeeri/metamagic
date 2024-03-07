import "math" for Vec
import "graphics" for Canvas
import "./ui/panel" for Panel
import "./palette" for INK
import "./text" for TextSplitter

class TextBox is Panel {
  construct new(t, width) {
    // TODO: handle font size
    super(Vec.new(width.ceil, 0), Vec.new())
    _lines = []
    text = t
  }

  color=(v) { _color = v }
  color { _color || INK["text"] }
  text { _lines ? _lines.join("\n") : "" }
  text=(v) {
    var lines = v.split("\n").map{|line| line.trim() }.toList
    _lines = TextSplitter.split(lines, size.x).map{|line| line.trim() }.toList
    var maxWidth = TextSplitter.getWidth(_lines)
    var maxHeight = _lines.count * 8
    size = Vec.new(size.x, maxHeight)
  }

  content() {
    var y = 0
    for (line in _lines) {
      Canvas.print(line, 0, y, color)
      y = y + 8
    }
  }
}
