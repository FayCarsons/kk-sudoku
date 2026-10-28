module pedagogy

import std/num/int32
import board
import cell
import terminal

// A reader effect, to hold state for the snapshot handler
pub effect program-context<c>
  val ctxt : c

pub fun checkpoint/local<c, a, b>(current : c, action : () -> <program-context<c>|e> b) : e b
  handle(action)
    val ctxt = current

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
  Choose(pos : position, candidates : cell)
  Try(pos : position, candidate : int)
  Fail(pos : position)

pub value struct snapshot
  board : board
  step  : step

pub fun snapshot/removed(board : board, pos : position, candidate : int) : <checkpoint<snapshot>|e> ()
  Snapshot(board, Removed(pos, candidate)).check

pub fun snapshot/forced(board, pos, candidate) : checkpoint<snapshot> ()
  Snapshot(board, Forced(pos, candidate)).check

pub fun snapshot/choose(board, pos, cell) : checkpoint<snapshot> ()
  Snapshot(board, Choose(pos, cell)).check

pub fun snapshot/try(board, pos, candidate) : checkpoint<snapshot> ()
  Snapshot(board, Try(pos, candidate)).check

pub fun snapshot/fail(board, pos) : checkpoint<snapshot> ()
  Snapshot(board, Fail(pos)).check

// ANIMATION

// Record the snapshots of `action`, then replay them; put this outside the `choose` handler to keep abandoned branches
pub inline fun snapshot/animate(action : () -> <checkpoint<snapshot>, console, exn, div|e> b) : <console, exn, div|e> b
  var recorded := []
  val result = handle(action)
    fun checkpoint(snapshot) recorded := Cons(snapshot, recorded)
  val trace = recorded.reverse.vector
  match trace.at(0)
    Just(first) ->
      val paths = trace.search-paths
      val depth = paths.list.map(fn(path) path.length).maximum
      val recording = Recording(trace, first.board, paths, depth)
      screen/live { recording.play(Player(0, True, normal-speed)) }
    Nothing -> ()
  result

// A finished solve; `givens` is the starting board, `paths` the search path after each step, `depth` the longest path
struct recording
  trace : vector<snapshot>
  givens : board
  paths : vector<list<guess>>
  depth : int

// Where the replay is, whether it advances by itself, and an index into `speeds`
value struct player
  index : int
  playing : bool
  speed : int

// Speed settings, slowest first: the label shown, and the delay as a percentage of normal
val speeds : vector<(string, int)> = [("0.25x", 400), ("0.5x", 200), ("1x", 100), ("2x", 50), ("4x", 25), ("10x", 10)].vector
val normal-speed = 2

fun recording/play(self : recording, player : player) : <screen, exn, div> ()
  draw(self.frame(player))
  if !interactive then
    if player.index < self.last then self.play(player(index = player.index + 1))
  else
    val timeout = if player.playing then self.delay(player) else -1
    match wait-key(timeout)
      Nothing -> self.play(self.advance(player))
      Just(Right) -> self.play(self.seek(player, player.index + 1))
      Just(Left) -> self.play(self.seek(player, player.index - 1))
      Just(Char(' ')) ->
        // Resuming at the end starts over
        if !player.playing && player.index == self.last then self.play(Player(0, True, player.speed))
        else self.play(player(playing = !player.playing))
      Just(Char('+')) -> self.play(player(speed = min(player.speed + 1, speeds.length - 1)))
      Just(Char('-')) -> self.play(player(speed = max(player.speed - 1, 0)))
      Just(Char('q')) -> ()
      Just(Escape) -> ()
      Just(Interrupt) -> ()
      Just(_) -> self.play(player)

fun recording/last(self : recording) : int
  self.trace.length - 1

fun recording/advance(self : recording, player : player) : player
  if player.index < self.last then player(index = player.index + 1) else player(playing = False)

// Jump to step `index`, clamped to the recording, and pause
fun recording/seek(self : recording, player : player, index : int) : player
  player(index = max(0, min(index, self.last)), playing = False)

fun recording/delay(self : recording, player : player) : exn int
  self.trace[player.index].step.base-delay * speeds[player.speed].snd / 100

// SEARCH PATH

// A choice point on the search path: the cell, its candidates, and each candidate tried so far with its step, latest first
value struct guess
  pos : position
  candidates : cell
  tried : list<(int, int)>

// The search path after each step of `trace`, deepest guess first
fun search-paths(trace : vector<snapshot>) : vector<list<guess>>
  var path : list<guess> := []
  var paths : list<list<guess>> := []
  trace.foreach-indexed fn(idx, snapshot)
    path := path.after(snapshot.step, idx)
    paths := Cons(path, paths)
  paths.reverse.vector

// The search path once `step`, the step at `idx`, has happened
fun path/after(path : list<guess>, step : step, idx : int) : list<guess>
  match step
    Choose(pos, candidates) -> Cons(Guess(pos, candidates, []), path)
    Try(at, candidate) ->
      // Retrying a guess drops every guess made after it
      val retried = path.drop-while(fn(guess) !(guess.pos == at))
      match retried
        Cons(guess, outer) -> Cons(guess(tried = Cons((candidate, idx), guess.tried)), outer)
        Nil -> path
    _ -> path

// LOG

// One line of the log: a step, or the steps that followed a guess that later failed
type entry
  Happened(idx : int)
  Abandoned(pos : position, candidate : int, steps : int)

// The last `count` lines of the log at step `idx`, newest first; retrying a guess folds the steps it abandoned into one line
fun recording/log(self : recording, idx : int, count : int) : <div, exn> list<entry>
  if idx < 0 || count <= 0 then []
  else
    val rest = match self.trace[idx].step
      Try(pos, _) -> self.fold-tries(pos, self.earlier-tries(idx, pos), idx, count - 1)
      _ -> self.log(idx - 1, count - 1)
    Cons(Happened(idx), rest)

// One line for each earlier try at `pos`, latest first, then the log from before the first try
fun recording/fold-tries(self : recording, pos : position, tries : list<(int, int)>, ended : int, count : int) : <div, exn> list<entry>
  match tries
    Cons((candidate, start), earlier) | count > 0 ->
      Cons(Abandoned(pos, candidate, ended - start), self.fold-tries(pos, earlier, start, count - 1))
    _ -> self.log(ended - 1, count)

// The candidates tried at `at` before step `idx`, latest first, with the step that tried each
fun recording/earlier-tries(self : recording, idx : int, at : position) : exn list<(int, int)>
  match self.paths[idx].find(fn(guess) guess.pos == at)
    Just(guess) -> guess.tried.drop(1)
    Nothing -> []

// COLORS

// Gruvbox's dark palette, as the nearest entries of the 256-color palette
val gruvbox/dark0 = palette(235)
val gruvbox/dark1 = palette(237)
val gruvbox/dark3 = palette(241)
val gruvbox/gray = palette(245)
val gruvbox/red = palette(167)
val gruvbox/green = palette(142)
val gruvbox/yellow = palette(214)
val gruvbox/blue = palette(109)
val gruvbox/purple = palette(175)
val gruvbox/aqua = palette(108)

val heading = plain.fg(gruvbox/gray).bold

// The text color of a log line `age` steps old; older lines are darker
fun fade(age : int) : color
  palette(max(240, 251 - age))

// FRAMES

val board-height = 19
val panel-col = 41
val frame-width = 80
val frame-height = 22

// The most rows the search path takes; a deeper path shows only its deepest guesses
val max-path-rows = 7

val positions : list<position> = list(0, 80).map(fn(i) Position(i % 9, i / 9))

fun recording/frame(self : recording, player : player) : <div, exn> canvas
  val snapshot = self.trace[player.index]
  val path = self.paths[player.index]
  canvas/blank(frame-width, frame-height)
    .draw-board(snapshot, self.givens, path)
    .draw-path(path, self.depth)
    .draw-log(self, player.index, path-rows(self.depth) + 2)
    .draw-footer(self, player)

// How many rows the search path takes in a solve whose longest path holds `depth` guesses
fun path-rows(depth : int) : int
  min(max(depth, 1), max-path-rows)

// The grid with every digit, the focused cell filled in, and the cells outside its row, column and box dimmed
fun canvas/draw-board(self : canvas, snapshot : snapshot, givens : board, path : list<guess>) : exn canvas
  val grid = list(0, board-height - 1).foldl(self) fn(canvas, row)
    canvas.text(row, 0, grid-line(row), plain.fg(gruvbox/dark3))
  positions.foldl(grid) fn(canvas, at)
    val (symbol, style) = cell-look(snapshot, givens, path, at)
    canvas.text(2 * at.y + 1, 4 * at.x + 1, " " ++ symbol ++ " ", style)

// The symbol shown in the cell at `at`, and its style; guessed cells on the search path are yellow
fun cell-look(snapshot : snapshot, givens : board, path : list<guess>, at : position) : exn (string, style)
  val step = snapshot.step
  if at == step.pos then (step.symbol, plain.fg(gruvbox/dark0).bg(gruvbox/green).bold)
  else
    val cell = snapshot.board.get(at)
    val symbol = if cell.is-solved then cell.first.show else "·"
    val style =
      if givens.get(at).is-solved then plain.bold
      else if !cell.is-solved then plain.fg(gruvbox/dark3)
      else if path.any(fn(guess) guess.pos == at) then plain.fg(gruvbox/yellow).bold
      else plain.fg(gruvbox/aqua)
    (symbol, if at.sees(step.pos) then style else style.dim)

// Row `row` of the empty grid: a border on even rows and cell walls on odd rows; heavy lines separate the boxes
fun grid-line(row : int) : string
  if row % 2 == 0 then
    val line = row / 2
    val (left, heavy, light, right) = junctions(line)
    val segment = (if line % 3 == 0 then "━" else "─").repeat(3)
    list(0, 8).map(fn(col) (if col == 0 then left else if col % 3 == 0 then heavy else light).string ++ segment).join ++ right.string
  else
    list(0, 8).map(fn(col) (if col % 3 == 0 then "┃" else "│") ++ "   ").join ++ "┃"

// Border characters of horizontal line `line`: left end, crossing a heavy line, crossing a light line, right end
fun junctions(line : int) : (char, char, char, char)
  if line == 0 then ('┏', '┳', '┯', '┓')
  else if line == 9 then ('┗', '┻', '┷', '┛')
  else if line % 3 == 0 then ('┣', '╋', '┿', '┫')
  else ('┠', '╂', '┼', '┨')

// The guesses on the search path, outermost first
fun canvas/draw-path(self : canvas, path : list<guess>, depth : int) : canvas
  val header = self.text(0, panel-col, "GUESSES", heading)
  if path.is-nil then header.text(1, panel-col + 1, if depth == 0 then "none" else "empty", plain.fg(gruvbox/gray))
  else
    val rows = path-rows(depth)
    val shown = if path.length > rows then path.take(rows - 1) else path
    val skipped = path.length - shown.length
    val start =
      if skipped > 0 then header.text(1, panel-col + 1, "… " ++ skipped.show ++ " earlier", plain.fg(gruvbox/gray))
      else header
    val first-row = if skipped > 0 then 2 else 1
    shown.reverse.map-indexed(fn(i, guess) (first-row + i, guess)).foldl(start) fn(canvas, line)
      canvas.draw-guess(line.fst, line.snd)

// One guess: its cell, then its candidates; failed ones are dark and the one being tried is filled in
fun canvas/draw-guess(self : canvas, row : int, guess : guess) : canvas
  val tried = guess.tried.map(fn(t) t.fst)
  val labeled = self.text(row, panel-col + 1, guess.pos.name)
  guess.candidates.digits.map-indexed(fn(i, d) (panel-col + 2 + name-width + 3 * i, d)).foldl(labeled) fn(canvas, slot)
    val (col, d) = slot
    val style =
      if tried.head(0) == d then plain.fg(gruvbox/dark0).bg(gruvbox/yellow).bold
      else if tried.any(fn(t) t == d) then plain.fg(gruvbox/dark3)
      else plain
    canvas.text(row, col, " " ++ d.show ++ " ", style)

// The newest steps, fading with age; the current step is the highlighted bottom line
fun canvas/draw-log(self : canvas, recording : recording, idx : int, top : int) : <div, exn> canvas
  val entries = recording.log(idx, board-height - top - 1)
  val header = self.text(top, panel-col, "STEPS", heading)
  entries.map-indexed(fn(age, entry) (age, entry)).foldl(header) fn(canvas, line)
    canvas.draw-entry(top + entries.length - line.fst, line.fst, recording, line.snd)

fun canvas/draw-entry(self : canvas, row : int, age : int, recording : recording, entry : entry) : exn canvas
  val (glyph, accent, focus, message) = match entry
    Happened(idx) ->
      val step = recording.trace[idx].step
      (step.glyph, step.accent, step.pos, step.describe)
    Abandoned(pos, candidate, steps) ->
      ("←", gruvbox/purple, pos, candidate.show ++ " failed · " ++ steps.show ++ " steps undone")
  val style = if age == 0 then plain.bg(gruvbox/dark1).bold else plain.fg(fade(age))
  self
    .text(row, panel-col, " ".repeat(frame-width - panel-col), style)
    .text(row, panel-col + 1, glyph, style.fg(accent))
    .text(row, panel-col + 3, focus.name, style)
    .text(row, panel-col + 5 + name-width, message, style)

fun canvas/draw-footer(self : canvas, recording : recording, player : player) : exn canvas
  val row = board-height + 1
  val (status, status-color) = if player.playing then ("playing", gruvbox/green) else ("paused", gruvbox/yellow)
  self
    .text(row, 0, "step " ++ (player.index + 1).show ++ " / " ++ recording.trace.length.show, plain.bold)
    .text(row, 20, status, plain.fg(status-color).bold)
    .text(row, 30, "speed " ++ speeds[player.speed].fst)
    .text(row + 1, 0, "←/→ step · space play/pause · +/- speed · q quit", plain.fg(gruvbox/gray))

// How the position reads in the panel: row, then column, such as `(5, 4)`
fun position/name(self : position) : string
  "(" ++ (self.y + 1).show ++ ", " ++ (self.x + 1).show ++ ")"

// The width of every position's name, so the columns after a name line up
val name-width = Position(0, 0).name.count

// Whether the two positions share a row, column or box
fun position/sees(self : position, other : position) : bool
  self.x == other.x || self.y == other.y || (self.x / 3 == other.x / 3 && self.y / 3 == other.y / 3)

// The candidates left in the cell, smallest first
fun cell/digits(self : cell) : list<int>
  list(1, 9).filter(fn(d) self.has(d))

fun step/symbol(self : step) : string
  match self
    Removed(_, candidate) -> candidate.show
    Forced(_, solution) -> solution.show
    Choose(_, _) -> "?"
    Try(_, candidate) -> candidate.show
    Fail(_) -> "×"

fun step/glyph(self : step) : string
  match self
    Removed(_, _) -> "−"
    Forced(_, _) -> "="
    Choose(_, _) -> "?"
    Try(_, _) -> "→"
    Fail(_) -> "×"

// What the step did, as its log line reads after the cell's name
fun step/describe(self : step) : string
  match self
    Removed(_, candidate) -> candidate.show ++ " removed from peers"
    Forced(_, solution) -> "only " ++ solution.show ++ " left"
    Choose(_, candidates) -> "fewest candidates: " ++ candidates.digits.map(fn(d) d.show).join(" ")
    Try(_, candidate) -> "guess " ++ candidate.show
    Fail(_) -> "no candidates left"

fun step/accent(self : step) : color
  match self
    Removed(_, _) -> gruvbox/blue
    Forced(_, _) -> gruvbox/aqua
    Choose(_, _) -> gruvbox/yellow
    Try(_, _) -> gruvbox/yellow
    Fail(_) -> gruvbox/red

// How long the step stays on screen at normal speed, in milliseconds
fun step/base-delay(self : step) : int
  match self
    Removed(_, _) -> 150
    Forced(_, _) -> 300
    Choose(_, _) -> 700
    Try(_, _) -> 700
    Fail(_) -> 1000
