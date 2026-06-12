#!/usr/bin/env bash
# Installs Hyprland + ecosystem, swww, pywal, Brave, Chrome into the Arch VM.
# Logs to /root/install-all.log ; writes /root/install-all.STATUS at the end.
set -o pipefail
LOG=/root/install-all.log
status() { echo "$1" > /root/install-all.STATUS; }
step()   { echo "===== $* ====="; }

status RUNNING

step "1/6 Full system upgrade + keyring"
pacman -Sy --noconfirm archlinux-keyring || { status FAIL_KEYRING; exit 1; }
pacman -Su --noconfirm                    || { status FAIL_UPGRADE; exit 1; }

step "2/6 Install repo packages (Hyprland ecosystem, pywal, build tools)"
pacman -S --needed --noconfirm \
    hyprland xdg-desktop-portal-hyprland \
    kitty waybar wofi wl-clipboard mako \
    polkit polkit-gnome \
    qt5-wayland qt6-wayland \
    grim slurp \
    python-pywal \
    ttf-dejavu ttf-font-awesome \
    flatpak \
    git base-devel sudo \
  || { status FAIL_PACMAN; exit 1; }

step "3/6 Create build user for AUR"
if ! id builder >/dev/null 2>&1; then
    useradd -m -G wheel builder
fi
# Temporary passwordless sudo so makepkg/yay can install packages unattended
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-builder
chmod 440 /etc/sudoers.d/99-builder

step "4/6 Install yay (AUR helper) via yay-bin"
sudo -u builder bash -c '
  set -e
  cd /home/builder
  rm -rf yay-bin
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git
  cd yay-bin
  makepkg -si --noconfirm
' || { status FAIL_YAY; exit 1; }

step "5/6 Build AUR packages: swww, brave-bin, google-chrome"
sudo -u builder yay -S --needed --noconfirm --answerclean None --answerdiff None \
    swww brave-bin google-chrome \
  || { status FAIL_AUR; exit 1; }

step "6/6 Write a starter Hyprland config (software rendering for the VM)"
install -d /root/.config/hypr
cat > /root/.config/hypr/hyprland.conf <<'HYPR'
# Minimal Hyprland config for a VirtualBox VM (software rendering)
env = WLR_NO_HARDWARE_CURSORS,1
env = WLR_RENDERER_ALLOW_SOFTWARE,1
env = LIBGL_ALWAYS_SOFTWARE,1

monitor = ,preferred,auto,1

exec-once = swww-daemon
exec-once = waybar
exec-once = mako
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

$mod = SUPER
bind = $mod, Return, exec, kitty
bind = $mod, D, exec, wofi --show drun
bind = $mod, B, exec, brave
bind = $mod, C, exec, google-chrome-stable
bind = $mod, Q, killactive
bind = $mod SHIFT, E, exit
bind = $mod, F, fullscreen

input {
    follow_mouse = 1
}
general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
}
decoration {
    rounding = 6
}
HYPR

# Generate a default wallpaper + pywal palette so swww/pywal have something to use.
install -d /root/Pictures
if command -v magick >/dev/null 2>&1; then
    magick -size 1920x1080 gradient:#1e3a5f-#0d1b2a /root/Pictures/wall.png || true
fi
cat >> /root/.config/hypr/hyprland.conf <<'HYPR2'

# Set wallpaper after the daemon starts (image created at first login if present)
exec-once = sh -c 'sleep 2; [ -f /root/Pictures/wall.png ] && swww img /root/Pictures/wall.png; command -v wal >/dev/null && wal -i /root/Pictures/wall.png -n'
HYPR2

echo "All done."
status DONE
