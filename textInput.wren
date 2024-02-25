import "stringUtils" for StringUtils
import "parcel" for
  TextInputReader,
  State,
  Event
import "inputs" for VI_SCHEME as INPUT

class TextComplete is Event {
  construct new(text) {
    super()
    data["text"] = text
  }
  text { data["text"] }
}
class TextChanged is Event {
  construct new(text) {
    super()
    data["text"] = text
  }
  text { data["text"] }
}

class TextInputState is State {

  construct new(scene) {
    super()
    _scene = scene
    _world = scene.world
    _kb = TextInputReader.new()
    _kb.enable()
  }

  update() {
    _kb.update()
    if (INPUT["confirm"].firing) {
      _kb.disable()
      events.add(TextComplete.new(_kb.text))
      return PlayerInputState.new(_scene)
    }
    if (INPUT["reject"].firing) {
      _kb.disable()
      return PlayerInputState.new(_scene)
    }
    events.add(TextChanged.new(_kb.text))
    return this
  }
}


/*------- Text rendering code
    /*
    TODO: Needs to be in its own UI widget
    if (_currentText) {
      var x = _kb.pos * 8
      var y = Canvas.height - 10
      if ((_t / 30).floor % 2 == 0) {
        Canvas.rectfill(x, y, 8, 10, Color.white)
      }
      Canvas.print(_currentText, 0, Canvas.height - 9, Color.white)
    }
     */
----------*/

/*
Text event processing
    for (event in _state.events) {
      if (event is TextComplete) {
        _currentText = ""
        _name = event.text
      }
      if (event is TextChanged) {
        _currentText = event.text
      }
    }

*/

import "scene" for PlayerInputState
