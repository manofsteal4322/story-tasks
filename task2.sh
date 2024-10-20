#!/bin/bash

# Define colors for creative logging
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
BOLD="\033[1m"
RESET="\033[0m"

# Log functions for creative output
log_info() {
  echo -e "${CYAN}[INFO] $1${RESET}"
}

log_success() {
  echo -e "${GREEN}[SUCCESS] $1${RESET}"
}

log_warning() {
  echo -e "${YELLOW}[WARNING] $1${RESET}"
}

log_error() {
  echo -e "${RED}[ERROR] $1${RESET}"
}

log_line() {
  echo -e "${BOLD}----------------------------------------${RESET}"
}

# Update and install necessary packages
log_info "1. Installing dependencies..." && sleep 1
sudo apt-get update -y
sudo apt-get install -y curl git wget htop tmux jq make lz4 unzip bc

# Define variables
type=testnet
project=story
rootUrl=server-3.itrocket.net
storyPath=$HOME/.story/story
gethPath=$HOME/.story/geth/iliad/geth
FILE_SERVERS=(
  "https://server-3.itrocket.net/testnet/story/.current_state.json"
  "https://server-1.itrocket.net/testnet/story/.current_state.json"
  "https://server-5.itrocket.net/testnet/story/.current_state.json"
)
PARENT_RPC="https://story-testnet-rpc.itrocket.net"
MAX_ATTEMPTS=3
TEST_FILE_SIZE=50000000  # File size in bytes for download speed check

# Function to fetch snapshot data from the server
fetch_snapshot_data() {
  local URL=$1
  local ATTEMPT=0
  local DATA=""

  while (( ATTEMPT < MAX_ATTEMPTS )); do
    DATA=$(curl -s --max-time 5 "$URL")
    if [[ -n "$DATA" ]]; then
      break
    else
      ((ATTEMPT++))
      sleep 1
    fi
  done

  echo "$DATA"
}

# Function to display available snapshots
display_snapshots() {
  local SNAPSHOTS=("$@")
  log_success "Available snapshots:"
  log_line
  for i in "${!SNAPSHOTS[@]}"; do
    IFS='|' read -r SERVER_NUMBER SNAPSHOT_TYPE SNAPSHOT_HEIGHT BLOCKS_BEHIND SNAPSHOT_AGE TOTAL_SIZE_GB SNAPSHOT_SIZE GETH_SIZE ESTIMATED_TIME SERVER_URL SNAPSHOT_NAME GETH_NAME <<< "${SNAPSHOTS[$i]}"
    echo "[$i] Server $SERVER_NUMBER: $SNAPSHOT_TYPE | Height: $SNAPSHOT_HEIGHT | Age: $SNAPSHOT_AGE | Size: $TOTAL_SIZE_GB GB | Est. Time: $ESTIMATED_TIME"
  done
}

# Function to install the selected snapshot
install_snapshot() {
  local SNAPSHOT_NAME=$1
  local GETH_NAME=$2
  local SERVER_URL=$3

  log_info "Installing snapshot from $SERVER_URL:"
  log_line
  log_info "Stopping story and story-geth services..." && sleep 1
  sudo systemctl stop story story-geth

  log_info "Backing up priv_validator_state.json..." && sleep 1
  cp "$storyPath/data/priv_validator_state.json" "$storyPath/priv_validator_state.json.backup"

  log_info "Removing old data and unpacking Story snapshot..." && sleep 1
  rm -rf "$storyPath/data"
  curl "$SERVER_URL/${type}/${project}/$SNAPSHOT_NAME" | lz4 -dc - | tar -xf - -C "$storyPath"

  log_info "Restoring priv_validator_state.json..." && sleep 1
  mv "$storyPath/priv_validator_state.json.backup" "$storyPath/data/priv_validator_state.json"

  log_info "Deleting geth data and unpacking Geth snapshot..." && sleep 1
  rm -rf "$gethPath/chaindata"
  curl "$SERVER_URL/${type}/${project}/$GETH_NAME" | lz4 -dc - | tar -xf - -C "$gethPath"

  log_info "Starting Story and Geth services..." && sleep 1
  sudo systemctl restart story story-geth

  log_success "Snapshot installation complete."
}

# Fetch snapshot data from servers
SNAPSHOTS=()
for FILE_SERVER in "${FILE_SERVERS[@]}"; do
  DATA=$(fetch_snapshot_data "$FILE_SERVER")
  if [[ -n "$DATA" ]]; then
    SERVER_URL=$(echo "$FILE_SERVER" | sed "s|/${type}/${project}/.current_state.json||")
    SERVER_NUMBER=$(echo "$SERVER_URL" | grep -oP 'server-\K[0-9]+')
    SNAPSHOT_NAME=$(echo "$DATA" | jq -r '.snapshot_name')
    GETH_NAME=$(echo "$DATA" | jq -r '.snapshot_geth_name')
    SNAPSHOT_HEIGHT=$(echo "$DATA" | jq -r '.snapshot_height')
    SNAPSHOT_SIZE=$(echo "$DATA" | jq -r '.snapshot_size')
    GETH_SIZE=$(echo "$DATA" | jq -r '.geth_snapshot_size')
    TOTAL_SIZE_GB=$(echo "$SNAPSHOT_SIZE + $GETH_SIZE" | bc)
    SNAPSHOT_AGE=$(echo "$DATA" | jq -r '.snapshot_age')
    ESTIMATED_TIME="N/A"  # Placeholder for estimated time calculation
    SNAPSHOTS+=("$SERVER_NUMBER|$SNAPSHOT_NAME|$SNAPSHOT_HEIGHT|$SNAPSHOT_AGE|$TOTAL_SIZE_GB|$SNAPSHOT_SIZE|$GETH_SIZE|$ESTIMATED_TIME|$SERVER_URL|$SNAPSHOT_NAME|$GETH_NAME")
  fi
done

# Display available snapshots
display_snapshots "${SNAPSHOTS[@]}"

# Prompt user to select a snapshot
read -p "Enter the number of the snapshot you want to install: " CHOICE

# Validate user choice and install the selected snapshot
if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 0 ] && [ "$CHOICE" -lt "${#SNAPSHOTS[@]}" ]; then
  IFS='|' read -r SERVER_NUMBER SNAPSHOT_NAME SNAPSHOT_HEIGHT SNAPSHOT_AGE TOTAL_SIZE_GB SNAPSHOT_SIZE GETH_SIZE ESTIMATED_TIME SERVER_URL SNAPSHOT_NAME GETH_NAME <<< "${SNAPSHOTS[$CHOICE]}"
  install_snapshot "$SNAPSHOT_NAME" "$GETH_NAME" "$SERVER_URL"
else
  log_error "Invalid choice. Exiting."
  exit 1
fi
