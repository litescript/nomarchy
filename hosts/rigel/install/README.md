# rigel — the install as it came up

Recorded 2026-09-13, the first day on the new install, from the running machine. This is
the record `docs/new-host/README.md` phase 4 asks for: what is painful to recover once it
has been forgotten.

**These files are snapshots, not deployed config.** Nothing symlinks or installs them, and
`bootstrap/copies` does not diff them — they describe how the disk was laid out, not a
state the bootstrap should enforce. `/etc/fstab` in particular is expected to grow (the
NAS lines in `bootstrap/root-steps` §6), and this copy will not follow it.

| file | from |
|---|---|
| `fstab` | `/etc/fstab`, verbatim |
| `boot/loader.conf` | `/boot/loader/loader.conf`, verbatim |
| `boot/arch.conf` | `/boot/loader/entries/arch.conf`, verbatim |

UUIDs are published here on purpose; that is settled policy for this repo.

## Disk

One NVMe, `nvme0n1`, 476.9G, GPT.

| partition | size | type | filesystem | UUID | PARTUUID |
|---|---|---|---|---|---|
| `nvme0n1p1` | 2G | EFI System | vfat (FAT32), `/boot` | `959A-EF7B` | `e56a6fd2-57ff-480f-a05c-59c414c8400c` |
| `nvme0n1p2` | 474.9G | Linux root (x86-64) | LUKS2 | `2057043b-d69f-423d-8b5c-a49ddadfe50a` | `b3fc16e8-f62f-465c-9233-0aef6f7b6377` |
| └ `cryptroot` | 474.9G | | btrfs, label `arch` | `534c02c7-4941-4397-be71-79aab5d3a447` | |

Address things by these UUIDs, never by device name — caesar's old disk has already moved
from `nvme2n1p2` to `nvme1n1p2` once.

## Encryption: no crypttab, by design

There is **no `/etc/crypttab`**. The root container is unlocked in the initramfs from the
kernel command line, which is the systemd-initramfs way of doing it:

```
rd.luks.name=2057043b-d69f-423d-8b5c-a49ddadfe50a=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw
```

That needs the `systemd` and `sd-encrypt` hooks rather than `udev` and `encrypt`:

```
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)
```

`MODULES=()` is empty — no NVIDIA modules are forced into the initramfs, and the `kms`
hook is still present. Anyone reading an older Arch guide that says "use `encrypt` and
`cryptdevice=`" is reading the other scheme; do not mix the two.

## btrfs subvolumes

All five mount with `rw,noatime,compress=zstd:3,ssd,space_cache=v2`:

| subvolume | mountpoint |
|---|---|
| `@` | `/` |
| `@home` | `/home` |
| `@var_log` | `/var/log` |
| `@snapshots` | `/.snapshots` |
| `swap` | `/swap` |

The complete list, from `sudo btrfs subvolume list /`:

```
ID 256 gen 183 top level 5 path @
ID 257 gen 183 top level 5 path @home
ID 258 gen 183 top level 5 path @var_log
ID 259 gen 9 top level 5 path @snapshots
ID 260 gen 13 top level 5 path swap
ID 261 gen 19 top level 256 path var/lib/portables
ID 262 gen 19 top level 256 path var/lib/machines
```

The five above sit at the top level (5), so each can be snapshotted or rolled back on its
own. The last two are **nested inside `@`** (top level 256) and were not made by hand:
systemd creates `/var/lib/portables` and `/var/lib/machines` as subvolumes when it finds
itself on btrfs. Neither is in use: `machinectl list` reports no machines and
`portablectl list` no images.
A btrfs snapshot does not descend into nested subvolumes, so a snapshot of `@` will hold
those two as empty directories — harmless while they are unused, worth knowing if either
ever gets used.

Differences from the old layout (`@`, `@home`, `@pkg`, `@log`, `relatime`):

- **No `@pkg`.** `/var/cache/pacman/pkg` lives inside `@`, so a snapshot of root carries
  the package cache with it, and rolling root back rolls the cache back too.
- `@log` is now `@var_log`; same purpose.
- `noatime` rather than `relatime`.
- `@snapshots` exists and is mounted, but **nothing uses it yet** — snapper is not
  installed. Whether to use it is still open; see `docs/new-host/rigel-status.md`.
- `swap` is a flat subvolume (no `@`) holding an 8G `/swap/swapfile`, active at priority -1.
  There is no `resume=` on the command line, so it is swap only, not hibernation.

## Boot

**systemd-boot**, not limine. `bootctl status` reports `systemd-boot 261.3-1-arch`, UEFI
firmware `Dell 1.00`, **Secure Boot disabled** (audit mode), TPM2 present. One entry,
`arch.conf`, loading `intel-ucode.img` then `initramfs-linux.img`; no fallback preset
(`PRESETS=('default')`), so there is no fallback initramfs to boot if the default breaks.

`loader.conf` sets `editor no`, so kernel command-line editing at the boot menu is off.

`systemd-boot-update.service` is **disabled**, so the bootloader binary on the ESP is not
refreshed when the `systemd` package updates. That is a choice to make, not a fault — note
it before assuming the ESP carries the version pacman installed.

## Versions at the time of recording

`linux 7.2.4.arch1-2`, `systemd 261.3-1`, `nvidia-open-dkms 615.71.09-1`,
`umbriel-git .r933.5678f16-1`, `noctalia 5.1.0-1`. 15G used of 475G.
