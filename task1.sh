#!/bin/bash
set -euo pipefail

# Define colors for creative logging
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
BOLD="\033[1m"
RESET="\033[0m"

# Log functions
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

# Installation functions
installGo() {
    log_info "Installing Go..."
    wget https://go.dev/dl/go1.23.2.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.23.2.linux-amd64.tar.gz
    sudo rm -f go1.23.2.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
    echo 'export GOPATH=$HOME/go' >> ~/.profile
    echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.profile
    source ~/.profile
    go version && log_success "Go installed successfully!"
}

installStory() {
    log_info "Installing Story..."
    wget -qO story.tar.gz $(curl -s https://api.github.com/repos/piplabs/story/releases/latest | grep 'body' | grep -Eo 'https?://[^ ]+story-linux-amd64[^ ]+' | sed 's/......$//')
    tar xf story.tar.gz
    sudo cp -f story*/story /bin
    rm -rf story*/ story.tar.gz
    log_success "Story installed successfully!"
}

installGeth() {
    log_info "Installing Geth..."
    wget -qO story-geth.tar.gz $(curl -s https://api.github.com/repos/piplabs/story-geth/releases/latest | grep 'body' | grep -Eo 'https?://[^ ]+geth-linux-amd64[^ ]+' | sed 's/......$//')
    tar xf story-geth.tar.gz
    sudo cp geth*/geth /bin
    rm -rf geth*/ story-geth.tar.gz
    log_success "Geth installed successfully!"
}

installStoryConsensus() {
    log_info "Installing Story Consensus..."
    wget -qO story.tar.gz $(curl -s https://api.github.com/repos/piplabs/story/releases/latest | grep 'body' | grep -Eo 'https?://[^ ]+story-linux-amd64[^ ]+' | sed 's/......$//')
    tar xf story.tar.gz
    sudo cp story*/story /bin
    rm -rf story*/ story.tar.gz
    log_success "Story Consensus installed successfully!"
}

autoUpdateStory() {
    log_info "Starting automatic update for Story..."
    installGo
    cd $HOME && \
    rm -rf story && \
    git clone https://github.com/piplabs/story && \
    cd $HOME/story && \
    latest_branch=$(git branch -r | grep -o 'origin/[^ ]*' | grep -v 'HEAD' | tail -n 1 | cut -d '/' -f 2) && \
    git checkout $latest_branch && \
    go build -o story ./client && \
    old_bin_path=$(which story) && \
    home_path=$HOME && \
    rpc_port=$(grep -m 1 -oP '^laddr = "\K[^"]+' "$HOME/.story/story/config/config.toml" | cut -d ':' -f 3) && \
    [[ -z "$rpc_port" ]] && rpc_port=$(grep -oP 'node = "tcp://[^:]+:\K\d+' "$HOME/.story/story/config/client.toml") ; \
    tmux new -s story-upgrade "sudo bash -c 'curl -s https://raw.githubusercontent.com/itrocket-team/testnet_guides/main/utils/autoupgrade/upgrade.sh | bash -s -- -u \"1325860\" -b story -n \"$HOME/story/story\" -o \"$old_bin_path\" -h \"$home_path\" -p \"undefined\" -r \"$rpc_port\"'"
    log_success "Story updated successfully!"
}

latestVersions() {
    log_info "Fetching latest versions..."
    latestStoryVersion=$(curl -s https://api.github.com/repos/piplabs/story/releases/latest | grep tag_name | cut -d\" -f4)
    latestGethVersion=$(curl -s https://api.github.com/repos/piplabs/story-geth/releases/latest | grep tag_name | cut -d\" -f4)
    log_success "Latest Story version: $latestStoryVersion"
    log_success "Latest Geth version: $latestGethVersion"
}

mainMenu() {
    echo -e "${BOLD}${CYAN}==== Main Menu ====${RESET}"
    echo "1 Install Story"
    echo "2 Install Geth"
    echo "3 Install Story Consensus"
    echo "4 Automatic Update Story"
    echo "5 See Latest Story and Geth Versions"
    echo "q Quit"
    echo -e "${CYAN}====================${RESET}"
}

while true; do
    mainMenu
    read -ep "Enter the number of the option you want: " CHOICE
    case "$CHOICE" in
        "1") installStory ;;
        "2") installGeth ;;
        "3") installStoryConsensus ;;
        "4") autoUpdateStory ;;
        "5") latestVersions ;;
        "q") exit ;;
        *) log_error "Invalid option: $CHOICE" ;;
    esac
done
