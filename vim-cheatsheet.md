## Default vim actions

Vim is a great text editor, where most text editor are optimized to insert text to a document Vim is optimized to edit!
Below I have a cheat sheet to reference manny of vim default command. Note everything is case sensitive!

Some helpers are used to abstact some of functionality 

  1. **!x** means you can use the commands x times just use a number **before** the command
  2. **-->** means you can use a motion **after** the command 

### If you want to get out

  * `ZZ` -> save and exit (also :x)
  * `ZQ` -> exit without save (also :q!) 

### Motions and Display

  * `h` -> left **!x**
  * `j` -> down **!x**
  * `k` -> up   **!x**
  * `l` -> right **!x**

  * `w` -> move at the beginning of next word **!x**
  * `W` -> like `w` but includes special characters **!x**
  * `b` -> move at the beginning of previous word **!x**
  * `B` -> like `b` but includes special characters **!x**
  * `e` -> moves at the end of next word **!x**
  * `E` -> like `e` but includes special characters **!x**
  * `ge` -> move at the end of previous word **!x**
  * `gE` -> like `ge` but includes special characters **!x**

  * `0` -> move to beginning of line
  * `$` -> move to end of line
  * `^` -> move to first non blank character of line

  * `G` -> jump to last line
  * `gg` -> jump to first line
  * `{num}G` -> jump to line with number `num`
  * `CTRL-O` -> jump to previous jump on stack (also moves between files)
  * `CTRL-O` -> jump to next jump on stack (also moves between files)
  * gf -> go to file under cursor

  * `zt` -> move display so cursor is at top 
  * `zz` -> center display to cursor
  * `zb` -> move display so cursor is at bottom 
  * `CTRL-E` -> display moves one line down
  * `CTRL-Y` -> display moves one line up

  * `K` -> display man page for word under cursor

  * `t{x}` -> move one character before `x`
  * `f{x}` -> find the next occurrence of `x`
  * `F{x}` -> like `f` but backwards
  * `;` -> repeat any of the above
  * `,` -> repeat any of the above in the opposite direction

  * `*` -> find next word under cursor
  * `#` -> find previous word under cursor

  * `CTRL-d` -> move half page Down
  * `CTRL-u` -> move half page Up
  * `CTRL-f` -> move one page Up
  * `CTRL-b` -> move one page Down

  * `)(` -> move sentences **-><-**
  * `}{` -> move paragraphs **-><-**

  * `HML` -> move to High Mid Low respectively 


### Editing

  * `Esc` -> back to normal mode

  * `i` -> insert mode
  * `I` -> insert mode at the beginning
  * `a` -> insert mode after cursor
  * `A` -> insert mode at end of line 
  * `o` -> insert mode at new line below
  * `O` -> insert mode at new line above
  
  * `d` -> delete **-->**
  * `dd` -> delete one line
  * `c` -> deletes and puts you in insert **-->**
  * `x` -> delete character under cursor **!x**
  * `X` -> delete character before cursor (back-space) **!x**
  * `s` -> like `x` but puts you to insert mode **!x**
  * `S` -> like `dd` but puts you to insert mode
  * `C` -> like `S` but from cursor to end of line
  * `r{x}` -> replace character under cursor with `x`   
  * `R` -> replace mode

  * `y` -> yank (copy) **-->**
  * `Y` -> yank current line

  * `>` -> indent **-->**
  * `<` -> deindent **-->**

  * `v` -> visual mode
  * `V` -> visual mode lines
  * `CTRL-v` -> visual mode block

  * `u` -> Undo!!! **!x**
  * `CTRL-R` -> Redo! **!x**

  * `.` -> Copies last command!! **!x**

  * `~` -> Toggles case **!x**

### Marks and Registers

  * `:marks` -> lists all marks
  * `m{x}` -> set a mark on `x`
  * `\`{x}` -> jump directly to mark `x`
  * `'{x}` -> jump to line of `x`
  * `''` -> go to previous location

  * `:reg` -> lists all registers
  * `"{x}` -> select register `x`

  * `q{x}` -> starts recording to `x`
  * `q` -> stop recording
  * `@{x}` -> play macro `x`
  * `@@` -> play last macro

  * `:changes` -> view all the changes you did in file
  * `g;` -> move to line of you changed last
  * `g,` -> like `g;` but move forward in changelist


### Ex commands

  * `:` -> Initiate one ex command 
  * `Q` -> Initiate EX mode (type visual to quit)

  * `:e {file}` -> Edit `file`
  * `:w {file}` -> save to `file` (filename optional)
  * `:q` -> quit
  * `:noh` -> turn of highlighting

  * `%` -> All lines
  * `.` -> this line
  * `$` -> last line
  * `+{x}` -> your line + `x`
  * `-{x}` -> your line - `x`
  * `{x},{y}{command}` -> from `x` to `y` lines do `command` usefull for substitution
  * `{range}s/{replace}/{with}i/` -> substitude `replace` with `with` for `range`
     also accepts `g` and `c` at the end meaning global (all words) and.. call? (ask first)

### Windows and tabs

 * `CTRL-w` -> listens for windows command always need to do this!!! ( unless using ex command)
 * `s` -> splits window horizontaly `:split`
 * `v` -> splits window vertically `:vsplit`
 * `w` -> cycle through windows `:switch`
 * `c` -> close window `:close`
 * `o` -> close all except current `:only` 
 * `=` -> makes all windows same size
 * `hjkl` -> move between windows left, down, up, right respectively

 * `:sp {file}` -> open `file` in new split can also use `:vsp`


 * `:tabnew` -> new tab
 * `gt` -> cycle though tabs
 * `{x}gt` -> go to tab `x`

