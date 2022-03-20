#!/bin/bash


install_dev_tools() {
  # Global version manager +++
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.7.7

  # Starship prompt ++
  curl -sS https://starship.rs/install.sh | sh


  # fzf install
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install

  # Fish
  # mkdir -p ~/.config/fish/completions; and cp ~/.asdf/completions/asdf.fish ~/.config/fish/completions

  # Zsh stuff
  # sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  curl -L git.io/antigen > ~/antigen.zsh
}

echo "Linking Dotfiles"
for file in $(ls -A | grep "^\.[a-z]" |  grep -v ".git" | grep -v ".DS_Store" | grep -v ".config")
do
  rm -rf ~/$file
  ln -v -s `pwd`/$file ~
done

# echo "Setup .config"
# for file in $(ls -A .config)
# do
#   rm -rf ~/$file
#   ln -v -s `pwd`/$file ~
# done
