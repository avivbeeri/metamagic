import "math" for Vec
import "graphics" for Canvas
import "./ui/panel" for Panel
import "./palette" for INK

class Line is Panel {
  construct new() {
    // TODO: handle font size
    super(Vec.new(), Vec.new())
    start = Vec.new()
    end = Vec.new()
    thickness = 1
    color = INK["black"]
  }

  end { _end || Vec.new() }
  end=(v) {
    _end = v
    size = Vec.new((start.x - end.x).abs, (start.y - end.y).abs)
  }
  start { _start || Vec.new() }
  start=(v) {
    _start = v
    size = Vec.new((start.x - end.x).abs, (start.y - end.y).abs)
  }
  color { _color }
  color=(v) { _color = v }
  thickness { _thickness }
  thickness=(v) { _thickness = v }

  content() {
//    System.print("pos only %(pos)")
 //   System.print("pos %(pos + start)")
  //  System.print("parent.size %(parent.size)")
    Canvas.line(start.x, start.y, end.x, end.y, color, thickness)
  }
}
