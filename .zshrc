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

alias  szsh="vim ~/.zshrc"
alias stmux="vim ~/.tmux.conf"
alias  svim="vim ~/.vimrc"
alias snote="vim ~/.note"
alias scustom="cd /home/x/custom; vim; popd"

alias -g rpsec="rspec"

######################
## Custom vars
######################

Work="~/Work"

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


###############################
# Inits, sourcing and plugins
###############################

plugins=(git z gem)

source $ZSH/oh-my-zsh.sh
eval "$(rbenv init -)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
