#!/bin/zsh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Ports to manage
PORTS=(8080 9191 9090 9292)

# Function to list Node processes
list_processes() {
    echo -e "${YELLOW}Node processes using ports ${PORTS[*]}:${NC}"
    for port in "${PORTS[@]}"; do
        echo "Port $port:"
        lsof -i :$port -sTCP:LISTEN | grep node || echo "No Node.js process found on port $port"
    done
}

# Function to kill Node processes
kill_processes() {
    local killed=false
    for port in "${PORTS[@]}"; do
        pids=$(lsof -ti:$port -sTCP:LISTEN)
        if [ -n "$pids" ]; then
            echo -e "${RED}Killing Node processes on port $port...${NC}"
            echo "$pids" | xargs kill -9
            killed=true
        fi
    done
    if $killed; then
        echo -e "${GREEN}Node processes killed.${NC}"
    else
        echo -e "${YELLOW}No Node processes to kill.${NC}"
    fi
}

# Check if -k argument is provided
if [[ "$1" == "-k" ]]; then
    kill_processes
    exit 0
fi

# Main script
list_processes

# Prompt user for action
while true; do
    print -n "${YELLOW}[K]ill all Node processes or [Q]uit ${NC}"
    read -k1 choice
    echo ""  # Move to a new line
    case "${(L)choice}" in
        k)
            kill_processes
            break
            ;;
        q)
            echo -e "${GREEN}Exiting without killing processes.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter either [K]ill or [Q]uit${NC}"
            ;;
    esac
done
