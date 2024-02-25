import "audio" for AudioEngine
import "math" for M

class JukeboxMode {
  static NONE { 0 }
  static FADE { 1 }
  static PLAY { 2 }
  static FADE_TARGET { 3 }
}

var MAX_VOLUME = 1.0
var VOL_STEP = 0.05

class Jukebox {
  static init() {
    __previousChannel = null
    __currentChannel = null
    __mode = JukeboxMode.NONE
    __target = MAX_VOLUME * 0.5
  }
  static register(name, path) {
    AudioEngine.load(name, path)
  }
  static update() {
    var dt = (1/60) / 2

    if (__mode == JukeboxMode.FADE) {
      if (__previousChannel != null) {
        __previousChannel.volume = M.max(0, __previousChannel.volume - dt * 2)
        if (__previousChannel.volume <= 0) {
          __previousChannel.stop()
        }
      }

      if (__currentChannel != null) {
        __currentChannel.volume = M.min(1, __currentChannel.volume + dt)
        if (__currentChannel.volume >= __target) {
          __mode = JukeboxMode.PLAY
        }
      }
    }
  }

  static playMusic(path) {
    if (__currentChannel && __currentChannel.soundId != path) {
      __previousChannel = __currentChannel
    }
    if (__currentChannel == null || __currentChannel.soundId != path) {
      __currentChannel = AudioEngine.play(path)
      __currentChannel.volume = 0
      __currentChannel.loop = true
      __mode = JukeboxMode.FADE
    }
  }

  static playing { __currentChannel != null }
  static volumeDown() {
    __target = __target - VOL_STEP
    __currentChannel.volume = __currentChannel.volume - VOL_STEP
  }
  static volumeUp() {
    __target = __target + VOL_STEP
    __currentChannel.volume = __currentChannel.volume + VOL_STEP
  }

  static stopMusic() {
    __previousChannel = __currentChannel
    __currentChannel = null
    __mode = JukeboxMode.FADE
  }

  static playSFX(effect) {
    AudioEngine.play(effect)
  }
}

Jukebox.init()

