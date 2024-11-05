#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Constants
GO_VERSION="1.22.3"
GO_URL="https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
EXPECTED_CHECKSUM="8920ea521bad8f6b7bc377b4824982e011c19af27df88a815e3586ea895f1b36"
GO_TAR="go${GO_VERSION}.linux-amd64.tar.gz"
GO_INSTALL_DIR="/usr/local/go"
GO_PATH_UPDATE='export PATH=$PATH:/usr/local/go/bin'
EVILGINX_REPO="https://github.com/kgretzky/evilginx2"
EVILGINX_SRC_DIR="/home/ubuntu/src-evilginx"
EVILGINX_INSTALL_DIR="/home/ubuntu/evilginx"

# Log output of script to a file
exec > >(tee -i /home/ubuntu/install.log)
exec 2>&1

# Function to update and install necessary packages
install_packages() {
    echo "Updating package manager and installing necessary packages..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y git make curl
}

# Function to verify the checksum of a file
verify_checksum() {
    local file=$1
    local expected_checksum=$2
    local actual_checksum

    actual_checksum=$(sha256sum "$file" | awk '{print $1}')
    if [ "$expected_checksum" != "$actual_checksum" ]; then
        echo "Checksum verification failed for $file. Aborting installation."
        exit 1
    fi
}

# Function to install Go
install_go() {
    if ! go version | grep -q "$GO_VERSION"; then
        echo "Downloading and installing Go..."
        curl -OL "$GO_URL"
        verify_checksum "$GO_TAR" "$EXPECTED_CHECKSUM"
        sudo rm -rf "$GO_INSTALL_DIR"
        sudo tar -C /usr/local -xzf "$GO_TAR"
        rm "$GO_TAR"
        echo "Setting up Go environment..."
        if ! grep -q "$GO_PATH_UPDATE" /home/ubuntu/.profile; then
            echo "$GO_PATH_UPDATE" >> /home/ubuntu/.profile
        fi
        export PATH=$PATH:/usr/local/go/bin
    else
        echo "Go version $GO_VERSION already installed, skipping installation."
    fi
}

# Function to enable byobu
enable_byobu() {
    echo "Enabling byobu..."
    byobu-enable
}

# Function to modify systemd-resolved configuration
modify_systemd_resolved() {
    echo "Modifying systemd-resolved configuration..."
    sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
    sudo systemctl restart systemd-resolved
}

# Function to clone the evilginx repository
clone_evilginx_repo() {
    echo "Cloning evilginx repository..."
    if [ ! -d "$EVILGINX_SRC_DIR" ]; then
        git clone "$EVILGINX_REPO" "$EVILGINX_SRC_DIR"
    fi
}

# Function to remove the evilginx indicator
remove_evilginx_indicator() {
    echo "Removing evilginx indicator (X-Evilginx header)..."
    sed -i 's/req.Header.Set(p.getHomeDir(), o_host)/\/\/req.Header.Set(p.getHomeDir(), o_host)/' "$EVILGINX_SRC_DIR/core/http_proxy.go"
}

# Function to build the evilginx project
build_evilginx() {
    echo "Building evilginx repository..."
    cd "$EVILGINX_SRC_DIR"
    go build
    make
}

# Function to set up the evilginx directory
setup_evilginx_directory() {
    echo "Setting up evilginx directory..."
    mkdir -p "$EVILGINX_INSTALL_DIR/phishlets" "$EVILGINX_INSTALL_DIR/redirectors"
    cp "$EVILGINX_SRC_DIR/build/evilginx" "$EVILGINX_INSTALL_DIR/"
    sudo setcap CAP_NET_BIND_SERVICE=+eip "$EVILGINX_INSTALL_DIR/evilginx"
}

# Function to clean up source directory
cleanup() {
    echo "Removing the src-evilginx directory"
    rm -rf "$EVILGINX_SRC_DIR"
}

# Main script execution
install_packages
install_go
enable_byobu
modify_systemd_resolved
clone_evilginx_repo
remove_evilginx_indicator
build_evilginx
setup_evilginx_directory
cleanup

echo "Installation and setup complete."
exit 0
