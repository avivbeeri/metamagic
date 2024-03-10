import "math" for Vec
import "fov" for Vision2 as Vision
import "parcel" for GameSystem, GameEndEvent, ChangeZoneEvent, Dijkstra, TargetGroup, RNG, DIR_EIGHT
import "./entities" for Player
import "./spells" for SpellWords
import "combat" for Condition, CombatProcessor, Damage, DamageType, Environment, TagGroup
import "collections" for Set

class ElementalSystem is GameSystem {
  construct new() {
    super()
    _variants  = {
      0: {
        "words": [ SpellWords.fire, SpellWords.conjure, SpellWords.far],
        "immunities": [ "FIRE" ],
        "resistances": [],
        "vulnerabilities": [ "ICE" ],
        "name": "Fire Elemental"
      },
      1: {
        "immunities": [ ],
        "vulnerabilities": [],
        "resistances": [ "KINETIC" ],
        "words": [ SpellWords.earth, SpellWords.conjure, SpellWords.close],
        "name": "Earth Elemental"
      },
      2: {
        "immunities": [ ],
        "vulnerabilities": [],
        "resistances": [ "FIRE", "ICE" ],
        "words": [ SpellWords.water, SpellWords.conjure, SpellWords.far],
        "name": "Water Elemental"
      },
      3: {
        "vulnerabilities": [],
        "immunities": [ ],
        "resistances": [ "FIRE" ],
        "words": [ SpellWords.air, SpellWords.conjure, SpellWords.close],
        "name": "Air Elemental"
      },
    }
  }
  process(ctx, event) {
    if (event is Components.events.entityAdded && event.entity["kind"] == "elemental") {
      var choice = RNG.int(4)
      var variant = _variants[choice]
      var entity = event.entity
      entity["name"] = variant["name"]
      entity["words"] = variant["words"]
      entity["vulnerabilities"].addAll(variant["vulnerabilities"])
      entity["resistances"].addAll(variant["resistances"])
      entity["immunities"].addAll(variant["immunities"])
    }
  }
}
class AirSystem is GameSystem {
  construct new() {
    super()
    _chilled = Set.new()
  }

  applyFreezeTo(ctx, actor, duration) {
    var frozen = actor.has("conditions") && actor["conditions"].containsKey("frozen")
    var effect = Components.effects.applyCondition.new(ctx, {
      "target": actor,
      "condition": {
        "id": "frozen",
        "duration": duration,
        "refresh": true,
        "curable": true
      }
    })
    effect.perform()
    if (!frozen) {
      ctx.addEvents(effect.events)
    }
  }

  process(ctx, event) {
    if (event is Components.events.clearCondition && event.condition == "frozen") {
      var events = CombatProcessor.calculate(Environment.ice, event.target, Damage.new(1, DamageType.ice))
      ctx.addEvents(events)
    }
    if (event is Components.events.turn) {
      var map = ctx.zone.map
      var removals = []
      for (pos in _chilled) {
        var tile = map[pos]
        if (tile["chilled"] && tile["chilled"] > 0) {
          tile["chilled"] = tile["chilled"] - 1
          if (tile["chilled"] <= 0) {
            removals.add(pos)
          }
        }
      }
      for (pos in removals) {
        _chilled.remove(pos)
      }
    } else if (event is Components.events.cast) {
      var spell = event.spell
      var targetSpec = spell.target()
      targetSpec["origin"] = event.origin
      targetSpec["src"] = event.src.pos
      var targetGroup = TargetGroup.new(targetSpec)
      System.print(spell.phrase.verb)
      if (spell.phrase.verb != SpellWords.infuse && spell.phrase.subject == SpellWords.air) {
        for (space in targetGroup.spaces(ctx)) {
          var tile = ctx.zone.map[space]
          if (!tile["water"]) {
            continue
          }
          var duration = 6 + RNG.int(4)
          if (tile["chilled"] && tile["chilled"] > 0) {
            tile["chilled"] = tile["chilled"] + 1
          } else {
            tile["chilled"] = duration
            _chilled.add(space)
          }
          for (entity in ctx.getEntitiesAtPosition(space)) {
            applyFreezeTo(ctx, entity, duration)
          }
        }
      } else if (spell.phrase.subject == SpellWords.fire) {
        for (space in targetGroup.spaces(ctx)) {
          var tile = ctx.zone.map[space]
          if (tile["chilled"] && tile["chilled"] > 0) {
            tile["chilled"] = (tile["chilled"] / 2).floor
          }
        }
      }
    }
  }
}

class FireSystem is GameSystem {
  construct new() {
    super()
    _burning = Set.new()
  }
  setFire(ctx, position) {
    if (_burning.contains(position)) {
      return
    }
    var tile = ctx.zone.map[position]
    tile["grass"] = false
    tile["burning"] = 3
    for (entity in ctx.getEntitiesAtPosition(position)) {
      if (!entity["immunities"].contains("FIRE")) {
        applyBurningTo(ctx, entity)
      }
    }
    _burning.add(position)
  }
  cureBurning(ctx, actor) {
    var effect = Components.effects.cureCondition.new(ctx, {
      "target": actor,
      "condition": "burning"
    })
    effect.perform()
    ctx.addEvents(effect.events)
  }
  applyBurningTo(ctx, actor) {
    var burning = actor.has("conditions") && actor["conditions"].containsKey("burning")
    var effect = Components.effects.applyCondition.new(ctx, {
      "target": actor,
      "condition": {
        "id": "burning",
        "duration": 5,
        "refresh": true,
        "curable": true
      }
    })
    effect.perform()
    if (!burning) {
      ctx.addEvents(effect.events)
    }
  }
  postUpdate(ctx, actor) {
    if (actor.pos == null) {
      return
    }
    var tile = ctx.zone.map[actor.pos]
    if (actor.has("conditions") && actor["conditions"].containsKey("burning")) {
      if (tile["water"]) {
        cureBurning(ctx, actor)
      }
      if (!actor["conditions"]["burning"].done) {
        var events = CombatProcessor.calculate(Environment.fire, actor, Damage.new(1, DamageType.fire))
        ctx.addEvents(events)
      }
    }
    if (tile["burning"] && tile["burning"] > 0) {
      applyBurningTo(ctx, actor)
    }
  }
  process(ctx, event) {
    if (event is Components.events.turn) {
      var hyperspace = []
      var map = ctx.zone.map
      var removals = []
      for (pos in _burning) {
        var tile = map[pos]
        if (tile["burning"] && tile["burning"] > 0) {
          if (RNG.float() < 0.6) {
            tile["burning"] = tile["burning"] - 1
            if (tile["burning"] <= 0) {
              removals.add(pos)
            }
          }
          for (next in map.neighbours(pos)) {
            var neighbour = map[next]
            if (neighbour["grass"] && RNG.float() > 0.3) {
              hyperspace.add(next)
            }
          }
          for (pos in removals) {
            _burning.remove(pos)
          }
        }
      }
      for (pos in hyperspace) {
        setFire(ctx, pos)
      }
    } else if (event is Components.events.cast) {
      var spell = event.spell
      var targetSpec = spell.target()
      targetSpec["origin"] = event.origin
      targetSpec["src"] = event.src.pos
      var targetGroup = TargetGroup.new(targetSpec)
      if (spell.phrase.subject == SpellWords.air) {
        for (space in targetGroup.spaces(ctx)) {
          var tile = ctx.zone.map[space]
          if (tile["burning"] && tile["burning"] > 0) {
            tile["burning"] = tile["burning"] + 2
          }
        }
      }
      if (spell.phrase.subject == SpellWords.water) {
        for (space in targetGroup.spaces(ctx)) {
          var tile = ctx.zone.map[space]
          if (tile["burning"] && tile["burning"] > 0) {
            tile["burning"] = 0
          }
        }
      } else if (spell.phrase.subject == SpellWords.fire) {
        System.print("fire cast")
        for (space in targetGroup.spaces(ctx)) {
          System.print(space)
          var tile = ctx.zone.map[space]
          if (tile["grass"]) {
            setFire(ctx, space)
          }
          for (entity in ctx.getEntitiesAtPosition(space)) {
            if (entity["tags"].contains("flammable")) {
              applyBurningTo(ctx, entity)
            }
          }
        }
      }
    }
  }
}
class ManaRegenSystem is GameSystem {
  construct new() { super() }
  process(ctx, event) {
    if (event is ChangeZoneEvent && event.floor != 0) {
      var player = ctx.getEntityByTag("player")
      var inventory = player["inventory"]

      var entries = player["inventory"].where {|entry| entry.id == "food" }
      var injured = (player["stats"]["hp"] < player["stats"]["hpMax"])
      if (entries.count <= 0) {
        ctx.addEvent(Components.events.campfire.new(injured, false))
        return
      }
      var entry = entries.toList[0]
      if (entry.qty <= 0) {
        ctx.addEvent(Components.events.campfire.new(injured, false))
        return
      }
      if (player["stats"]["hp"] < player["stats"]["hpMax"]) {
        entry.subtract(1)
        var amount = player["stats"].maximize("hp", "hpMax")
        player["stats"].maximize("mp", "mpMax")
        ctx.addEvent(Components.events.heal.new(player, amount))
        ctx.addEvent(Components.events.regen.new(player))
        ctx.addEvent(Components.events.campfire.new(injured, true))
      } else {
        ctx.addEvent(Components.events.campfire.new(injured, false))
      }
    }
    if (event is Components.events.turn) {
      for (entity in ctx.entities()) {
        if (!entity.has("stats")) {
          continue
        }
        var stats = entity["stats"]
        if (!stats.has("mpMax")) {
          continue
        }
        stats.increase("mpHidden", 1)
        if (stats["mpHidden"] >= 5) {
          stats.increase("mp", 3, "mpMax")
          stats.set("mpHidden", 0)
          ctx.addEvent(Components.events.regen.new(entity))
        }
      }
    }
  }
}

class ExperienceSystem is GameSystem {
  construct new() { super() }
  process(ctx, event) {
    if (event is Components.events.kill) {
      // Count XP just in case
      if (event.src.has("stats")) {
        event.src["stats"].increase("xp", 1)
      }
    }
  }
}

class InventorySystem is GameSystem {
  construct new() { super() }
  postUpdate(ctx, actor) {
    if (actor.has("inventory")) {
      actor["inventory"] = actor["inventory"].where {|entry| entry.qty > 0 }.toList.sort{|a, b|
        var itemA = ctx["items"][a.id]
        var itemB = ctx["items"][b.id]
        var itemEquipmentA = (itemA.slot)
        var itemEquipmentB = (itemB.slot)
        var itemEquippedA = (itemEquipmentA && actor["equipment"][itemA.slot] == itemA.id)
        var itemEquippedB = (itemEquipmentB && actor["equipment"][itemB.slot] == itemB.id)
        var order = {
          "PRIORITY": 0,
          "WEAPON": 1,
          "ARMOR": 2,
          "OFF_HAND": 3,
          "TRINKET": 4,
        }
        if (!itemEquipmentA && !itemEquipmentB) {
          return true
        } else if (!itemEquipmentA && itemEquipmentB) {
          return false
        } else if (itemEquipmentA && !itemEquipmentB) {
          return true
        } else if (itemEquippedA && !itemEquippedB) {
          return true
        } else if (!itemEquippedA && itemEquippedB) {
          return false
        } else {
          return order[itemA.slot] < order[itemB.slot]
        }
      }
    }
  }
}

class TagModifierSystem is GameSystem {
  construct new() { super() }
  postUpdate(ctx, actor) {
    for (field in actor.data.keys) {
      var group = actor[field]
      if (!(group is TagGroup)) {
        continue
      }
      for (modifier in group.modifiers) {
        modifier.tick()
        if (!modifier.done) {
          continue
        }

        group.removeModifier(modifier.id)
        ctx.addEvent(Components.events.clearTag.new(actor, modifier.id))
      }
    }
  }
}

class ModifierSystem is GameSystem {
  construct new() { super() }
  postUpdate(ctx, actor) {
    if (actor["stats"]) {
      var stats = actor["stats"]
      for (modifier in stats.modifiers) {
        modifier.tick()
        if (modifier.done) {
          stats.removeModifier(modifier.id)
          ctx.addEvent(Components.events.clearModifier.new(actor, modifier.id))
        }
      }
    }
  }
}

class ConditionSystem is GameSystem {
  construct new() { super() }
  process(ctx, event) {
    if (event is Components.events.inflictCondition && event.condition == "confusion") {
      event.target.behaviours.add(Components.behaviours.confused.new(null))
    }
    if (event is Components.events.inflictCondition && event.condition == "frozen") {
      event.target.behaviours.add(Components.behaviours.frozen.new(null))
    }

  }
  postUpdate(ctx, actor) {
    if (actor.has("conditions")) {
      for (entry in actor["conditions"]) {
        var condition = entry.value
        var wasDone = condition.done
        condition.tick()
        if (condition.done) {
          actor["conditions"].remove(condition.id)
          if (!wasDone) {
            ctx.addEvent(Components.events.clearCondition.new(actor, condition.id))
          }
        }
      }
    }
  }
}
class DefeatSystem is GameSystem {
  construct new() { super() }
  process(ctx, event) {
    if (event is Components.events.kill) {
      if (event.target["boss"]) {
        ctx.addEvent(GameEndEvent.new(true))
      }
    }
    if (event is GameEndEvent) {
      ctx.complete = true
    }
  }
  postUpdate(ctx, actor) {
    var player = ctx.getEntityByTag("player")
    if (!player || player["killed"] || player["stats"]["hp"] <= 0) {
      ctx.addEvent(GameEndEvent.new(false))
    }
  }
}
class VisionSystem is GameSystem {
  construct new() { super() }
  start(ctx) {
    var player = ctx.getEntityByTag("player")
    if (!player) {
      return
    }
    postUpdate(ctx, player)
  }

  process(ctx, event) {
    if (event is ChangeZoneEvent) {
      var player = ctx.getEntityByTag("player")
      if (!player) {
        return
      }
      ctx["map"] = Dijkstra.map(ctx.zone.map, player.pos)
    }
  }
  postUpdate(ctx, actor) {
    var player = ctx.getEntityByTag("player")
    if (!player) {
      return
    }
    var map = ctx.zone.map
    for (y in map.yRange) {
      for (x in map.xRange) {
        if (map[x, y]["visible"]) {
          map[x, y]["visible"] = "maybe"
        } else {
          map[x, y]["visible"] = false
        }
      }
    }
    var visibleList = Vision.new(map, player.pos, 12).compute()
    for (pos in visibleList) {
      map[pos]["visible"] = true
    }
  }
}

import "groups" for Components
