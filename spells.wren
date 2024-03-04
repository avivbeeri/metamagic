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
  construct new(lexeme, category, maxCost) {
    _lexeme = lexeme
    _category = category
    _maxCost = maxCost
  }

  toString { _lexeme }
  category { _category }
  lexeme { _lexeme }
  maxCost { _maxCost }

  == (other) {
    return _lexeme == other.lexeme
  }

  static errorToken(lexeme) { SpellToken.new(lexeme, TokenCategory.error, 0)}
}

class SpellWords {
  // verb
  static conjure { SpellToken.new("CONJURE", TokenCategory.verb, 2) }

  static infuse { SpellToken.new("INFUSE", TokenCategory.verb, 1) }

  //subject
  static fire { SpellToken.new("FIRE", TokenCategory.subject, 3) }
  static earth { SpellToken.new("EARTH", TokenCategory.subject, 3) }
  static water { SpellToken.new("WATER", TokenCategory.subject, 3) }
  static air { SpellToken.new("AIR", TokenCategory.subject, 3) }

  // object
  static self { SpellToken.new("SELF", TokenCategory.object, 2) }
  static close { SpellToken.new("CLOSE", TokenCategory.object, 3) }
  static far { SpellToken.new("FAR", TokenCategory.object, 3) }
}

var BaseTable = {
  SpellWords.close.lexeme: { "target": "area", "area": 1, "range": 0, "origin": null, "exclude": [ Vec.new(0,0) ]  },
  SpellWords.far.lexeme: { "target": "area", "area": 1, "range": 4, "origin": null, "exclude": [], "needEntity": false  }
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
    var effects = []
    var cost = 0

    if (valid && phrase) {
      if (phrase.verb == SpellWords.conjure && phrase.subject == SpellWords.fire) {
        effects.add([ "directDamage", { "damage": 1 } ])
      }
    }

    return Spell.new({
      "phrase": phrase,
      "valid": valid,
      "effects": effects,
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


  phrase { data["phrase"] }
  valid { data["valid"] }
  effects { data["effects"] }

  cost(caster) {
    System.print("Calculating spell cost:")
    if (caster.has("proficiency")) {
      var cost = 0
      for (word in phrase.list) {
        var entry = caster["proficiency"][word.lexeme]
        if (!entry) {
          entry = caster["proficiency"][word.lexeme] = {
            "used": true,
            "success": 0,
            "discovered": false
          }
        }
        var success = entry["success"]
        cost = cost + (entry["discovered"] ? 0 : 2)
        cost = cost + (word.maxCost - success).max(1)
        System.print("%(word): %(entry)")
      }
      System.print("Cost: %(cost)")
      return cost
    }

    // figure out a default
    return valid ? 3 : 0
  }

  target() {
    var result = {}
    Stateful.assign(result, BaseTable[phrase.object.lexeme])
    return result
  }
}

class SpellPhrase {
  construct new(verb, subject, object) {
    _verb = verb
    _subject = subject
    _object = object
  }

  list { [ _verb, _subject, _object ]}

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
