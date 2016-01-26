" Pathogen to;q include all plugins in ~/.vim/bundle, puck vundle!
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
set mouse=
map <silent> <F1> ;call ToggleMouse()<cr>
set bs=2     " make backspace behave like normal again
set nocompatible      " We're running Vim, not Vi!
syntax on             " Enable syntax highlighting
filetype on           " Enable filetype detection
filetype indent on    " Enable filetype-specific indenting
filetype plugin on    " Enable filetype-specific plugins

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

" Leader Mappings
nnoremap <leader>t :tabnew<CR>
map <leader>n ;NERDTreeToggle<CR>

" -------------------------------------
"  Plugins Configuration
" -------------------------------------

" fzf be fuzzy at lighting speed
set rtp+=~/.fzf
nmap <leader>f ;Files <CR>
nmap <leader>gf ;GitFiles <CR>
nmap <leader><tab> <plug>(fzf-maps-n)
xmap <leader><tab> <plug>(fzf-maps-x)
omap <leader><tab> <plug>(fzf-maps-o)
autocmd! User FzfStatusLine call <SID>fzf_statusline()

" Insert mode completion
imap <c-x><c-f> <plug>(fzf-complete-path)
imap <c-x><c-j> <plug>(fzf-complete-file-ag)
imap <c-x><c-l> <plug>(fzf-complete-line)

" Incsearh
set hlsearch
let g:incsearch#auto_nohlsearch = 1
nnoremap <Esc><Esc> :<C-u>nohlsearch<CR>!
map /  <Plug>(incsearch-forward)
map ?  <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)
map n  <Plug>(incsearch-nohl-n)
map N  <Plug>(incsearch-nohl-N)
map *  <Plug>(incsearch-nohl-*)
map #  <Plug>(incsearch-nohl-#)
map g* <Plug>(incsearch-nohl-g*)
map g# <Plug>(incsearch-nohl-g#)

" rspec
map <Leader>s :call RunCurrentSpecFile()<CR>
map <Leader>l :call RunLastSpec()<CR>
map <Leader>a :call RunAllSpecs()<CR>

" Ag
let g:ag_working_path_mode="r"

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

" other
let g:autoswap_detect_tmux = 1

" -------------------------------------
" Window Shortcuts
" -------------------------------------

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


" -------------------------------------
"  Appearance settings
" -------------------------------------

syntax enable
set background=dark
set t_Co=256

let g:airline_theme = 'molokai'

" -------------------------------------
"  Custom Functions
" -------------------------------------

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

function! s:fzf_statusline()
  " Override statusline as you like
  highlight fzf1 ctermfg=161 ctermbg=251
  highlight fzf2 ctermfg=23 ctermbg=251
  highlight fzf3 ctermfg=237 ctermbg=251
  setlocal statusline=%#fzf1#\ >\ %#fzf2#fz%#fzf3#f
endfunction


"-------------
" Neovim setup
"-------------

if has('nvim')
	tnoremap <Esc> <C-\><C-n>
endif
