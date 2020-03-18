#!/bin/bash


echo "Dotfiles"
for file in $(ls -A | grep "^\.[a-z]"| grep -v '.git$\|.gitmodules$\|\.gitignore$')
do
  rm -rf ~/$file
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
