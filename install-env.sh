#!/bin/bash

# This is a home-built script to help me create reproducible MacOS environments. 
# Do not use, or if you do be sure you understand everything before running it -- it's possible it will brick your machine

# Helper function for error handling
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

echo "Installing Homebrew if not present..."
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    check_error "Failed to install Homebrew"
fi

echo "Installing stow via Homebrew..."
brew install stow
check_error "Failed to install stow"

echo "Installing nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
check_error "Failed to install nvm"

# Load nvm immediately
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

echo "Installing latest LTS version of Node.js..."
nvm install --lts
check_error "Failed to install Node.js LTS"

echo "Installing Starship..."
curl -sS https://starship.rs/install.sh | sh
check_error "Failed to install Starship"

if [ -d "$HOME/dotfiles" ]; then
    cd "$HOME/dotfiles"
    stow starship
    check_error "Failed to stow starship configuration"
else
    echo "Warning: ~/dotfiles directory not found. Please clone your dotfiles repository first."
fi

# Create a temporary script to source the shell
cat > /tmp/source_shell.sh << 'EOF'
#!/bin/bash
if [ -n "$ZSH_VERSION" ]; then
    source ~/.zshrc
elif [ -n "$BASH_VERSION" ]; then
    source ~/.bashrc
fi
EOF

chmod +x /tmp/source_shell.sh
echo "Installation complete! Reloading shell configuration..."
exec /tmp/source_shell.sh
