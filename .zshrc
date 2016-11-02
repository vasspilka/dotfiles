###########################
# ZSH DEFAULTS
###########################

ZSH_THEME="xiong-chiamiov-plus"
TERM=xterm-256color
COMPLETION_WAITING_DOTS="true"
ENABLE_CORRECTION="true"
# CASE_SENSITIVE="true"
# HYPHEN_INSENSITIVE="true"
# DISABLE_AUTO_TITLE="true"
source ".zshenv"

#####################
## Aliases
#####################

alias vim="nvim"
alias   e="emacsclient -t"
alias pac="sudo pacman"

alias  scustom="cd /home/x/custom; vim; popd"
alias  szsh="vim ~/.zshrc"
alias stmux="vim ~/.tmux.conf"
alias  svim="vim ~/.vimrc"

alias  note="vim ~/notes/note.org"
alias bnote="vim ~/notes/books.org"
alias dnote="vim ~/notes/developer.org"

alias mine='sudo chown -R $USER'

## Ruby
alias be='bundle exec'
alias rs="bundle exec rspec"
alias -g rpsec="rspec"
alias rake='bundle exec rake'

## Git
alias gpds='git push && ./deploy.sh staging'
alias gamend='git commit -a --amend'

alias err='systemctl restart --user emacs'
alias est='systemctl stop    --user emacs'

## Places
alias Work="~/Work"
alias x="/home/x"

######################
## Custom vars
######################


run_specs_and_notify () {
  rake
}

psql () {
  if (($# == 0)) then
    docker run -it --link postgres:postgres --rm postgres sh -c 'exec psql -h "$POSTGRES_PORT_5432_TCP_ADDR" -p "$POSTGRES_PORT_5432_TCP_PORT" -U postgres'
  else
    docker run -it --link postgres:postgres --rm postgres sh -c "exec psql $*"
  fi
}

###############################
# Inits, sourcing and plugins
###############################

plugins=(git z gem zsh-syntax-highlighting elixir mix)

source $ZSH/oh-my-zsh.sh
eval "$(rbenv init -)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
ZSH_THEME_GIT_PROMPT_PREFIX="(%{$fg[white]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{\e[0;34m%}%B)"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}*"
