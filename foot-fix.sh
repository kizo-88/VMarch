#!/usr/bin/env bash
cat > /home/arch/.config/foot/foot.ini <<'FOOT'
[main]
font=JetBrainsMono Nerd Font:size=11
pad=14x14
shell=/usr/bin/zsh

[colors-dark]
alpha=0.85
background=0d1117
foreground=c9d1d9
FOOT
chown arch:arch /home/arch/.config/foot/foot.ini

SIG=$(ls /run/user/1001/hypr | head -1)
RUN="sudo -u arch env XDG_RUNTIME_DIR=/run/user/1001 HYPRLAND_INSTANCE_SIGNATURE=$SIG"
$RUN hyprctl dispatch killactive
sleep 1
$RUN hyprctl dispatch exec foot
echo FOOT_FIXED
