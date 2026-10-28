# Records the lesson for board 33 of puzzles/easy50.txt to lesson.gif; run `vhs lesson.tape` inside the dev shell
Output lesson.gif

Set Shell "bash"
Set FontFamily "Berkeley Mono"
Set FontSize 16
Set Theme "GruvboxDark"
# The lesson draws an 80×22 frame; 880×520 gives 81×24, and any narrower wraps every line
Set Width 880
Set Height 520
Set Padding 20
Set TypingSpeed 40ms

# Build off camera, so the recording starts at a clean prompt
Hide
Type "koka -O2 -isrc -c src/main.kk -o .koka/sudoku > /dev/null && chmod +x .koka/sudoku && clear"
Enter
Wait@3m
Show

Type ".koka/sudoku --lesson=33"
Sleep 400ms
Enter

# Off camera, pause and rewind to step 1, so the timings below count from a known step
Hide
Sleep 500ms
Space
Left 5
Sleep 200ms
Show

# Show the puzzle, then play the 32 removals at 2x
Sleep 1.5s
Type "+"
Sleep 500ms
Space

# Drop to 1x just before the first guess, at step 33
Sleep 2.2s
Type "-"

# Three nested guesses at 1x; pause on step 59, where the last candidate of the third guess fails
Sleep 13.4s
Space
Sleep 2s

# Step to 60: both inner guesses are dropped, and the outer one tries its other candidate
Right
Sleep 3s

# Finish at 4x; the last 48 steps take about 4 seconds, then the replay pauses on the solved board
Type "++"
Sleep 500ms
Space
Sleep 6.5s

Type "q"
Sleep 1s
