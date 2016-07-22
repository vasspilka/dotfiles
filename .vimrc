""""""""""""""""""""""""""""""""""""""""""""""
"" Config
""""""""""""""""""""""""""""""""""""""""""""""
let $NVIM_TUI_ENABLE_TRUE_COLOR=1
set number relativenumber

" Use spaces, damn it!
set expandtab
set smarttab
set tabstop=2
set softtabstop=2
set shiftwidth=2
set autoindent
set wrap
set textwidth=0
set mouse=""
let g:autoswap_detect_tmux = 1

""""""""""""""""""""""""""""""""""""""""""""""
"" Plugins
""""""""""""""""""""""""""""""""""""""""""""""

call plug#begin('~/.vim/plugged')

Plug 'tyrannicaltoucan/vim-deep-space' " Colorscheme
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
Plug 'dkprice/vim-easygrep'
Plug 'gioele/vim-autoswap'

"" Ruby
Plug 'janko-m/vim-test'

"" Elixir
Plug 'elixir-lang/vim-elixir'
Plug 'slashmili/alchemist.vim'
Plug 'lucidstack/hex.vim'

function! DoRemote(arg)
  UpdateRemotePlugins
endfunction
Plug 'Shougo/deoplete.nvim', { 'do': function('DoRemote') }


call plug#end()

""""""""""""""""""""""""""""""""""""""""""""""
"" MAPPINGS
""""""""""""""""""""""""""""""""""""""""""""""
let mapleader = ","

""""" Leader Mappings """""
nnoremap <leader>t :tabnew<CR>
nnoremap <leader>r :source ~/.vimrc<CR>
nnoremap <leader>sv :e ~/.vimrc<CR>

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
"noremap x  "_d
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

""
colorscheme deep-space

""""""""""""""""""""""""""""""""""""""""""""""
"" Let
""""""""""""""""""""""""""""""""""""""""""""""

let g:alchemist#elixir_erlang_src = '/usr/local/share/src'

"" Macros

let @p = 'orequire "pry"; binding.pry'

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
