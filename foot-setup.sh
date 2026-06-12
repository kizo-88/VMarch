#!/usr/bin/env bash
set -x
pkill -x kitty 2>/dev/null

# 1. Install foot (Wayland-native, CPU-rendered - reliable in VMs)
pacman -S --needed --noconfirm foot || exit 1

# 2. foot config: transparency + nerd font + padding (colors come from pywal at shell start)
install -d -o arch -g arch /home/arch/.config/foot
cat > /home/arch/.config/foot/foot.ini <<'FOOT'
[main]
font=JetBrainsMono Nerd Font:size=11
pad=14x14

[colors]
alpha=0.85
background=0d1117
foreground=c9d1d9
FOOT

# 3. zshrc: run fastfetch in foot (not just kitty)
sed -i 's/\[\[ -n "\$KITTY_WINDOW_ID" \]\]/[[ $TERM == foot* || -n "$KITTY_WINDOW_ID" ]]/' /home/arch/.zshrc
grep -n 'TERM == foot' /home/arch/.zshrc

# 4. Hyprland: Super+Enter opens foot
sed -i 's/bind = \$mod, Return, exec, kitty/bind = $mod, Return, exec, foot/' /home/arch/.config/hypr/hyprland.conf
grep -n 'Return, exec' /home/arch/.config/hypr/hyprland.conf

chown -R arch:arch /home/arch/.config/foot
# 5. Reload + open foot
SIG=$(ls /run/user/1001/hypr | head -1)
sudo -u arch env XDG_RUNTIME_DIR=/run/user/1001 HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl reload
sudo -u arch env XDG_RUNTIME_DIR=/run/user/1001 HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl dispatch exec foot
echo FOOT_DONE
