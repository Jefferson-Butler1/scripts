#!/usr/bin/env zsh

# Set errexit and pipefail options for better error handling
set -eo pipefail

# Define color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Function to find directory
find_directory() {
    local dir_name=$1
    local found_dir=$(find ~/WebstormProjects -type d -name "$dir_name" -print -quit 2>/dev/null)
    if [[ -z "$found_dir" ]]; then
        echo -e "${RED}Error: Directory '$dir_name' not found.${NC}" >&2
        exit 1
    fi
    echo "$found_dir"
}

# Find directories
readonly BE_DIR=$(find_directory "v3-nest")
readonly FE_DIR=$(find_directory "v3-monorepo")

# Define constants for port numbers
readonly BE_PORT=8080
readonly FE_PORTS=(9090 9191)
readonly ALL_PORTS=($BE_PORT ${FE_PORTS[@]})

function run_be {
    echo -e "${BLUE}Starting backend...${NC}"
    (
        cd "$BE_DIR" || exit 1
        echo -e "${BLUE}Changed to directory: $BE_DIR${NC}"
        yarn install
        if ! command -v docker-compose &> /dev/null; then
            echo -e "${RED}docker-compose not found. Please install it.${NC}"
            exit 1
        fi
        open -a Docker
        docker-compose up -d
        kill_process_on_port $BE_PORT
        yarn run dev | sed "s/^/[BE] /"
    ) &
}

function run_fe {
    echo -e "${GREEN}Starting frontend...${NC}"
    (
        cd "$FE_DIR" || exit 1
        echo -e "${GREEN}Changed to directory: $FE_DIR${NC}"
        for port in "${FE_PORTS[@]}"; do
            kill_process_on_port $port
        done
        if ! lsof -i:$BE_PORT &> /dev/null; then
            echo -e "${RED}Warning: Backend is not running. You may want to start it.${NC}"
        fi
        yarn install
        FORCE_COLOR=1 yarn run all-dev | sed -u 's/^/[FE] /'
    ) &
}

function kill_process_on_port {
    local port=$1
    lsof -ti:$port | xargs kill -9 2>/dev/null || true
}

function stop_all {
    echo -e "${RED}Stopping all processes on specified ports...${NC}"
    for port in "${ALL_PORTS[@]}"; do
        kill_process_on_port $port
    done
    list_processes
}

function list_processes {
    echo -e "${BLUE}Listing processes on specified ports...${NC}"
    lsof -i :$(IFS=,; echo "${ALL_PORTS[*]}")
}

function run_all {
    echo -e "${BLUE}Running full stack...${NC}"
    run_be
    run_fe
    # Keep the script running
}

# Main execution
case "${1:-}" in
    ""|"run")
        run_all
        ;;
    "stop" | "kill")
        stop_all
        ;;
    *)
        echo "Usage: $0 [run|stop]"
        echo "  - Without arguments or 'run': starts both apps"
        echo "  - 'stop': kills all processes on specified ports and lists remaining processes"
        exit 1
        ;;
esac
