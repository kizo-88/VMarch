#!/usr/bin/env bash
# Temporarily autologin into Hyprland to test that it renders in the VM.
set -x
groupadd -r autologin 2>/dev/null || true
gpasswd -a root autologin

cp -n /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.bak 2>/dev/null || true

# Append a test autologin seat config
cat >> /etc/lightdm/lightdm.conf <<'EOF'

# --- HYPR TEST (temporary) ---
[Seat:*]
autologin-user=root
autologin-user-timeout=0
autologin-session=hyprland
# --- END HYPR TEST ---
EOF

# Make sure Hyprland has a log we can read
mkdir -p /root/.config/hypr
systemctl restart display-manager
echo "lightdm restarted for hyprland autologin test"
