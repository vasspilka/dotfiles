#!/bin/bash

cd "$(dirname "$0")"

git submodule init
git submodule update

echo "Dotfiles"
for file in $(ls -A | grep "^\.[a-z]"| grep -v '.git$\|.gitmodules$\|\.gitignore$')
do
  ln -v -s `pwd`/$file ~
done

echo "Custom zsh files"
for file in $(ls -A custom)
do
  ln -v -s `pwd`/custom/$file ~/.oh-my-zsh/custom
done
for file in $(ls -A custom/plugins)
do
  ln -v -s `pwd`/custom/plugins/$file ~/.oh-my-zsh/custom/plugins 
done


read -p "You use neovim yet? y/n"
if [[ $REPLY =~ ^[Yy]$ ]]
then
  mkdir ~/.config
  rm -rf ~/.config/nvim
  ln -s ~/.vim ~/.config/nvim
  ln -s ~/.vimrc ~/.config/nvim/init.vim
fi
