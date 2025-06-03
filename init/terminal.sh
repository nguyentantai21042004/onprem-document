#!/bin/bash

# Get the actual user (not root when using sudo)
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

echo "🔧 Installing Zsh for user: $ACTUAL_USER"
echo "📁 Home directory: $ACTUAL_HOME"

# Install packages
echo "📦 Installing required packages..."
sudo apt update
sudo apt install zsh git curl wget -y

# Set Zsh as default shell for the actual user
echo "✅ Setting Zsh as default shell for $ACTUAL_USER..."
sudo chsh -s $(which zsh) $ACTUAL_USER

# Install Oh My Zsh for the actual user (run as the user, not root)
echo "💡 Installing Oh My Zsh..."
sudo -u $ACTUAL_USER bash -c '
export RUNZSH=no
export CHSH=no
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
'

# Set paths for the actual user
ZSH_DIR="$ACTUAL_HOME/.oh-my-zsh"
ZSH_CUSTOM="$ZSH_DIR/custom"

# Install plugins as the actual user
echo "🔌 Installing plugin zsh-autosuggestions..."
sudo -u $ACTUAL_USER git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

echo "🎨 Installing plugin zsh-syntax-highlighting..."
sudo -u $ACTUAL_USER git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

echo "✨ Installing theme powerlevel10k..."
sudo -u $ACTUAL_USER git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

# Create .zshrc for the actual user
echo "⚙️  Creating ~/.zshrc for $ACTUAL_USER..."
sudo -u $ACTUAL_USER tee "$ACTUAL_HOME/.zshrc" > /dev/null <<EOF
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

echo "[+] Setting custom Zsh theme..."
sudo -u $ACTUAL_USER tee "$CUSTOM_THEME_PATH" > /dev/null <<'EOF'
PROMPT="%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) %{$fg[magenta]%}[%m] %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}%1{✗%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
EOF

# Update .zshrc to use new theme
sudo -u $ACTUAL_USER sed -i "s/^ZSH_THEME=.*/ZSH_THEME=\"$CUSTOM_THEME_NAME\"/" "$ACTUAL_HOME/.zshrc"

# Set proper ownership for all files
echo "🔐 Setting proper file ownership..."
sudo chown -R $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.oh-my-zsh"
sudo chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.zshrc"

echo "[+] Setup complete!"
echo "💡 To start using Zsh, run: su - $ACTUAL_USER"
echo "💡 Or logout and login again to use Zsh as default shell"