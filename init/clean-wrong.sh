#!/bin/bash

# Get the actual user
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

echo "🧹 Cleaning up Zsh installation..."
echo "👤 Target user: $ACTUAL_USER"
echo "📁 User home: $ACTUAL_HOME"

# 1. Reset default shell back to bash for all users
echo "🔄 Resetting shell to bash..."
sudo chsh -s /bin/bash root 2>/dev/null || true
sudo chsh -s /bin/bash $ACTUAL_USER 2>/dev/null || true

# 2. Remove Oh My Zsh from root directory
echo "🗑️  Removing Oh My Zsh from /root..."
sudo rm -rf /root/.oh-my-zsh
sudo rm -f /root/.zshrc
sudo rm -f /root/.zshrc.pre-oh-my-zsh
sudo rm -f /root/.zsh_history
sudo rm -rf /root/.cache/oh-my-zsh

# 3. Remove Oh My Zsh from user directory (in case it exists)
echo "🗑️  Removing Oh My Zsh from $ACTUAL_HOME..."
sudo rm -rf "$ACTUAL_HOME/.oh-my-zsh"
sudo rm -f "$ACTUAL_HOME/.zshrc"
sudo rm -f "$ACTUAL_HOME/.zshrc.pre-oh-my-zsh"
sudo rm -f "$ACTUAL_HOME/.zsh_history"
sudo rm -rf "$ACTUAL_HOME/.cache/oh-my-zsh"

# 4. Remove any Zsh-related configs from other common locations
echo "🗑️  Cleaning other Zsh configs..."
sudo rm -rf /etc/zsh_command_not_found
sudo rm -f /etc/zsh/zshrc.d/* 2>/dev/null || true

# 5. Optional: Remove Zsh package entirely (uncomment if you want to uninstall Zsh)
# echo "📦 Removing Zsh package..."
# sudo apt remove --purge zsh -y
# sudo apt autoremove -y

# 6. Verify cleanup
echo "✅ Verification:"
echo "Root shell: $(getent passwd root | cut -d: -f7)"
echo "$ACTUAL_USER shell: $(getent passwd $ACTUAL_USER | cut -d: -f7)"

if [[ -d "/root/.oh-my-zsh" ]]; then
    echo "❌ /root/.oh-my-zsh still exists"
else
    echo "✅ /root/.oh-my-zsh removed"
fi

if [[ -d "$ACTUAL_HOME/.oh-my-zsh" ]]; then
    echo "❌ $ACTUAL_HOME/.oh-my-zsh still exists"
else
    echo "✅ $ACTUAL_HOME/.oh-my-zsh removed"
fi

echo ""
echo "🎉 Cleanup complete!"
echo "💡 You can now run the new installation script"
echo "💡 Current shell will reset after logout/login"