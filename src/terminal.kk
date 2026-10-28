module terminal

import std/core/unsafe
import std/num/int32

extern import
  c file "terminal-inline.c"

// PRIMITIVES

extern flush() : console ()
  c "kk_tty_flush"

extern raw-mode() : console bool
  c "kk_tty_raw_mode"

extern restore-mode() : console ()
  c "kk_tty_restore_mode"

extern read-byte(timeout-ms : int32) : console int32
  c "kk_tty_read_byte"

extern window-columns() : console int32
  c "kk_tty_columns"

extern window-rows() : console int32
  c "kk_tty_rows"

// The terminal's size as (columns, rows); throws when stdout is not a terminal
pub fun window-size() : <console, exn> (int, int)
  val columns = window-columns().int
  val rows = window-rows().int
  if columns > 0 && rows > 0 then (columns, rows) else throw("stdout is not a tty")

// ESCAPES

val reset = "\x1B[0m"
val home = "\x1B[H"
val clear-screen = "\x1B[2J"
val clear-below = "\x1B[J"
val clear-line-end = "\x1B[K"
val hide-cursor = "\x1B[?25l"
val show-cursor = "\x1B[?25h"
val enter-alt-screen = "\x1B[?1049h"
val leave-alt-screen = "\x1B[?1049l"

// COLOR

// A color from the terminal's 256-color palette
abstract value struct color
  index : int

pub val color/black = Color(0)
pub val color/red = Color(1)
pub val color/green = Color(2)
pub val color/yellow = Color(3)
pub val color/blue = Color(4)
pub val color/magenta = Color(5)
pub val color/cyan = Color(6)
pub val color/white = Color(7)

// The bright variant of one of the eight theme colors; other colors are returned unchanged
pub fun color/bright(self : color) : color
  if self.index < 8 then Color(self.index + 8) else self

// Palette entry `index`, from 0 to 255; entries 0 to 15 follow the terminal's theme
pub fun color/palette(index : int) : color
  Color(index)

fun color/(==)(^self : color, ^other : color) : bool
  self.index == other.index

// SGR parameters that select `color`; `base` is 38 for the foreground or 48 for the background
fun params(color : maybe<color>, base : int) : list<string>
  match color
    Just(Color(index)) -> [base.show, "5", index.show]
    Nothing -> []

// STYLE

abstract struct style
  foreground : maybe<color> = Nothing
  background : maybe<color> = Nothing
  is-bold : bool = False
  is-dim : bool = False

// The terminal's default colors, with no attributes
pub val plain : style = Style()

pub fun style/fg(self : style, color : color) : style
  self(foreground = Just(color))

pub fun style/bg(self : style, color : color) : style
  self(background = Just(color))

pub fun style/bold(self : style) : style
  self(is-bold = True)

pub fun style/dim(self : style) : style
  self(is-dim = True)

fun style/(==)(^self : style, ^other : style) : bool
  self.foreground == other.foreground && self.background == other.background
    && self.is-bold == other.is-bold && self.is-dim == other.is-dim

// The escape that switches from any style to this one
fun style/sgr(self : style) : string
  val attributes = [(self.is-bold, "1"), (self.is-dim, "2")]
    .filter(fn(attribute) attribute.fst)
    .map(fn(attribute) attribute.snd)
  val codes = Cons("0", attributes ++ self.foreground.params(38) ++ self.background.params(48))
  "\x1B[" ++ codes.join(";") ++ "m"

// CANVAS

// One character cell; `ch` must be one column wide
value struct glyph
  ch : char
  style : style

// A grid of styled characters; chain or fold updates rather than reassigning a `var`, which copies the grid
abstract struct canvas
  width : int
  height : int
  glyphs : vector<glyph>

pub fun canvas/blank(width : int, height : int) : canvas
  Canvas(width, height, vector(width * height, Glyph(' ', plain)))

// Write `text` on one line from `row`, `col`; the parts outside the canvas are cut off
pub fun canvas/text(self : canvas, row : int, col : int, text : string, style : style = plain) : canvas
  val chars = text.vector
  self.map-region(row, col, 1, chars.length) fn(_, c, _)
    Glyph(chars.at(c - col).default(' '), style)

// Apply `f` to the style of every cell in the region, keeping the characters
pub fun canvas/restyle(self : canvas, row : int, col : int, height : int, width : int, f : style -> style) : canvas
  self.map-region(row, col, height, width) fn(_, _, glyph)
    glyph(style = f(glyph.style))

// Replace each glyph in the region with `f(row, col, glyph)`, skipping the parts outside the canvas
// Keep `noinline`: if another module inlines the `unsafe-total` body below, Koka 3.2.3 writes a .kki file that fails to parse
noinline fun canvas/map-region(self : canvas, row : int, col : int, height : int, width : int, f : (int, int, glyph) -> glyph) : canvas
  match self
    Canvas(w, h, glyphs) ->
      // The loops are clipped to the canvas, so indexing cannot throw
      unsafe-total fn()
        var local := glyphs
        for(max(row, 0), min(row + height, h) - 1) fn(r)
          for(max(col, 0), min(col + width, w) - 1) fn(c)
            val idx = r * w + c
            local[idx] := f(r, c, local[idx])
        Canvas(w, h, local)

// Render as newline-separated lines, emitting an escape only where the style changes
fun canvas/show(self : canvas) : string
  var parts := []
  var current := plain
  self.glyphs.foreach-indexed fn(idx, glyph)
    if idx > 0 && idx % self.width == 0 then
      if !(current == plain) then
        parts := Cons(reset, parts)
        current := plain
      parts := Cons("\n", parts)
    if !(glyph.style == current) then
      parts := Cons(glyph.style.sgr, parts)
      current := glyph.style
    parts := Cons(glyph.ch.string, parts)
  if !(current == plain) then
    parts := Cons(reset, parts)
  parts.reverse.join

// KEYS

pub type key
  Char(c : char)
  Up
  Down
  Left
  Right
  Enter
  Tab
  Backspace
  Escape
  // Ctrl-C; raw mode turns its signal off, so it arrives as a key
  Interrupt
  // Any other byte, such as part of a non-ASCII character; unknown escape sequences arrive as 27
  Other(byte : int)

// How long to wait for the rest of an escape sequence before reporting a lone Escape
val escape-timeout-ms = 25

fun next-byte(timeout-ms : int) : console int
  read-byte(timeout-ms.int32).int

// The next key press, or `Nothing` when none arrives within `timeout-ms`; a negative timeout waits forever
fun read-key(timeout-ms : int) : console maybe<key>
  val byte = next-byte(timeout-ms)
  if byte < 0 then Nothing else Just(decode(byte))

fun decode(byte : int) : console key
  match byte
    3 -> Interrupt
    8 -> Backspace
    9 -> Tab
    10 -> Enter
    13 -> Enter
    27 -> escape-sequence()
    127 -> Backspace
    _ -> if byte >= 32 && byte < 127 then Char(byte.char) else Other(byte)

// Decode what follows an ESC: an arrow key's sequence, or nothing for a lone Escape
fun escape-sequence() : console key
  val next = next-byte(escape-timeout-ms)
  if next != '['.int && next != 'O'.int then Escape
  else
    // Skip parameter bytes, such as the `1;5` in Ctrl-Right's `ESC [ 1 ; 5 C`
    val last = for-while(1, 16) fn(_)
      val byte = next-byte(escape-timeout-ms)
      if byte >= 0x30 && byte <= 0x3F then Nothing else Just(byte)
    match last.default(-1)
      -1 -> Other(27)
      byte -> match byte.char
        'A' -> Up
        'B' -> Down
        'C' -> Right
        'D' -> Left
        _ -> Other(27)

// SCREEN

// Somewhere to show frames and read keys
pub effect screen
  // Whether `wait-key` can ever return a key; when false, loops must not wait for input
  val interactive : bool
  // Replace the previous frame with `frame`
  fun draw(frame : canvas) : ()
  // The next key press, or `Nothing` when none arrives within `timeout-ms`; a negative timeout waits forever
  fun wait-key(timeout-ms : int) : maybe<key>

// Draw on the terminal's alternate screen and read raw keys; without a terminal, print each frame instead
pub fun screen/live(action : () -> <screen, console|e> a) : <console|e> a
  if raw-mode() then on-terminal(action) else transcript(action)

fun on-terminal(action : () -> <screen, console|e> a) : <console|e> a
  print(enter-alt-screen ++ hide-cursor ++ clear-screen)
  flush()
  with finally { leave-terminal() }
  with handler
    val interactive = True
    fun draw(frame)
      print(home ++ frame.show.lines.map(fn(line) line ++ clear-line-end).join("\n") ++ clear-below)
      flush()
    fun wait-key(timeout-ms) read-key(timeout-ms)
  action()

fun leave-terminal() : console ()
  print(reset ++ show-cursor ++ leave-alt-screen)
  flush()
  restore-mode()

fun transcript(action : () -> <screen, console|e> a) : <console|e> a
  with handler
    val interactive = False
    fun draw(frame) frame.show.println
    fun wait-key(timeout-ms) Nothing
  action()
