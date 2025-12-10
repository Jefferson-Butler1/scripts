#!/usr/bin/env bash

CATEGORIES=(
  "OE"
  "CONFIG"
  "PROGRAMMING"
  "WASTED"
  "STOP"
)

selected=$(printf "%s\n" "${CATEGORIES[@]}" | fzf)

if [[ "$selected" == "STOP" ]]; then
  timew stop
  tmux set -g status-right ""
else
  timew start "$selected"
  tmux set -g status-right "$selected"
fi
