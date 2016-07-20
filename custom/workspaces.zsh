tmux_go() {
  if [ $TMUX ]
  then
    tmux switch -t $SESSION
  else 
    tmux attach -t $SESSION
  fi
}

tmux_base_session_and_windows() {
    tmux new-session -d -s $SESSION
    tmux new-window -t $SESSION:2 -n 'editor'
    tmux new-window -t $SESSION:3 -n 'test'
    tmux send-keys -t $SESSION:2 "vim" C-m
    tmux select-window -t $SESSION:2
}


glide () {
  SESSION="Glider"
  cd ~/Work/Gliderpath

  docker restart postgres&
  docker restart redis&
  docker restart elastic&

  tmux has-session -t $SESSION
  if [ $? != 0 ]
  then
    tmux new-session -d -s sidekiq 'sidekiq -C config/sidekiq.yml'
    tmux_base_session_and_windows
  fi

  tmux_go
}

dev_vene () {
  SESSION="Vene"
  cd ~/Work/Vene/backend

  docker restart postgres&
  docker restart redis&
  docker restart neo4j&

  tmux has-session -t $SESSION
  if [ $? != 0 ]
  then
    # tmux new-session -d -s revine-front 'http-server /home/x/Work/revine-frontend/www'
    tmux_base_session_and_windows
  fi

  tmux_go
}

dev_vanman () {
  SESSION="VanMan"
  cd ~/Work/vanman

  docker restart postgres&

  tmux has-session -t $SESSION
  if [ $? != 0 ]
  then
    tmux_base_session_and_windows
  fi

  tmux_go
}


dev_blog () {
  SESSION="Blog"
  cd ~/Work/vasspilka.github.io

  tmux has-session -t $SESSION
  if [ $? != 0 ]
  then
    tmux_base_session_and_windows
    tmux send-keys -t $SESSION:1 "rake" C-m
  fi

  tmux_go
}

zen_mode () {
  SESSION="Zen"
  cd ~/misc/LJ

  tmux has-session -t $SESSION
  if [ $? != 0 ]
  then
    tmux new-session -d -s $SESSION
    tmux send-keys -t $SESSION:1 "vim -c ZenmodeToggle" C-m
  fi

  tmux_go
}

ruby_meetup_27 () {
  SESSION="Ruby Meetup 27"
  cd ~/Work/ruby_meetup_27

  tmux has-session -t $SESSION
  if [ $? != 0 ]
  then
    tmux new-session -d -s $SESSION
    tmux new-window     -t $SESSION:2 -n 'vim'
    tmux new-window     -t $SESSION:3 -n 'notes'
    tmux send-keys      -t $SESSION:2 "vim" C-m
    tmux rename-window  -t $SESSION:1 'term'
    tmux select-window  -t $SESSION:1
  fi

  tmux_go

}
