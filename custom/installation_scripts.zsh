install_everything! () {
  install_packages_pac
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

install_docker_cont () {
  docker run -p 5432:5432 -v /run/postgresql:/run/postgresql -d --name postgres postgres -c 'shared_buffers=512MB' -c 'max_connections=400'
}

link_libudev () {
  sudo ln -s /usr/lib/libudev.so /usr/lib/libudev.so.0
}
