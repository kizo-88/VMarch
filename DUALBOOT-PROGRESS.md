# Dual-boot progress tracker

Companion to [`DUALBOOT.md`](DUALBOOT.md). Updated as steps complete.
Last verified: **2026-08-20**

> **Steps 0–3 are done. The remaining work is all outside Windows —
> see [`YOUR-PART.md`](YOUR-PART.md) for the step-by-step, readable from the live USB.**

## Verified live on this machine (elevated; step 0 on 2026-08-19, step 1 on 2026-08-20)

| Check | Result |
|---|---|
| Disk 1 = PNY CS1031 1 TB NVMe, GPT | ✅ matches plan (note: it is disk **1**, not 0) |
| Partition layout p1–p5 | ✅ p1/p2/p4/p5 untouched at their original offsets; p3 (`C:`) now 792.414 GB after the shrink |
| Unallocated space on disk 1 | ✅ **120 GB** — shrunk 2026-08-20, sits between `C:` (ends 792.834 GB) and WinRE (starts 912.83 GB) |
| `C:` free space | 95 GB free of 792.414 GB |
| Disk 2 (`D:`) | 464 GB, BusType **Spaces** → confirmed Storage Spaces, unusable for Arch |
| Fast Startup (`HiberbootEnabled`) | ✅ `0` (off) |
| `hiberfil.sys` | ✅ absent — hibernation already off |
| Arch ISO | ✅ `C:\.DEVELOPER\VM\archlinux.iso`, 1523 MB |
| Arch ISO SHA256 | ✅ **verified** — recomputed from the file on disk and matched against the official `sha256sums.txt` for 2026.08.01: `4e82dced…425ffe5e`. Safe to flash. |
| Secure Boot | ⚠️ **`SecureBootEnabled = True` — must be turned off in firmware before the USB will boot** |
| BitLocker `C:` and `D:` | ✅ `FullyDecrypted`, ProtectionStatus `Off`, no key protectors — nothing to suspend |
| Shadow copies | ℹ️ **two exist** (`{10471591-…}` 08-18, `{8fbc1fd0-…}` 08-19) — not worth deleting, see below |
| Max shrink on `C:` | ✅ **149.45 GB** (min size 762.97 GB) — measured elevated, query took 356 s |
| Pagefile location | ⭐ **`D:\pagefile.sys`, 14 GB — not on `C:` at all** |
| Installer medium | ✅ **Disk 3, `SSD 1TB`, USB, 953.87 GB** — the Samsung, after the user removed its storage pool on 2026-08-20 |
| USB writer | ✅ **Rufus 4.15 installed** 2026-08-20 via `winget` (official GitHub release, installer hash verified). On PATH as `rufus`; binary at `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Rufus.Rufus_Microsoft.Winget.Source_8wekyb3d8bbwe\rufus.exe` |

### Resolved — there is no shrink problem

The 54.1 GB ceiling recorded on 2026-08-18 was an artefact of a query that never finished.
`Get-PartitionSupportedSize -DriveLetter C` takes **~6 minutes** on this 912 GB volume;
every earlier run (including the one inside `preflight.ps1`, which dies with "The pipeline
has been stopped") was killed before it returned. Run in isolation with
[`_maxshrink.ps1`](_maxshrink.ps1) and allowed to finish, it reports:

```
Current size : 912.41 GB
Minimum size : 762.97 GB
MAX SHRINK   : 149.45 GB
```

So none of the space-reclamation advice is needed:

- **Pagefile** — on `D:`, `C:` has none. Nothing to move.
- **Hibernation** — already off, `hiberfil.sys` absent. `powercfg /h off` is a no-op.
- **Shadow copies** — two exist, but at 149 GB available there is no reason to delete
  System Restore points to gain more.

**Executed 2026-08-20: shrank by exactly 120 GB**, well inside the 149.45 GB limit. `C:` went
912.414 → 792.414 GB and 120 GB is now unallocated. No shadow copies were deleted, no
pagefile or hibernation changes were needed.

## Step status

| # | Step | Where | Status |
|---|---|---|---|
| 0 | Pre-flight verification | Windows | ✅ **done** — elevated, 2026-08-19 |
| 1 | Shrink `C:` by 120 GB, leave unallocated | Windows, elevated | ✅ **done 2026-08-20** — `C:` 912.414 → **792.414 GB**, **120 GB unallocated**, volume Healthy, 95 GB free |
| 2 | Disable Secure Boot | Firmware (Del at MSI splash) | ⬜ **you must do this** — not reachable from Windows |
| 3 | Write Arch USB | Windows | ✅ **done 2026-08-20** — raw-written to disk 3 by [`_write-iso.ps1`](_write-iso.ps1) (1523 MB in 5.6 s), **read-back SHA256 verified byte-for-byte**. Isohybrid layout present: MBR + 258 MB EFI partition |
| 4 | Boot installer (F11), connect wifi | Firmware / live USB | ⬜ |
| 5 | Partition free space → p6, `mkfs.ext4` | Arch live USB | 🟩 scripted — [`arch/01-partition.sh`](arch/01-partition.sh) |
| 6 | Mount p6, mount existing ESP p2 at `/boot/efi` | Arch live USB | 🟩 scripted — [`arch/02-install.sh`](arch/02-install.sh) |
| 7 | `pacstrap` base system | Arch live USB | 🟩 scripted — [`arch/02-install.sh`](arch/02-install.sh) |
| 8 | GRUB + `GRUB_DISABLE_OS_PROBER=false` → Windows entry | chroot | 🟩 scripted — [`arch/03-chroot.sh`](arch/03-chroot.sh) |
| 9 | NVIDIA Optimus drivers, laptop extras | Arch | 🟩 scripted — [`arch/04-nvidia.sh`](arch/04-nvidia.sh) |

🟩 = script written, syntax-checked, LF line endings, not yet executed (needs the live USB).
See [`arch/README.md`](arch/README.md) for the run order and how to copy the folder onto the USB.

## Log — 2026-08-19

- Elevated `preflight.ps1` ran to completion. Secure Boot, BitLocker and the disk layout
  all confirmed; its max-shrink section still aborted with "The pipeline has been stopped".
- Added [`_maxshrink.ps1`](_maxshrink.ps1) — read-only, isolates the slow
  `Get-PartitionSupportedSize` call. Returned **149.45 GB** after 356 seconds, overturning
  the 54.1 GB figure that `DUALBOOT.md` was built around.
- Nothing on disk was modified. `C:` is still 912.414 GB with 0 GB unallocated.

### Also on 2026-08-19 — script review and fixes

The four `arch/*.sh` scripts were read end to end, not just syntax-checked. They are sound;
three real defects were found and fixed.

| File | Defect | Fix |
|---|---|---|
| [`preflight.ps1`](preflight.ps1) | `Get-PartitionSupportedSize` runs inline and is torn down mid-pipeline before the ~6-minute query returns — this is what produced the bogus 54.1 GB figure | now runs in a job with a 15-minute wait and an explicit failure message |
| [`arch/01-partition.sh`](arch/01-partition.sh) | with more than one non-Windows partition it printed "pass TARGET= explicitly" and then **carried on anyway** with `NEW[0]` — it could format a partition you never chose | now `exit 1` unless `TARGET=` is set |
| [`arch/03-chroot.sh`](arch/03-chroot.sh) | `HOSTNAME=${HOSTNAME:-archmsi}` — **bash sets `HOSTNAME` itself**, so the default never applied and the box would have been named `archiso` after the live USB | renamed to `ARCH_HOSTNAME`, override documented in `arch/README.md` |

All four still pass `bash -n`, LF endings intact; `preflight.ps1` parses clean.

Reviewed and left alone: the p1–p5 guards, the ESP `bootmgfw.efi` check in both 01 and 02,
the ext4-only check in 02, and the "Found Windows Boot Manager" gate in 03 — that last one
is the most valuable thing in the set and it is correct.

**Note for later:** `03-chroot.sh` runs `timedatectl set-local-rtc 0` (Linux keeps the RTC
in UTC). Windows keeps it in local time, so the two will disagree by your UTC offset until
you either point Windows at UTC via the registry or set `--local-rtc 1` on the Arch side.
Cosmetic, but it will look like a bug on first boot.

## Log — 2026-08-20

- **Step 1 executed.** [`_shrink-c.ps1`](_shrink-c.ps1) (elevated) resized `C:` from
  912.414 GB to 792.414 GB via `Resize-Partition`, leaving **120 GB unallocated**. p1, p2,
  p4 and p5 kept their original offsets. `C:` reports Healthy with 95 GB free.
- Arch ISO SHA256 recomputed from disk and matched against the official
  `sha256sums.txt` for 2026.08.01 — **verified authentic**.
- `arch/*.sh` reviewed line by line; three defects found and fixed (table above).

### Verification gotcha — do not trust `Win32_DiskPartition`

While the resize was running the storage-service cmdlets (`Get-Partition`, `Get-Disk`)
blocked, and `Get-CimInstance Win32_DiskPartition` was used as a fallback. **It returned
stale cached values** — still showing `C:` at 912.414 GB *after* the shrink had committed —
which led to a wrong "the shrink did not run" conclusion. `Get-Partition` blocking is a sign
the operation is **in progress**, not that it failed. Wait for it; do not switch to CIM.

### Step 3 — why Rufus was bypassed

Rufus reported **"0 devices found"** twice. Cause: the Samsung kept being re-absorbed into a
Storage Space, and Rufus additionally hides non-removable drives (a 1 TB USB SSD reports as
fixed media, so it needs *Advanced drive properties → List USB Hard Drives*).

At one point **two pools were both named `Storage pool`** — one backing the Samsung, one
backing `D:` on the internal SATA HDD. Any `Remove-StoragePool -FriendlyName "Storage pool"`
would have been ambiguous and could have destroyed `D:`. [`_unpool-samsung.ps1`](_unpool-samsung.ps1)
therefore selects the pool **by the physical DeviceId it contains**, refuses if the pool has
any member other than disk 3, and refuses if any volume on it holds more than 1 GB.

The image was then written directly with [`_write-iso.ps1`](_write-iso.ps1) — a raw
`\\.\PhysicalDrive3` copy, the same thing Rufus DD mode does — which refuses any target that
is not USB, is boot/system, or is outside 900–1000 GB. It verifies by **reading the image
back off the disk and hashing it**, which is stronger than Rufus's own check.

> Gotcha: `"\\.\PhysicalDrive3"` loses a backslash when written through a shell heredoc,
> producing `Could not find file 'C:\PhysicalDrive3'`. Check the literal in the file.

### The `I:` trap (2026-08-20)

A 200 GB virtual disk `Storage space` → `I:` was created and proposed as either a backup
target or the Arch target. **It is carved out of the `Samsung` pool — the same physical
disk 3 as `H:`.** Confirmed with `Get-PhysicalDisk -StoragePool`:

```
physical disk 3  "SSD 1TB"  USB  953.9 GB
  └── pool "Samsung"
        ├── virtual disk "Samsung 870 Evo" → H:  949.9 GB   (K4120, 119.72 GB)
        └── virtual disk "Storage space"   → I:  199.9 GB   (empty)
```

So `I:` is useless for both purposes: copying `H:` → `I:` relocates nothing, and wiping the
physical disk destroys both at once. It is also Storage Spaces, which Linux cannot read.
The pool is overcommitted too — 953.2 GB backing 1150 GB of thin-provisioned virtual disks.

Nowhere on this machine fits the 119.72 GB: `C:` 90.7 GB free, `D:` 59.3 GB free.

### Resolved 2026-08-20 — the Samsung was reset by the user

The user removed the `Samsung` pool (both virtual disks + the pool). `H:` and `I:` are gone
along with the 119.72 GB in `K4120`. Physical disk 3 is now a plain USB disk: **Disk 3,
`SSD 1TB`, USB, GPT, 953.87 GB**, `CanPool: True`, 953.74 GB unallocated (one leftover
128 MB reserved stub, which Rufus overwrites).

The internal HDD pool `Storage pool` → `s` → `D:` was **not** touched.

This is now the installer medium. Rufus 4.15 was launched elevated with
`C:\.DEVELOPER\VM\archlinux.iso` preloaded.

> Note: Rufus hides non-removable drives by default. A 1 TB USB SSD only appears after
> ticking **Advanced drive properties → List USB Hard Drives**.

## The USB medium — history

The only USB device attached is a 1 TB SSD that is **already claimed by the `Samsung`
storage pool** and mounted as `H:`. It holds a single folder, `K4120`, of **119.72 GB**.

Using it as the installer medium would require `Remove-VirtualDisk` + `Remove-StoragePool`
before the raw device is writable, which destroys that 119.72 GB irreversibly. There is also
nowhere local to move it: `C:` now has 95 GB free and `D:` has 59.3 GB.

**Get a spare 8 GB stick.** The ISO is 1523 MB and verified. That is the only thing still
standing between this machine and step 4.

## Hard rules (from DUALBOOT.md)

- Never `mkfs` or format **p2** (ESP), **p4** (WinRE), **p5** (MSI recovery).
- Never touch disk 2 — Storage Spaces.
- GRUB, not systemd-boot — the ESP is only 300 MB.
- Keep Fast Startup off.
