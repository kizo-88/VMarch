#!/usr/bin/env bash
# Install the 3 stragglers via isolated methods (avoid python 3.14 repo conflicts).
status() { echo "$1" > /root/fix3.STATUS; }
status RUNNING
set -x

pacman -S --needed --noconfirm python-pipx git >/dev/null 2>&1
export PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin

# 1. sqlmap — pure python, run from git
rm -rf /opt/sqlmap
git clone --depth=1 https://github.com/sqlmapproject/sqlmap.git /opt/sqlmap
ln -sf /opt/sqlmap/sqlmap.py /usr/local/bin/sqlmap
chmod +x /opt/sqlmap/sqlmap.py

# 2. mitmproxy — pipx isolated venv
pipx install mitmproxy

# 3. recon-ng — pipx from git
pipx install "git+https://github.com/lanmaster53/recon-ng.git" || {
    rm -rf /opt/recon-ng
    git clone --depth=1 https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
    python -m venv /opt/recon-ng/.venv
    /opt/recon-ng/.venv/bin/pip install -r /opt/recon-ng/REQUIREMENTS >/dev/null 2>&1
    printf '#!/bin/bash\ncd /opt/recon-ng && /opt/recon-ng/.venv/bin/python recon-ng "$@"\n' > /usr/local/bin/recon-ng
    chmod +x /usr/local/bin/recon-ng
}

echo "=== verify ==="
for t in sqlmap mitmproxy recon-ng; do
  command -v "$t" >/dev/null 2>&1 && echo "OK $t -> $(command -v $t)" || echo "MISS $t"
done
status DONE
