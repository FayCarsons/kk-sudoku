module pedagogy

import std/num/int32
import board

pub effect program-context<c>
  val ctxt : c

pub fun checkpoint/local<c, a, b>(current : c, action : () -> <program-context<c>|e> b) : e b
  with handler
    val ctxt = current
  action()

pub effect checkpoint<a>
  fun checkpoint(step : a) : ()

pub fun checkpoint/check(step : a) : checkpoint<a> ()
  checkpoint(step)

pub inline fun checkpoint/no-op(action : () -> <checkpoint<a>|e> b) : e b 
  with handler 
    fun checkpoint(step) ()
  action()

pub inline fun checkpoint/print(action : () -> <checkpoint<a>, exn, console|e> b, ?show : a -> exn string) : <console,exn|e> b
  with handler
    fun checkpoint(step) show(step).println
  action()

pub type step
  Removed(pos : position, candidate : int)
  Forced(pos : position, solution : int)
  Choose(pos : position, candidates : int32)
  Fail

pub value struct snapshot
  board : board
  step  : step

pub fun snapshot/removed(board : board, pos : position, candidate : int) : <checkpoint<snapshot>|e> () 
  Snapshot(board, Removed(pos, candidate)).check

pub fun snapshot/forced(board, pos, candidate) : checkpoint<snapshot> ()
  Snapshot(board, Forced(pos, candidate)).check

pub fun snapshot/choose(board, pos, cell) : checkpoint<snapshot> ()
  Snapshot(board, Choose(pos, cell)).check

pub fun snapshot/fail(board) : checkpoint<snapshot> ()
  Snapshot(board, Fail).check

pub inline fun checkpoint/animate(action : () -> <checkpoint<a>, div|e> b) : <div|e> b
  var queue := []
  with handler 
    fun checkpoint(step)
      queue := Cons(step, queue)
  action()
