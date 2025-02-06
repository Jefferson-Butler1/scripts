#!/bin/bash

# Run the `gh pr diff` command and capture its exit status
gh pr diff --color always | less -R
exit_status=$?

# Check if the command failed
if [ $exit_status -ne 0 ]; then
    echo "Error: 'gh pr diff' command failed with exit status $exit_status"
    exit $exit_status
fi
