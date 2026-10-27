module cell

import iterator
import std/num/int32

// cell is a 9bit mask: bit `d` is set while digit `d` (1 to 9) is possible
pub value struct cell
  inner : int32

// A cell with bits 1 to 9 set to 1
pub fun cell/unsolved() : total cell
  Cell(i32(0x3FE))

// A cell with no candidates left
pub fun cell/empty() : total cell
  Cell(i32(0))

// A cell with only the solution set to 1
pub fun cell/solved(solution : int) : total cell
  Cell(1.i32.shl(solution))

pub fun cell/is-solved(self : cell) : bool 
  self.count == 1

pub fun cell/has(self : cell, candidate : int) : bool
  self.inner.shr(candidate).and(1.i32).bool

pub fun cell/remove-candidate(self : cell, candidate : int) : cell
  // negated mask `cell & ~(1 << candidate)`
  val bit-mask = 1.i32.shl(candidate).not
  Cell(self.inner.and(bit-mask))

pub fun cell/count(self : cell) : int
  self.inner.popcount

// The lowest candidate; for a solved cell, its solution
pub fun cell/first(self : cell) : int
  self.inner.ctz

// Call `f` on each candidate, lowest first, until it returns `Just`
pub fun cell/find-map(self : cell, ^f : int -> e maybe<a>) : e maybe<a>
  for-while(1, 9) fn(candidate)
    if self.has(candidate) then 
      f(candidate) 
    else 
      Nothing

pub fun cell/candidates(self : cell) : iterator<int> ()
  for(1, 9) fn(candidate)
    if self.has(candidate) then 
      yield(candidate)
