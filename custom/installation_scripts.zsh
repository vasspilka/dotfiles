install_everything! () {
  install_packages_pac
  install_rbenv
  install_linux_brew
  install_docker_cont
  link_libudev
}

install_packages_pac () {
  pac -S zsh docker skype tmux neovim the_silver_searcher xclip nodejs python-virtualenv
  yaourt -S google-chrome
  yaourt -S atom-editor
  yaourt -S ruby-build
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
  docker run -p 5432:5432 -v /run/postgresql:/run/postgresql -d --name postgres postgres -c 'shared_buffers=512MB' -c 'max_connections=400'
}

link_libudev () {
  sudo ln -s /usr/lib/libudev.so /usr/lib/libudev.so.0
}
