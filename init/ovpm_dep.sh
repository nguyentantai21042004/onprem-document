#!/bin/bash

set -e  # Stop script if there's an error
echo "🛠️  Starting dependencies installation..."

# ------------------------------
# 1. Update system
echo "🔄 Updating system..."
sudo apt update && sudo apt upgrade -y

# ------------------------------
# 2. Install Go >= 1.14
GO_VERSION="1.21.5"
echo "📦 Installing Go ${GO_VERSION}..."
wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
rm go${GO_VERSION}.linux-amd64.tar.gz

# Add Go to PATH
if ! grep -q "/usr/local/go/bin" ~/.zshrc; then
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
fi

# ------------------------------
# 3. Install OpenVPN
echo "📦 Installing OpenVPN..."
sudo apt install -y openvpn

# ------------------------------
# 4. Install OpenSSL
echo "📦 Installing OpenSSL..."
sudo apt install -y openssl

# ------------------------------
# 5. Install iptables
echo "📦 Installing iptables..."
sudo apt install -y iptables

# ------------------------------
# 6. Install Node.js (via nvm + zsh)
echo "📦 Installing nvm + Node.js..."

# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Configure for zsh
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc

# Load nvm now
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

# Install Node.js LTS
nvm install --lts

# ------------------------------
# Print results
echo ""
echo "✅ Version check:"
go version
openvpn --version | head -n 1
openssl version
iptables --version
node --version

echo ""
echo "🎉 All dependencies have been successfully installed!"
