#!/bin/bash


if [[ "$OSTYPE" == "linux-gnu" ]]; then
elif [[ "$OSTYPE" == "darwin"* ]]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" 

  brew install rg fd wget
  brew install emacs
end


install_dev_tools() {
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  git clone https://github.com/gusaiani/elixir-oh-my-zsh.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/elixir
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.7.7
}

git clone https://github.com/syl20bnr/spacemacs ~/.spacemacs.d
git clone https://github.com/hlissner/doom-emacs ~/.doom-emacs
doom install

wget -O ~/.emacs https://raw.githubusercontent.com/plexus/chemacs/master/.emacs

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
