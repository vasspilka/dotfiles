###########################
# ZSH DEFAULTS
###########################

ZSH_THEME="xiong-chiamiov-plus"
ZSH="$HOME/.oh-my-zsh"
TERM=xterm-256color
COMPLETION_WAITING_DOTS="true"
ENABLE_CORRECTION="true"
BROWSER="/usr/bin/firefox-developer"
TIMBER_LOGS_KEY="1865_65d5ad3e5c527387:c0efdc3425f4ef401494bb7e40baa7c269865ad9d3492dba2b532ef778872691"

autoload bashcompinit
bashcompinit

# CASE_SENSITIVE="true"
# HYPHEN_INSENSITIVE="true"
# DISABLE_AUTO_TITLE="true"
# source "~/.zshenv"

#####################
## SSH
#####################

eval `keychain --eval --agents ssh vasspilka`
# if ! pgrep -u "$USER" ssh-agent > /dev/null; then
# fi
# if [[ "$SSH_AGENT_PID" == "" ]]; then
# fi



#####################
## Aliases
#####################

alias   e="emacs --with-profile doom -nw"
alias pac="sudo pacman"
alias doom="~/.doom-emacs/bin/doom"


alias  yi="yarn install"
alias  ys="yarn start"
alias  yt="yarn test"
alias  yb="yarn build"


alias  scustom="cd /home/x/custom; vim; popd"
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
alias ptrr='mix ecto.reset && MIX_ENV=test mix ecto.reset'

## Git
alias gpds='git push && ./deploy.sh staging'
alias gamend='git commit -a --amend'
alias gitdeletemerged='git branch --merged | egrep -v "(^\*|master|dev)" | xargs git branch -d'

alias err='systemctl restart --user emacs'
alias est='systemctl stop    --user emacs'

## Places
alias Work="~/Work"
alias x="/home/x"

###############################
# Inits, sourcing and plugins
###############################

plugins=(git z elixir zsh-syntax-highlighting mix docker docker-compose)

source $HOME/.oh-my-zsh/oh-my-zsh.sh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
ZSH_THEME_GIT_PROMPT_SUFFIX="%{\e[0;34m%}%B)"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}*"

ERL_AFLAGS="-kernel shell_history enabled"


# No autocorrect
unsetopt correct_all

# sourcing
# source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# source /usr/share/nvm/init-nvm.sh

. $HOME/.asdf/asdf.sh

. $HOME/.asdf/completions/asdf.bash

export PATH=$HOME/.utrust-cli/bin:$PATH
export LOCAL_AWS_USERNAME="vasilis.spilka"
