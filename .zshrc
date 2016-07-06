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

#####################
## Aliases
#####################

alias vim="nvim"
alias pac="sudo pacman"

alias  szsh="vim ~/.zshrc"
alias stmux="vim ~/.tmux.conf"
alias  svim="vim ~/.vimrc"
alias note="vim ~/.note"
alias scustom="cd /home/x/custom; vim; popd"

alias mine='sudo chown -R $USER'

## Ruby
alias -g rpsec="rspec"
alias be='bundle exec'
alias rake='bundle exec rake'

## Git
alias gpds='git push && ./deploy.sh staging'
alias gamend='git commit -a --amend'

######################
## Custom vars
######################

Work="~/Work"

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

######################
# Export vars
######################

export ZSH=/home/vs/.oh-my-zsh
export LANG=en_US.UTF-8
export EDITOR='nvim'
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export PATH="$HOME/.rbenv/bin:$PATH"
export MANPATH="/usr/local/man:$MANPATH"
# export ARCHFLAGS="-arch x86_64"
# export SSH_KEY_PATH="~/.ssh/dsa_id"
export SLACK_WEBHOOK_URI="https://hooks.slack.com/services/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"


###############################
# Inits, sourcing and plugins
###############################

plugins=(git z gem zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh
eval "$(rbenv init -)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
ZSH_THEME_GIT_PROMPT_PREFIX="(%{$fg[white]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{\e[0;34m%}%B)"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}*"
