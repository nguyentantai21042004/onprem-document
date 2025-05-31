#!/bin/bash

# 1. Cài zsh nếu chưa có
if ! command -v zsh &> /dev/null; then
    echo "[+] Installing zsh..."
    sudo apt update
    sudo apt install -y zsh
fi

# 2. Thiết lập zsh làm shell mặc định
echo "[+] Setting zsh as default shell..."
chsh -s $(which zsh)

# 3. Cài đặt Oh My Zsh (nếu chưa cài)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "[+] Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# 4. Cài plugin: zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "[+] Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
fi

# 5. Cài plugin: zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "[+] Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
fi

# 6. Thêm plugin vào .zshrc nếu chưa có
echo "[+] Configuring .zshrc..."
sed -i 's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
awk '!x[$0]++' ~/.zshrc > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc

# 7. Thay thế theme bằng custom prompt
CUSTOM_THEME_NAME="mytheme"
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

# 8. Cập nhật .zshrc để dùng theme mới
sed -i "s/^ZSH_THEME=.*/ZSH_THEME=\"$CUSTOM_THEME_NAME\"/" ~/.zshrc

# 9. Reload zsh
echo "[+] Setup complete! Reloading Zsh..."
exec zsh