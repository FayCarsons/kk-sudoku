module board

import cell
import iterator

pub value struct position
  x : int
  y : int

pub fun position/(==)(^self : position, ^other : position) : total bool 
  self.x == other.x && self.y == other.y

val size : int = 9

pub alias board = vector<cell>

fun into-one-dim(x : int, y : int) : int 
  x + y * size

fun into-two-dim(idx : int) : (int, int)
  (idx % size, idx / size)

pub fun board/row(origin : position) : <iterator<position>, exn> ()
  for(0, 8) fn(col)
    if col != origin.x then 
      yield(Position(col, origin.y))

pub fun board/col(origin : position) : <iterator<position>, exn> ()
  for(0, 8) fn(row)
    if row != origin.y then 
      yield(Position(origin.x, row))

pub fun board/square(origin : position) : <iterator<position>, exn> ()
  val start-x = origin.x / 3 * 3
  val start-y = origin.y / 3 * 3
  for(0, 8) fn(i)
    val px = (start-x + i % 3)
    val py = (start-y + i / 3)
    if px != origin.x && py != origin.y then 
      yield(Position(px, py))

pub fun board/peers(^origin : position) : <iterator<position>, exn> ()
  row(origin)
  col(origin)
  square(origin)

pub fun board/all() : iterator<position> ()
  for(0, 8) fn(y)
    for(0, 8) fn(x)
      yield(Position(x, y))

pub fun board/get(^self : board, ^pos : position) : exn cell
  self[into-one-dim(pos.x,pos.y)]

pub fun board/assign(self : board, ^pos : position, ^f : cell -> cell) : exn board
  var local := self
  val idx = into-one-dim(pos.x, pos.y)
  local[idx] := f(self[idx])
  local

pub fun board/parse(chars : vector<char>) : exn board
  chars.map fn(char)
    if char.is-digit then
      val digit = int(char) - int('0')
      if digit == 0 then 
        unsolved()
      else 
        solved(digit)
    else 
      if char == '.' then 
        unsolved()
      else
        throw("Unexpected char '" ++ char.string ++ "'")


// Print the board as a grid with box borders. Unsolved cells show as `·`.
pub fun board/show(self : board) : exn string
  fun symbol(x : int, y : int) : exn string
    val cell = self.get(Position(x, y))
    if cell.is-solved then 
      cell.first.show 
    else 
      "."

  fun row(y : int) : exn string
    val boxes = list(0, 8, 3).map fn(x0) list(x0, x0 + 2).map(fn(x) symbol(x, y)).join(" ")
    "│ " ++ boxes.join(" │ ") ++ " │"

  fun border(left : string, mid : string, right : string) : string
    left ++ "─".repeat(7).replicate(3).join(mid) ++ right

  val bands = list(0, 8, 3).map fn(y0) list(y0, y0 + 2).map(row).unlines
  border("┌", "┬", "┐") 
    ++ "\n" 
    ++ bands.join("\n" ++ border("├", "┼", "┤") ++ "\n")
    ++ "\n"
    ++ border("└", "┴", "┘")
    ++ "\n"
