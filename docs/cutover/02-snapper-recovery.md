# Snapper recovery on caesar

Decided 2026-09-27: **no bootable snapshots.** systemd-boot + Snapper + snap-pac, with
recovery done either from the running system or, when it will not boot, from the SATA
Nomarchy install — a complete second OS on the same machine. This is that procedure.

What gets snapshotted: `@` (`/`) only, by the `root` config
(`hosts/caesar/storage/snapper-root.conf`), into the top-level `@snapshots`. **Not** in
those snapshots, by design (`hosts/caesar/storage/layout`): `@home`, `@var_log` (`/var/log`),
`@pkg` (`/var/cache/pacman/pkg`), the nested docker subvolume, and **the ESP** — which holds
the kernel and initramfs.

## 1. File-level: the system runs, something changed that should not have

```bash
snapper -c root list                            # find the snapshot from before the change
snapper -c root status N..0                     # what changed since then
snapper -c root diff N..0 /etc/some.conf        # how
sudo snapper -c root undochange N..0 /etc/some.conf
```

snap-pac takes a pre/post pair around every pacman transaction, so "before that update" is
usually a `pre` snapshot. `undochange` with no paths reverts **every** change since N.

**Tested by `tests/snapper-recovery`**: disposable snapshot, a marker file in `@`, Snapper
must report exactly it, `undochange` must remove it, the snapshot is deleted. Run it after
provisioning and after any change to the Snapper setup.

## 2. Whole-root: caesar will not boot

Done from the SATA rescue install. Nothing here touches the SATA disk or its ESP.

1. **Boot the rescue system**: firmware boot menu → *Nomarchy* (`sda1`'s systemd-boot).
2. **Open and mount the top level** — by UUID, never by device name:
   ```bash
   sudo cryptsetup open /dev/disk/by-uuid/df147db6-fe3c-4385-9a3b-6140dc390f29 cryptroot
   sudo mkdir -p /mnt/caesar-top
   sudo mount -o subvolid=5 /dev/mapper/cryptroot /mnt/caesar-top
   ```
3. **Pick the snapshot**:
   ```bash
   for d in /mnt/caesar-top/@snapshots/*/; do
     printf '%s  ' "$(basename "$d")"; grep -oP '(?<=<date>).*(?=</date>)|(?<=<description>).*(?=</description>)' "$d/info.xml" | paste -sd' '
   done
   ```
4. **Swap `@`** — move the broken root aside, never delete it yet:
   ```bash
   sudo mv /mnt/caesar-top/@ /mnt/caesar-top/@.broken-$(date +%F)
   sudo btrfs subvolume snapshot /mnt/caesar-top/@snapshots/N/snapshot /mnt/caesar-top/@
   ```
   The cmdline says `rootflags=subvol=@`, so the new `@` is what boots. (`snapper rollback`'s
   default-subvolume mechanism does not apply to this layout, which names `@` explicitly.)
5. **Kernel vs modules — the caveat.** The kernel and initramfs live on the ESP, which no
   snapshot contains. If the snapshot predates a kernel update, the ESP's kernel has no
   modules in the restored `@`: it boots, then cannot load drivers. Check, and fix by
   reinstalling the kernel into the restored root:
   ```bash
   ls /mnt/caesar-top/@/usr/lib/modules/            # versions the restored root has
   file -L /boot/vmlinuz-linux 2>/dev/null           # (rescue's own; for caesar's, mount its ESP:)
   sudo mkdir -p /mnt/caesar && sudo mount -o subvol=@ /dev/mapper/cryptroot /mnt/caesar
   sudo mount /dev/disk/by-uuid/F7ED-D893 /mnt/caesar/boot
   file -L /mnt/caesar/boot/vmlinuz-linux             # the version caesar's ESP will boot
   # if they differ:
   sudo arch-chroot /mnt/caesar pacman -S linux      # puts matching kernel + initramfs on the ESP
   sudo umount -R /mnt/caesar
   ```
6. **Close and boot caesar**:
   ```bash
   sudo umount /mnt/caesar-top && sudo cryptsetup close cryptroot
   sudo efibootmgr --bootnext <caesar's entry> && systemctl reboot
   ```
7. When caesar has proven itself again, delete `@.broken-*` (from caesar, top level mounted).

The same procedure works from any Arch live medium if the SATA disk is ever gone.
