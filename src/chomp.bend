object Field { width, height, cells }

type Cell:
  Point { x, y, a }
  Leaf

def fullField(width, height):
  bend y = 0:
    when y < height:
      bend x = 0:
        when x < width:
          cells = ![!Cell/Point{x: x, y: y, a: 1}, fork(x+1)]
        else:
          cells = fork(y+1)

    else:
      cells = !Cell/Leaf

  return Field{width: width, height: height, cells: cells}

def eatPoint(xe: u24, ye: u24, x: u24, y: u24, alive: u24):
  if x >= xe:
    if y >= ye:
      return 0
    else:
      return alive
  else:
    return alive

def eat(tree, xe, ye):
  fold tree:
    case Tree/Node:
      return ![tree.left, tree.right]
    case Tree/Leaf:
      match tree.value:
        case Cell/Point:
          alive = eatPoint(xe, ye, tree.value.x, tree.value.y, tree.value.a)
          return !Cell/Point{x: tree.value.x, y: tree.value.y, a: alive}
        case Cell/Leaf:
          return !Cell/Leaf

def main():
  field = fullField(10, 10)
  open Field: field

  return eat(field.cells, 1, 1)
