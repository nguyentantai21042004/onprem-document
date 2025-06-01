# Install Zsh
echo "🔧 Installing Zsh..."
sudo apt update
sudo apt install zsh git curl wget -y

# Set Zsh as default shell
echo "✅ Setting Zsh as default shell..."
chsh -s $(which zsh)

# Install Oh My Zsh (non-interactive, prevent auto-zsh switch)
echo "💡 Installing Oh My Zsh..."
export RUNZSH=no
export CHSH=no
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Custom plugin directory
ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

# Install plugin zsh-autosuggestions
echo "🔌 Installing plugin zsh-autosuggestions..."
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions

# Install plugin zsh-syntax-highlighting
echo "🎨 Installing plugin zsh-syntax-highlighting..."
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting

# Install theme powerlevel10k
echo "✨ Installing theme powerlevel10k..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

# Customize .zshrc
echo "⚙️  Customizing ~/.zshrc..."
cat > ~/.zshrc <<'EOF'

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Customize theme
CUSTOM_THEME_NAME="robbyrussell"
CUSTOM_THEME_PATH="$ZSH_CUSTOM/themes/$CUSTOM_THEME_NAME.zsh-theme"

echo "[+] Setting custom Zsh theme..."

cat > "$CUSTOM_THEME_PATH" << 'EOF'
PROMPT="%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) %{$fg[magenta]%}[%m] %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}%1{✗%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
EOF

# Update .zshrc to use new theme
sed -i "s/^ZSH_THEME=.*/ZSH_THEME=\"$CUSTOM_THEME_NAME\"/" ~/.zshrc

# Reload zsh
echo "[+] Setup complete! Reloading Zsh..."
exec zsh