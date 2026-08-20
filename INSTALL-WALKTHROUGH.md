# Installing Arch alongside Windows 11 — MSI GF63 Thin 10SC

A record of the install as it actually happened on 20 August 2026, including every
place it went wrong. The idealised version is in [`YOUR-PART.md`](YOUR-PART.md); this
one keeps the mistakes, because all of them are easy to repeat.

Result: Arch Linux and Windows 11 sharing one NVMe, both reachable from a GRUB menu.

---

## The machine

| | |
|---|---|
| Model | MSI GF63 Thin 10SC |
| CPU / RAM | i5-10300H · 20 GB |
| GPU | GTX 1650 Max-Q + Intel UHD (no MUX switch) |
| Disk | PNY CS1031 1 TB SSD — 931.51 GiB, GPT |
| Firmware | UEFI, Secure Boot **had to be disabled** |
| Boot menu key | **F11** · BIOS Setup: **Del** |

Partition layout before the install:

```
p1   128M     Microsoft reserved
p2   300M     EFI System            <- shared with Arch, never formatted
p3   792.4G   Windows (NTFS)
     129GB    Free space            <- carved out beforehand, becomes p6
p4   900M     Windows recovery
p5   17.8G    MSI OEM recovery
```

Two design consequences fall straight out of that table:

* **The ESP is only 300 MB and already holds Windows' boot loader.** It cannot also hold
  Linux kernels, so this build uses **GRUB** (a ~10 MB stub on the ESP, kernels on the
  root filesystem) rather than systemd-boot.
* **The free space sits between `p3` and `p4`.** The new partition still gets numbered
  `p6`, because GPT numbers by table slot, not by physical position. That looks wrong
  and is not.

---

## Before the USB: the Windows side

Done in an earlier session, verified rather than assumed:

* **BitLocker** — checked with `manage-bde -status C:`. Both volumes fully decrypted, no
  key protectors, so nothing needed suspending. **If yours is encrypted, save the
  recovery key somewhere off the machine first.** Repartitioning an encrypted volume
  without the key is how people lose a Windows install.
* **Fast Startup** — turned off with `powercfg /h off`. It hibernates the kernel instead
  of shutting down, which leaves NTFS dirty and makes Linux refuse to mount `C:`
  read-write. **Leave it off permanently.**
* **The shrink** — 120 GiB freed from `C:` in Disk Management, left **unallocated**.
  Don't create or format a partition here; the Arch installer wants raw space.

> **Trap: the shrink ceiling lies.** `Get-PartitionSupportedSize` took **356 seconds** on
> a 912 GB volume. Earlier runs were killed before answering, and Disk Management's
> pessimistic estimate (54 GB) got recorded instead. The real answer was 149.45 GB.
> Isolate that call and let it finish.

---

## Phase 1 — Boot the installer

Secure Boot must be off; the Arch image is unsigned and the firmware will refuse it
outright.

1. **Del** at the MSI splash → **Security** → **Secure Boot → Disabled** → **F10**.
2. **F11** at the splash → pick the USB from under **UEFI**.

> **Trap: take the UEFI entry.** If the same stick appears twice, the non-UEFI one boots
> in legacy mode and produces an install that cannot coexist with Windows.

At the boot menu, the highlighted entry is **"Reboot Into Firmware Interface"**, which
drops you back into BIOS. Arrow **up** to the top entry:

```
Arch Linux install medium (x86_64, UEFI)
```

That the menu says `UEFI` and offers a firmware-reboot entry is itself confirmation you
booted the right way.

### Confirm where you are

```bash
cat /sys/class/dmi/id/product_name     # GF63 Thin 10SC
lsblk
parted /dev/nvme0n1 print free
```

`parted` should show the five Windows partitions and a **129GB Free Space** block.
(129 GB decimal = 120 GiB — `parted` counts in powers of ten, Windows in powers of two.
Same space, two conventions.)

---

## Phase 2 — Network

`pacstrap` downloads the entire base system, so nothing proceeds without this.

```bash
iwctl
```

Then, at the `[iwd]#` prompt:

```
device list                              # confirm the name is wlan0 and Powered is on
station wlan0 scan
station wlan0 get-networks               # your SSID is in this list
station wlan0 connect YOUR_SSID
station wlan0 show                       # State: connected
exit
```

```bash
ping -c3 archlinux.org
```

> **Trap: scanning is not connecting.** The first attempt here ran `scan` and then `exit`
> — `get-networks` and `connect` never happened. `ping` then failed with *Temporary
> failure in name resolution*, which reads like a DNS problem and isn't. **Confirm
> `State: connected` before leaving `iwctl`.**

> **Trap: `wlan` is not `wlan0`.** `device wlan set-property Powered on` returns *Device
> wlan not found*. Use the exact name from `device list`.

Ignore `NetworkConfigurationEnabled: disabled` — iwd is saying it doesn't do addressing
itself. archiso runs `systemd-networkd` for that.

**Wired is easier.** The GF63 has an ethernet port; plug in a cable and DHCP just works.
Worth it for a multi-minute `pacstrap`.

While you're here, sync the clock. A skewed clock makes `pacstrap` fail later with GPG
signature errors that look like corruption:

```bash
timedatectl set-ntp true
```

---

## Phase 3 — Fetch the scripts

```bash
bash -c 'cd /root && for f in 01-partition 02-install 03-chroot 04-nvidia; do curl -fLO https://raw.githubusercontent.com/kizo-88/VMarch/dualboot-setup/arch/$f.sh; done'
chmod +x /root/*.sh
head -1 /root/01-partition.sh          # must be #!/usr/bin/env bash
```

> **Trap: archiso's shell is zsh, not bash.** Running the loop directly, zsh's autocorrect
> prompted `correct 'f.sh' to '_fsh' [nyae]?`. Answering `y` substituted a zsh completion
> function for the filename, producing a screenful of
> `_arguments:comparguments:327: can only be called from completion function`, four
> backgrounded curls against a truncated URL, and no files.
>
> **Answer `n` to any `zsh: correct …` prompt**, and wrap loops in `bash -c '…'`.

> **Use `curl -f`.** Without it, curl cheerfully saves a 404 page *as* the script. With
> it, a bad URL fails loudly. This is why `head -1` is worth running.

---

## Phase 4 — Create the partition

```bash
./01-partition.sh
```

The first run verifies the layout and stops. Two lines must appear:

```
p1-p5 present.
ESP p2 holds the Windows boot loader. Good - it will be reused, never formatted.
```

It ends with **`No new partition yet.`** — that is **success**, not an error. The script
is handing back to you because the partition doesn't exist yet.

```bash
cfdisk /dev/nvme0n1
```

* Arrow **down** to the green **Free space** row showing **120G**. The cursor starts on
  `p1`, and `p3` (792.4G, Windows) sits directly above your target.
* **New** → accept the full size → leave the type as *Linux filesystem*.
* **Check the table before writing.** You want a new `p6` at 120G and `p1`–`p5`
  completely unchanged.
* **Write** → type **`yes`** in full → **Quit**.

> **Trap: Quit is not Write.** After creating the partition, cfdisk leaves the menu on
> **[ Quit ]**, whose help text reads *"Quit program without writing changes."* Pressing
> Enter there silently discards the new partition. Arrow **right** to **[ Write ]** and
> watch the help line change to *"Write partition table to disk"* first.
>
> **[ Delete ]** lives in that same menu row, and at this moment the cursor is sitting on
> your Windows partition. Move right, not left.

Now the destructive step:

```bash
./01-partition.sh
```

It finds `p6`, prints what it is about to do, and waits:

```
About to run:  mkfs.ext4 /dev/nvme0n1p6   (120 GB)
Type YES to format this partition:
```

**Read the size before typing `YES`.** 120 GB is right. Anything near 792 GB is Windows.

This is the first irreversible action in the whole process; everything before it can be
walked back.

---

## Phase 5 — Install the base system

```bash
./02-install.sh
```

It re-checks the recorded target, refuses anything in `p1`–`p5`, requires ext4, verifies
the network, mounts the shared ESP, and confirms `bootmgfw.efi` is still on it before
installing anything. Then `pacstrap`. **Took 3m10s** over wifi.

Ends with `Base system installed.` and prints the generated `/etc/fstab`.

If it fails partway:

* *Signature … unknown trust* → `pacman -Sy archlinux-keyring`, re-run.
* *Failed to retrieve file* → wifi dropped. Reconnect, re-run. `pacstrap` resumes safely.

---

## Phase 6 — Configure, and make Windows appear in the menu

```bash
arch-chroot /mnt
```

**Set the variables explicitly.** Do not rely on the defaults:

```bash
TZ_REGION=Asia/Kuala_Lumpur ARCH_HOSTNAME=archmsi USERNAME=kizo /root/03-chroot.sh
```

> **Trap: the shell shadows your defaults.** `HOSTNAME=${HOSTNAME:-archmsi}` never applies
> its default, because bash sets `HOSTNAME` itself — the install would come out named
> `archiso`, after the live USB. That one was caught and renamed to `ARCH_HOSTNAME`.
>
> **`USERNAME` in `03-chroot.sh` still has the same flaw**, and zsh sets `USERNAME` as a
> special parameter. If it leaks through as `root`, then `id root` succeeds, `useradd` is
> skipped, `passwd` just resets root a second time, and you finish with **no user account
> at all**. Passing `USERNAME=` explicitly sidesteps it entirely.

The script sets locale, clock and hostname, creates the user with wheel sudo, enables
NetworkManager, prompts for both passwords, then installs GRUB and — the part that
matters — enables `os-prober`, which is disabled by default in Arch and is the single
most common reason a dual boot ends up with no Windows entry.

The line to watch for:

```
Found Windows Boot Manager on /dev/nvme0n1p2@/EFI/Microsoft/Boot/bootmgfw.efi
==============================================
 Found Windows Boot Manager - dual boot is OK
==============================================
```

Green means done. Red means stop and fix it before rebooting — you are not locked out
either way, since **F11** lists both loaders straight from firmware.

```bash
exit
umount -R /mnt
reboot          # pull the USB out as it restarts
```

---

## Phase 7 — It boots straight into Windows

Expected, and not a fault. The firmware simply prefers its own Windows entry over the
new GRUB one, so GRUB is never reached.

**Right now:** reboot, tap **F11**, pick **`Arch`**.

**Permanently**, once in Arch:

```bash
efibootmgr                       # note the 4-digit number next to Arch
sudo efibootmgr -o 0002,0000     # Arch first, Windows second
efibootmgr | head -5             # confirm BootOrder changed
sudo reboot
```

Or from firmware: **Del** at the splash → **Boot** → **Boot Option #1** → `Arch` → **F10**.
The firmware route tends to stick better on MSI boards.

> Some MSI boards re-assert Windows as default after a Windows Update. Same fix; not a
> broken install.

**Boot both systems once before doing anything else.** If something is wrong, you want to
find it now.

---

## Phase 8 — Graphics and the leftovers

```bash
sudo /root/04-nvidia.sh
```

(The script lives in root's home, which a normal user can't read — hence `sudo`.)

It installs the proprietary driver plus `nvidia-prime`, sets early KMS in
`mkinitcpio.conf`, and re-checks the Windows GRUB entry afterwards. Reboot, then:

```bash
nvidia-smi
prime-run glxinfo | grep "OpenGL renderer"
```

> Early KMS can produce a black screen if something is off. Recoverable: pick the
> *fallback* initramfs entry in GRUB, or press `e` on the Arch entry and append
> `nomodeset` to the kernel line.

### Two gaps the scripts leave

No swap is configured. With 20 GB you rarely need the capacity, but without any swap the
machine hard-stalls under memory pressure instead of degrading:

```bash
sudo mkswap -U clear -s 8G -F /swapfile && sudo swapon /swapfile && echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
```

And to read the Windows partition from Arch:

```bash
sudo pacman -S ntfs-3g
```

### The clock

Arch keeps the hardware clock in UTC (`03-chroot.sh` runs `timedatectl set-local-rtc 0`);
Windows assumes local time. Left alone they overwrite each other and one is always wrong
by your UTC offset. Fix it on the Windows side, once, as Administrator:

```
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

> Do **not** also run `timedatectl set-local-rtc 1` in Arch. Some notes recommend it; it
> directly contradicts what `03-chroot.sh` already did, and applying both leaves you worse
> off than either alone.

---

## What the install produced

| | |
|---|---|
| Root | `/dev/nvme0n1p6` · ext4 · 120 GiB |
| ESP | `/dev/nvme0n1p2` · shared, **never reformatted** |
| Bootloader | GRUB, `--bootloader-id=Arch`, `os-prober` enabled |
| Hostname | `archmsi` |
| Windows | untouched at 792.4 G, in the GRUB menu |

---

## If you need to undo it

Fully reversible. In Windows Disk Management, delete `p6` and extend `C:` back over the
free space. Then clear the firmware entry:

```
bcdedit /enum firmware
bcdedit /delete "{THE-GUID-SHOWN}"
```

Optionally remove `\EFI\Arch` from the ESP. Nothing in this process wrote to `p1`–`p5`
except adding one directory to the shared ESP.

---

## The short version

Nine things cost time, and none of them were the install itself:

1. The boot menu opens on *Reboot Into Firmware Interface*, not the installer.
2. `scan` is not `connect` — check `State: connected` before leaving `iwctl`.
3. archiso runs **zsh**; its autocorrect will rewrite your commands if you answer `y`.
4. `curl` without `-f` saves 404 pages as scripts.
5. cfdisk's menu rests on **Quit**, whose help text says *without writing changes*.
6. GPT numbers by slot, so free space between `p3` and `p4` becomes `p6`.
7. The shell sets `HOSTNAME` and `USERNAME`, silently eating your `${VAR:-default}`.
8. `os-prober` is disabled by default — the usual cause of a missing Windows entry.
9. Firmware prefers Windows; GRUB never gets reached until you reorder the boot entries.
