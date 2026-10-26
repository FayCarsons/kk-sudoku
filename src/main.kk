module main

import std/os/file
import std/os/path
import std/num/int32
import cell
import board
import iterator

fun todo() : exn a
  throw("TODO")

effect choice
  ctl choose(candidates : list<int>) : int

fun iter<item, e>(iterator : () -> <iterator<item>|e> (), ^f : item -> e ()) : e ()
  with fun yield(item) f(item)
  iterator()

fun list/find-map(^xs: list<a>, ^f : a -> e maybe<b>) : e maybe<b>
  match xs 
    Cons(x, xs) ->
      match f(x)
        Just(x') -> Just(x')
        Nothing -> xs.find-map(f)
    Nil         -> Nothing

fun run-choice(action : () -> <choice|e> a) : e maybe<a>
  with handler 
    return(x) Just(x) 
    ctl choose(candidates) 
      candidates.find-map(resume)
  action()
   
fun fail() 
  choose([])

fun eliminate(self : board, pos, solution) : exn board
  var board := self
  iter({ board/peers(pos) }) fn(peer-pos)
    board := board.assign(peer-pos) fn(cell)
      cell.remove-candidate(solution)

  board

fun constrain(self : board) : exn board
  var board := self
  iter(board/all) fn(pos)
    val cell = board.get(pos)

    match cell 
      Solved(solution)     -> board := eliminate(board, pos, solution)
      _                          -> ()

  board

fun search(self : board) : <choice, exn> board
  var board := self
  iter(board/all) fn(pos)
    val cell = board.get(pos)

    match cell 
      Unsolved([]) -> fail().ignore
      Unsolved(candidates) -> 
        val solution = choose(candidates)
        board := board.assign(pos, const(Solved(solution))).eliminate(pos, solution)
      _ -> ()

  board

fun solve(self : board) : <choice, exn|e> board
  self.constrain.search

fun main()
  val boards = 
    read-text-file(cwd() / "easy50.txt")
      .lines
      .filter fn(line : string)
        !line.string/is-empty
      .list/vector
      .vector/map fn(line : string) board/parse(line.vector)

  match run-choice({solve(boards[0])})
    Just(solution) -> solution.print 
    Nothing                      -> throw("no solution")

