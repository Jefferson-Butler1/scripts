#!/usr/bin/env bash

if [[ $# -eq 1 ]]; then
    selected=$1
else
    # Get directories
    dirs=$(fd --max-depth 1 --type d . ~/ ~/OE; fd --min-depth 2 --max-depth 2 --type d . ~/.config/superpowers/worktrees 2>/dev/null)

    # Get active tmux sessions
    active_sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null || echo "")

    # Sort directories: active sessions first, then alphabetically
    # Use vague.tmux yellow color #f3be7c (ANSI 222)
    sorted_dirs=$(echo "$dirs" | while read -r dir; do
        if [[ -n "$dir" ]]; then
            session_name=$(basename "$dir" | tr . _)
            if echo "$active_sessions" | grep -q "^${session_name}$"; then
                echo "0|$(printf '\033[38;5;222m%s\033[0m' "$dir")"  # Prefix with 0 and highlight active sessions
            else
                echo "1|$dir"  # Prefix with 1 for inactive
            fi
        fi
    done | sort | cut -d'|' -f2-)

    # Get SSH hosts from config
    hosts=$(grep "^Host " ~/.ssh/config | grep -v "\*" | awk '{print "ssh:" $2}')

    # Combine and let user select
    selected=$(echo -e "$sorted_dirs\n$hosts" | fzf --ansi)
fi

if [[ -z $selected ]]; then
    exit 0
fi

# Check if it's an SSH host
if [[ $selected == ssh:* ]]; then
    hostname=${selected#ssh:}
    selected_name=$(echo "$hostname" | tr . _)
    tmux_running=$(pgrep tmux)
    
    if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
        tmux new-session -s "$selected_name" -c ~ "ssh $hostname"
        exit 0
    fi
    
    if ! tmux has-session -t="$selected_name" 2> /dev/null; then
        tmux new-session -ds "$selected_name" -c ~ "ssh $hostname"
    fi
    
    tmux switch-client -t "$selected_name" || tmux attach -t "$selected_name"
else
    # Regular directory handling
    selected_name=$(basename "$selected" | tr . _)
    tmux_running=$(pgrep tmux)
    
    if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
        tmux new-session -s "$selected_name" -c "$selected"
        exit 0
    fi
    
    if ! tmux has-session -t="$selected_name" 2> /dev/null; then
        tmux new-session -ds "$selected_name" -c "$selected"
    fi
    
    tmux switch-client -t "$selected_name" || tmux attach -t "$selected_name"
fi
