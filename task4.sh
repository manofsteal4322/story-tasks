#!/bin/bash

# Define colors for creative logging
green="\e[32m"
red="\e[31m"
cyan="\e[36m"
reset="\e[0m"

# Function to print in green
printGreen() {
  echo -e "${green}$1${reset}"
}

# Function to print in red
printRed() {
  echo -e "${red}$1${reset}"
}

# Function to print a line
printLine() {
  echo -e "${cyan}----------------------------------------${reset}"
}

# Function to install the latest Story
installLatestStory() {
    printGreen "Installing the latest Story..."
    
    # Detect system architecture
    ARCH=$(uname -m)
    if [ "$ARCH" == "x86_64" ]; then
        ARCH="amd64"
    elif [[ "$ARCH" == "arm"* || "$ARCH" == "aarch64" ]]; then
        ARCH="arm64"
    else
        echo "Unsupported architecture: $ARCH"
        return 1
    fi
    
    # Fetch the latest release data
    RELEASE_DATA=$(curl -s https://api.github.com/repos/piplabs/story/releases/latest)
    
    # Extract the URL for the story binary based on architecture
    STORY_URL=$(echo "$RELEASE_DATA" | grep 'body' | grep -Eo "https?://[^ ]+story-linux-${ARCH}[^ ]+" | sed 's/......$//')
    
    if [ -z "$STORY_URL" ]; then
        echo "Failed to fetch Story URL. Exiting."
        return 1
    fi
    
    echo "Fetched Story URL: $STORY_URL"
    wget -qO story-linux-$ARCH.tar.gz "$STORY_URL"
    
    if [ ! -f story-linux-$ARCH.tar.gz ]; then
        echo "Failed to download Story. Exiting."
        return 1
    fi
    
    echo "Configuring Story..."
    
    # Check if the file is a tar.gz archive and extract it
    if file story-linux-$ARCH.tar.gz | grep -q 'gzip compressed data'; then
        tar -xzf story-linux-$ARCH.tar.gz
        rm story-linux-$ARCH.tar.gz
    else
        echo "Downloaded file is not a valid tar.gz archive. Exiting."
        return 1
    fi
    
    # Verify if the extracted folder exists
    EXTRACTED_FOLDER=$(ls -d story-linux-$ARCH-* 2>/dev/null || true)
    if [ -z "$EXTRACTED_FOLDER" ]; then
        echo "Extracted folder not found. Exiting."
        return 1
    fi
    
    [ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
    if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
        echo 'export PATH=$PATH:$HOME/go/bin' >> $HOME/.bash_profile
    fi
    
    # Move the contents of the extracted folder to $HOME/go/bin
    sudo rm -rf $HOME/go/bin/story
    sudo mv "$EXTRACTED_FOLDER"/* $HOME/go/bin/story
    rm -rf "$EXTRACTED_FOLDER"
    source $HOME/.bash_profile
    
    if ! $HOME/go/bin/story version; then
        echo "Failed to execute story. Please check permissions."
        return 1
    fi
    story version
}

# Function to install the latest Geth-Story
installLatestGethStory() {
    printGreen "Installing the latest Geth-Story..."
    GETH_URL=$(curl -s https://api.github.com/repos/piplabs/story-geth/releases/latest | grep 'browser_download_url' | grep 'geth-linux-amd64' | head -n 1 | cut -d '"' -f 4)
    
    if [ -z "$GETH_URL" ]; then
        echo "Failed to fetch Geth URL. Exiting."
        return 1
    fi
    
    echo "Fetched Geth URL: $GETH_URL"
    wget -qO geth-linux-amd64 "$GETH_URL"
    
    if [ ! -f geth-linux-amd64 ]; then
        echo "Failed to download Geth. Exiting."
        return 1
    fi
    
    echo "Configuring Story Geth..."
    
    chmod +x geth-linux-amd64
    
    [ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
    if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
        echo 'export PATH=$PATH:$HOME/go/bin' >> $HOME/.bash_profile
    fi
    
    rm -f $HOME/go/bin/story-geth
    mv geth-linux-amd64 $HOME/go/bin/story-geth
    chmod +x $HOME/go/bin/story-geth
    source $HOME/.bash_profile
    
    if ! $HOME/go/bin/story-geth version; then
        echo "Failed to execute story-geth. Please check permissions."
        return 1
    fi
}

# Function to check the current status of Story and Geth
checkStatus() {
  printGreen "Checking the current status of Story and Geth..."
  sudo systemctl status story
  sudo systemctl status story-geth
}

# Function to check the latest block the process is working on
checkLatestBlock() {
  printGreen "Checking the latest block the process is working on..."
  curl -s localhost:26657/status | jq .result.sync_info.latest_block_height
}

# Function to install snapshot for the process
installSnapshot() {
  printGreen "Installing snapshot for the process..."
  block=$(curl -sS https://snapshots.mandragora.io/height.txt)
  echo -e "${cyan}This snapshot at block $block is provided by Mandragora${reset}"
  sudo systemctl stop story story-geth
  sudo apt-get install lz4 pv -y
  wget -O geth_snapshot.lz4 https://snapshots.mandragora.io/geth_snapshot.lz4
  wget -O story_snapshot.lz4 https://snapshots.mandragora.io/story_snapshot.lz4
  sudo cp $HOME/.story/story/data/priv_validator_state.json $HOME/.story/priv_validator_state.json.backup
  sudo rm -rf $HOME/.story/geth/iliad/geth/chaindata
  sudo rm -rf $HOME/.story/story/data
  lz4 -c -d geth_snapshot.lz4 | tar -x -C $HOME/.story/geth/iliad/geth
  lz4 -c -d story_snapshot.lz4 | tar -x -C $HOME/.story/story
  sudo rm -v geth_snapshot.lz4
  sudo rm -v story_snapshot.lz4
  sudo cp $HOME/.story/priv_validator_state.json.backup $HOME/.story/story/data/priv_validator_state.json
  sudo systemctl start story-geth
  sudo systemctl start story
}

# Function to refresh the process if there are any errors
refreshProcess() {
  printGreen "Refreshing the process..."
  sudo systemctl restart story
  sudo systemctl restart story-geth
}

# Function to get user's keys
getUserKeys() {
  printGreen "Getting user's keys..."
  story validator export --export-evm-key
  cat $HOME/.story/story/config/private_key.txt
  cat $HOME/.story/story/config/priv_validator_key.json | grep address
}

# Function to start Story
startStory() {
  printGreen "Starting Story..."
  sudo systemctl start story
  sudo systemctl start story-geth
}

# Function to stop Story
stopStory() {
  printGreen "Stopping Story..."
  sudo systemctl stop story
  sudo systemctl stop story-geth
}

# Function to restart Story
restartStory() {
  printGreen "Restarting Story..."
  sudo systemctl restart story
  sudo systemctl restart story-geth
}

# Function to get the latest block from testnet/server
getLatestBlockFromTestnet() {
  printGreen "Getting the latest block from testnet/server..."
  curl -s https://story-testnet-rpc.polkachu.com/status | jq .result.sync_info.latest_block_height
}

# Function to install Grafana
installGrafana() {
  printGreen "Installing Grafana..."
  apt-get install -y apt-transport-https software-properties-common wget
  wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
  echo "deb https://packages.grafana.com/enterprise/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list
  apt-get update -y
  apt-get install grafana-enterprise -y
  systemctl daemon-reload
  systemctl enable grafana-server
  systemctl start grafana-server
  printGreen "Grafana installed and started."
}

# Function to stop Grafana
stopGrafana() {
  printGreen "Stopping Grafana..."
  sudo systemctl stop grafana-server
  printGreen "Grafana stopped."
}

# Function to uninstall Grafana
uninstallGrafana() {
  printGreen "Uninstalling Grafana..."
  sudo systemctl stop grafana-server
  sudo systemctl disable grafana-server
  sudo apt-get remove --purge grafana-enterprise -y
  sudo rm -rf /etc/grafana /var/lib/grafana
  printGreen "Grafana uninstalled."
}

# Main menu
mainMenu() {
  echo -e "${cyan}========== Story Utility Tool ==========${reset}"
  echo "1. Install latest Story"
  echo "2. Install latest Geth-Story"
  echo "3. Check current status of Story and Geth"
  echo "4. Check the latest block the process is working on"
  echo "5. Install snapshot for the process"
  echo "6. Refresh process if there are any errors"
  echo "7. Get user's keys (public key, private key, public address)"
  echo "8. Start Story"
  echo "9. Stop Story"
  echo "10. Restart Story"
  echo "11. Get the latest block from testnet/server"
  echo "12. Install Grafana"
  echo "13. Stop Grafana"
  echo "14. Uninstall Grafana"
  echo "q. Quit"
  echo -e "${cyan}========================================${reset}"
}

# Main loop
while true; do
  mainMenu
  read -p "Enter your choice: " choice
  case $choice in
    1) installLatestStory ;;
    2) installLatestGethStory ;;
    3) checkStatus ;;
    4) checkLatestBlock ;;
    5) installSnapshot ;;
    6) refreshProcess ;;
    7) getUserKeys ;;
    8) startStory ;;
    9) stopStory ;;
    10) restartStory ;;
    11) getLatestBlockFromTestnet ;;
    12) installGrafana ;;
    13) stopGrafana ;;
    14) uninstallGrafana ;;
    q) exit 0 ;;
    *) printRed "Invalid choice, please try again." ;;
  esac
done
