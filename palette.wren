import "graphics" for Color
import "parcel" for Palette


var INK = Palette.new()

INK.addColor("black", Color.hex("#1B0326"))
INK.addColor("white", Color.hex("#E6DCB8"))
INK.addColor("brown", Color.hex("#5E3E24"))

INK.addColor("burgandy", Color.hex("#450327"))
INK.addColor("red", Color.hex("#9C173B"))

INK.addColor("lilac", Color.hex("#AB9AA1"))
INK.addColor("purple", Color.hex("#4F3A54"))
INK.addColor("purpleTransparent", Color.hex("#4F3A5460"))

INK.addColor("bronze", Color.hex("#855504"))
INK.addColor("gold", Color.hex("#D19B11"))

INK.addColor("darkgreen", Color.hex("#284722"))
INK.addColor("green", Color.hex("#239617"))

INK.addColor("darkblue", Color.hex("#1F4A69"))
INK.addColor("blue", Color.hex("#3A8CC7"))

INK.addColor("deeppurple", Color.hex("#65276A"))
INK.addColor("pastelpurple", Color.hex("#9A649E"))
INK.addColor("pastelpurpleTransparent", Color.hex("#9A649E60"))

INK.addColor("orange", Color.hex("#CC751F"))
INK.addColor("gray", Color.hex("#C5B26D"))


INK.setPurpose("targetArea", "pastelpurpleTransparent")
INK.setPurpose("targetCursor", "purpleTransparent")
INK.setPurpose("targetBorder", "red")
INK.setPurpose("wall", "lilac")
INK.setPurpose("obscured", "purple")
INK.setPurpose("bg", "black")
INK.setPurpose("impossible", "lilac")
INK.setPurpose("error", "red")
INK.setPurpose("playerAtk", "white")
INK.setPurpose("enemyAtk", "red")

INK.setPurpose("titleFg", "red")
INK.setPurpose("titleBg", "burgandy")
INK.setPurpose("mainBg", "black")

INK.setPurpose("welcome", "white")
INK.setPurpose("text", "white")

INK.setPurpose("barText", "white")
INK.setPurpose("barFilled", "purple")
INK.setPurpose("barEmpty", "red")

INK.setPurpose("blood", "red")

INK.setPurpose("creature", "white")
INK.setPurpose("altar", "orange")
INK.setPurpose("altarBg", "bronze")

INK.setPurpose("border", "burgandy")
INK.setPurpose("invalid", "burgandy")

INK.setPurpose("healthRecovered", "white")
INK.setPurpose("treasure", "gold")
INK.setPurpose("needsTarget", "blue")
INK.setPurpose("statusApplied", "green")

INK.setPurpose("downstairs", "gold")
INK.setPurpose("upstairs", "darkgreen")


