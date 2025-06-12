#!/bin/bash

# Get the actual user (not root when using sudo)
ACTUAL_HOME=/home/tantai
ZSH_CUSTOM="$ACTUAL_HOME/.oh-my-zsh/custom"

# Update and install zsh
sudo apt update
sudo apt install zsh -y

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"  

# Install plugins
git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"


# Create .zshrc for the actual user
tee "$ACTUAL_HOME/.zshrc" > /dev/null <<EOF
export ZSH="$ACTUAL_HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source \$ZSH/oh-my-zsh.sh
EOF

# Create custom theme
CUSTOM_THEME_NAME="robbyrussell"
CUSTOM_THEME_PATH="$ZSH_CUSTOM/themes/$CUSTOM_THEME_NAME.zsh-theme"

# Ensure themes directory exists
mkdir -p "$ZSH_CUSTOM/themes"

tee "$CUSTOM_THEME_PATH" > /dev/null <<'EOF'
PROMPT="%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) %{$fg[magenta]%}[%m] %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}%1{✗%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
EOF

echo "Setup complete!"