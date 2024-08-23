#!/bin/bash

# Directory containing your scripts
SCRIPT_DIR="$scripts"

# Directory to store symlinks (should be in your PATH)
SYMLINK_DIR="$HOME/.local/bin"

# Create SYMLINK_DIR if it doesn't exist
mkdir -p "$SYMLINK_DIR"

# Function to create symlinks for scripts
create_script_symlinks() {
    # Check if the scripts directory exists
    if [[ ! -d "$SCRIPT_DIR" ]]; then
        echo "Warning: $SCRIPT_DIR does not exist."
        return 1
    fi

    # Loop through all files in the scripts directory
    for script in "$SCRIPT_DIR"/*; do
        if [[ -f "$script" && -x "$script" ]]; then
            # Get the base name of the script without extension
            local symlink_name=$(basename "$script" .sh)
            local symlink_path="$SYMLINK_DIR/$symlink_name"

            # Create or update symlink
            if [[ -L "$symlink_path" ]]; then
                # Symlink exists, update if necessary
                if [[ "$(readlink "$symlink_path")" != "$script" ]]; then
                    ln -sf "$script" "$symlink_path"
                    echo "Updated symlink: $symlink_name"
                fi
            else
                # Create new symlink
                ln -s "$script" "$symlink_path"
                echo "Created symlink: $symlink_name"
            fi
        fi
    done
}

# Call the function to create symlinks
create_script_symlinks

