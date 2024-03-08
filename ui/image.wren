import "math" for Vec
import "graphics" for Canvas
import "./ui/panel" for Panel
import "./palette" for INK

class ImagePanel is Panel {
  construct new(image) {
    super(Vec.new(), Vec.new())
    this.image = image
  }

  center() {
    System.print("%(pos), %(size)")
    super.center()
    System.print("%(pos), %(size)")

  }

  image { _image }
  image=(v) {
    _image = v
    size = Vec.new(v.width, v.height)
  }

  content() {
    if (_image) {
      _image.draw(0, 0)
    }
  }
}
