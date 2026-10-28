# kk-sudoku

A hand-written Sudoku solver written in [Koka](https://github.com/koka-lang/koka), leveraging algebraic effects for backtracking search and constraint propagation as well as a few utilities like iterators.

This is both an exploration of first-class algebraic effects in practice, as well as Sudoku itself, which I am currently a bit fixated on :3

It has a vibecoded TUI which displays the entire search process with the ability to pause and explore the steps in `src/pedagogy`. 

An example:
![animated sudoku solver](lesson.gif)
