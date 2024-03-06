import "collections" for Set
import "math" for M
import "parcel" for Action, ActionResult, Event, Stateful, RNG

// Fake combat source
class Environment {
  construct new(name) {
    _name = name
  }
  has(field) { false }
  name { _name }
  static ice { Environment.new("ice") }
  static fire { Environment.new("fire") }
  static wall { Environment.new("wall") }
}


class Damage is Stateful {
  static calculateLow(atk, def) {
    var o1 = atk * 2 - def
    var o2 = (atk * atk) / def
    if (atk > def) {
      return o1.floor
    }
    if (!o2.isNan) {
      return o2.floor
    }
    return 0
  }
  static calculateHigh(atk, def) {
    var o1 = atk * 2 - def
    var o2 = (atk * atk) / def
    if (atk > def) {
      return o1.ceil
    }
    if (!o2.isNan) {
      return o2.ceil
    }
    return 0
  }

  static calculate(atk, def) {
    var low = calculateLow(atk, def)
    var high = calculateHigh(atk, def)
    return RNG.float() < 0.3 ? low : high
  }

  construct new(amount, type) {
    super()
    this["amount"] = amount
    this["type"]  = type
  }

  amount { this["amount"] || 0 }
  type { this["type"] || DamageType.kinetic }
  toString { "%(amount) %(type) damage" }
}

class AttackResult {
  static success { "success" } // Hit and did damage
  static overkill { "overkill" } // Hit and did excessive damage
  static blocked { "blocked" } // hit but did no damage, high defend
  static missed { "missed" } // didn't hit
  static inert { "inert" } // couldn't hit (attack capability reduced to zero)
  static invulnerable { "invulnerable" } // special blocked, it's invulnerable
}

class DamageType {
  static kinetic { "KINETIC" } // Punches, bludgeoning
  static energy { "ENERGY" }
  static fire { "FIRE" } // Fire that burns
  static ice { "ICE" }
  static poison { "POISON" }
}


class BaseModifier is Stateful {
  construct new(id, duration, args) {
    super()
    data["id"] = id
    data["duration"] = duration || null
    assign(args)
  }

  id { data["id"] }
  duration=(v) { data["duration"] = v }
  duration { data["duration"] }

  done { duration && duration <= 0 }
  tick() {
    duration = duration ? duration - 1 : null
  }

  extend(n) {
    if (duration != null) {
      duration = (duration || 0) + n
    }
  }
}
class TagModifier is BaseModifier {
  construct new(id, duration, add, remove) {
    super(id, duration, {
      "add": add || [],
      "remove": remove || []
    })
  }

  add { data["add"] }
  remove { data["remove"] }
}

class TagGroup {
  construct new() {
    init_([])
  }
  construct new(tags) {
    init_(tags)
  }
  init_(tags) {
    _base = Set.new()
    _mods = {}
    _base.addAll(tags)
  }

  contains(value) { tags.contains(value) }

  tags {
    var result = Set.new()
    result.addAll(_base)

    for (modifier in modifiers) {
      if (modifier.done) {
        continue
      }
      for (item in modifier.add) {
        result.add(item)
      }
    }
    for (modifier in modifiers) {
      if (modifier.done) {
        continue
      }
      for (item in modifier.remove) {
        result.remove(item)
      }
    }
    return result.toList
  }

  modifiers { _mods.values }

  addAll(tags) {
    _base.addAll(tags)
  }
  add(tag) {
    _base.add(tag)
  }

  remove(tag) {
    _base.remove(tag)
  }

  addModifier(mod) {
    _mods[mod.id] = mod
  }

  removeModifier(id) {
    _mods.remove(id)
  }
  getModifier(id) {
    return _mods[id]
  }
}

class StatGroup {
  construct new(statMap, onChange) {
    _base = statMap
    _mods = {}
    _onChange = onChange
    for (entry in statMap) {
      set(entry.key, entry.value)
    }
  }
  construct new(statMap) {
    _base = statMap
    _mods = {}
    _onChange = null
    for (entry in statMap) {
      set(entry.key, entry.value)
    }
  }

  modifiers { _mods.values }

  addModifier(mod) {
    _mods[mod.id] = mod
  }
  hasModifier(id) {
    return _mods.containsKey(id)
  }
  getModifier(id) {
    return _mods[id]
  }
  removeModifier(id) {
    _mods.remove(id)
  }

  base(stat) { _base[stat] }
  onChange=(v) { _onChange = v }

  set(stat, value) {
    _base[stat] = value
    if (_onChange) {
      _onChange.call(this, stat, value)
    }
  }
  decrease(stat, by) {
    set(stat, _base[stat] - by)
    return by
  }
  increase(stat, by) {
    set(stat, _base[stat] + by)
    return by
  }
  increase(stat, by, maxStat) {
    var amount = by.min(_base[maxStat] - _base[stat])
    set(stat, M.mid(0, _base[stat] + amount, _base[maxStat]))
    return amount
  }

  has(stat) { _base[stat] }
  [stat] { get(stat) }
  get(stat) {
    var value = _base[stat]
    if (value == null) {
      Fiber.abort("Stat %(stat) does not exist")
    }
    var multiplier = 0
    var total = value || 0
    for (mod in _mods.values) {
      total = total + (mod.add[stat] || 0)
      multiplier = multiplier + (mod.mult[stat] || 0)
    }
    return M.max(0, total + total * multiplier)
  }

  toString {
    var s = "Stats { "
    for (stat in _base) {
      s = s + print(stat.key) + ", "
    }
    s = s + "}"
    return s
  }
  print(stat) {
    return "\"%(stat)\": %(get(stat)) (%(base(stat)))"
  }
}

/**
  Represent a condition
 */

class Condition is Stateful {
  construct new(id, duration, curable, refresh) {
    super()
    data["id"] = id
    data["duration"] = duration
    data["curable"] = curable
    data["refresh"] = refresh
  }

  id { data["id"] }
  duration { data["duration"] }
  duration=(v) { data["duration"] = v }
  curable { data["curable"] }
  refresh { data["refresh"] || false }

  tick() {
    duration = duration ? duration - 1 : null
  }
  done { duration && duration <= 0 }
  hash() { id }

  cure() {
    if (curable) {
      duration = 0
    }
  }

  extend(n) {
    if (duration != null) {
      if (refresh) {
        duration = n
      } else {
        duration = (duration  || 0) + n
      }
    }
  }
}

/**
  Represent arbitrary modifiers to multiple stats at once
  Modifiers can be additive or multiplicative.
  Multipliers are a "percentage change", so +0.5 adds 50% of base to the value.
*/
class Modifier {
  construct add(id, add, duration, positive) {
    init_(id, add, null, duration, positive)
  }
  construct add(id, add, positive) {
    init_(id, add, null, null, positive)
  }

  construct new(id, add, mult, duration, positive) {
    init_(id, add, mult, duration, positive)
  }

  init_(id, add, mult, duration, positive) {
    _id = id
    _add = add || {}
    _mult = mult || {}
    _duration = duration || null
    _positive = positive || false
  }

  id { _id }
  add { _add }
  mult { _mult }
  duration { _duration }
  positive { _positive }

  tick() {
    _duration = _duration ? _duration - 1 : null
  }
  done { _duration && _duration <= 0 }

  extend(n) {
    if (_duration != null) {
      _duration = (_duration  || 0) + n
    }
  }
}


class CombatProcessor {

  static calculate(src, target) { calculate(src, target, Damage.new(src["stats"].get("atk"), DamageType.kinetic)) }
  static calculate(src, target, incoming) {
    var ctx = target.ctx
    var result = AttackResult.success
    if (target["conditions"].containsKey("invulnerable") || (target.has("immunities") && target["immunities"].contains(incoming.type))) {
      ctx.addEvent(Components.events.attack.new(src, target, "area", AttackResult.invulnerable, 0))
      return [false, false, 0]
    }

    var targetStats = target["stats"]
    var def = targetStats.get("def")

    var damage = Damage.calculate(incoming.amount, def)
    if (damage == 0) {
      result = AttackResult.blocked
    }
    if (target.has("vulnerabilities")) {
      if (target["vulnerabilities"].contains(incoming.type)) {
        damage = damage * 2
        System.print("vulnerable")
      }
    }
    if (target.has("resistances")) {
      if (target["resistances"].contains(incoming.type)) {
        damage = (damage / 2).floor.max(1)
      }
    }

    ctx.addEvent(Components.events.attack.new(src, target, "area", result, Damage.new(damage, incoming.type)))
    target["stats"].decrease("hp", damage)
    if (target["stats"].get("hp") <= 0) {
      ctx.zone.map[target.pos]["blood"] = true
      ctx.addEvent(Components.events.kill.new(src, target))
      ctx.removeEntity(target)
    }
  }
}

import "groups" for Components
