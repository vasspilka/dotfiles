## Vim Defaults

###

  * `ZZ` -> save and exit (also :x)
  * `ZQ` -> exit without save (also :q!) 

### Motions

  * `h` -> left
  * `j` -> down
  * `k` -> up
  * `l` -> right

  * `w` -> move at the beginning of next word
  * `W` -> like `w` but includes special characters
  * `b` -> move at the beginning of previous word
  * `B` -> like `b` but includes special characters
  * `e` -> moves at the end of next word
  * `E` -> like `e` but includes special characters
  * `ge` -> move at the end of previous word
  * `gE` -> like `ge` but includes special characters

  * `0` -> move to beginning of line
  * `$` -> move to end of line
  * `^` -> move to first non blank character of line

  * `G` -> go to last line
  * `gg` -> go to first line
  * `{num}G` -> go to line with number `num`

  * `t{x}` -> move one character before `x`
  * `f{x}` -> find the next occurrence of `x`
  * `F{x}` -> like `f` but backwards
  * `;` -> repeat any of the above
  * `,` -> repeat any of the above in the opposite direction

  * `*` -> find next word under cursor
  * `#` -> find previous word under cursor

  * `CTRL-d` -> move half page Down
  * `CTRL-u` -> move half page Up
  * `CTRL-E` -> move only screen one line down

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
  * `x` -> delete character under cursor **-->>**
  * `s` -> like `x` but puts you to insert mode **-->>**
  * `S` -> like `dd` but puts you to insert mode
  * `c` -> deletes and puts you in insert **-->**
  * `C` -> like `S` but from cursor to end of line
  * `r{x}` -> replace character under cursor with `x`   
  * `R` -> replace mode

  * `y` -> yank (copy) **-->**
  * `Y` -> yank current line

  * `>` -> indent **-->**
  * `<` -> deindent **-->**

  * `v` -> visual mode
  ls s
  a `V` -> visual mode lines
  * `CTRL-v` -> visual mode block

