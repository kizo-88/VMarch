#!/usr/bin/env bash
# Rice the Hyprland setup: fastfetch + zsh + themed kitty + dark forest wallpaper.
set -x

# 1. Packages
pacman -S --needed --noconfirm fastfetch zsh zsh-autosuggestions zsh-syntax-highlighting ttf-jetbrains-mono-nerd || exit 1

# 2. zsh as default shell for arch
chsh -s /usr/bin/zsh arch

# 3. Dark misty-forest wallpaper from the nordic-wallpapers repo (pick one file via GitHub API)
curl -s "https://api.github.com/repos/linuxdotexe/nordic-wallpapers/contents/wallpapers" -o /tmp/walls.json
URL=$(grep -o '"download_url": *"[^"]*"' /tmp/walls.json | cut -d'"' -f4 | grep -iE 'forest|fog|mist|pine' | head -1)
[ -z "$URL" ] && URL=$(grep -o '"download_url": *"[^"]*"' /tmp/walls.json | cut -d'"' -f4 | grep -i 'ign_' | head -1)
echo "wallpaper URL: $URL"
if [ -n "$URL" ]; then
    curl -sL "$URL" -o /home/arch/Pictures/wall.png && echo WALL_DOWNLOADED
fi

# 4. kitty config: pywal colors + transparency + nerd font
install -d -o arch -g arch /home/arch/.config/kitty
cat > /home/arch/.config/kitty/kitty.conf <<'KITTY'
include ~/.cache/wal/colors-kitty.conf
background_opacity 0.82
font_family JetBrainsMono Nerd Font
font_size 11
window_padding_width 14
cursor_shape beam
confirm_os_window_close 0
KITTY

# 5. zsh config: pywal colors in every terminal + fastfetch on open + plugins
cat > /home/arch/.zshrc <<'ZSHRC'
# pywal colors for this terminal
(cat ~/.cache/wal/sequences 2>/dev/null &)

autoload -U colors && colors
PROMPT='%F{cyan}%n%f %F{blue}%~%f %F{magenta}❯%f '

HISTFILE=~/.zsh_history
HISTSIZE=5000
SAVEHIST=5000
setopt autocd correct interactive_comments

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null

alias ls='ls --color=auto'
alias ff='fastfetch'

# system info splash like the rice screenshots
if [[ $- == *i* ]] && [[ -n "$KITTY_WINDOW_ID" ]]; then
    fastfetch
fi
ZSHRC

# 6. Hyprland: blur + rounding + kitty transparency rule (replace decoration block)
HCONF=/home/arch/.config/hypr/hyprland.conf
sed -i '/^decoration {/,/^}/d' "$HCONF"
cat >> "$HCONF" <<'HYPR'

decoration {
    rounding = 8
    active_opacity = 1.0
    inactive_opacity = 0.95
    blur {
        enabled = true
        size = 5
        passes = 2
        ignore_opacity = false
    }
}
windowrule = opacity 0.92 0.86, class:kitty
HYPR

chown -R arch:arch /home/arch
echo RICE_SETUP_DONE
