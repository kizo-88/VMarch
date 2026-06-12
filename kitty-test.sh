#!/usr/bin/env bash
U=1001
ENV="sudo -u arch env XDG_RUNTIME_DIR=/run/user/$U WAYLAND_DISPLAY=wayland-1 DISPLAY=:0"

echo "=== test1: wayland, opacity 1.0 ==="
timeout 5 $ENV kitty -o background_opacity=1.0 >/tmp/k1.log 2>&1
echo "exit=$? log: $(tail -n2 /tmp/k1.log)"

echo "=== test2: xwayland backend ==="
timeout 5 $ENV kitty -o linux_display_server=x11 >/tmp/k2.log 2>&1
echo "exit=$? log: $(tail -n2 /tmp/k2.log)"

echo "=== test3: wayland, no wal include (plain config) ==="
timeout 5 $ENV kitty --config NONE >/tmp/k3.log 2>&1
echo "exit=$? log: $(tail -n2 /tmp/k3.log)"
