import "io" for FileSystem
import "json" for Json
import "./parcel" for Stateful, RNG, GameSystem
import "collections" for Set
import "math" for Vec
import "combat" for Damage, DamageType

class TokenCategory {
  static verb { "VERB" }
  static subject { "SUBJECT" }
  static object { "OBJECT" }
  static modifier { "MODIFIER" }
  static error { "error" }
}

class SpellToken {
  construct new(lexeme, category, description, maxCost) {
    _lexeme = lexeme
    _category = category
    _description = description
    _maxCost = maxCost
  }

  toString { _lexeme }
  category { _category }
  description { _description }
  lexeme { _lexeme }
  maxCost { _maxCost }
  minCost { 1 }
  toList { [ this ] }

  != (other) {
    return !(this == other)
  }
  == (other) {
    return lexeme == other.lexeme
  }

  static errorToken(lexeme) { SpellToken.new(lexeme, TokenCategory.error, "<ERROR>", 0)}
  static eof { SpellToken.new("<EOF>", TokenCategory.error, "<EOF>", 0)}
}

class SpellWords {
  // verb
  static conjure { SpellToken.new("CONJURE", TokenCategory.verb, "To call forth...", 2) }

  static infuse { SpellToken.new("INFUSE", TokenCategory.verb, "To instill...", 1) }

  //subject
  static fire { SpellToken.new("FIRE", TokenCategory.subject, "The element of Fire", 3) }
  static earth { SpellToken.new("EARTH", TokenCategory.subject, "The element of Earth", 3) }
  static water { SpellToken.new("WATER", TokenCategory.subject, "The element of Water",  3) }
  static air { SpellToken.new("AIR", TokenCategory.subject, "The element of Air", 3) }

  // object
  static self { SpellToken.new("SELF", TokenCategory.object, "Myself", 2) }
  static close { SpellToken.new("CLOSE", TokenCategory.object, "Nearby to me", 3) }
  static far { SpellToken.new("FAR", TokenCategory.object, "Distant from here", 4) }

  static big { SpellToken.new("BIG", TokenCategory.modifier, "...in a broad area", 1) }
  static bigger { SpellToken.new("BIGGER", TokenCategory.modifier, "...in an enormous area.", 2) }
}

var BaseTable = {
  SpellWords.self.lexeme: { "target": "self", "area": 0, "range": 0, "origin": null },
  SpellWords.close.lexeme: { "target": "area", "area": 0, "range": 1, "origin": null, "exclude": [ Vec.new(0,0) ], "needEntity": false  },
  SpellWords.far.lexeme: { "target": "area", "area": 0, "range": 4, "origin": null, "exclude": [], "needEntity": false  },
  SpellWords.big.lexeme: { "area": 1 },
  SpellWords.bigger.lexeme: { "area": 2 }
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

  // Modifiers
  SpellWords.big,
  SpellWords.bigger,
]

class Spell is Stateful {
  static build(phrase) {
    var valid = phrase.valid
    var effects = []
    var cost = 0

    if (valid && phrase) {
      if (phrase.verb == SpellWords.infuse) {
        if (phrase.subject == SpellWords.fire) {
          effects.add([ "cureCondition", { "condition": "frozen" } ])
        }
        if (phrase.subject == SpellWords.water) {
          effects.add([ "cureCondition", { "condition": "burning" } ])
          effects.add([ "applyTag", {
            "field": "resistances",
            "modifier": {
              "id": "infuse.water",
              "duration": 10,
              "add": [ DamageType.fire ]
            }
          }])
          // Make moving through water easier?
          // provide fire immunity
        }
        if (phrase.subject == SpellWords.earth) {
          // add to def
          effects.add([ "applyModifier", {
            "modifier": {
              "id": "infuse.earth",
              "add": { "def": 1 },
              "duration": 10,
              "positive": true
            }
          }])
        }
        if (phrase.subject == SpellWords.air) {
          // make you faster
          effects.add([ "applyModifier", {
            "modifier": {
              "id": "infuse.air",
              "mult": { "spd": 1.2 },
              "duration": 10,
              "positive": true
            }
          }])
        }
      }

      if (phrase.verb == SpellWords.conjure) {
        if (phrase.subject == SpellWords.fire) {
          effects.add([ "damage", { "damage": Damage.new(1, DamageType.fire) } ])
          effects.add([ "applyCondition", {
            "condition": {
              "id": "burning",
              "duration": 5,
              "curable": true,
              "refresh": true
            }
          } ])
        }
        if (phrase.subject == SpellWords.water) {
          // effects.add([ "damage", { "damage": Damage.new(1, DamageType.kinetic) } ])
          effects.add([ "cureCondition", { "condition": "burning" } ])
          effects.add([ "push", { "distance": 2, "strong": true } ])
        }
        if (phrase.subject == SpellWords.earth) {
          effects.add([ "damage", { "damage": Damage.new(2, DamageType.kinetic) } ])
        }
        if (phrase.subject == SpellWords.air) {
          effects.add([ "push", { "distance": 2 } ])
        }
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

  incantation() {
    return phrase.list.map {|token| SpellUtils.getWordFromToken(token) }.join(" ")
  }
  cost(caster) {
    System.print("Calculating spell cost:")
    if (caster.has("proficiency")) {
      var cost = 0
      for (word in phrase.list) {
        var entry = caster["proficiency"][word.lexeme]
        if (!entry) {
          entry = caster["proficiency"][word.lexeme] = {
            "floorUsed": false,
            "gameUsed": false,
            "success": 0,
            "discovered": false
          }
        }
        var success = entry["success"]
        var wordCost = 0
        wordCost = (entry["discovered"] ? 0 : 2)
        wordCost = wordCost + (word.maxCost - success).max(word.minCost)
        cost = cost + wordCost
        System.print("%(word) [ %(wordCost) MP ]: %(entry)")
      }
      System.print("Cost: %(cost) MP")
      return cost
    }

    // figure out a default
    return valid ? 3 : 0
  }

  target() {
    var result = {}
    var object = phrase.object
    var modifier = null
    if (object is SpellFragment) {
      modifier = object.modifier
      object = object.atom

    }
    Stateful.assign(result, BaseTable[object.lexeme])
    if (modifier) {
      Stateful.assign(result, BaseTable[modifier.lexeme])
      if (object == SpellWords.close) {
        result["range"] = 0
      }
    }
    return result
  }
}

class SpellFragment {
  construct new(atom, modifier) {
    _atom = atom
    _modifier = modifier
  }

  atom { _atom }
  modifier { _modifier }
  toString { "%(atom) %(modifier)"}
  toList { [ atom, modifier ] }
}

class SpellPhrase {
  construct new(verb, subject, object) {
    _verb = verb
    _subject = subject
    _object = object
  }

  valid { list.all {|token| token.category != TokenCategory.error } }

  list {
    var result = [ _verb ]
    result.addAll(_subject.toList)
    result.addAll(_object.toList)
    return result
  }

  verb { _verb }
  subject { _subject }
  object { _object }
  toString {
    return "<%(_verb) %(_subject) %(_object)>"
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
    var verb = null
    var subject = null
    var object = null
    var modifier = null

    if (!match(TokenCategory.verb)) {
      _error = true
      advance()
      verb = SpellToken.errorToken(previous().lexeme)
    } else {
      verb = previous()
    }

    if (!match(TokenCategory.subject)) {
      _error = true
      advance()
      subject = SpellToken.errorToken(previous().lexeme)
    } else {
      subject = previous()
    }
    /*
    // TODO
    if (match(TokenCategory.modifier)) {
      subject = SpellFragment.new(subject, previous())
    }
    */
    if (!match(TokenCategory.object)) {
      _error = true
      advance()
      object = SpellToken.errorToken(previous().lexeme)
    } else {
      object = previous()
    }

    if (match(TokenCategory.modifier)) {
      object = SpellFragment.new(object, previous())
    }

    if (!isAtEnd()) {
      _error = true
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

  isAtEnd() {  _current == SpellToken.eof || _current >= _tokens.count }
  peek() {
    return _tokens[_current]
  }
  previous() {
    return _tokens[_current - 1]
  }
}

class SpellUtils {
  static lexicon {
    if (!__lexicon) {
      initializeLexicon()
    }
    return __lexicon
  }
  static getWordFromToken(token) {
    var position = AllWords.indexOf(token)
    if (position != -1) {
      return lexicon[position]
    }
    return "<???>"
  }
  static initializeLexicon() {
    if (__lexicon) {
      return
    }
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
    tokens.add(SpellToken.eof)

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
class SpellSystem is GameSystem {
  construct new() {
    super()
  }
  start(ctx) {
    var player = ctx.getEntityByTag("player")
    if (!player) {
      return
    }
    if (!player.has("proficiency")) {
      Fiber.abort("Player has no proficiency")
    }

    var words = [
      RNG.sample(AllWords.where {|word| word == SpellWords.conjure }.toList),
      // RNG.sample(AllWords.where {|word| word.category == TokenCategory.verb }.toList),
      RNG.sample(AllWords.where {|word| word.category == TokenCategory.subject }.toList),
      RNG.sample(AllWords.where {|word| word.category == TokenCategory.object }.toList)
    ]

    for (word in words) {
      teach(player, word)
    }
  }

  process(ctx, event) {
    if (event is Components.events.pickup && event.item == "book" && event.qty > 0) {
      var actor = event.src
      var inventory = actor["inventory"]

      var entries = actor["inventory"].where {|entry| entry.id == event.item }
      if (entries.count <= 0) {
        return
      }
      var entry = entries.toList[0]
      if (entry.qty <= 0) {
        return
      }
      entry.qty = 0

      if (actor.has("proficiency")) {
        var newWord = RNG.sample(AllWords.where {|word|
          var entry = actor["proficiency"][word.lexeme]
          return (!entry || !entry["discovered"])
        }.toList)
        teach(actor, newWord)
      }

    }
  }
  teach(actor, word) {
    if (actor.has("learningOrder")) {
      actor["learningOrder"].add(word)
    }
    if (!actor.has("proficiency")) {
      return
    }
    var table = actor["proficiency"]
    var entry = table[word.lexeme]
    if (!entry) {
      entry = table[word.lexeme] = {
        "floorUsed": false,
        "gameUsed": true,
        "success": 0,
        "discovered": true
      }
    } else {
      entry["discovered"] = true
      entry["gameUsed"] = true
    }
  }
}

import "groups" for Components
