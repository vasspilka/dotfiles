###########################
# ZSH DEFAULTS
###########################

ZSH="$HOME/.oh-my-zsh"
TERM=xterm-256color
ENABLE_CORRECTION="false"
BROWSER="/usr/bin/goole-chrome-stable"

###############################
# Inits, sourcing and plugins
###############################

# Path & Env Exports
export PATH=$HOME/.utrust-cli/bin:$PATH
export PATH=$HOME/.cargo/bin:$PATH

export LOCAL_AWS_USERNAME="vasilis.spilka"
export ERL_AFLAGS="-kernel shell_history enabled"

# Inits
# Starship prompts
eval "$(starship init zsh)"
# ssh agent to keychain
eval `keychain --eval --agents ssh vasspilka`

autoload bashcompinit
bashcompinit
autoload -U compinit && compinit

# No autocorrect
unsetopt correct_all

. $HOME/.asdf/asdf.sh
. $HOME/.asdf/completions/asdf.bash


## Plugins
source $HOME/antigen.zsh

antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions

antigen apply

plugins=(git z mix)

# Sourcing
source $HOME/.oh-my-zsh/oh-my-zsh.sh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

#####################
## Aliases
#####################

# System
alias   e="emacs -nw"
alias pac="sudo pacman"
alias doom="~/.doom-emacs/bin/doom"

# JS
alias  yi="yarn install"
alias  ys="yarn start"
alias  yt="yarn test"
alias  yb="yarn build"

alias  szsh="e ~/.zshrc"
alias stmux="e ~/.tmux.conf"
alias  svim="e ~/.vimrc"

alias  note="e ~/notes/note.org"
alias bnote="e ~/notes/books.org"
alias dnote="e ~/notes/developer.org"

alias mine='sudo chown -R $USER'
alias open='xdg-open'

## Elixir Phoenix
alias  mt="mix test"
alias mixs='iex -S mix'
alias ms='mix phx.server'
alias mxs='iex -S mix phx.server'

## Git
alias gamend='git commit -a --amend'
alias gitdeletemerged='git branch --merged | egrep -v "(^\*|master|dev)" | xargs git branch -d'

## Places
alias Work="~/Work"
alias x="/home/x"
