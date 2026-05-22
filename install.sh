#!/usr/bin/env bash
# Deploy these dotfiles on an Arch Linux + Hyprland machine.
#
#   ./install.sh            full install (packages + stow)
#   ./install.sh --stow     only symlink configs (skip package install)
#   ./install.sh --packages only install packages (skip stow)
#
# Existing real config files are moved to ~/.dotfiles-backup-<timestamp>/
# before they are replaced with symlinks, so this is safe to re-run.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Stow packages (each top-level dir whose contents mirror $HOME).
PACKAGES=(hypr waybar kitty rofi dunst gtk qt nwg-look zsh tmux thunar opentabletdriver themes)

DO_PACKAGES=1
DO_STOW=1
case "${1:-}" in
  --stow)     DO_PACKAGES=0 ;;
  --packages) DO_STOW=0 ;;
  "" )        ;;
  *) echo "unknown option: $1"; exit 1 ;;
esac

info() { printf '\033[1;33m::\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------- packages ---
install_packages() {
  if ! command -v pacman >/dev/null 2>&1; then
    info "Not an Arch system — skipping package install."
    return
  fi

  info "Installing repo packages from packages.txt"
  mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$DOTFILES/packages.txt")
  sudo pacman -S --needed --noconfirm "${pkgs[@]}"

  # AUR packages need an AUR helper.
  if [ -s "$DOTFILES/aur-packages.txt" ]; then
    if ! command -v yay >/dev/null 2>&1; then
      info "Installing yay (AUR helper)"
      sudo pacman -S --needed --noconfirm git base-devel
      tmp="$(mktemp -d)"
      git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay"
      ( cd "$tmp/yay" && makepkg -si --noconfirm )
      rm -rf "$tmp"
    fi
    info "Installing AUR packages from aur-packages.txt"
    mapfile -t aur < <(grep -vE '^\s*(#|$)' "$DOTFILES/aur-packages.txt")
    [ ${#aur[@]} -gt 0 ] && yay -S --needed --noconfirm "${aur[@]}"
  fi

  info "Refreshing font cache"
  fc-cache -f >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------- shell ---
install_shell_extras() {
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing oh-my-zsh"
    RUNZSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
  local p10k="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  if [ ! -d "$p10k" ]; then
    info "Installing powerlevel10k theme"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k "$p10k"
  fi
  if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    info "Installing tmux plugin manager (tpm)"
    git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  fi
}

# -------------------------------------------------------------------- stow ---
stow_packages() {
  if ! command -v stow >/dev/null 2>&1; then
    echo "stow is not installed — run './install.sh --packages' first." >&2
    exit 1
  fi
  cd "$DOTFILES"
  for pkg in "${PACKAGES[@]}"; do
    [ -d "$pkg" ] || continue
    # Move any conflicting real (non-symlink) files into the backup dir.
    while IFS= read -r -d '' f; do
      rel="${f#"$DOTFILES/$pkg/"}"
      tgt="$HOME/$rel"
      if [ -e "$tgt" ] && [ ! -L "$tgt" ]; then
        mkdir -p "$BACKUP/$(dirname "$rel")"
        mv "$tgt" "$BACKUP/$rel"
        echo "   backed up ~/$rel"
      fi
    done < <(find "$pkg" -type f -print0)
    info "Stowing $pkg"
    stow --target="$HOME" --restow "$pkg"
  done
  [ -d "$BACKUP" ] && info "Replaced files were saved to $BACKUP"
}

# -------------------------------------------------------------------- main ---
[ "$DO_PACKAGES" -eq 1 ] && install_packages
[ "$DO_PACKAGES" -eq 1 ] && install_shell_extras
[ "$DO_STOW" -eq 1 ] && stow_packages

info "Done."
echo
echo "Next steps:"
echo "  - Set zsh as your shell:  chsh -s \$(command -v zsh)"
echo "  - Start tmux and press  prefix + I  to install tmux plugins"
echo "  - Log out / restart Hyprland to apply everything"
