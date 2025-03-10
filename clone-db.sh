#!/bin/bash
# clone-db.sh - Jeff's Postgres database cloning script
#
# Description:
#   Clones or restores a PostgreSQL database to a local Docker container or another PostgreSQL instance.
#   Can operate in two modes:
#     1. Restore from a backup file URL (using -b option, default)
#     2. Clone from an active PostgreSQL URL (using -c option)
#
# Usage:
#   ./clone-db.sh [options]
#   yarn clone-db [options]
#
# Options:
#   -h, --help                  Display this help message
#   -n, --name NAME             Docker container name (default: local-db-clone)
#   -p, --port PORT             Local port for Docker container (default: 5436)
#   -b, --backup-url URL        Source backup file URL (default: latest staging backup)
#   -c, --clone-url URL         Source PostgreSQL URL to clone from (active database)
#   -d, --destination-url URL   Destination PostgreSQL URL (optional, eg: review app db)
#   -v, --verbose               Enable verbose output (mostly logs from pg utils, should never be necessary)
#   --schema SCHEMA             Schema name for restoration (default: public)
#
# Examples:
#   ./clone-db.sh -b URL                # Restore from backup URL to local Docker
#   ./clone-db.sh -c URL                # Clone from running PostgreSQL URL to local Docker
#   ./clone-db.sh -b URL -d URL         # Restore from backup URL to destination
#   ./clone-db.sh -c URL -d URL         # Clone from running PostgreSQL URL to destination
#
# I've only tested this on my mac, I think that lsof and sed have different behaviour on linux
# so be careful of that

set -e

CONTAINER_NAME="local-db-clone"
PORT="5436"
BACKUP_URL="https://cloud-cube-us2.s3.amazonaws.com/o03u5q31l6d4/public/latest.dump"
CLONE_URL=""
DESTINATION_URL=""
SCHEMA_NAME="public"
VERBOSE=0
OPERATION_MODE=""

show_help() {
  grep -E '^#' "$0" | sed -e 's/^#//' -e 's/^#//'
  exit 0
}

readonly RED=$'\e[0;31m'
readonly YELLOW=$'\e[0;33m'
readonly GREEN=$'\e[0;32m'
readonly BLUE=$'\e[0;34m'
readonly NC=$'\e[0m' # No Color
log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "${BLUE} [INFO] ${NC} $1"
  fi
}

warn() {
  echo "${YELLOW}[WARNING]${NC} $1" >&2
}

error() {
  echo "${RED}[ERROR]${NC}$1" >&2
  exit 1
}

check_tool_available() {
  if ! command -v "$1" &>/dev/null; then
    error "$1 is not installed or not in PATH"
  fi
  log "$1 is available"
}
check_postgres_url() {
  local url="$1"
  local purpose="$2"

  if pg_isready -d "$url"; then
    log "$purpose PostgreSQL URL is accessible"
    return 0
  else
    if [ "$3" = "optional" ]; then
      warn "Cannot connect to $purpose PostgreSQL URL: $url (but continuing as this is optional)"
      return 1
    else
      error "Cannot connect to $purpose PostgreSQL URL: $url"
    fi
  fi
}

check_backup_url() {
  local url="$1"

  if ! curl --silent --head --fail "$url" &>/dev/null; then
    error "Cannot access backup URL: $url"
  fi
  log "Backup URL is accessible"
}

check_container_exists() {
  if [ "$(docker ps -a -q -f name=^/"${CONTAINER_NAME}"$)" ]; then
    log "Container with name '$CONTAINER_NAME' already exists"
    return 0
  else
    log "No container found with name '$CONTAINER_NAME'"
    return 1
  fi
}

check_port_available() {
  if [ "$(lsof -ti:"$PORT" | wc -l)" -ne 0 ]; then
    lsof -i:"$PORT"
    error "Port $PORT is already in use. Please specify a different port."
  else
    log "Port $PORT is available"
  fi
}

extract_postgres_details() {
  local url="$1"
  POSTGRES_USER=$(echo "$url" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
  POSTGRES_PASSWORD=$(echo "$url" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
  DB_NAME=$(echo "$url" | sed -n 's/.*\/\([^/?]*\).*/\1/p')

  if [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ] || [ -z "$DB_NAME" ]; then
    error "Failed to extract database credentials from URL. Check URL format."
  fi

  log "${GREEN}Successfully extracted database credentials${NC}"
  log "User: $POSTGRES_USER, Database: $DB_NAME"
}

create_postgres_container() {
  log "Creating PostgreSQL container '$CONTAINER_NAME' on port $PORT"

  if ! docker run -d --name "$CONTAINER_NAME" \
    -p "$PORT":5432 \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_DB="$DB_NAME" \
    postgres:15.9; then
    error "Failed to create PostgreSQL container"
  fi

  log "Waiting for PostgreSQL container to initialize..."
  sleep 3

  if [ "$(docker inspect -f {{.State.Running}} "$CONTAINER_NAME")" != "true" ]; then
    error "Container failed to start properly. Check docker logs."
  fi

  log "PostgreSQL container is running"
}

restore_backup_to_container() {
  log "Restoring database from backup $BACKUP_URL to container $CONTAINER_NAME"
  local container_url="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:$PORT/$DB_NAME"

  echo "Starting database restore from backup..."
  VERBOSE_FLAG=""
  [ "$VERBOSE" -eq 1 ] && VERBOSE_FLAG="--verbose"
  if ! curl -L "$BACKUP_URL" | pg_restore $VERBOSE_FLAG --clean --if-exists --schema "$SCHEMA_NAME" --no-owner --dbname "$container_url"; then
    warn "pg_restore completed with warnings or errors"
    # Don't exit with error as pg_restore often returns non-zero even for non-fatal issues
  fi

  echo "${GREEN}Successfully restored database to container${NC}"
  echo "Your new PostgreSQL URL is:"
  echo "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:$PORT/$DB_NAME"
}

restore_backup_to_destination() {
  log "Restoring database from backup $BACKUP_URL to $DESTINATION_URL"

  echo "Starting database restore from backup to destination..."
  VERBOSE_FLAG=""
  [ "$VERBOSE" -eq 1 ] && VERBOSE_FLAG="--verbose"
  if ! curl -L "$BACKUP_URL" | pg_restore $VERBOSE_FLAG --clean --if-exists --schema "$SCHEMA_NAME" --no-owner --dbname "$DESTINATION_URL"; then
    warn "pg_restore completed with warnings or errors"
    # Don't exit with error as pg_restore often returns non-zero even for non-fatal issues
  fi

  echo "Successfully restored database to destination URL"
}

clone_db_to_container() {
  log "Cloning database from $CLONE_URL to container $CONTAINER_NAME"
  local container_url="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:$PORT/$DB_NAME"

  echo "Starting database clone operation..."
  VERBOSE_FLAG=""
  [ "$VERBOSE" -eq 1 ] && VERBOSE_FLAG="--verbose"

  if ! docker run --rm --network host postgres:16 pg_dump $VERBOSE_FLAG --no-owner --no-acl "$CLONE_URL" |
    docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$DB_NAME"; then
    error "Failed to clone database to container"
  fi

  echo "Successfully cloned database to container"
  echo "Your new PostgreSQL URL is:"
  echo "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:$PORT/$DB_NAME"
}

clone_db_to_destination() {
  log "Cloning database from $CLONE_URL to $DESTINATION_URL"

  echo "Starting database clone operation to destination..."
  VERBOSE_FLAG=""
  [ "$VERBOSE" -eq 1 ] && VERBOSE_FLAG="--verbose"

  if ! docker run --rm --network host postgres:15.9 \
    bash -c "pg_dump $VERBOSE_FLAG --no-owner --no-acl '$CLONE_URL' | psql '$DESTINATION_URL'"; then
    error "Failed to clone database to destination"
  fi

  echo "Successfully cloned database to destination URL"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help)
      show_help
      ;;
    -n | --name)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    -p | --port)
      PORT="$2"
      shift 2
      ;;
    -b | --backup-url)
      BACKUP_URL="$2"
      OPERATION_MODE="restore"
      shift 2
      ;;
    -c | --clone-url)
      CLONE_URL="$2"
      OPERATION_MODE="clone"
      shift 2
      ;;
    -d | --destination-url)
      DESTINATION_URL="$2"
      shift 2
      ;;
    --schema)
      SCHEMA_NAME="$2"
      shift 2
      ;;
    -v | --verbose)
      VERBOSE=1
      shift
      ;;
    *)
      error "Unknown option: $1. Use --help for usage information."
      ;;
  esac
done

if [ -z "$OPERATION_MODE" ]; then
  if [ -n "$BACKUP_URL" ]; then
    OPERATION_MODE="restore"
  elif [ -n "$CLONE_URL" ]; then
    OPERATION_MODE="clone"
  else
    OPERATION_MODE="restore" # Default to restore mode with default backup URL
  fi
fi

log "Starting database operation in $OPERATION_MODE mode"

if [ "$OPERATION_MODE" = "restore" ]; then
  check_tool_available curl
  check_tool_available pg_dump
  check_tool_available pg_isready
  check_tool_available psql
  check_backup_url "$BACKUP_URL"
  log "Using backup URL: $BACKUP_URL"
elif [ "$OPERATION_MODE" = "clone" ]; then
  check_tool_available pg_dump
  check_tool_available pg_isready
  check_tool_available psql
  check_postgres_url "$CLONE_URL" "source"
  log "Using clone URL: $CLONE_URL"
else
  error "Invalid operation mode: $OPERATION_MODE"
fi

if [ -n "$DESTINATION_URL" ]; then
  warn "Operation to an existing database at $DESTINATION_URL may overwrite data!"
  read -p "Do you want to continue? This may result in DATA LOSS! (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled by user"
    exit 0
  fi

  check_postgres_url "$DESTINATION_URL" "destination"

  if [ "$OPERATION_MODE" = "restore" ]; then
    restore_backup_to_destination
  else
    clone_db_to_destination
  fi
else
  # We're operating to a local Docker container
  check_tool_available docker
  if ! docker info &>/dev/null; then
    error "Docker daemon is not running or you don't have permissions"
  fi

  # Set default PostgreSQL credentials for the new container
  if [ "$OPERATION_MODE" = "clone" ]; then
    extract_postgres_details "$CLONE_URL"
  else
    if [ "$VERBOSE" -eq 1 ]; then
      log "Using default credentials for new container"
    fi
    POSTGRES_USER="postgres"
    POSTGRES_PASSWORD="postgres"
    DB_NAME="postgres"
  fi

  if check_container_exists; then
    warn "A container named '$CONTAINER_NAME' already exists"
    read -p "Do you want to remove it and create a new one? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      log "Stopping and removing existing container"
      docker stop "$CONTAINER_NAME" >/dev/null
      docker rm "$CONTAINER_NAME" >/dev/null
    else
      echo "Operation cancelled by user"
      exit 0
    fi
  fi

  check_port_available

  create_postgres_container

  if [ "$OPERATION_MODE" = "restore" ]; then
    restore_backup_to_container
  else
    clone_db_to_container
  fi
fi

log "Database operation completed successfully"
exit 0
