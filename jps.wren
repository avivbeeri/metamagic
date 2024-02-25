import "math" for M, Vec
import "collections" for PriorityQueue, HashMap,Set
import "parcel" for TileMap, Zone, Line, TileMap8

/*

This is based on the work of Kevin Sheehan and Xueqiao Xu <xueqiaoxu@gmail.com>
Backtracking code and port to Wren is copyright to me, Aviv Beeri

Pathfinding.js: https://github.com/qiao/PathFinding.js
Java - Jump Point Search: https://github.com/qiao/PathFinding.js

The MIT License (MIT)

Copyright (c) 2023 Aviv Beeri, 2015 Kevin Sheehan, 2011-2012 Xeuqiao Xu

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

class JPS {
  construct new(zone, self) {
    _zone = zone
    _map = zone
    _self = self
    if (!(map is TileMap8) && !(map is Zone && map.map is TileMap8)) {
      Fiber.abort("JPS only works with TileMap8")
    }
    if (zone is TileMap) {
      _map = zone
    } else if (zone is Zone) {
      _map = zone.map
    }
    // Build an occupation map
    _zoneEntities = zone.ctx.entities()
    _occupation = HashMap.new()
    for (entity in _zoneEntities) {
      if (entity != self && entity["solid"]) {
        for (dy in 0...entity.size.y) {
          for (dx in 0...entity.size.x) {
            var v = Vec.new(dx, dy)
            _occupation[entity.pos + v] = true
          }
        }
      }
    }
  }
  map { _map }
  zone { _zone }
  self { _self }
  isFloor(x, y) {
    var occupied = _occupation[Vec.new(x, y)]
    return (_map.isFloor(x, y) && !occupied)
  }
  isFloor(v) { isFloor(v.x, v.y) }

  heuristic(a, b) {
    var cardinal = 5
    var diagonal = 7

    var dMinus = diagonal - cardinal
    var dx = (a.x - b.x).abs
    var dy = (a.y - b.y).abs
    if (dx > dy) {
      return cardinal * dx + dMinus * dy
    }
    return cardinal * dy + dMinus * dx
  }

  search(start, goal) {

    if (goal == null) {
      Fiber.abort("JPS doesn't work without a goals")
    }
    var goals = map.neighbours(goal)

    // Cost maps
    var fMap = HashMap.new()
    var gMap = HashMap.new()
    var hMap = HashMap.new()

    // visitation structures
    var open = PriorityQueue.min()
    var parentMap = HashMap.new()
    var closed = Set.new()

    if (start is Sequence) {
      Fiber.abort("JPS doesn't support multiple goals")
    }

    open.add(start, 0)
    parentMap[start] = null

    while (!open.isEmpty) {
      var node = open.remove()
      closed.add(node)
      if (goals.contains(node)) {
        parentMap[goal] = node
        return backtrace(start, goal, parentMap)
      }
      identifySuccessors(node, goal, goals, open, closed, parentMap, fMap, gMap, hMap)
    }
    return null
  }

  findNeighbours(node, parentMap) {
    var neighbours = Set.new()
    var parent = parentMap[node]
    if (parent != null) {
      var x = node.x
      var y = node.y
      var dx = M.mid(-1, x - parent.x, 1)
      var dy = M.mid(-1, y - parent.y, 1)
      if (dx != 0 && dy != 0) {
        if (isFloor(x, y + dy)) {
          neighbours.add(Vec.new(x, y + dy))
        }
        if (isFloor(x + dx, y)) {
          neighbours.add(Vec.new(x + dx, y))
        }
        if ((isFloor(x, y + dy) && isFloor(x + dx, y))) {
          neighbours.add(Vec.new(x + dx, y + dy))
        }
      } else {
        if (dx != 0) {
          var nextWalkable = isFloor(x + dx, y)
          var topWalkable = isFloor(x, y + 1)
          var bottomWalkable = isFloor(x, y - 1)
          if (nextWalkable) {
            neighbours.add(Vec.new(x + dx, y))
            if (topWalkable) {
              neighbours.add(Vec.new(x + dx, y + 1))
            }
            if (bottomWalkable) {
              neighbours.add(Vec.new(x + dx, y - 1))
            }
          }
          if (topWalkable) {
            neighbours.add(Vec.new(x, y + 1))
          }
          if (bottomWalkable) {
            neighbours.add(Vec.new(x, y - 1))
          }
        } else if (dy != 0) {
          var nextWalkable = isFloor(x, y + dy)
          var rightWalkable = isFloor(x + 1, y)
          var leftWalkable = isFloor(x - 1, y)
          if (nextWalkable) {
            neighbours.add(Vec.new(x, y + dy))
            if (rightWalkable) {
              neighbours.add(Vec.new(x + 1, y + dy))
            }
            if (leftWalkable) {
              neighbours.add(Vec.new(x - 1, y + dy))
            }
          }
          if (rightWalkable) {
            neighbours.add(Vec.new(x + 1, y))
          }
          if (leftWalkable) {
            neighbours.add(Vec.new(x - 1, y))
          }
        }
      }
    } else {
      for (next in map.neighbours(node)) {
        neighbours.add(next)
      }
    }

    return neighbours
  }

  identifySuccessors(node, goal, goals, open, closed, parentMap, fMap, gMap, hMap) {
    var neighbours = findNeighbours(node, parentMap)
    var d
    var ng
    for (neighbour in neighbours) {
      var jumpNode = jump(neighbour, node, goals)
      if (jumpNode == null || closed.contains(jumpNode)) {
        continue
      }
      d = Line.chebychev(jumpNode, node)
      ng = (gMap[node] || 0) + d
      if (!open.contains(jumpNode) || ng < (gMap[jumpNode] || 0)) {
        var g = ng
        var h = heuristic(jumpNode, goal)
        gMap[jumpNode] = g
        hMap[jumpNode] = h
        var f = g + h
        fMap[jumpNode] = f
        parentMap[jumpNode] = node
        if (!open.contains(jumpNode)) {
          open.add(jumpNode, f)
        }
      }
    }
  }

  jump(neighbour, current, goals) {
    if (neighbour == null || !isFloor(neighbour)) {
      return null
    }
    if (goals.contains(neighbour)) {
      return neighbour
    }

    var dx = neighbour.x - current.x
    var dy = neighbour.y - current.y

    if (dx != 0 && dy != 0) {
      if ((jump(Vec.new(neighbour.x + dx, neighbour.y), neighbour, goals) != null) ||
          (jump(Vec.new(neighbour.x, neighbour.y + dy), neighbour, goals) != null)) {
        return neighbour
      }
    } else {
      if (dx != 0) {
        if ((isFloor(neighbour.x, neighbour.y - 1) && !isFloor(neighbour.x - dx, neighbour.y - 1)) ||
           (isFloor(neighbour.x, neighbour.y + 1) && !isFloor(neighbour.x - dx, neighbour.y + 1))) {
          return neighbour
        }
      } else if (dy != 0) {
        if ((isFloor(neighbour.x - 1, neighbour.y) && !isFloor(neighbour.x - 1, neighbour.y - dy)) ||
           (isFloor(neighbour.x + 1, neighbour.y) && !isFloor(neighbour.x + 1, neighbour.y - dy))) {
          return neighbour
        }

      }
    }

    if (isFloor(neighbour.x + dx, neighbour.y) && isFloor(neighbour.x, neighbour.y + dy)) {
      return jump(Vec.new(neighbour.x + dx, neighbour.y + dy), neighbour, goals)
    } else {
      return null
    }
  }

  backtrace(start, goal, parentMap) {
    var current = goal
    if (!parentMap) {
      Fiber.abort("There is no valid path")
      return
    }
    if (parentMap[goal] == null) {
      return null // There is no valid path
    }

    var path = []
    var next = null
    while (start != current) {
      path.add(current)
      next = parentMap[current]
      if (next == null) {
        break
      }
      var dx = M.mid(-1, next.x - current.x, 1)
      var dy = M.mid(-1, next.y - current.y, 1)
      var unit = Vec.new(dx, dy)

      var intermediate = current
      while (intermediate != next && intermediate != start) {
        path.insert(0, intermediate)
        intermediate = intermediate + unit
      }
      current = next
    }
    path.insert(0, current)
    for (pos in path) {
      map[pos]["seen"] = true
    }
    return path
  }
}
