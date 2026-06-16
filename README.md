# VMarch — Arch Linux VM scripts

PowerShell scripts and notes for running an **Arch Linux** virtual machine on Windows,
in both **VirtualBox (Oracle)** and **QEMU**.

> The disk image (`arch.vdi`), the installer (`archlinux.iso`), and the QEMU binaries are
> **not** included in this repo (too large for GitHub — see `.gitignore`). This repo holds
> only the scripts and the setup documentation.

## Contents

| File | Purpose |
|------|---------|
| [`SETUP-LOG.md`](SETUP-LOG.md) | Full step-by-step log of how the VM was set up (boot fix, password reset, networking, XFCE desktop). |
| [`NMAP-TUTORIAL.md`](NMAP-TUTORIAL.md) | Full nmap tutorial — install, common scans, timing flags, saving output. |
| `nmap-guide.sh` | Interactive nmap helper script — run inside the Arch VM. |
| [`Cybersecurity-Toolkit-Tutorial.pdf`](Cybersecurity-Toolkit-Tutorial.pdf) | PDF tutorial for the installed security toolkit (recon → exploitation → forensics). |
| `install-sectools.sh` | Installs the curated cybersecurity toolkit (run inside the VM). |
| `enable-repos.sh` | Enables the BlackArch repo + multilib in the VM. |
| `make-pdf.py` | Regenerates the toolkit PDF (reportlab, run in the VM). |
| `setup-vbox.ps1` | Create/repair the VirtualBox VM `ArchLinux-VM` (BIOS firmware, attach disk). |
| `run-vm.ps1` | Boot the installed disk in QEMU. |
| `download.ps1` | Download the latest Arch Linux ISO. |

## Quick start

The disk is a **BIOS/MBR** install (GRUB in the MBR) — the VM **must use BIOS firmware, not EFI**.

**VirtualBox:**
```powershell
.\setup-vbox.ps1          # first time only (creates the VM)
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm "ArchLinux-VM" --type gui
```

**QEMU:**
```powershell
.\run-vm.ps1
```

> Run only **one** hypervisor at a time against the same disk image.

## Login

- User: `root`
- Password: `arch`

Boots into an **XFCE graphical desktop** via the LightDM login screen.
See [`SETUP-LOG.md`](SETUP-LOG.md) for everything that was configured.

## Tutorial: Fixing Network in QEMU

If you boot the system in QEMU and find you have no internet access (e.g. `ping archlinux.org` fails or `pacman` cannot resolve hosts), the built-in system network service may not be fully active or DHCP isn't enabled for the QEMU interface.

Run these steps as `root` to enable a temporary or persistent DHCP connection:

1. **Configure DHCP** for the wired interface:
   ```bash
   echo '[Match]
   Name=en*
   [Network]
   DHCP=yes' > /etc/systemd/network/20-wired.network
   ```

2. **Start systemd network services**:
   ```bash
   systemctl start systemd-networkd
   systemctl start systemd-resolved
   ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
   ```

3. **Verify Connection**:
   ```bash
   ping -c 3 archlinux.org
   ```
   If successful, you can now run `pacman -Syy` and continue installing packages.
