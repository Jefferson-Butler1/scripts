#!/bin/zsh

# Function to create aliases for scripts in ~/scripts/*
function create_script_aliases() {
    local script_dir="$HOME/scripts"
    
    # Check if the scripts directory exists
    if [[ -d "$script_dir" ]]; then
        # Loop through all files in the scripts directory
        for script in "$script_dir"/*; do
            if [[ -f "$script" && -x "$script" ]]; then
                # Get the base name of the script without extension
                local alias_name=$(basename "$script" .sh)
                # Create an alias
                alias "$alias_name"="$script"
            fi
        done
    else
        echo "Warning: $script_dir does not exist."
    fi
}

# Call the function to create aliases
create_script_aliases

