#!/usr/bin/env bash
# Create a normal user for Hyprland (it refuses to run as root) and wire up the session.
set -x

# 1. User: arch / arch
if ! id arch >/dev/null 2>&1; then
    useradd -m -G wheel,video,audio,autologin arch
else
    gpasswd -a arch autologin
    gpasswd -a arch video
fi
echo 'arch:arch' | chpasswd

# sudo for wheel
pacman -S --needed --noconfirm sudo >/dev/null 2>&1
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

# 2. Hyprland config for the arch user (VM-friendly)
install -d -o arch -g arch /home/arch/.config/hypr /home/arch/Pictures

cat > /home/arch/.config/hypr/hyprland.conf <<'HYPR'
# Hyprland in a VirtualBox VM
env = WLR_NO_HARDWARE_CURSORS,1
env = WLR_RENDERER_ALLOW_SOFTWARE,1
env = AQ_NO_MODIFIERS,1

monitor = ,preferred,auto,1

exec-once = swww-daemon
exec-once = waybar
exec-once = mako
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = sh -c 'sleep 2; [ -f ~/Pictures/wall.png ] && swww img ~/Pictures/wall.png; command -v wal >/dev/null && wal -i ~/Pictures/wall.png -n'

$mod = SUPER
bind = $mod, Return, exec, kitty
bind = $mod, D, exec, wofi --show drun
bind = $mod, B, exec, brave
bind = $mod, C, exec, google-chrome-stable
bind = $mod, Q, killactive
bind = $mod SHIFT, E, exit
bind = $mod, F, fullscreen
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow

cursor {
    no_hardware_cursors = true
}
general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
}
decoration {
    rounding = 6
}
misc {
    force_default_wallpaper = 0
}
HYPR

# 3. Wallpaper for swww/pywal
magick -size 1920x1080 gradient:'#1e3a5f'-'#0d1b2a' /home/arch/Pictures/wall.png || true
chown -R arch:arch /home/arch

# 4. Autologin -> arch into hyprland
sed -i 's/^autologin-user=root/autologin-user=arch/' /etc/lightdm/lightdm.conf
grep -n 'autologin' /etc/lightdm/lightdm.conf | tail -5

# 5. Avoid dual DRM drivers: VMSVGA uses vmwgfx; vboxvideo conflicts
echo 'blacklist vboxvideo' > /etc/modprobe.d/blacklist-vboxvideo.conf

echo HYPR_USER_SETUP_DONE
