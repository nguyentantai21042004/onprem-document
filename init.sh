#!/bin/bash

set -e

# === MÀU CHỮ ===
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

# === BIẾN ===
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
ZSHRC="$HOME/.zshrc"
CUSTOM_THEME_NAME="mytheme"
CUSTOM_THEME_PATH="$ZSH_CUSTOM/themes/$CUSTOM_THEME_NAME.zsh-theme"

# === THAM SỐ ===
FORCE=0
NO_THEME=0
for arg in "$@"; do
    case $arg in
        --force)
            FORCE=1
            ;;
        --no-theme)
            NO_THEME=1
            ;;
    esac
done

log() {
    echo -e "${CYAN}[+] $1${RESET}"
}

error() {
    echo -e "${RED}[!] $1${RESET}"
}

# === 1. Cài đặt zsh nếu chưa có ===
if ! command -v zsh &> /dev/null; then
    log "Installing zsh..."
    sudo apt update
    sudo apt install -y zsh
else
    log "Zsh already installed"
fi

# === 2. Đặt zsh làm shell mặc định ===
log "Setting zsh as default shell..."
chsh -s "$(which zsh)" || error "Failed to change default shell"

# === 3. Cài đặt Oh My Zsh nếu chưa có ===
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing Oh My Zsh..."
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o install.sh
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh install.sh --unattended
    rm install.sh
else
    log "Oh My Zsh already installed"
fi

# === 4. Cài plugin zsh-autosuggestions ===
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    log "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# === 5. Cài plugin zsh-syntax-highlighting ===
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    log "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# === 6. Backup & thêm plugin vào ~/.zshrc ===
log "Backing up .zshrc..."
cp "$ZSHRC" "$ZSHRC.bak"

log "Configuring plugins..."
if ! grep -q "zsh-autosuggestions" "$ZSHRC"; then
    sed -i 's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions)/' "$ZSHRC"
fi
if ! grep -q "zsh-syntax-highlighting" "$ZSHRC"; then
    sed -i 's/^plugins=(\(.*\))/plugins=(\1 zsh-syntax-highlighting)/' "$ZSHRC"
fi

# === 7. Ghi theme tùy chỉnh nếu không tắt ===
if [ "$NO_THEME" -eq 0 ]; then
    log "Creating custom Zsh theme..."
    mkdir -p "$(dirname "$CUSTOM_THEME_PATH")"
    cat > "$CUSTOM_THEME_PATH" << 'EOF'
PROMPT="%(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ ) %{$fg[magenta]%}[%m] %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}✗"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
EOF

    sed -i "s/^ZSH_THEME=.*/ZSH_THEME=\"$CUSTOM_THEME_NAME\"/" "$ZSHRC"
fi

# === 8. Kết thúc ===
log "Setup complete!"

# === 9. Reload zsh nếu đang ở interactive terminal ===
if [ "$FORCE" -eq 1 ] && [ -t 1 ]; then
    log "Reloading zsh..."
    exec zsh
else
    echo -e "${YELLOW}Bạn có thể chạy lệnh ${GREEN}exec zsh${YELLOW} hoặc mở terminal mới để sử dụng.${RESET}"
fi
