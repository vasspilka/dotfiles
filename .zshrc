###########################
# ZSH DEFAULTS
###########################

ZSH="$HOME/.oh-my-zsh"
TERM=xterm-256color
ENABLE_CORRECTION="false"

# Platform detection
case "$(uname -s)" in
  Darwin) IS_MAC=true ;;
  Linux)  IS_LINUX=true ;;
esac

###############################
# Inits, sourcing and plugins
###############################
export ERL_AFLAGS="-kernel shell_history enabled"
export KERL_BUILD_DOCS=yes

# Path & Env Exports
if [ "$IS_MAC" = true ]; then
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  export PATH=$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin
  export PATH="/usr/local/opt/libpq/bin:$PATH"
fi

eval "$(mise activate zsh)"
export PATH=$HOME/.cargo/bin:$PATH
export PATH=$HOME/elixir-ls/release:$PATH
export PATH=$HOME/.config/emacs/bin:$PATH
export PATH=$HOME/.local/bin:$PATH

# Starship prompt
eval "$(starship init zsh)"
stty -ixon
autoload bashcompinit
bashcompinit
autoload -U compinit && compinit

# No autocorrect
unsetopt correct_all

## Plugins
source $HOME/antigen.zsh
source $HOME/.zprofile

antigen bundle agkozak/zsh-z
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle git
antigen bundle mix
antigen bundle zsh-users/zsh-completions
antigen use oh-my-zsh

antigen apply

source <(fzf --zsh)

#####################
## Aliases
#####################

# System
alias   e="emacs -nw"
[ "$IS_LINUX" = true ] && alias pac="sudo pacman"

# JS
alias  yi="yarn install"
alias  ys="yarn start"
alias  yt="yarn test"
alias  yb="yarn build"

alias  szsh="nvim ~/.zshrc"
alias stmux="e ~/.tmux.conf"
alias  svim="e ~/.vimrc"

alias  note="e ~/notes/note.org"
alias bnote="e ~/notes/books.org"
alias dnote="e ~/notes/developer.org"

alias mine='sudo chown -R $USER'
[ "$IS_LINUX" = true ] && alias open='xdg-open'
alias tmux='tmux -u'

alias dk='docker'
alias dkc='docker-compose'
alias c='claude --dangerously-skip-permissions'


## Elixir Phoenix
alias  mt="mix test"
alias mixs='iex -S mix'
alias ms='mix phx.server'
alias mxs='iex -S mix phx.server'
alias mck='mix do format, credo, dialyzer, test'
alias ashremigrate='mix do ash_postgres.generate_migrations, ash_postgres.migrate'

## Git
alias gamend='git commit -a --amend'
alias gitdeletemerged='git branch --merged | egrep -v "(^\*|master|dev)" | xargs git branch -d'

## Places
alias Work="~/Work"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
