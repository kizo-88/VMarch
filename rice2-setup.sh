#!/usr/bin/env bash
# Taskbar (waybar, pywal-themed) + dock (nwg-dock-hyprland) + app drawer (nwg-drawer).
set -x

pacman -S --needed --noconfirm nwg-drawer nwg-dock-hyprland papirus-icon-theme || exit 1

# --- icon theme for dock/drawer/taskbar ---
install -d -o arch -g arch /home/arch/.config/gtk-3.0
cat > /home/arch/.config/gtk-3.0/settings.ini <<'GTK'
[Settings]
gtk-icon-theme-name=Papirus-Dark
gtk-application-prefer-dark-theme=1
GTK

# --- waybar taskbar config ---
install -d -o arch -g arch /home/arch/.config/waybar
cat > /home/arch/.config/waybar/config.jsonc <<'WB'
{
    "layer": "top",
    "position": "top",
    "height": 34,
    "margin-top": 6,
    "margin-left": 10,
    "margin-right": 10,
    "spacing": 6,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "network", "tray"],
    "hyprland/workspaces": {
        "format": "{id}",
        "on-click": "activate"
    },
    "hyprland/window": {
        "max-length": 40,
        "separate-outputs": true
    },
    "clock": {
        "format": "  {:%a %d %b    %H:%M}",
        "tooltip-format": "{calendar}"
    },
    "cpu":    { "format": "  {usage}%", "interval": 3 },
    "memory": { "format": "  {percentage}%", "interval": 5 },
    "network": {
        "format-ethernet": "󰈀  {ipaddr}",
        "format-wifi": "  {essid}",
        "format-disconnected": "󰖪  offline"
    },
    "tray": { "icon-size": 16, "spacing": 8 }
}
WB

# --- waybar style: pywal colors, floating pill modules ---
cat > /home/arch/.config/waybar/style.css <<'CSS'
@import "/home/arch/.cache/wal/colors-waybar.css";

* {
    font-family: "JetBrainsMono Nerd Font";
    font-size: 13px;
    min-height: 0;
}
window#waybar {
    background: transparent;
    color: @foreground;
}
#workspaces, #window, #clock, #cpu, #memory, #network, #tray {
    background: alpha(@background, 0.82);
    border: 1px solid alpha(@color4, 0.55);
    border-radius: 14px;
    padding: 2px 12px;
    margin: 0 3px;
}
#workspaces {
    padding: 2px 5px;
}
#workspaces button {
    color: @color4;
    background: transparent;
    border-radius: 10px;
    padding: 0 7px;
    margin: 1px 1px;
}
#workspaces button.active {
    background: alpha(@color4, 0.4);
    color: @foreground;
}
#window {
    color: @color6;
}
#window.empty {
    background: transparent;
    border: none;
}
#clock {
    font-weight: bold;
}
#cpu    { color: @color2; }
#memory { color: @color5; }
#network { color: @color4; }
CSS

# --- dock pinned apps ---
printf 'foot\nthunar\nbrave-browser\ngoogle-chrome\n' > /home/arch/.cache/nwg-dock-pinned
chown arch:arch /home/arch/.cache/nwg-dock-pinned

# --- hyprland: autostart dock + drawer, new binds ---
HCONF=/home/arch/.config/hypr/hyprland.conf
grep -q 'nwg-dock-hyprland' "$HCONF" || sed -i '/^exec-once = waybar/a exec-once = nwg-dock-hyprland -r -i 42 -mb 8 -x -c nwg-drawer\nexec-once = nwg-drawer -r' "$HCONF"
grep -q 'bind = \$mod, A,' "$HCONF" || cat >> "$HCONF" <<'BINDS'

bind = $mod, A, exec, nwg-drawer
bind = $mod, E, exec, thunar
BINDS

chown -R arch:arch /home/arch/.config /home/arch/.cache
echo RICE2_SETUP_DONE
