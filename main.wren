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

var TITLE = [
  "Arcanist's",
  "Heritage",
]

class StartScene is Scene {
  construct new(args) {
    super(args)
    Window.color = Color.black
    Font.load("empire", "res/fonts/empire.ttf", 64)
    _font = Font["empire"]
    _area = TITLE.map {|line| _font.getArea(line) }.toList

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


  printTitle(top) {
    var thick = 4
    var i = 0
    var x0 = (Canvas.width - _area[0].x) / 2
    for (line in TITLE) {
      for (y in -thick..thick) {
        for (x in -thick..thick) {
          _font.print(line, x0 + x, top + y, INK["titleBg"])
        }
      }
      _font.print(line, x0, top, INK["titleFg"])
      top = top + _area[i].y
      i = i + 1
    }
  }

  drawCircle(offset, color) {
    var thick = 3
    var c = Vec.new(Canvas.width, Canvas.height + 72) / 2 + offset

    var d = (_t - 5 * 60).min(1 * 60) / (1 * 60)
    var angle = Num.pi * Animation.ease(d)
    Canvas.circlefill(c.x, c.y, (128 + thick) * d, color)
    Canvas.circlefill(c.x, c.y, 128 * d, INK["black"])
    for (i in 1..4) {
      var x0 = (c.x + (angle + ((i+0.5) / 4) * 2 * Num.pi).cos * 78 * d)
      var y0 = (c.y + (angle + ((i + 0.5) / 4)* 2 * Num.pi).sin * 78 * d)
      var x2 = (c.x + (angle + ((i-0.5) / 4)* 2 * Num.pi).cos * 78 * d)
      var y2 = (c.y + (angle + ((i - 0.5) / 4)* 2 * Num.pi).sin * 78 * d)
      var x1 = (c.x + (angle + (i / 4)* 2 * Num.pi).cos * 128 * d)
      var y1 = (c.y + (angle + (i / 4)* 2 * Num.pi).sin * 128 * d)
      Canvas.line(x0, y0, x1, y1, color, thick)
      Canvas.line(x2, y2, x1, y1, color, thick)
    }
    for (i in 1..4) {
      var r = 32
      var x = (c.x + (angle + (i / 4)* 2 * Num.pi).cos * 128 * d)
      var y = (c.y + (angle + (i / 4)* 2 * Num.pi).sin * 128 * d)
      Canvas.circlefill(x, y, r, color)
      Canvas.circlefill(x, y, r - thick, INK["black"])
    }
    for (i in 1..4) {
      var r = 24
      var x = (c.x + (angle + ((i+0.5) / 4)* 2 * Num.pi).cos * 78 * d)
      var y = (c.y + (angle + ((i + 0.5) / 4)* 2 * Num.pi).sin * 78 * d)
      Canvas.circlefill(x, y, r, color)
      Canvas.circlefill(x, y, r - thick, INK["black"])
    }

  }

  draw() {
    Canvas.cls(INK["mainBg"])
    var v = Config["version"]
    Canvas.print(v, Canvas.width - 8 - v.count * 8, Canvas.height - 16 , INK["title"])
    var height = _area.reduce(0) {|acc, area| acc + area.y }
    var top = (Canvas.height - height) / 2
    if (_t > 3 * 60) {
      var length = 3 * 60
      var t = (_t - 3 * 60).clamp(0, length) / (length)
      var diff = (top - 56)
      top = top - diff * Animation.ease(t)
    }
    if (_t > 5 * 60) {
      drawCircle(Vec.new(), INK["circle"])
    }
    printTitle(top)
    var x = (Canvas.width - 30 * 8)/ 2
    Canvas.print("Press SPACE or ENTER to begin", x, Canvas.height * 0.90, INK["title"])
    super.draw()
  }
}

var Game = ParcelMain.new("start")
import "./scene" for GameScene
Game.registerScene("start", StartScene)
Game.registerScene("game", GameScene)
