// Which tier am I in? (beginner, middle, endgame)
// Items
//

var TierMap = {
  0 :1,
  1: 1,
  2: 1,
  3: 2,
  4: 2,
  5: 3,
  6:3
}

var Distribution = [
  {
    "items": [
      ["shortsword", 0.1],
      ["potion", 0.2],
      ["wand", 0.3],
      ["scroll", 0.4]
    ],
    "enemies": [
      ["rat", 0.4],
      ["zombie", 0.3],
      ["hound", 0.1]
    ]
  },
  {
    "items": [
      ["fireball", 0.1],
      ["chainmail", 0.2],
      ["longsword", 0.2],
      ["scroll", 0.3],
      ["potion", 0.2]
    ],
    "enemies": [
      ["rat", 0.2],
      ["zombie", 0.5],
      ["hound", 0.2]
    ]
  },
  {
    "items": [
      ["longsword", 0.05],
      ["potion", 0.1],
      ["platemail", 0.1],
      ["fireball", 0.1],
      ["wand", 0.2],
      ["scroll", 0.2]
    ],
    "enemies": [
      ["rat", 0.1],
      ["hound", 0.8]
    ]
  }
]

var ratData = {
  "kind": "rat",
  "name": "Rat",
  "symbol": "r",
  "behaviours": [
    ["wander"]
  ],
  "stats": {
    "hpMax": 1,
    "hp": 1
  },
  "pronoun": "it"
}
var houndData = {
  "kind": "hound",
  "name": "Hound",
  "symbol": "d",
  "behaviours": [
    ["seek", 7]
  ],
  "stats": {
    "hpMax": 4,
    "hp": 4,
    "dex": 2,
    "atk": 2
  },
  "pronoun": "it"
}
var zombieData = {
  "kind": "zombie",
  "name": "Zombie",
  "symbol": "z",
  "behaviours": [
    ["localSeek", 7]
  ],
  "stats": {
    "hpMax": 2,
    "hp": 2,
    "spd": 0.5,
    "dex": 1,
    "atk": 3
  },
  "pronoun": "it"
}
var statueData = {
  "kind": "statue",
  "name": "Statue",
  "symbol": "£",
  "behaviours": [
    ["statue"]
  ],
  "stats": {
    "def": 10, // make this absurdly high
  },
  "pronoun": "it"
}
var gargoyleData = {
  "kind": "gargoyle",
  "name": "Statue",
  "symbol": "?",
  "behaviours": [
    ["statue"]
  ],
  "stats": {
    "hpMax": 5,
    "hp": 5,
    "dex": 4,
    "str": 3
  },
  "butter": true,
  "pronoun": "it",
  "frozen": true
}
var demonData = {
  "kind": "demon",
  "boss": true,
  "name": "????",
  "symbol": "?",
  "behaviours": [
    ["boss"]
  ],
  "conditions": [
    ["invulnerable", null, null]
  ],
  "stats": {
    "hpMax": 5,
    "hp": 5,
    "dex": 3,
    "str": 3
  },
  "size": [3, 3],
  "butter": true,
  "pronoun": "they"
}

var CreatureData = {
  "rat": ratData,
  "hound": houndData,
  "demon": demonData,
  "gargoyle": gargoyleData,
  "statue": statueData,
  "zombie": zombieData
}
