# dotfiles

Arch Linux + Hyprland setup, themed **Gruvbox Dark** with the **Iosevka Nerd Font**.

## Install

On a fresh Arch machine:

```sh
git clone https://github.com/qnichi21999/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` will:

1. install every package in [`packages.txt`](packages.txt) (pacman) and [`aur-packages.txt`](aur-packages.txt) (yay — installed automatically if missing);
2. install `oh-my-zsh`, the `powerlevel10k` theme, and the tmux plugin manager;
3. symlink all configs into `$HOME` with GNU Stow.

Any existing real config file is moved to `~/.dotfiles-backup-<timestamp>/` before being
replaced, so the script is safe to re-run.

```sh
./install.sh --stow      # only re-symlink configs
./install.sh --packages  # only (re)install packages
```

## Layout

The repo is organised as [GNU Stow](https://www.gnu.org/software/stow/) packages — each
top-level directory mirrors `$HOME`:

| Package            | Installs into                                            |
|--------------------|----------------------------------------------------------|
| `hypr`             | `~/.config/hypr` (Hyprland, hyprpaper, scripts, wallpaper)|
| `waybar`           | `~/.config/waybar`                                       |
| `kitty`            | `~/.config/kitty`                                        |
| `rofi`             | `~/.config/rofi`                                         |
| `dunst`            | `~/.config/dunst`                                        |
| `gtk`              | `~/.config/gtk-3.0`, `gtk-4.0`, `xsettingsd`, `~/.gtkrc-2.0` |
| `qt`               | `~/.config/qt5ct`, `qt6ct`, `kdeglobals`, KDE color scheme |
| `nwg-look`         | `~/.config/nwg-look`                                     |
| `zsh`              | `~/.zshrc`, `~/.p10k.zsh`                                 |
| `tmux`             | `~/.config/tmux`                                         |
| `thunar`           | `~/.config/Thunar`                                       |
| `opentabletdriver` | `~/.config/OpenTabletDriver`                             |
| `themes`           | `~/.themes` (Gruvbox GTK theme)                          |

To stow a single package manually: `stow --target=$HOME hypr`.

## Theming

- **GTK** — `Gruvbox-Dark-Medium` (in `themes/`), set via `nwg-look`.
- **Qt** — `qt5ct`/`qt6ct` with the Fusion style and a Gruvbox palette
  (`qt/.config/qt6ct/colors/gruvbox.conf`). `QT_QPA_PLATFORMTHEME=qt6ct` is exported
  in `hyprland.conf`.
- **KDE apps** (Dolphin, Ark) — Gruvbox color scheme baked into `kdeglobals`.
- **Terminal / bar / notifications** — Gruvbox + Iosevka Nerd Font.

## Notes

- The clipboard history (`SUPER+V`) needs the `cliphist` watcher, which is started from
  `hyprland.conf` (`exec-once = wl-paste --watch cliphist store`).
- After first install, run tmux and press `prefix + I` to fetch tmux plugins.
