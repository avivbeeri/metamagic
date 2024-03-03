import "math" for Vec
import "fov" for Vision2 as Vision
import "parcel" for GameSystem, GameEndEvent, ChangeZoneEvent, Dijkstra
import "./entities" for Player
import "combat" for Condition

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
          stats.increase("mp", 1, "mpMax")
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
      event.src["stats"].increase("xp", 1)
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
    var visibleList = Vision.new(map, player.pos, 16).compute()
    for (pos in visibleList) {
      map[pos]["visible"] = true
    }
  }
}

import "groups" for Components
