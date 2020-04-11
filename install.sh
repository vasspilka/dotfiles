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

  # Rust ++
  $ curl https://sh.rustup.rs -sSf | sh

  # Starship prompt ++
  curl -fsSL https://starship.rs/install.sh | bash

  # Zsh stuff
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  curl -L git.io/antigen > ~/antigen.zsh
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
