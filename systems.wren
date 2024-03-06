import "math" for Vec
import "fov" for Vision2 as Vision
import "parcel" for GameSystem, GameEndEvent, ChangeZoneEvent, Dijkstra, TargetGroup, RNG, DIR_EIGHT
import "./entities" for Player
import "./spells" for SpellWords
import "combat" for Condition, CombatProcessor, Damage, DamageType, Environment
import "collections" for Set

class AirSystem is GameSystem {
  construct new() {
    super()
    _chilled = Set.new()
  }

  applyFreezeTo(ctx, actor) {
    var frozen = actor.has("conditions") && actor["conditions"].containsKey("frozen")
    var effect = Components.effects.applyCondition.new(ctx, {
      "target": actor,
      "condition": {
        "id": "frozen",
        "duration": 5,
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
      CombatProcessor.calculate(Environment.ice, event.target, Damage.new(1, DamageType.ice))
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
      if (spell.phrase.subject == SpellWords.air) {
        for (space in targetGroup.spaces()) {
          var tile = ctx.zone.map[space]
          if (!tile["water"]) {
            continue
          }
          if (tile["chilled"] && tile["chilled"] > 0) {
            tile["chilled"] = tile["chilled"] + 1
          } else {
            tile["chilled"] = 6
            _chilled.add(space)
          }
          for (entity in ctx.getEntitiesAtPosition(space)) {
            applyFreezeTo(ctx, entity)
          }
        }
      } else if (spell.phrase.subject == SpellWords.fire) {
        for (space in targetGroup.spaces()) {
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
      applyBurningTo(ctx, entity)
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
        CombatProcessor.calculate(Environment.fire, actor, Damage.new(1, DamageType.fire))
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
            if (neighbour["grass"]) {
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
        for (space in targetGroup.spaces()) {
          var tile = ctx.zone.map[space]
          if (tile["burning"] && tile["burning"] > 0) {
            tile["burning"] = tile["burning"] + 2
          }
        }
      }
      if (spell.phrase.subject == SpellWords.water) {
        for (space in targetGroup.spaces()) {
          var tile = ctx.zone.map[space]
          if (tile["burning"] && tile["burning"] > 0) {
            tile["burning"] = 0
          }
        }
      } else if (spell.phrase.subject == SpellWords.fire) {
        System.print("fire cast")
        for (space in targetGroup.spaces()) {
          System.print(space)
          var tile = ctx.zone.map[space]
          if (tile["grass"]) {
            setFire(ctx, space)
          }
        }
      }
    }
  }
}
class ManaRegenSystem is GameSystem {
  construct new() { super() }
  process(ctx, event) {
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
    if (actor["stats"]) {
      actor["stats"].tick()
    }
    if (actor.has("conditions")) {
      for (entry in actor["conditions"]) {
        var condition = entry.value
        condition.tick()
        if (condition.done) {
          actor["conditions"].remove(condition.id)
          ctx.addEvent(Components.events.clearCondition.new(actor, condition.id))
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
