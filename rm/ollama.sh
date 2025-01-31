#!/bin/bash

# Create build directory
BUILD_DIR=$(mktemp -d)
echo "Created temporary build directory: $BUILD_DIR"
cd "$BUILD_DIR" || exit

# Install dependencies if needed
if ! command -v go &> /dev/null; then
    echo "Installing Go..."
    brew install go
fi

if ! command -v git &> /dev/null; then
    echo "Installing Git..."
    brew install git
fi

# Clone Ollama
echo "Cloning Ollama repository..."
git clone https://github.com/ollama/ollama.git
cd ollama || exit

# Force ARM64 build regardless of Terminal architecture
export GOARCH=arm64
export GOOS=darwin
export CGO_ENABLED=1

# Build
echo "Building Ollama for ARM64..."
go generate ./...
go build -o ollama

# Move to a known location
echo "Moving binary to /usr/local/bin..."
sudo mv ollama /usr/local/bin/
sudo chmod +x /usr/local/bin/ollama

# Clean up
cd
rm -rf "$BUILD_DIR"

echo "Build complete! Binary is at /usr/local/bin/ollama"
echo "Checking binary architecture:"
file /usr/local/bin/ollama

echo -e "\nTo start Ollama, run: ollama serve"
