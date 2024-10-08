#!/bin/bash

# Find the most recently modified file in ~/Downloads
recent_file=$(ls -t ~/Downloads | head -n1)

# target directory
target=${1:-.}

# Check if a file was found
if [ -n "$recent_file" ]; then
    # Move the file to the current directory
    mv ~/Downloads/"$recent_file" "$target"
    echo "Moved '$recent_file' to '$target'."
else
    echo "No files found in ~/Downloads."
fi
