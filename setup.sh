#!/bin/bash

set -e

SHARED_PACKAGES=(
  # Version control
  "git"
  "gh"
  "lazygit"

  # Shell & terminal
  "fish"
  "tmux"
  "mosh"
  "fnm"

  # Modern CLI tools
  "bat"
  "ripgrep"
  "fzf"
  "dust"
  "tree"
  "ranger"
  "tldr"
  "watch"

  # Build tools
  "ninja"
  "gettext"
  "curl"

  # Languages & runtimes
  "node"
  "go"

  # Package managers
  "pnpm"
  "yarn"
  "uv"

  # Utilities
  "sqlite"
  "zstd"
  "gnupg"
  "stow"
  "tailscale"
)

MACOS_PACKAGES=(
  "libtool"
  "terminal-notifier"
  "font-meslo-lg-nerd-font"
)

ARCH_PACKAGES=(
  "base-devel"
  "cmake"
  "unzip"
)

# curl install commands
curl https://sh.rustup.rs -sSf | sh
curl -fsSL https://claude.ai/install.sh | bash

echo "Cloning dotfiles..."
DOTFILES_DIR="$HOME/dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
  git clone https://github.com/Jefferson-Butler1/dotfiles.git "$DOTFILES_DIR"
else
  echo "Dotfiles already exist, pulling latest..."
  (cd "$DOTFILES_DIR" && git pull)
fi

case "$OSTYPE" in
darwin*)
  echo "Detected macOS"

  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo "Upgrading Homebrew..."
    brew upgrade --quiet 2>&1 | grep -E "(==>|=>|\[)"
    brew upgrade --quiet | grep -E "(==>|=>|\[)"
  fi

  echo "Installing packages..."
  brew install "${SHARED_PACKAGES[@]}" "${MACOS_PACKAGES[@]}"

  echo "Stowing macOS configurations..."
  cd "$DOTFILES_DIR"
  stow ghostty
  stow raycast
  ;;

linux-gnu*)
  echo "Detected Linux"

  if ! command -v yay &>/dev/null; then
    echo "Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
  else
    echo "Upgrading yay..."
    yay -Syu --noconfirm
  fi

  echo "Installing packages..."
  yay -S --noconfirm "${SHARED_PACKAGES[@]}" "${ARCH_PACKAGES[@]}"
  ;;

*)
  echo "Unknown OS: $OSTYPE"
  exit 1
  ;;
esac

echo "Building Neovim from source..."
TMP_DIR=$(mktemp -d)
INSTALL_DIR="$HOME/.local"
mkdir -p "$INSTALL_DIR/bin"

(
  cd "$TMP_DIR"
  git clone https://github.com/neovim/neovim.git
  cd neovim
  make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$INSTALL_DIR"
  make install
)
rm -rf "$TMP_DIR"

if [[ ":$PATH:" != *":$INSTALL_DIR/bin:"* ]]; then
  echo "Adding ~/.local/bin to PATH..."
  echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.bashrc
  echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.config/fish/config.fish
fi

echo "Stowing core configurations..."
(
  cd "$DOTFILES_DIR"
  stow tmux
  stow nvim
  stow fish
  stow git
  stow lazygit
  stow starship
  stow ssh
  stow btop
)

echo "Setting fish as default shell..."
FISH_PATH=$(command -v fish)
if [ -n "$FISH_PATH" ]; then
  if ! grep -q "$FISH_PATH" /etc/shells; then
    echo "Adding fish to /etc/shells..."
    echo "$FISH_PATH" | sudo tee -a /etc/shells
  fi

  if [ "$SHELL" != "$FISH_PATH" ]; then
    chsh -s "$FISH_PATH"
  fi
fi

echo "Setting up Tailscale..."
case "$OSTYPE" in
darwin*)
  sudo tailscale up
  ;;
linux-gnu*)
  sudo systemctl enable --now tailscaled
  sudo tailscale up
  ;;
esac

echo "Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash

echo "Setup complete!"
