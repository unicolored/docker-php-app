#! /bin/bash

# https://tmuxcheatsheet.com/

session=$(jq .name composer.json)

tmux has-session -t $session 2>/dev/null

if [ $? != 0 ]; then
  #tmux new-session -d -s $session -n $window_name

  # Start new session with a name

  window_name="editor"
  tmux new-session -d -s $session -n $window_name
  tmux send-keys -t $session:$window_name "nvim" C-m

  name="up"
  tmux new-window -n $name
  tmux send-keys -t $session:$name 'bash script/build.sh'

  server_name="lazydocker"
  tmux new-window -n $server_name
  tmux send-keys -t $session:$server_name 'lazydocker' C-m

  tmux select-window -t $session:$window_name
fi

tmux attach-session -t $session
