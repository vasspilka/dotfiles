""""""""""""""""""""""""""""""""""""""""""""""
"" Config
""""""""""""""""""""""""""""""""""""""""""""""
let $NVIM_TUI_ENABLE_TRUE_COLOR=1
set number relativenumber

""""""""""""""""""""""""""""""""""""""""""""""
"" Plugins
""""""""""""""""""""""""""""""""""""""""""""""

call plug#begin('~/.vim/plugged')

Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }

function! DoRemote(arg)
  UpdateRemotePlugins
endfunction
Plug 'Shougo/deoplete.nvim', { 'do': function('DoRemote') }
"" yet to user
Plug 'janko-m/vim-test'


call plug#end()

""""""""""""""""""""""""""""""""""""""""""""""
"" MAPPINGS
""""""""""""""""""""""""""""""""""""""""""""""
let mapleader = ","

""""" Leader Mappings """""
nnoremap <leader>t :tabnew<CR>
" nerdtree
map <leader>n :NERDTreeToggle<CR>
" fzf
nmap <leader>f :Files<CR>
nmap <leader>gf :GitFiles<CR>
nmap <leader><tab> <plug>(fzf-maps-n)
xmap <leader><tab> <plug>(fzf-maps-x)
omap <leader><tab> <plug>(fzf-maps-o)

vnoremap <C-c> "*y<CR>
nmap <C-c> "*y
nnoremap =p o<esc>p==
nnoremap =P O<esc>p==

""""" Refinements """""
nnoremap vd "_d
noremap x  "_d
nnoremap vD "_D
xnoremap P  "0p
xnoremap - $
nnoremap - $

""""" Windows & Panes """""
map <silent> @sj :call WinMove('j')<cr>
map <silent> @sk :call WinMove('k')<cr>
map <silent> @sl :call WinMove('l')<cr>
map <silent> @sh :call WinMove('h')<cr>

map <silent> <m-j> :call WinMove('j')<cr>
map <silent> <m-k> :call WinMove('k')<cr>
map <silent> <m-l> :call WinMove('l')<cr>
map <silent> <m-h> :call WinMove('h')<cr>

nnoremap <silent> @s+ :res +1<CR>
nnoremap <silent> @s_ :res -1<CR>
nnoremap <silent> @s. :vertical resize +1<CR>
nnoremap <silent> @s, :vertical resize -1<CR>
nnoremap <silent> @s> :vertical resize +5<CR>
nnoremap <silent> @s< :vertical resize -5<CR>

nnoremap @so <C-W>o
nnoremap @st <C-W>T


""""""""""""""""""""""""""""""""""""""""""""""
"" Custom Functions
""""""""""""""""""""""""""""""""""""""""""""""

function! WinMove(key)
  let t:curwin = winnr()
  exec "wincmd ".a:key
  if (t:curwin == winnr())
    if (match(a:key,'[jk]'))
      wincmd v
    else
      wincmd s
    endif
    exec "wincmd ".a:key
  endif
endfunction

function! ToggleMouse()
    " check if mouse is enabled
    if &mouse == 'a'
        " disable mouse
        set mouse=
    else
        " enable mouse everywhere
        set mouse=a
    endif
endfunc
