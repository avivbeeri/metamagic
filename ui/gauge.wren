import "graphics" for Canvas
import "./parcel" for
  Scheduler,
  Element
import "./palette" for INK
import "./ui/animation" for Animation


var HEIGHT = 18
var TEXT_OFFSET = (HEIGHT - 8) / 2
class Gauge is Element {
  construct new(pos, label, value, maxValue, segments) {
    super()
    _pos = pos
    _label = label
    _segments = segments
    _value = value
    _maxValue = maxValue
    _targetValue = value
    _changing = false
    _fg = INK["barFilled"]
    _bg = INK["barEmpty"]
    _border = INK["barBorder"]
    _mirror = false
  }


  mirror { _mirror }
  mirror=(v) { _mirror = v }
  fg { _fg }
  fg=(v) { _fg = v }
  bg { _bg }
  bg=(v) { _bg = v }
  border { _border }
  border=(v) { _border = v }

  animateValues(value, maxValue) {
    _maxValue = maxValue
    _targetValue = value
    if (_targetValue != _value && !_changing) {
      _changing = true
      Scheduler.defer {
        var t = 0
        var start = _value
        var target = _targetValue
        var diff = target - start

        while ((target - _value).abs > 0.1) {
          _value = start + diff * Animation.ease(t / 15)
          t = t + 1
          Fiber.yield()
        }
        _value = target
        _changing = false
        // If value changed during fiber defer, recurse
        if (_value != _targetValue) {
          animateValues(_targetValue, maxValue)
        }
      }
    }
  }

  value { _targetValue }
  value=(v) {
    _targetValue = v
    _value = v
  }
  maxValue { _maxValue }
  maxValue=(v) { _maxValue = v }

  update() {
    super.update()
  }

  draw() {
    var offset = Canvas.offset
    Canvas.offset(_pos.x,_pos.y)
    var width = _segments
    var current = _value / _maxValue * width

    Canvas.rectfill(0, 0, width * 16, HEIGHT, _bg)
    var text = "%(_label): %(_targetValue) / %(_maxValue)"
    var textWidth = text.count * 8
    if (!mirror) {
      Canvas.rectfill(0, 0, current * 16, HEIGHT, _fg)
      /*
      for (i in 0...3) {
        Canvas.rect(-i, -i, width * 16 + i * 2, HEIGHT + i * 2, border)
      }
      */
      Canvas.print(text, 4, TEXT_OFFSET, INK["barText"])
    } else {
      text = "%(_targetValue) / %(_maxValue) :%(_label)"
      var right = width * 16
      Canvas.rectfill(right - current * 16, 0, current * 16, HEIGHT, _fg)
      /*
      for (i in 0...3) {
        Canvas.rect(-i + right - current * 16, -i, width * 16 + i * 2, HEIGHT + i * 2, border)
      }
      */
      Canvas.print(text, right - textWidth - 4, TEXT_OFFSET, INK["barText"])
    }
    for (i in 0...3) {
      Canvas.rect(-i, -i, width * 16 + i * 2, HEIGHT + i * 2, border)
    }

    Canvas.offset(offset.x, offset.y)
  }
}

