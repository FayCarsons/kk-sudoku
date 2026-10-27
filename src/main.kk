module main

import std/os/file
import std/os/path
import cell
import board
import iterator
import pedagogy

fun todo() : exn a
  throw("TODO")

// CHOICE

effect choice
  ctl choose(candidates : cell) : int

fun run-choice(^action : () -> <choice|e> a) : e maybe<a>
  with handler
    return(x) Just(x)
    ctl choose(candidates)
      candidates.find-map(resume)
  action()

fun fail()
  choose(empty())

alias lesson = checkpoint<step>

fun place(self : board, ^pos : position, ^solution : int) : <div, exn, checkpoint<snapshot>, console, choice> board 
  self.assign(pos, const(solved(solution))).eliminate(pos, solution)

// Remove `solution` from every peer of `pos` that still has it, then check what is left in that peer.
fun eliminate(self : board, ^pos : position, ^solution : int) : <choice, div, exn, checkpoint<snapshot>, console> board
  var board := self

  iter({ board/peers(pos) }) fn(peer-pos)
    val cell = board.get(peer-pos)
    if cell.has(solution) then
      val rest = cell.remove-candidate(solution)
      match rest.count
        0 -> fail().ignore
        1 ->
          forced(board, peer-pos, rest.first)
          board := board.place(peer-pos, rest.first)
        _ -> board := board.assign(peer-pos, const(rest))

  board

fun constrain(self : board) : <choice, div, exn, checkpoint<snapshot>, console> board
  var board := self
  iter(board/all) fn(pos)
    val cell = self.get(pos)
    if cell.count == 1 then
      removed(board, pos, cell.first)
      board := board.eliminate(pos, cell.first)

  board

// The unsolved cell with the fewest candidates, or `Nothing` when every cell is solved.
fun most-constrained(self : board) : exn maybe<position>
  var best := Nothing
  var best-count := 10
  handle(board/all)
    return(_) best
    ctl yield(pos)
      val count = self.get(pos).count
      if count == 2 then Just(pos)
      else
        if count > 2 && count < best-count then
          best := Just(pos)
          best-count := count
        resume(())

fun search(self : board) : <choice, div, exn, checkpoint<snapshot>, console> board
  match self.most-constrained
      Nothing   -> self
      Just(pos) ->
        val solution = choose(self.get(pos))
        search(self.place(pos, solution))

fun solve(self : board) : <choice, exn, checkpoint<snapshot>, div, console|e> board
  search(constrain(self))

fun main()
  with fun checkpoint(step) step.ignore

  val boards = 
    read-text-file(cwd() / "top95.txt")
      .lines
      .filter fn(line : string)
        !line.string/is-empty
      .list/vector
      .vector/map fn(line : string) board/parse(line.vector)

  boards.foreach-indexed fn(idx, board)
    match run-choice({ board.solve })
      Just(solution) -> solution.print 
      Nothing                      -> throw("no solution for board " ++ idx.show)

