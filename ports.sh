#!/bin/zsh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to list processes
list_processes() {
    echo -e "${YELLOW}Processes using ports 8080, 9191, and 9090:${NC}"
    lsof -P -i :8080,9191,9090,9292
}

# Function to kill processes
kill_processes() {
    pids=($(lsof -t -i :8080,9191,9090,9292))
    if [ ${#pids[@]} -gt 0 ]; then
        echo -e "${RED}Killing processes...${NC}"
        for pid in "${pids[@]}"; do
            kill -9 "$pid" 2>/dev/null
        done
        echo -e "${GREEN}Processes killed.${NC}"
    else
        echo -e "${YELLOW}No processes to kill.${NC}"
    fi
}

# Main script
list_processes

# Prompt user for action
while true; do
    print -n "${YELLOW}[K]ill all or [Q]uit${NC}"
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
