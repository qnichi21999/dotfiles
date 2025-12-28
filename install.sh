#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
OMZ_DIR="$HOME/.oh-my-zsh"

mkdir -p "$BACKUP_DIR"

backup_and_copy() {
  local src="$1"
  local dest="$2"

  if [ -e "$dest" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$dest")"
    cp -a "$dest" "$BACKUP_DIR/$dest"
  fi

  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
}

# -------------------------
# Install core packages
# -------------------------
if command -v pacman >/dev/null 2>&1; then
  sudo pacman -Syu --noconfirm

  sudo pacman -S --needed --noconfirm \
    hyprland \
    waybar \
    blueman \
    kitty \
    tmux \
    vim \
    sddm \
    firefox \
    git \
    curl \
    wget \
    zsh \
    polkit-kde-agent \
    network-manager-applet \
    unzip \
    zip
else
  echo "Pacman not found. Unsupported system."
  exit 1
fi

# -------------------------
# AUR helper
# -------------------------
if ! command -v yay >/dev/null 2>&1; then
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (cd /tmp/yay && makepkg -si --noconfirm)
  rm -rf /tmp/yay
fi

# VS Code from AUR
yay -S --needed --noconfirm visual-studio-code-bin

# -------------------------
# Oh My Zsh
# -------------------------
if [ ! -d "$OMZ_DIR" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# -------------------------
# Install ~/.config
# -------------------------
if [ -d "$DOTFILES_DIR/.config" ]; then
  find "$DOTFILES_DIR/.config" -type f | while read -r file; do
    dest="$HOME/${file#$DOTFILES_DIR/}"
    backup_and_copy "$file" "$dest"
  done
fi

# -------------------------
# Install absolute-path files
# -------------------------
find "$DOTFILES_DIR" -type f | while read -r file; do
  case "$file" in
    */.config/*|"$DOTFILES_DIR/install.sh") continue ;;
  esac

  rel="${file#$DOTFILES_DIR}"
  if [[ "$rel" == /* ]]; then
    sudo bash -c "$(declare -f backup_and_copy); backup_and_copy '$file' '$rel'"
  fi
done

# -------------------------
# Default shell
# -------------------------
if command -v zsh >/dev/null 2>&1; then
  [ "$SHELL" != "$(command -v zsh)" ] && chsh -s "$(command -v zsh)"
fi

cat vscode-extensions.txt | xargs -L 1 code --install-extension
