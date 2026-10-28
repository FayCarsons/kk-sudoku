module main

import std/os/env
import std/os/file
import std/os/flags
import std/os/path
import std/core/unsafe
import cell
import board
import iterator
import pedagogy/trace
import pedagogy/replay

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
        0 -> 
          snapshot/fail(board, peer-pos)
          fail().ignore
        1 ->
          snapshot/forced(board, peer-pos, rest.first)
          board := board.place(peer-pos, rest.first)
        _ -> board := board.assign(peer-pos, const(rest))

  board

fun constrain(self : board) : <choice, div, exn, checkpoint<snapshot>, console> board
  var board := self
  iter(board/all) fn(pos)
    val cell = self.get(pos)
    if cell.count == 1 then
      snapshot/removed(board, pos, cell.first)
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
        snapshot/choose(self, pos, self.get(pos))
        val solution = choose(self.get(pos))
        snapshot/try(self, pos, solution)
        search(self.place(pos, solution))

fun solve(self : board) : <choice, exn, checkpoint<snapshot>, div, console|e> board
  // with unsafe-total
  search(constrain(self))

// OPTIONS

struct options
  // The board to replay step by step, counted from 1
  lesson : maybe<string> = Nothing

val option-flags : list<flag<options>> =
  [Flag("l", ["lesson"], Opt(set-lesson, "BOARD"), "replay the solve of BOARD (default 1) step by step")]

fun set-lesson(options : options, board : maybe<string>) : options
  options(lesson = Just(board.default("1")))

// The board numbered `number`, counted from 1
fun pick(boards : vector<board>, number : string) : exn board
  match number.parse-int
    Just(n) | n >= 1 && n <= boards.length -> boards[n - 1]
    _ -> throw("no board " ++ number ++ "; pick 1 to " ++ boards.length.show)

fun main()
  val (options, _, errors) = parse(Options(), option-flags, get-args())
  if !errors.is-nil then
    println(errors.join("\n") ++ "\n" ++ option-flags.usage)
  else
    val boards =
      read-text-file(cwd() / "puzzles" / "easy50.txt")
        .lines
        .filter fn(line : string)
          !line.string/is-empty
        .list/vector
        .vector/map fn(line : string) board/parse(line.vector)

    match options.lesson
      Nothing ->
        with fun checkpoint(step) step.ignore
        boards.foreach-indexed fn(idx, board)
          match run-choice({ board.solve })
            Just(solution) -> solution.print
            Nothing                      -> throw("no solution for board " ++ idx.show)
      Just(number) ->
        val board = boards.pick(number)
        with animate
        match run-choice({board.solve})
          Just(_) -> ()
          Nothing -> throw("No solution for board " ++ number.show)

