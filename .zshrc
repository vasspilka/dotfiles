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
export PATH=$HOME/.cargo/bin:$PATH
export PATH=$HOME/.asdf/installs/nodejs/10.16.3/.npm/bin:$PATH
export PATH=$HOME/.asdf/installs/nodejs/15.8.0/.npm/bin:$PATH
export PATH=$HOME/elixir-ls/release:$PATH
export PATH=$HOME/.asdf/installs/rust/stable/bin:$PATH
# export PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"

export LOCAL_AWS_USERNAME="vasilis.spilka"
export ERL_AFLAGS="-kernel shell_history enabled"
export KERL_BUILD_DOCS=yes

# Inits
# Starship prompts
eval "$(starship init zsh)"
# ssh agent to keychain
# eval `keychain --eval --agents ssh vasspilka`

autoload bashcompinit
bashcompinit
autoload -U compinit && compinit

# No autocorrect
unsetopt correct_all

. $HOME/.asdf/asdf.sh
. $HOME/.asdf/completions/asdf.bash


## Plugins
source $HOME/antigen.zsh

plugins=(git z mix)

antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions
antigen use oh-my-zsh

antigen apply

plugins=(git z mix asdf)

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
alias tmux='tmux -u'

alias dk='docker'
alias dkc='docker-compose'

## Elixir Phoenix
alias  mt="mix test"
alias mixs='iex -S mix'
alias ms='mix phx.server'
alias mxs='iex -S mix phx.server'
alias mck='mix do format, credo, dialyzer, test'
# alias mdrr='mix do ecto.drop, ecto.create, event_store.drop, event_store.create, event_store.init, event_store.migrate, ecto.migrate'

## Git
alias gamend='git commit -a --amend'
alias gitdeletemerged='git branch --merged | egrep -v "(^\*|master|dev)" | xargs git branch -d'

## Places
alias Work="~/Work"
alias x="/home/x"
export PATH="/usr/local/opt/libpq/bin:$PATH"
export PATH="~/.asdf/installs/rust/stable/bin:$PATH"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '~/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '~/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '~/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '~/Downloads/google-cloud-sdk/completion.zsh.inc'; fi


export PATH="/usr/local/opt/libpq/bin:$PATH"
