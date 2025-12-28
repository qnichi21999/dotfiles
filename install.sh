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

# Install Oh My Zsh
if [ ! -d "$OMZ_DIR" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install ~/.config files
if [ -d "$DOTFILES_DIR/.config" ]; then
  find "$DOTFILES_DIR/.config" -type f | while read -r file; do
    dest="$HOME/${file#$DOTFILES_DIR/}"
    backup_and_copy "$file" "$dest"
  done
fi

# Install absolute-path files
find "$DOTFILES_DIR" -type f | while read -r file; do
  case "$file" in
    */.config/*|"$DOTFILES_DIR/install.sh") continue ;;
  esac

  rel="${file#$DOTFILES_DIR}"
  if [[ "$rel" == /* ]]; then
    sudo bash -c "$(declare -f backup_and_copy); backup_and_copy '$file' '$rel'"
  fi
done

# Set default shell to zsh
if command -v zsh >/dev/null 2>&1; then
  [ "$SHELL" != "$(command -v zsh)" ] && chsh -s "$(command -v zsh)"
fi

