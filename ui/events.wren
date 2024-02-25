import "parcel" for Event

var HoverEvent = Event.create("hover", ["target"])
var TargetEvent = Event.create("target", ["pos"])
var TargetBeginEvent = Event.create("targetBegin", ["pos", "range"])
var TargetEndEvent = Event.create("targetEnd", [])

/*
class HoverEvent is Event {
  construct new(target) {
    super()
    _src = target
  }
  target { _src }
}

class TargetEvent is Event {
  construct new(pos) {
    super()
    data["pos"] = pos
  }
  pos { data["pos"] }
}
class TargetBeginEvent is TargetEvent {
  construct new(pos) {
    super(pos)
    data["range"] = 1
  }
  construct new(pos, range) {
    super(pos)
    data["range"] = range
  }
  range { data["range"] }
}

class TargetEndEvent is Event {
  construct new() {
    super()
  }
}
*/
