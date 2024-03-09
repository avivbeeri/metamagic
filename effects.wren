import "math" for Vec
import "parcel" for Stateful, RNG, Line
import "groups" for Components
import "collections" for Set
import "factory" for CreatureFactory
import "combat" for Condition, Modifier, CombatProcessor, Environment, Damage, DamageType, TagModifier

class Effect is Stateful {
  construct new(ctx, args) {
    super(args)
    _ctx = ctx
    _events = []
  }

  ctx { _ctx }
  events { _events }

  perform() { Fiber.abort("Abstract effect has no perform action") }
  addEvent(event) { _events.add(event) }
  addEvents(events) { _events.addAll(events) }
}

#!component(id="cureCondition", group="effect")
class CureConditionEffect is Effect {
  construct new(ctx, args) {
    super(ctx, args)
  }

  target { data["target"] }
  src { data["src"] }
  condition { data["condition"] }

  perform() {
    if (target["conditions"].containsKey(condition)) {
      target["conditions"][condition].cure()
      addEvent(Components.events.clearCondition.new(target, condition))
    }
  }
}

#!component(id="summon", group="effect")
class SummonEffect is Effect {
  construct new(ctx, args) {
    super(ctx, args)
  }

  origin { data["origin"] }
  id { data["id"] }
  qty { data["qty"] || 1 }
  src { data["src"] }

  getSpace() {
    var queue = [ origin ]
    var visited = Set.new()
    visited.add(origin)
    while (!queue.isEmpty) {
      var node = queue.removeAt(0)
      if (ctx.getEntitiesAtPosition(node).count == 0) {
        return node
      }
      for (next in ctx.zone.map.neighbours(node)) {
        if (!visited.contains(next)) {
          visited.add(next)
          queue.add(next)
        }
      }
    }
    return null
  }

  perform() {
    var level = ctx.zone
    var example = null
    if (qty < 1) {
      Fiber.abort("Must summon at least one entity")
    }
    for (i in 0...qty) {
      var position = getSpace()
      System.print(position)
      if (position == null) {
        Fiber.abort("There were no empty spaces on the whole map to summon in.")
      }
      var entity = CreatureFactory.spawn(id, level, position)
      if (!example) {
        example = entity
      }
      ctx.addEntity(entity)
    }
    addEvent(Components.events.summon.new(src, example, qty))
  }
}

#!component(id="push", group="effect")
class PushEffect is Effect {
  construct new(ctx, args) {
    super(ctx, args)
  }

  target { data["target"] }
  src { data["src"] }
  distance { data["distance"] }
  strong { data["strong"] || false }

  perform() {
    var origin = target.pos
    var d = (target.pos - src.pos)
    d.x = d.x.clamp(-1, 1)
    d.y = d.y.clamp(-1, 1)
    if (d.x == d.y && d.x == 0) {
      return
    }

    var current = target.pos
    if (!strong && ctx.zone.map[current]["water"]) {
      data["distance"] = 0
    }
    var finalDistance = 0
    for (i in 0...distance) {
      var next = current + d
      if (ctx.zone.map.neighbours(current).contains(next)) {
        target.pos = next
        // TODO: if the space is occupied already?
        // TODO: if hit a wall, stun? extra damage?
      } else {
        break
      }
      current = next
      finalDistance = i + 1
    }

    if (finalDistance > 0) {
      addEvent(Components.events.push.new(src, target))
      addEvent(Components.events.move.new(target, origin))
    }

    // TODO: this was pulled out of the loop and needs testing
    if (finalDistance < distance) {
      var damageEffect = Components.effects.damage.new(ctx, {
        "damage": Damage.new(((distance - finalDistance - 1) / 0.75).ceil.min(1), DamageType.kinetic),
        "target": target,
        "src": Environment.wall
      })
      damageEffect.perform()
      addEvents(damageEffect.events)
    }
  }
}

#!component(id="damage", group="effect")
class DamageEffect is Effect {
  construct new(ctx, args) {
    super(ctx, args)
  }

  damage { data["damage"] }
  target { data["target"] }
  src { data["src"] }

  perform() {
    var events = []
    if (damage) {
      events = CombatProcessor.calculate(src, target, damage)
    } else {
      events = CombatProcessor.calculate(src, target)
    }
    addEvents(events)
  }
}

#!component(id="meleeDamage", group="effect")
class MeleeDamageEffect is DamageEffect {
  construct new(ctx, args) {
    super(ctx, args)
  }
}

// Restores <target> for <amount> (percentage of their total)
#!component(id="restore", group="effect")
class RestoreEffect is Effect {
  construct new(ctx, args) {
    super(ctx, args)
  }

  amount { data["amount"] }
  target { data["target"] }

  perform() {
    var mpMax = target["stats"].get("mpMax")
    var total = (amount * mpMax).ceil
    var amount = target["stats"].increase("mp", total, "mpMax")
    addEvent(Components.events.recover.new(target, amount))
  }
}
// Heals <target> for <amount> (percentage of their total)
#!component(id="heal", group="effect")
class HealEffect is Effect {
  construct new(ctx, args) {
    super(ctx, args)
  }

  amount { data["amount"] }
  target { data["target"] }

  perform() {
    var hpMax = target["stats"].get("hpMax")
    var total = (amount * hpMax).ceil
    var amount = target["stats"].increase("hp", total, "hpMax")
    addEvent(Components.events.heal.new(target, amount))
  }
}

// Applies a stat modifier to <target>
#!component(id="applyTag", group="effect")
class ApplyTagEffect is Effect {
  construct new(ctx, args) {
    super(ctx, args)
  }

  src { data["src"] }
  target { data["target"] }
  field { data["field"] }
  modifier { data["modifier"] }

  perform() {
    var group = target[field]
    var mod = TagModifier.new(modifier["id"], modifier["duration"], modifier["add"], modifier["remove"])
    group.addModifier(mod)
    addEvent(Components.events.applyTag.new(src, target, modifier["id"]))
  }
}
// Applies a stat modifier to <target>
#!component(id="applyModifier", group="effect")
class ApplyModifierEffect is Effect {
  construct new(ctx, args) {
    super(ctx, args)
  }

  src { data["src"] }
  target { data["target"] }
  modifier { data["modifier"] }

  perform() {
    var stats = target["stats"]
    var mod = Modifier.new(modifier["id"], modifier["add"], modifier["mult"], modifier["duration"], modifier["positive"])
    stats.addModifier(mod)
    addEvent(Components.events.applyModifier.new(src, target, modifier["id"]))
  }
}
// Applies a condition to <target>
#!component(id="applyCondition", group="effect")
class ApplyConditionEffect is Effect {
  construct new(ctx, args) {
    super(ctx, args)
  }

  src { data["src"] }
  target { data["target"] }
  condition { data["condition"] }

  // inside condition
  curable { condition["curable"] }
  duration { condition["duration"] }
  refresh { condition["refresh"] }
  id { condition["id"] }

  perform() {
    if (target["conditions"].containsKey(id)) {
      if (refresh && target["conditions"][id].duration == duration) {
        return
      }
      target["conditions"][id].extend(duration)
      addEvent(Components.events.extendCondition.new(target, id))
    } else {
      target["conditions"][id] = Condition.new(id, duration, curable, refresh)
      addEvent(Components.events.inflictCondition.new(target, id))
    }
  }
}
// Applies a condition to <target>
#!component(id="blink", group="effect")
class BlinkEffect is Effect {
  construct new(ctx, args) {
    super(ctx, args)
  }

  target { data["target"] }

  perform() {
    var options = []
    var map = ctx.zone.map
    for (y in map.yRange) {
      for (x in map.xRange) {
        var pos = Vec.new(x, y)
        if (!map.isFloor(pos) || target.pos == pos || !ctx.getEntitiesAtPosition(pos).isEmpty) {
          continue
        }
        if (Line.chebychev(target.pos, pos) < 4) {
          continue
        }
        options.add(Vec.new(x, y))
      }
    }
    var origin = target.pos
    target.pos = RNG.sample(options)
    ctx.addEvent(Components.events.move.new(target, origin))
  }
}
