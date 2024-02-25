import "graphics" for Canvas
import "./parcel" for
  Scheduler,
  Element
import "./palette" for INK
import "./ui/animation" for Animation

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
  }

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

    Canvas.rectfill(0, 2, width * 16, 12, INK["barEmpty"])
    Canvas.rectfill(0, 2, current * 16, 12, INK["barFilled"])
    Canvas.print("%(_label): %(_targetValue) / %(_maxValue)", 4, 4, INK["barText"])

    Canvas.offset(offset.x, offset.y)
  }
}

