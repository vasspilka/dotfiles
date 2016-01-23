#!/bin/bash

cd "$(dirname "$0")"

git submodule init
git submodule update

echo "Dotfiles"
for file in $(ls -A | grep -v 'custom$\|.git$\|.gitmodules$\|\.gitignore$\|install.sh$')
do
  ln -v -s `pwd`/$file ~
done

echo "Custom zsh files"
for file in $(ls -A custom)
do
  ln -v -s `pwd`/custom/$file ~/.oh-my-zsh/custom
done


read -p "You use neovim yet? y/n"
if [[ $REPLY =~ ^[Yy]$ ]]
then
  mkdir -p ${XDG_CONFIG_HOME:=$HOME/.config}
  ln -s ~/.vim $XDG_CONFIG_HOME/nvim
  ln -s ~/.vimrc $XDG_CONFIG_HOME/nvim/init.vim
fi
