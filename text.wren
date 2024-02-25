import "stringUtils" for StringUtils

class TextSplitter {
  static leftPad(text, width) {
    var out = text.toString
    var diff = width - out.count
    for (i in 0...diff) {
      out = " " + out
    }
    return out
  }

  static capitalize(text) {
    var out = StringUtils.toUppercase(text[0])
    out = out + text[1..-1]
    return out
  }

  static getWidth(lines) {
    var max = 0
    for (line in lines) {
      if (line.count > max) {
        max = line.count
      }
    }
    return max
  }

  static split(lines, width) {
    var outputLines = []
    var glyphWidth = 8

    var count = lines.count
    var line = 0
    var i = 0
    while (line < count) {
      var outputLine = ""
      var text = lines[i]
      var words = text.split(" ")

      var x = 0
      for (word in words) {
        if (width - x * glyphWidth <= word.count * glyphWidth) {
          count = count + 1
          line = line + 1
          x = 0
          outputLines.add(outputLine)
          outputLine = ""
        }
        outputLine = outputLine + " " + word
        x = x + (word.count + 1)
      }

      line = line + 1
      i = i + 1
      x = 0
      outputLines.add(outputLine)
    }
    return outputLines
  }
}

