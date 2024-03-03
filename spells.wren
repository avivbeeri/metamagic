import "io" for FileSystem
import "json" for Json
import "./parcel" for Stateful, RNG
import "collections" for Set
import "math" for Vec

class TokenCategory {
  static verb { "VERB" }
  static subject { "SUBJECT" }
  static object { "OBJECT" }
  static modifier { "MODIFIER" }
  static error { "error" }
}

class SpellToken {
  construct new(lexeme, category) {
    _lexeme = lexeme
    _category = category
  }

  toString { _lexeme }
  category { _category }
  lexeme { _lexeme }

  == (other) {
    return _lexeme == other.lexeme && _category == other.category
  }

  static errorToken(lexeme) { SpellToken.new(lexeme, TokenCategory.error)}
}

class SpellWords {
  // verb
  static conjure { SpellToken.new("CONJURE", TokenCategory.verb) }

  static infuse { SpellToken.new("INFUSE", TokenCategory.verb) }

  //subject
  static fire { SpellToken.new("FIRE", TokenCategory.subject) }
  static earth { SpellToken.new("EARTH", TokenCategory.subject) }
  static water { SpellToken.new("WATER", TokenCategory.subject) }
  static air { SpellToken.new("AIR", TokenCategory.subject) }

  // object
  static self { SpellToken.new("SELF", TokenCategory.object) }
  static close { SpellToken.new("CLOSE", TokenCategory.object) }
  static far { SpellToken.new("FAR", TokenCategory.object) }
}


// The order of this matters. We shouldn't disturb it once we start shipping
var AllWords = [
  // Verbs
  SpellWords.conjure,
  SpellWords.infuse,
  // Subjects
  SpellWords.fire,
  SpellWords.earth,
  SpellWords.water,
  SpellWords.air,
  // Objects
  SpellWords.self,
  SpellWords.close,
  SpellWords.far,
]

class Spell is Stateful {
  static build(phrase) {
    System.print(phrase)
    var valid = phrase != null
    var target = {}
    var effects = []
    var cost = 0
    if (phrase.verb == SpellWords.conjure && phrase.subject == SpellWords.fire) {
      effects.add([ "directDamage", { "damage": 1} ])
      cost = 3
    }
    if (phrase.object == SpellWords.close) {
      target = {
        "target": "area",
        "area": 1,
        "origin": null,
        "exclude": [ Vec.new(0, 0) ]
      }
    }

    return Spell.new({
      "phrase": phrase,
      "valid": valid,
      "cost": cost,
      "effects": effects,
      "target": target
    })
  }
  construct new(data) {
    super(data)
    _tokens = data["tokens"]
    _words = data["words"]
    if (valid) {
      data["cost"] = 3
    }
  }

  words { _words }
  tokens { _tokens }

  valid { data["valid"] }
  cost { data["cost"] || 0 }
  target { data["target"] }
  effects { data["effects"] }
}

class SpellPhrase {
  construct new(verb, subject, object) {
    _verb = verb
    _subject = subject
    _object = object
  }

  verb { _verb }
  subject { _subject }
  object { _object }
  toString {
    return "<%(_verb.lexeme) %(_subject.lexeme) %(_object.lexeme)>"
  }
}

class SpellParser {
  construct new(tokens) {
    _tokens = tokens
    _current = 0
    _output = null
    _error = false
  }

  validate() {
    _output = parse()
    return !_error
  }

  parse() {
    if (!_output) {
      _output = phrase()
    }
    return _output
  }

  phrase() {
    if (!match(TokenCategory.verb)) {
      _error = true
      return null
    }
    var verb = previous()
    if (!match(TokenCategory.subject)) {
      _error = true
      return null
    }
    var subject = previous()
    if (!match(TokenCategory.object)) {
      _error = true
      return null
    }
    var object = previous()

    /*
    TODO: support modifiers
    if (check(TokenCategory.modifier)) {
      // modifying object?
      advance()
    }
    */

    if (!isAtEnd()) {
      _error = true
      return f
    }
    return SpellPhrase.new(verb, subject, object)
  }

  match(token) {
    if (check(token)) {
      advance()
      return true
    }
    return false
  }

  check(category) {
    if (isAtEnd()) {
      return false
    }
    // we only care about the category
    return peek().category == category
  }
  advance() {
    if (!isAtEnd()) {
      _current = _current + 1
    }
    return previous()
  }

  isAtEnd() {  _current >= _tokens.count }
  peek() {
    return _tokens[_current]
  }
  previous() {
    return _tokens[_current - 1]
  }
}

class SpellUtils {
  static lexicon { __lexicon }
  static initializeLexicon() {
    var location = FileSystem.prefPath("avivbeeri", "arcanist")
    var path = "%(location)lexicon.json"
    var lexicon = []
    if (!FileSystem.doesFileExist(path)) {
      lexicon = SpellUtils.generateLexicon()
      RNG.shuffle(lexicon)
      Json.save(path, lexicon.toList)
    } else {
      lexicon = Json.load(path)
    }
    __lexicon = lexicon
  }

  static parseSpell(incantation) {
    var words = incantation.split(" ")
    var current = 0

    var tokens = words.map {|word|
      var position = __lexicon.indexOf(word)
      if (position == -1 || position >= AllWords.count) {
        System.print("%(word) is not in the spell lexicon")
        return SpellToken.errorToken(word)
      }

      var token = AllWords[position]
      System.print("%(word) -> %(token.category) [%(token.lexeme)]")
      return token
    }.toList

    var parser = SpellParser.new(tokens)
    var valid = parser.validate()
    var text = valid ? "VALID" : "INVALID"
    System.print("Spell is: %(text)")

    return Spell.build(parser.parse())
  }

  static generateLexicon() {
    var vowels = "aeiouy"
    var consonents = "bcdfghjklmnpqrstvwxyz"
    var possibleWords = Set.new()
    for (vowel in vowels) {
      for (consonent in consonents) {
        if (vowel != consonent) {
          possibleWords.add("%(vowel)%(consonent)")
          possibleWords.add("%(consonent)%(vowel)")
        }
      }
    }
    var sortedList = possibleWords.toList.sort {|a, b|
      var aBytes = a.bytes.toList
      var bBytes = b.bytes.toList
      for (i in 0...aBytes.count) {
        if (i >= bBytes.count) {
          break
        }
        if (aBytes[i] == bBytes[i]) {
          continue
        }
        return aBytes[i] < bBytes[i]
      }
      return true
    }
    return sortedList
  }

}
