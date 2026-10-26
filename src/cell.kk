module cell

import iterator
import std/num/int32

// cell
pub type cell
  Solved(solution : int)
  Unsolved(candidates : list<int>)

pub fun cell/unsolved() : total cell 
  Unsolved(list(1, 9))

pub fun cell/solved(solution : int) : total cell 
  Solved(solution)

pub fun cell/remove-candidate(self : cell, candidate : int) : cell
  match self 
    Unsolved(candidates) -> Unsolved(candidates.remove fn(x) x == candidate)
    solution             -> solution

pub fun cell/add-candidate(self : cell, candidate : int) : cell
  match self
    Unsolved(candidates) -> Unsolved(Cons(candidate, candidates))
    Solved(solution)     -> Unsolved([solution, candidate])
