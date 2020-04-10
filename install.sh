#!/bin/bash

## if [[ "$OSTYPE" == "linux-gnu" ]]; then
if [[ "$OSTYPE" == "darwin"* ]]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

  brew install rg fd wget
  brew install emacs
fi


install_dev_tools() {
  # Global version manager +++
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.7.7

  # Starship prompt ++
  curl -fsSL https://starship.rs/install.sh | bash

  # Zsh stuff
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  # TODO: install plugins with antigen
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  git clone https://github.com/gusaiani/elixir-oh-my-zsh.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/elixir
}

install_emacs() {
  git clone https://github.com/syl20bnr/spacemacs ~/.spacemacs.d
  git clone https://github.com/hlissner/doom-emacs ~/.doom-emacs
  doom install

  wget -O ~/.emacs https://raw.githubusercontent.com/plexus/chemacs/master/.emacs
}  > ~/.dotinstall.tmp

echo "Dotfiles"
for file in $(ls -A | grep "^\.[a-z]"| grep -v '.git$\|.gitmodules$\|\.gitignore$|\.config$')
do
  rm -rf ~/$file
  ln -v -s `pwd`/$file ~
done
