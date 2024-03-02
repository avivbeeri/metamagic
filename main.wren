import "dome" for Window
import "math" for Vec
import "jukebox" for Jukebox
import "graphics" for Canvas, Font, ImageData, Color
import "parcel" for ParcelMain, Scene, Config, Scheduler
import "inputs" for VI_SCHEME as INPUT
import "input" for Mouse
import "palette" for INK
import "ui/animation" for Animation
import "ui" for HintText

class StartScene is Scene {
  construct new(args) {
    super(args)
    Window.color = Color.black
    _area = [
      Vec.new(8 * 8, 8), // Font["nightmare"].getArea("Acolyte's"),
    ]
    _t = 0
    _a = 0

    if (!Config["mute"]) {
      Scheduler.deferBy(60) {
        // Jukebox.playMusic("soundTrack")
        Window.color = INK["mainBg"]
      }
    }

    _done = false
    var start = 3 * 60
    Scheduler.deferBy(start) {
      while (!_done) {
        var max = (3 * 60) // different from start
        _a = ((_t - start) / max).clamp(0, 1)
        Fiber.yield()
      }
    }
  }

  update() {
    _t = _t + 1
    if (INPUT["easyConfirm"].firing || Mouse["left"].justPressed) {
      _done = true
      game.push("game")
    }
    if (INPUT["volUp"].firing) {
      Jukebox.volumeUp()
    }
    if (INPUT["volDown"].firing) {
      Jukebox.volumeDown()
    }
    if (INPUT["mute"].firing) {
      if (Jukebox.playing) {
        Jukebox.stopMusic()
      } else {
        // Jukebox.playMusic("soundTrack")
      }
    }
    super.update()
  }

  draw() {
    Canvas.cls(INK["mainBg"])
    var v = Config["version"]
    Canvas.print(v, Canvas.width - 8 - v.count * 8, Canvas.height - 16 , INK["title"])
    var height = _area.reduce(0) {|acc, area| acc + area.y }
    var top = (Canvas.height - height) / 2
    var x0 = (Canvas.width - _area[0].x) / 2
    var thick = 4
    for (y in -thick..thick) {
      for (x in -thick..thick) {
        Canvas.print("Untitled", x0 + x, top + y, INK["titleBg"])
      }
    }
    Canvas.print("Untitled", x0, top, INK["titleFg"])

    var x = (Canvas.width - 30 * 8)/ 2
    Canvas.print("Press SPACE or ENTER to begin", x, Canvas.height * 0.90, INK["title"])
    super.draw()
  }
}

var Game = ParcelMain.new("start")
import "./scene" for GameScene
Game.registerScene("start", StartScene)
Game.registerScene("game", GameScene)
