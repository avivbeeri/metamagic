import "parcel" for BehaviourEntity, DIR_EIGHT, RNG, Action, Dijkstra, DataFile
import "math" for M

var PlayerData = DataFile.load("playerData", "data/player.json")

class Creature is BehaviourEntity {
  construct new(stats) {
    super()
    this["symbol"] = "?"
    this["solid"] = true
    this["resistances"] = TagGroup.new([])
    this["vulnerabilities"] = TagGroup.new([])
    this["immunities"] = TagGroup.new([])
    this["stats"] =  StatGroup.new({
      "hpMax": 1,
      "hp": 1,
      "mpHidden": 5,
      "mp": 5,
      "mpMax": 5,
      "spd": 1,
      "atk": 1,
      "def": 1,
      "str": 1,
      "dex": 1,
      "xp": 0
    }) {|stats, stat, value|
      if (stat == "str") {
        stats.set("atk", value)
      }
      if (stat == "dex") {
        stats.set("def", value)
      }
    }
    this["conditions"] = {}

    this["inventory"] = [
    ]
    this["equipment"] = {}
    for (entry in stats) {
      this["stats"].set(entry.key, entry.value)
    }
    this["pronoun"] = Pronoun.it
  }
  pronoun { this["pronoun"] }
  speed { 1 / this["stats"]["spd"] }
}

class Player is Creature {
  construct new() {
    super(PlayerData["stats"])
    this["symbol"] = "@"
    this["equipment"] = PlayerData["equipment"]
    this["inventory"] = []
    for (entry in PlayerData["inventory"]) {
      this["inventory"].add(InventoryEntry.new(entry[0], entry[1]))
    }
    this["proficiency"] = {}
  }

  name { data["name"] || "Player" }
  pronoun { Pronoun.you }
  pushAction(action) {
    if (hasActions()) {
      return
    }
    super.pushAction(action)
  }
  getAction() {
    var action = super.getAction()
    if (action == Action.none) {
      return null
    }
    return action
  }
  endTurn() {
    data["map"] = Dijkstra.map(ctx.zone.map, pos)
  }
}

import "items" for InventoryEntry, EquipmentSlot
import "combat" for StatGroup, Condition, TagGroup
import "messages" for Pronoun
