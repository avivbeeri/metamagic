import "dome" for Log

class Pronoun {
  construct new(subject, object, possessive) {
    _subject = subject
    _object = object
    _possessive = possessive
  }
  subject { _subject }
  object { _object }
  possessive { _possessive }

  == (other) {
    if (!(other is Pronoun)) {
      return false
    }
    return subject == other.subject && object == other.object && possessive == other.possessive
  }

  static you { Pronoun.new("you", "you", "yours") }
  static they { Pronoun.new("they", "them", "their") }
  static it { Pronoun.new("it", "it", "its") }

// Try not to use these?
  static male { Pronoun.new("he", "him", "his") }
  static female { Pronoun.new("she", "her", "her") }
}


class Message {

  construct new(text, color) {
    _text = text
    _color = color
    _count = 1
  }
  text { _text }
  color { _color }
  count { _count }

  stack() {
    _count = _count + 1
  }
}

class MessageLog {
  construct new() {
    _messages = []
  }
  count { _messages.count }
  add(text, color, stack) {
    if (stack && _messages.count > 0) {
      var first = _messages[0]
      if (first.text == text) {
        first.stack()
        return
      }
    }

    _messages.insert(0, Message.new(text, color))
    Log.w(text)
  }

  history(start, length) {
    start = start.clamp(0, _messages.count)
    var end = (start + length).clamp(0, _messages.count)
    return _messages[start...end]
  }
  previous(count) {
    count = count.clamp(0, _messages.count)
    return _messages[0...count]
  }
}
