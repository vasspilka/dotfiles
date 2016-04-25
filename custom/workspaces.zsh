glide () {
  SESSION="Glider"
  cd /home/x/Work/Gliderpath

  docker restart postgres
  docker restart redis
  docker restart elastic

  tmux has-session -t $SESSION
  if [ $? != 0 ]
  then
    tmux new-session -d -s sidekiq 'sidekiq -C config/sidekiq.yml'
    tmux new-session -d -s $SESSION

    tmux new-window -t $SESSION:2 -n 'editor'
    tmux new-window -t $SESSION:3 -n 'test'

    tmux send-keys -t $SESSION:2 "vim" C-m
    tmux select-window -t $SESSION:2
  fi

  if [ $TMUX ]
  then
    tmux switch -t $SESSION
  else 
    tmux attach -t $SESSION
  fi
}

dev_revine () {
  SESSION="Revine"
  cd '/home/x/Work/Revine'

  docker restart postgres
  docker restart redis

  tmux has-session -t $SESSION
  if [ $? != 0 ]
  then
    # tmux new-session -d -s revine-front 'http-server /home/x/Work/revine-frontend/www'
    tmux new-session -d -s $SESSION

    tmux new-window -t $SESSION:2 -n 'editor'
    tmux new-window -t $SESSION:3 -n 'test'

    tmux send-keys -t $SESSION:2 "vim" C-m
    tmux send-keys -t $SESSION:3 "rails c" C-m

    tmux select-window -t $SESSION:2
  fi

  if [ $TMUX ]
  then
    tmux switch -t $SESSION
  else 
    tmux attach -t $SESSION
  fi
}

dev_blog () {
  SESSION="Blog"
  cd /home/x/Work/vasspilka.github.io

  tmux has-session -t $SESSION
  if [ $? != 0 ]
  then
    tmux new-session -d -s $SESSION

    tmux new-window -t $SESSION:2 -n 'editor'
    tmux new-window -t $SESSION:3
    tmux select-window -t $SESSION:2

    tmux send-keys -t $SESSION:1 "rake" C-m
    tmux send-keys -t $SESSION:2 "vim" C-m
  fi

  if [ $TMUX ]
  then
    tmux switch -t $SESSION
  else 
    tmux attach -t $SESSION
  fi
}
