import "input" for Keyboard, Mouse, InputGroup

class InputScheme {
  construct new(data) {
    init(data)
  }

  construct new() {
    init([null, null])
  }

  init(data) {
    _inputs = data[0] || {}
    _list = data[1] || {}
  }

  register(purpose, group) {
    if (!(group is String) && !(group is InputGroup)) {
      group = InputGroup.new(group)
    }
    _inputs[purpose] = group
  }
  registerList(name, group) { _list[name] = group }
  list(name) { _list[name].map {|purpose| this[purpose] }.toList }

  [purpose] {
    var original = purpose
    var result = null
    var found = false
    while (result == null) {
      purpose = _inputs[purpose]
      if (purpose == null) {
        Fiber.abort("Input \"%(original)\" could not be resolved.")
      }
      if (purpose is InputGroup) {
        result = purpose
      }
    }

    return result
  }

  [purpose]=(v) { register(purpose, v) }


  copy() { InputScheme.new([ _inputs, _list ]) }
}

var KEY_SET_1 = [
  [ Keyboard["up"] ],
  [ Keyboard["right"] ],
  [ Keyboard["down"] ],
  [ Keyboard["left"] ],
  [ Keyboard["page up"] ],
  [ Keyboard["page down"] ],
  [ Keyboard["home"] ],
  [ Keyboard["end"] ]
]

var KEY_SET_2 = [
  [ Keyboard["k"] ],
  [ Keyboard["l"] ],
  [ Keyboard["j"] ],
  [ Keyboard["h"] ],
  [ Keyboard["y"] ],
  [ Keyboard["u"] ],
  [ Keyboard["n"] ],
  [ Keyboard["b"] ]
]
var KEY_SET_3 = [
  [ Keyboard["keypad 8"], Keyboard["8"] ],
  [ Keyboard["keypad 6"], Keyboard["6"] ],
  [ Keyboard["keypad 2"], Keyboard["2"] ],
  [ Keyboard["keypad 4"], Keyboard["4"] ],
  [ Keyboard["keypad 7"], Keyboard["7"] ],
  [ Keyboard["keypad 9"], Keyboard["9"] ],
  [ Keyboard["keypad 3"], Keyboard["3"] ],
  [ Keyboard["keypad 1"], Keyboard["1"] ]
]
var KEY_SET_4 = [
  [ Keyboard["w"] ],
  [ Keyboard["d"] ],
  [ Keyboard["s"] ],
  [ Keyboard["a"] ],
  [ Keyboard["q"] ],
  [ Keyboard["e"] ],
  [ Keyboard["c"] ],
  [ Keyboard["z"] ]
]

var KEY_SET_ORDER = [
  "north",
  "east",
  "south",
  "west",
  "nw",
  "ne",
  "se",
  "sw"
]

var KEY_SET = []
for (i in 0...KEY_SET_1.count) {
  KEY_SET.add(KEY_SET_1[i] + KEY_SET_2[i] + KEY_SET_3[i] + KEY_SET_4[i])
}

//var DIR_INPUTS = KEY_SET.map {|keys| InputGroup.new(keys) }.toList

var BASIC = InputScheme.new()
// TODO: space can't be confirm during text entry
BASIC.register("confirm", [ Keyboard["return"] ])
BASIC.register("easyConfirm", [ Keyboard["return"], Keyboard["space"] ])
BASIC.register("reject", [ Keyboard["escape"] ])
BASIC.register("exit", [ Keyboard["F12"] ])
BASIC.register("cast", [ Keyboard["space"], Keyboard["keypad ."], Keyboard["keypad 5"] ])
BASIC.register("drop", [ Keyboard["r"]  ])
BASIC.register("pickup", [ Keyboard["g"] ])
BASIC.register("inventory", [ Keyboard["i"] ])
BASIC.register("log", [ Keyboard["v"] ])
BASIC.register("info", [ Keyboard["t"] ])
BASIC.register("strike", [ Keyboard["x"]  ])
BASIC.register("descend", [ Keyboard[","] ])
BASIC.register("ascend", [ Keyboard[","] ])
BASIC.register("mute", [ Keyboard["m"] ])
BASIC.register("volDown", [ Keyboard["["] ])
BASIC.register("volUp", [ Keyboard["]"] ])
BASIC.register("toggleTiles", [ Keyboard["tab"] ])
BASIC.register("scrollUp", "north")
BASIC.register("scrollDown", "south")
BASIC.register("help", [ Keyboard["/"], Keyboard["?"] ])

var VI_SCHEME = BASIC.copy()
for (i in 0...KEY_SET_1.count) {
  VI_SCHEME.register(KEY_SET_ORDER[i], KEY_SET[i])
}
VI_SCHEME.registerList("dir", KEY_SET_ORDER)

/*
var SCROLL_UP = InputGroup.new([ Keyboard["up"], Keyboard["page up"], Keyboard["k"] ])
var SCROLL_DOWN = InputGroup.new([ Keyboard["down"], Keyboard["page down"], Keyboard["j"]] )
var SCROLL_BEGIN = InputGroup.new(Keyboard["home"])
var SCROLL_END = InputGroup.new(Keyboard["end"])
var ESC_INPUT = InputGroup.new(Keyboard["escape"])
var OPEN_LOG = InputGroup.new(Keyboard["v"])
var OPEN_INVENTORY = InputGroup.new(Keyboard["i"])
var CONFIRM = InputGroup.new(Keyboard["return"])
var REJECT = InputGroup.new(Keyboard["escape"])
var REST_INPUT = InputGroup.new([Keyboard["space"], Keyboard["."], Keyboard["keypad ."]])
var PICKUP_INPUT = InputGroup.new([ Keyboard["g"] ])
*/
