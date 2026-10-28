# Records the lesson for board 1 of puzzles/easy50.txt to lesson.gif; run `vhs lesson.tape` inside the dev shell
Output lesson.gif

Set Shell "bash"
Set FontFamily "Berkeley Mono"
Set FontSize 16
Set Theme "GruvboxDark"
# The lesson draws an 80×22 frame, so the terminal must be at least that big
Set Width 860
Set Height 520
Set Padding 20
Set TypingSpeed 40ms

# Build off camera, so the recording starts at a clean prompt
Hide
Type "koka -O2 -isrc -c src/main.kk -o .koka/sudoku > /dev/null && chmod +x .koka/sudoku && clear"
Enter
Wait@3m
Show

Type ".koka/sudoku --lesson=1"
Sleep 400ms
Enter

# At 1x, clearing the givens from their peers takes about 4 seconds, then forced placements begin
Sleep 6s

# Pause on step 36, a forced placement; step forward three, then back one
Space
Sleep 1.5s
Right
Sleep 800ms
Right
Sleep 800ms
Right
Sleep 800ms
Left
Sleep 1.5s

# Resume at 2x; the last 43 steps take about 6.5 seconds, then the replay pauses on the solved board
Type "+"
Sleep 500ms
Space
Sleep 9s

Type "q"
Sleep 1s
