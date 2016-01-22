glide () {
  SESSION="Glider"
  cd /home/x/Work/Gliderpath

  docker restart postgres
  docker restart redis
  docker restart elastic

  tmux new-session -d -s sidekiq 'sidekiq -C config/sidekiq.yml'
  tmux new-session -d -s $SESSION

  tmux new-window -t $SESSION:2 -n 'Vim'
  tmux new-window -t $SESSION:3 -n 'Console'

  tmux send-keys -t $SESSION:1 "rails s" C-m
  tmux send-keys -t $SESSION:2 "vim" C-m

  tmux select-window -t $SESSION:2

  chrome http://alexey.lvh.me:3000
  tmux attach-session -t $SESSION
}

dev_revine () {
  SESSION="Revine"
  cd '/home/x/Work/Revine'

  docker restart postgres
  docker restart redis

  tmux new-session -d -s revine-front 'http-server /home/x/Work/revine-frontend/www'
  tmux -2 new-session -d -s $SESSION

  tmux new-window -t $SESSION:2 -n 'Back'
  tmux new-window -t $SESSION:3 -n 'Front'
  tmux new-window -t $SESSION:4 -n 'Console'

  tmux send-keys -t $SESSION:1 "rails s -p 8030" C-m
  tmux send-keys -t $SESSION:2 "vim" C-m
  tmux send-keys -t $SESSION:3 "rails c" C-m
  tmux send-keys -t $SESSION:4 "cd /home/x/Work/revine-frontend && vim" C-m

  tmux select-window -t $SESSION:2

  chrome http://gorevine.dev:8080
  tmux -2 attach-session -t $SESSION
}

dev_blog () {
  SESSION="Blog"
  cd /home/x/Work/vasspilka.github.io

  tmux -2 new-session -d -s $SESSION

  tmux new-window -t $SESSION:2 -n 'Vim'
  tmux new-window -t $SESSION:3 -n 'Console'
  tmux select-window -t $SESSION:2

  tmux send-keys -t $SESSION:1 "rake" C-m
  tmux send-keys -t $SESSION:2 "vim" C-m

  tmux -2 attach-session -t $SESSION
}
