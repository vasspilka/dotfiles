export ZSH=~/.oh-my-zsh

ZSH_THEME="xiong-chi-btd"
TERM=xterm-256color

alias pac="sudo pacman"
alias pacup="sudo pacman -Suy"
alias apti="sudo apt-get install"
alias aptup="sudo apt-get update && sudo apt-get upgrade"

alias gpds="git push && ./deploy.sh staging"
#alias tmux="tmux -2"

alias vim="nvim"
alias szsh="vim ~/.zshrc"
alias svim="vim ~/.vimrc"
alias snote="vim ~/.note"
alias scustom="cd /home/x/custom; vim; popd"

alias mine='sudo chown -R $USER'
alias drun='docker run -it --rm'
alias cordova='drun --privileged -v /dev/bus/usb:/dev/bus/usb -v $PWD:/src cordova cordova'

alias compose='docker-compose'

alias tail='tail -f'
alias be='bundle exec'
alias rake='bundle exec rake'



# Typo aliases
alias -g rpsec='rspec'

testingspec () {
  bundle exec rake
  echo $?
  if [ $? -ne 1 ]; then
   echo "test"
  fi
}

mkcd () {
    mkdir -p "$*"
    cd "$*"
}

cdl () {
    cd "$*"
    ls -la
}

gacm () {
  git add .
  git commit -m "$1"
}

gamend () {
    git add .
    git commit --amend
}

gamrc () {
    git add .
    git commit --amend
    git rebase --continue
}

btc () {
    curl -s http://api.coindesk.com/v1/bpi/currentprice.json | python -c "import json, sys; print(json.load(sys.stdin)['bpi']['EUR']['rate'])"
}

d_init () {
  docker start postgres
  docker start redis
  docker start neo4j
}

docker_stop () {
  docker kill $(docker ps -q)
}

docker_wipe () {
  docker kill $(docker ps -q)
  docker rm $(docker ps -a -q)
  docker rmi $(docker images -q)
  sudo ~/.oh-my-zsh/custom/docker-cleanup-volumes/docker-cleanup-volumes.sh
}

git_pull_dir () {
  CUR_DIR=$(pwd)

  echo "\n\033[1mPulling in latest changes for all repositories...\033[0m\n"

  for i in $(find . -name ".git" | cut -c 3-); do
    echo "";
    echo "\033[33m"+$i+"\033[0m";
    cd "$i";
    cd ..;

    git pull origin master;

    cd $CUR_DIR
  done

  echo "\n\033[32mComplete!\033[0m\n"
}

psql () {
  if (($# == 0)) then
    docker run -it --link postgres:postgres --rm postgres sh -c 'exec psql -h "$POSTGRES_PORT_5432_TCP_ADDR" -p "$POSTGRES_PORT_5432_TCP_PORT" -U postgres'
  else
    docker run -it --link postgres:postgres --rm postgres sh -c "exec psql $*"
  fi
}

alias -s html=vim
alias -s php=vim
alias -s css=vim
alias -s js=vim
alias -s py=vim
alias -s sql=vim
alias -s cpp=vim
alias -s y=vim
alias -s c=vim
alias -s h=vim
alias -s txt=vim
alias -s log=tail

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to disable command auto-correction.
# DISABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

HIST_STAMPS="dd/mm/yyyy"

plugins=(z git zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:"

# Yay for brew on linux
export PATH="$HOME/.linuxbrew/bin:$PATH"
export MANPATH="$HOME/.linuxbrew/share/man:$MANPATH"
export INFOPATH="$HOME/.linuxbrew/share/info:$INFOPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"


autoload -Uz zcalc
bindkey ' ' magic-space

# rbenv 
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
