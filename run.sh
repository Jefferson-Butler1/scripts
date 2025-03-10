#!/bin/bash
source /users/jeff/.nvm/nvm.sh

# Set errexit and pipefail options for better error handling
set -eo pipefail

# Define color codes
readonly RED=$'\e[0;31m'
readonly GREEN=$'\e[0;32m'
readonly BLUE=$'\e[0;34m'
readonly NC=$'\e[0m' # No Color

readonly BE_PORTS=(8080)
readonly FE_PORTS=(9090 9191)

function killports {
  # local killed=false
  for port in "$@"; do
    echo -e "Clearing :$port"
    pids=$(lsof -ti:"$port")
    for pid in "${pids[@]}"; do
      echo -e "${RED}Killing ${pid}${NC}"
      kill -9 "$pid" 2>/dev/null || true
      # killed=true
    done
  done
  # Not necessary in current setup, option to flag if any processies were killed
  # if $killed; then exit 0; else exit 1; fi
}

function start_docker {
  if [[ $(docker ps | grep -c v3-nest) -eq 0 ]]; then
    open -a Docker
    docker compose up -d
    if [[ $(docker ps | grep -c local-db-clone) -eq 0 ]]; then
      docker start local-db-clone
    fi
  else
    echo "Docker already running"
  fi
}

function run_be {
  echo -e "${BLUE}Starting Nest... ${NC}"
  (
    cd "$OE"/v3-nest &&
      nvm install 18.13.0 &&
      nvm use 18.13.0 &&
      yarn install &&
      start_docker &&
      killports "${BE_PORTS[@]}" &&
      yarn run dev | sed "s/^/${BLUE}[BE]${NC} /"
  ) &
}

function run_fe {
  echo -e "${GREEN} Starting Next... ${NC}"
  (
    cd "$OE"/v3-monorepo &&
      nvm install 22.13.1 &&
      nvm use 22.13.1 &&
      yarn install &&
      killports "${FE_PORTS[@]}" &&
      yarn run all-dev | sed "s/^/${GREEN}[FE]${NC} /"
  ) &

}

case "${1}" in
  "fe")
    run_fe
    ;;
  "be")
    run_be
    ;;
  "all")
    run_fe &
    run_be &
    ;;
esac

wait
