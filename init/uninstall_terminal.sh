#!/bin/bash

# Get the actual user (not root when using sudo)
ACTUAL_USER=tantai
ACTUAL_HOME=/home/tantai
ZSH_CUSTOM="$ACTUAL_HOME/.oh-my-zsh/custom"

echo "Uninstalling Zsh setup for user: $ACTUAL_USER"
echo "Home directory: $ACTUAL_HOME"

# Change default shell back to bash
echo "Changing default shell back to bash..."
chsh -s $(which bash) $ACTUAL_USER

# Remove Oh My Zsh and related files
echo "Removing Oh My Zsh..."
if [ -d "$ACTUAL_HOME/.oh-my-zsh" ]; then
    rm -rf "$ACTUAL_HOME/.oh-my-zsh"
    echo "Oh My Zsh directory removed"
fi

# Remove .zshrc file
echo "Removing .zshrc configuration..."
if [ -f "$ACTUAL_HOME/.zshrc" ]; then
    rm -f "$ACTUAL_HOME/.zshrc"
    echo ".zshrc file removed"
fi

# Remove any zsh history files
echo "Removing zsh history files..."
if [ -f "$ACTUAL_HOME/.zsh_history" ]; then
    rm -f "$ACTUAL_HOME/.zsh_history"
    echo "Zsh history file removed"
fi

# Remove any remaining zsh configuration files
echo "Removing remaining zsh configuration files..."
rm -f "$ACTUAL_HOME/.zshenv"
rm -f "$ACTUAL_HOME/.zprofile"
rm -f "$ACTUAL_HOME/.zlogin"
rm -f "$ACTUAL_HOME/.zlogout"

# Uninstall zsh package
echo "Uninstalling zsh package..."
sudo apt remove zsh -y
sudo apt autoremove -y

# Clean package cache
echo "Cleaning package cache..."
sudo apt autoclean

echo ""
echo "Zsh uninstallation complete!"
echo "Default shell has been changed back to bash"
echo "Please logout and login again for changes to take effect"
echo ""
echo "To verify the change, run: echo \$SHELL"
echo "It should show: /bin/bash" 