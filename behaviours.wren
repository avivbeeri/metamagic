import "jps" for JPS
import "math" for Vec, M
import "fov" for Vision
import "./spells" for Spell, SpellPhrase, SpellWords, SpellFragment, TokenCategory, AllWords
import "parcel" for
  TargetGroup,
  Reflect,
  Entity,
  BehaviourEntity,
  GameSystem,
  AStar,
  Stateful,
  DIR_EIGHT,
  RNG,
  Action

import "collections" for Set

class Behaviour is GameSystem {
  construct new(args) {
    super()
  }
  pathTo(ctx, actor, start, end) {
    var map = ctx.zone
    //var path = AStar.search(map, start, end)
    var path = JPS.new(map, actor).search(start, end)
    return path
  }

  static spaceAvailable(ctx, pos) {
    var destEntities = ctx.getEntitiesAtPosition(pos)
    return (destEntities.isEmpty || !destEntities.any{|entity| !(entity is Player) && entity is Creature && !entity["killed"] })
  }
  static spaceAvailableWithPlayer(ctx, pos) {
    var destEntities = ctx.getEntitiesAtPosition(pos)
    return (destEntities.isEmpty || !destEntities.any{|entity| entity is Creature && !entity["killed"] })
  }
}

#!component(id="confused", group="behaviour")
class ConfusedBehaviour is Behaviour {
  construct new(args) {
    super()
  }
  update(ctx, actor) {
    if (!actor["conditions"].containsKey("confusion")) {
      actor.removeBehaviour(this)
      return false
    }
    var dir = RNG.sample(DIR_EIGHT)
    actor.pushAction(Components.actions.bump.new(dir))
    return true
  }
}
#!component(id="frozen", group="behaviour")
class FrozenBehaviour is Behaviour {
  construct new(args) {
    super()
  }
  update(ctx, actor) {
    if (!actor["conditions"].containsKey("frozen") || actor["conditions"]["frozen"].done) {
      actor.removeBehaviour(this)
      return false
    }
    actor.pushAction(Components.actions.stuck.new())
    return true
  }
}

#!component(id="unconscious", group="behaviour")
class UnconsciousBehaviour is Behaviour {
  construct new(args) {
    super()
  }
  update(ctx, actor) {
    if (!actor["conditions"].containsKey("unconscious")) {
      if (ctx.getEntitiesAtPosition(actor.pos).where {|entity| !entity["killed"] }.count > 1) {
        // Wait til everyone else gets up
        actor.pushAction(Action.none)
        return true
      }
      actor.removeBehaviour(this)
      actor["solid"] = true
      actor["killed"] = false
      // What should we set this to?
      var maxHp = actor["stats"].get("hpMax")
      actor["stats"].set("hp", RNG.int(maxHp) + 1)
      return false
    }
    actor.pushAction(Action.none)
    return true
  }
}


#!component(id="randomWalk", group="behaviour")
class RandomWalkBehaviour is Behaviour {
  construct new(args) {
    super()
  }
  update(ctx, actor) {
    var options= ctx.zone.map.neighbours(actor.pos)
    var next = RNG.sample(options)

    var dir = next - actor.pos
    var dx = M.mid(-1, dir.x, 1)
    var dy = M.mid(-1, dir.y, 1)
    dir.x = dx
    dir.y = dy
    actor.pushAction(Components.actions.bump.new(dir))
    return true
  }
}

#!component(id="wander", group="behaviour")
class WanderBehaviour is RandomWalkBehaviour {
  construct new(args) {
    super()
  }
  update(ctx, actor) {
    // This is a weighted random walk
    // We have a 75% chance of continuing in the direction of travel
    // 25% to change direction, assuming the space is valid.
    var previous = actor["previousPosition"] || actor.pos
    var previousDir = actor["previousDir"] || Vec.new()
    var dir = previousDir
    var options = RNG.shuffle(DIR_EIGHT[0..-1])
    var i = 0
    var fine = false
    while (!fine && i < options.count) {
      if (actor.pos == previous || RNG.float() < 0.25) {
        while (dir == previousDir) {
          dir = RNG.sample(options)
        }
      } else {
        dir = actor.pos - previous
        dir.x = M.mid(-1, dir.x, 1)
        dir.y = M.mid(-1, dir.y, 1)
      }
      var dest = actor.pos + dir
      fine = ctx.zone.map.isFloor(dest) && Behaviour.spaceAvailable(ctx, dest)
      i = i + 1
    }
    if (!fine) {
      dir = RNG.sample(DIR_EIGHT)
    }
    actor["previousDir"] = dir
    actor["previousPosition"] = actor.pos
    actor.pushAction(Components.actions.bump.new(dir))
    return true
  }
}

#!component(id="cast", group="behaviour")
class CastBehaviour is Behaviour {
  construct new(args) {
    super()
  }

  initializeWords(actor) {
    actor["words"].addAll([
      SpellWords.conjure,
      SpellWords.fire,
      SpellWords.far,
      SpellWords.big
    ])
  }

  buildSpell(actor) {
    var words = actor["words"]
    var verb =  RNG.sample(words.where {|word| word.category == TokenCategory.verb }.toList)
    var subject =  RNG.sample(words.where {|word| word.category == TokenCategory.subject }.toList)
    var object =  RNG.sample(words.where {|word| word.category == TokenCategory.object }.toList)

    var modifiers = words.where {|word| word.category == TokenCategory.modifier }.toList
    if (!modifiers.isEmpty && RNG.float() > 0.5) {
      var modifier =  RNG.sample(modifiers)
      object = SpellFragment.new(object, modifier)
    }

    return Spell.build(SpellPhrase.new(verb, subject, object))
  }

  update(ctx, actor) {
    if (!actor.has("words")) {
      actor["words"] = []
      initializeWords(actor)
    }
    if (!actor.has("spells.queue")) {
      actor["spells.queue"] = []
    }
    if (actor["spells.queue"].isEmpty) {
      actor["spells.queue"].add(buildSpell(actor))
      return false
    }
    var spell = actor["spells.queue"][0]

    var player = ctx.getEntityByTag("player")
    if (!player) {
      return false
    }

    var spec = spell.target()

    var valid = false
    var srcGroup = TargetGroup.new(spell.target())
    srcGroup["src"] = actor.pos
    srcGroup["origin"] = actor.pos
    srcGroup["exclude"] = 0
    var maxRange = spec["area"] + (spec["range"]).max(1)
    srcGroup["area"] = maxRange
    var originalOptions = srcGroup.spaces(ctx)
    // maximum hittable area
    var visibleSet = Set.new()
    var vision = Vision.new(ctx.zone.map, actor.pos, spec["range"])
    visibleSet.addAll(vision.compute().result)

    var playerScan = TargetGroup.new({
      "src": player.pos,
      "target": "area",
      "area": spec["area"],
      "exclude": 0,
      "origin": player.pos
    })
    var options = Set.new()
    options.addAll(playerScan.spaces(ctx))

    var intersection = originalOptions.where {|space| visibleSet.contains(space) && options.contains(space) }.toList
    var found = false
    for (space in RNG.shuffle(intersection)) {
      srcGroup["origin"] = space
      var entities = srcGroup.entities(ctx, actor)
      if (!entities.isEmpty && !entities.any {|entity| entity["kind"] == "illusion" || entity["kind"] == "archmage" }) {
        found = true
        break
      }
    }
    if (!found && !intersection.isEmpty) {
      srcGroup["origin"] = RNG.sample(intersection)
      valid = true
    }

    if (!valid) {
      System.print("not valid?")
      return false
    }
    if (spell.cost(actor) > actor["stats"]["mp"]) {
      System.print("out of mana")
      return false
    }

    actor.pushAction(Components.actions.cast.new().withArgs({
      "spell": spell,
      "target": srcGroup
    }))
    actor["spells.queue"].removeAt(0)
    return true
  }
}

#!component(id="summon", group="behaviour")
class SummonBehaviour is Behaviour {

  construct new(args) {
    super()
    _summonCount = 0
  }

  update(ctx, actor) {
    var illusions = ctx.entities().where{|entity| entity["kind"] == "illusion"}.toList
    if (_summonCount == 0  && illusions.isEmpty) {
      _summonCount = 50
      var position = RNG.sample(ctx.zone.map.neighbours(actor.pos))

      var effectSpec = ["summon",
      {
        "src": actor,
        "origin": actor.pos,
        "qty": 2,
        "id": "illusion",
      }]

      actor.pushAction(Components.actions.effect.new().withArgs({
        "effects": [ effectSpec ]
      }))
      return true
    }
    _summonCount = _summonCount - 1
    return false
  }
}
#!component(id="boss", group="behaviour")
class BossBehaviour is CastBehaviour {
  construct new(args) {
    super()
  }
  initializeWords(actor) {
    var ctx = actor.ctx
    var player = ctx.getEntityByTag("player")
    var table = player["proficiency"]
    for (tableEntry in table) {
      var entry = tableEntry.value
      var key = tableEntry.key
      if (entry["gameUsed"] || entry["discovered"]) {
        var word = AllWords.where {|word| word.lexeme == key }.toList[0]
        actor["words"].add(word)
      }
    }
    System.print(actor["words"])
  }
  buildSpell(actor) {
    var spell = super.buildSpell(actor)
    var mp = actor["stats"]["mp"]
    var mpMax = actor["stats"]["mpMax"]
    var cost = spell.cost(actor)
    System.print("MP: %(mp)/%(mpMax) - spell: %(cost)")
    actor["stats"].set("mpMax", cost)
    if (actor["stats"]["mp"] > cost) {
      actor["stats"].set("mp", cost)
    }

    return spell
  }

  update(ctx, actor) {
    return super.update(ctx, actor)
  }
}

#!component(id="seek", group="behaviour")
class SeekBehaviour is Behaviour {
  construct new(args) {
    super()
    if (args.count > 0) {
      _bump = args[0]
    } else {
      _bump = true
    }
  }
  bump { _bump }
  bump=(v) { _bump = v }
  update(ctx, actor) {
    var player = ctx.getEntityByTag("player")
    if (!player) {
      return false
    }
    var path = pathTo(ctx, actor, actor.pos, player.pos)
    if (path == null || path.count < 2) {
      return false
    }
    var next = path[1]
    var dir = next - actor.pos
    dir.x = M.mid(-1, dir.x, 1)
    dir.y = M.mid(-1, dir.y, 1)

    if (!Behaviour.spaceAvailable(ctx, next)) {
      // Stop swarms eating each other
      return false
    }
    if (!_bump) {
      System.print("nobump")
      if (!Behaviour.spaceAvailableWithPlayer(ctx, next)) {
        actor.pushAction(Action.doNothing)
        return false
      }
      actor.pushAction(Components.actions.simpleMove.new(dir))
      return true
    }
    System.print("bump")
    actor.pushAction(Components.actions.bump.new(dir))
    return true
  }
}

#!component(id="buffer", group="behaviour")
class BufferBehaviour is Behaviour {
  construct new(args) {
    super()
    if (args.count > 0) {
      _bump = args[0]
    } else {
      _bump = true
    }
  }

  update(ctx, actor) {
    var player = ctx.getEntityByTag("player")
    if (!player) {
      return false
    }
    var minRange = actor["targetRange"] || 1

    var dMap = player["map"]
    var costMap = dMap[0]
    var nextMap = dMap[1]
    var next = null
    if (costMap[actor.pos] < minRange) {
      var neighbours = ctx.zone.map.neighbours(actor.pos)
      var candidate = []
      for (node in neighbours) {
        if (costMap[node] >= minRange) {
          candidate.add(node)
        }
      }
      if (candidate.isEmpty) {
        for (node in neighbours) {
          if (costMap[node] >= costMap[actor.pos]) {
            candidate.add(node)
          }
        }
      }
      if (candidate.isEmpty) {
        next = RNG.sample(neighbours)
      } else {
        next = RNG.sample(candidate)
      }
    } else if (costMap[actor.pos] > minRange) {
      var path = pathTo(ctx, actor, actor.pos, player.pos)
      if (path == null || path.count < 2) {
        return false
      }
      next = path[1]
    } else {
      return false
    }

    var dir = next - actor.pos
    dir.x = M.mid(-1, dir.x, 1)
    dir.y = M.mid(-1, dir.y, 1)

    if (!Behaviour.spaceAvailable(ctx, next)) {
      // Stop swarms eating each other
      return false
    }

    if (!_bump) {
      if (!Behaviour.spaceAvailableWithPlayer(ctx, next)) {
        actor.pushAction(Action.doNothing)
        return false
      }
      actor.pushAction(Components.actions.simpleMove.new(dir))
      return true
    }
    actor.pushAction(Components.actions.bump.new(dir))
    return true
  }
}

#!component(id="localSeek", group="behaviour")
class LocalSeekBehaviour is SeekBehaviour {
  construct new(args) {
    super(args)
    _range = args[0]
    if (args.count > 1) {
      bump = args[1]
    }
  }
  update(ctx, actor) {
    var player = ctx.getEntityByTag("player")
    if (!player || player["map"] == null) {
      return false
    }
    var dpath = player["map"][0]
    if (!dpath[actor.pos] || (_range && dpath[actor.pos] > _range)) {
      System.print("ignoring localseek")
      return false
    }
    return super.update(ctx, actor)
  }
}

import "entities" for Player, Creature
import "groups" for Components
