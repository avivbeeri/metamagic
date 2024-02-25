import "parcel" for State

class SceneState is State {
  construct new() {
    super()
    _scene = null
    _previous = null
    _args = []
  }
  scene { _scene }
  previous { _previous }
  with(args) { withArgs(args) }
  withArgs(args) {
    if (!(args is List)) {
      args = [ args ]
    }
    _args = args
    return this
  }
  from(previous) {
    _previous = previous
    return this
  }
  withScene(scene) {
    _scene = scene
    _previous = scene.previous
    return this
  }
  arg(n) {
    if (n < _args.count) {
      return _args[n]
    }
    return null
  }
  onEnter() {}
  onExit() {}
  update() {
    return this
  }
}


