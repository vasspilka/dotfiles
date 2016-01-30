install_everything! () {
  install_packages_pac
  install_docker_cont
  install_rbenv
  install_linux_brew
}

install_packages_pac () {
  pac -S zsh docker skype tmux vim the_silver_searcher xclip nodejs
  yaourt -S google-chrome atom-editor
}

install_linux_brew () {
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/linuxbrew/go/install)"
}

install_rvm () {
  gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
  \curl -sSL https://get.rvm.io | bash -s stable --ruby=2.3.0
}

install_rbenv () {
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv
  cd ~/.rbenv && src/configure && make -C src
}

install_docker_cont () {
  docker run -p 5432:5432 -d --name postgres postgres
  docker run -p 6379:6379 -d --name redis redis
  docker run -p 9200:9200 -p 9300:9300 -d --name elastic elasticsearch
}

