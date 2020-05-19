###########################
# Inits, sourcing and plugins
###########################
set XDG_CONFIG_HOME ~/.config

if not functions -q fisher
  curl https://git.io/fisher --create-dirs -sLo $XDG_CONFIG_HOME/fish/functions/fisher.fish
end

if status --is-interactive
  eval (keychain --eval --agents ssh -Q --quiet vasspilka --nogui)
end

# Path & Env Exports
set PATH $PATH $HOME/.utrust-cli/bin
set PATH $PATH $HOME/.cargo/bin

set LOCAL_AWS_USERNAME "vasilis.spilka"
set ERL_AFLAGS "-kernel shell_history enabled"

set fish_greeting

starship init fish | source

source ~/.asdf/asdf.fish

#####################
## Aliases
#####################

# System
alias   e='emacs -nw'
alias pac='sudo pacman'
alias doom='~/.doom-emacs/bin/doom'

# JS
alias  yi='yarn install'
alias  ys='yarn start'
alias  yt='yarn test'
alias  yb='yarn build'

alias  szsh='e ~/.zshrc'
alias stmux='e ~/.tmux.conf'
alias  svim='e ~/.vimrc'

alias  note='e ~/notes/note.org'
alias bnote='e ~/notes/books.org'
alias dnote='e ~/notes/developer.org'

alias mine='sudo chown -R $USER'
alias open='xdg-open'

## Elixir Phoenix
alias   mt='mix test'
alias mixs='iex -S mix'
alias   ms='mix phx.server'
alias  mxs='iex -S mix phx.server'

## Git
alias gamend='git commit -a --amend'
alias gitdeletemerged='git branch --merged | egrep -v "(^\*|master|dev)" | xargs git branch -d'
alias gst='git status'
alias gd='git diff'
alias gco='git checkout'

## Places
alias Work='cd ~/Work'
alias x='cd /home/x'


#####################
## Functions
#####################

function gdh
    git diff HEAD~$argv
end

function grhh
  if $argv
    git reset --hard HEAD~$argv
  else
    git reset --hard HEAD
  end
end

function gcu
    git add .
    git commit -m "update"
end
