import "input" for Keyboard, Clipboard
import "math" for Vec
import "graphics" for Color, Canvas

var FontSize = Vec.new(6, 9, 2, 3)

class TextStyle {
  construct new() {
    init(Color.lightgray, false, Color.black)
  }
  construct new(options) {
    if (options is Map) {
      init(options["color"], options["underline"], options["background"])
    } else {
      init(options, false, Color.black)
    }
  }
  init(color, underline, background) {
    _color = color || Color.lightgray
    _underline = underline || false
    _background = null
  }
  underline { _underline }
  underline=(v) { _underline = v }
  color { _color }
  color=(v) { _color = v }

  background { _background }
  background=(v) { _background = v }

  mirror(style) {
    this.underline = style.underline
    this.color = style.color
    this.background = style.background
  }
}

class TextComponent {
  construct new(content) {
    init(content, null)
  }
  construct new(content, style) {
    init(content, style)
  }
  init(content, style) {
    _content = content
    _style = style
    _siblings = []
  }
  style { _style }
  siblings { _siblings }
  content { _content }

  append(component) {
    if (component is TextComponent) {
      _siblings.add(component)
    } else {
      _siblings.add(TextComponent.new(component))
    }
  }

  print(x, y) {
    printWithStyle(x, y, style)
  }

  printWithStyle(x, y, context) {
    var left = x
    if (_content) {
      var style = style || context || TextStyle.new()
      Canvas.print(content, left, y, style.color)
      left = content.count * FontSize.x
      if (style.underline) {
        Canvas.line(x, y + FontSize.y - FontSize.w, left, y + FontSize.y - FontSize.w, style.color)
      }
    }
    for (text in _siblings) {
      text.printWithStyle(left, y, style)
      left = left + text.count * (FontSize.x + FontSize.z)
    }
  }

  count {
    var total = content.count
    for (text in _siblings) {
      total = total + text.count
    }
    return total
  }
}

class TextInputReader {
  construct new() {
    _enabled = false
    _text = ""
    _pos = 0
  }

  pos { _pos }
  text { _text }
  changed { _changed }
  enabled { _enabled }
  clear() {
    _pos = 0
    _text = ""
    Keyboard.handleText = false
  }

  enable() {
    _enabled = true
    Keyboard.handleText = true
  }
  disable() {
    _enabled = false
    Keyboard.handleText = false
  }

  splitText(before, insert, after) {
    var codePoints = _text.codePoints
    _text = ""
    for (point in codePoints.take(before)) {
      _text = _text + String.fromCodePoint(point)
    }
    if (insert != null) {
      _text = _text + insert
    }
    for (point in codePoints.skip(after)) {
      _text = _text + String.fromCodePoint(point)
    }
  }

  update() {
    if (!_enabled) {
      return
    }

    if (Keyboard["left"].justPressed) {
      _pos = (_pos - 1).clamp(0, _text.count)
    }
    if (Keyboard["right"].justPressed) {
      _pos = (_pos + 1).clamp(0, _text.count)
    }

    if (Keyboard.text.count > 0) {
      splitText(_pos, Keyboard.text, _pos)
      _pos = _pos + Keyboard.text.count
    }

    if (!Keyboard.compositionText && Keyboard["backspace"].justPressed && _text.count > 0) {
      var codePoints = _text.codePoints
      splitText(_pos - 1, null, _pos)
      _pos = (_pos - 1).clamp(0, _text.count)
    }
    if (!Keyboard.compositionText && Keyboard["delete"].justPressed && _text.count > 0) {
      var codePoints = _text.codePoints
      splitText(_pos, null, _pos+1)
      _pos = (_pos).clamp(0, _text.count)
    }
    // TODO handle text region for CJK

    if ((Keyboard["left ctrl"].down || Keyboard["right ctrl"].down) && Keyboard["c"].justPressed) {
      Clipboard.content = _text
    }
    if ((Keyboard["left ctrl"].down || Keyboard["right ctrl"].down) && Keyboard["v"].justPressed) {
      _text = _text + Clipboard.content
    }
  }
}
