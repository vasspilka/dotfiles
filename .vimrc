" Pathogen to include all plugins in ~/.vim/bundle, puck vundle!
execute pathogen#infect()

" -------------------------------------
"  Basic configuration
" -------------------------------------

let mapleader = ","
nnoremap ; :
nnoremap : ;
set number relativenumber
autocmd! bufwritepost .vimrc source %
set pastetoggle=<F2>
set clipboard=unnamed
map <silent> <F1> ;call ToggleMouse()<cr>
set bs=2     " make backspace behave like normal again
set nocompatible      " We're running Vim, not Vi!
syntax on             " Enable syntax highlighting
filetype on           " Enable filetype detection
filetype indent on    " Enable filetype-specific indenting
filetype plugin on    " Enable filetype-specific plugins

" Incsearh
map /  <Plug>(incsearch-forward)
map ?  <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)

map <Leader>s :call RunCurrentSpecFile()<CR>
map <Leader>l :call RunLastSpec()<CR>
map <Leader>a :call RunAllSpecs()<CR>

" ctrlp config
let g:ctrlp_map = '<leader>f'
let g:ctrlp_max_height = 30
let g:ctrlp_working_path_mode = 0
let g:ctrlp_match_window_reversed = 0

" Ag 
let g:ag_working_path_mode="r"

" Windows with WinKey
map <silent> @sj ;call WinMove('j')<cr>
map <silent> @sk ;call WinMove('k')<cr>
map <silent> @sl ;call WinMove('l')<cr>
map <silent> @sh ;call WinMove('h')<cr>

map <silent> <m-j> ;call WinMove('j')<cr>
map <silent> <m-k> ;call WinMove('k')<cr>
map <silent> <m-l> ;call WinMove('l')<cr>
map <silent> <m-h> ;call WinMove('h')<cr>

nnoremap <silent> @s+ :res +1<CR>
nnoremap <silent> @s_ :res -1<CR>
nnoremap <silent> @s. :vertical resize +1<CR>
nnoremap <silent> @s, :vertical resize -1<CR>
nnoremap <silent> @s> :vertical resize +5<CR>
nnoremap <silent> @s< :vertical resize -5<CR>

nnoremap @so <C-W>o
nnoremap @st <C-W>T

" new tab
nnoremap <leader>t :tabnew<CR>
map <leader>n ;NERDTreeToggle<CR>

" airline config
set laststatus=2
let g:airline#extensions#tabline#enabled = 1

" visual drag config
runtime plugin/dragvisuals.vim

vmap  <expr>  <LEFT>   DVB_Drag('left')
vmap  <expr>  <RIGHT>  DVB_Drag('right')
vmap  <expr>  <DOWN>   DVB_Drag('down')
vmap  <expr>  <UP>     DVB_Drag('up')
vmap  <expr>  D        DVB_Duplicate()
let g:DVB_TrimWS = 1 " Remove trailing space

" Use spaces, damn it!
set expandtab
set smarttab
set tabstop=2
set softtabstop=2
set shiftwidth=2
set autoindent
set nowrap
set textwidth=0

" Reselect visual block after indent/outdent
vnoremap > >gv
vnoremap < <gv

" -------------------------------------
"  Appearance settings
" -------------------------------------

syntax enable
set background=dark
set t_Co=256
"colorscheme monokai

let g:airline_theme = 'molokai'

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

"-------------
" Neovim setup
"-------------

if has('nvim')
	tnoremap <Esc> <C-\><C-n>
endif
