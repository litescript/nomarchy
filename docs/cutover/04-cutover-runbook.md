# caesar cutover — the command sequence

Every command, in order, from the SATA prompt to an accepted new caesar. Nothing here is
inferred: it is the order `tests/vm/rc` rehearses, with the VM's stand-ins replaced by the
real thing. If a step's output does not say what this says it should, **stop**; SATA is
untouched and remains the fallback until `--finalize-nvram`, and even after it.

`<C>` below is the frozen cutover commit; the formal RC that passed at it is recorded in
`CLAUDE_NOTES.md`.

## 0. Before the day (on SATA)

```bash
cd ~/Projects/nomarchy
git status --short                              # prints nothing
git log --oneline -1                            # <C>
sudo pacman -S --needed gptfdisk dosfstools parted
```

The coordinated umbriel/Noctalia update, if not already done. Noctalia moves first: SATA's
5.0.1 writes palette keys (`scratchpad_*`) the pinned umbriel 6bf03a0 does not have, so no
umbriel can pass the gate until Noctalia 5.2.0 has rewritten the palette. Between the
`pacman -Syu` and the reboot, do not change the wallpaper or theme (the still-running 5.0.1
would add the palette to `[include]` too; 5.2.0 repairs that, but the order below avoids it).

```bash
sudo pacman -Syu                                # Noctalia 5.2.0 (and a kernel, likely)
systemctl reboot                                # autologin brings the desktop back with the NEW Noctalia
irides apply NSX                                # Noctalia applies the theme: its 5.2.0 hook rewrites the palette
grep scratchpad_ ~/.config/umbriel/noctalia.toml # prints NOTHING: no 5.0.1 colour keys left
                                                # (5.2.0's match.is_scratchpad window rule is fine)
git -C ~/Projects/nomarchy status --short       # prints NOTHING: the host config is already 5.2.0's fixed point
umbriel-update --sync --apply                   # builds 6bf03a0, gates it on the live config, installs it and the portal
systemctl reboot                                # a new compositor only runs after a restart
umbriel-update --check-pins && umbriel-update --check-config   # "= pin" twice, then "config: ok"
```

If `--sync --apply` refuses, it now says which file was rejected and what to do; do not run
`--merge-config` unless it names base.toml.

## 1. Provision the XPG (destroys it)

```bash
cd ~/Projects/nomarchy
provision/provision caesar                      # dry run: every gate passes, "tools: all present", read the plan
sudo provision/provision caesar --apply
```

It asks, in order: the disk serial — type `2K0420036195`; the new LUKS passphrase, twice (the
one you will type at every boot); the same passphrase once more to enroll the recovery key,
then it shows the **recovery key once** — write it down and store it offline; the passphrase
once more to open the volume; then the password for `peter` on the new system, twice. It must
end with `... unmounted, /dev/mapper/cryptroot closed` and `Provisioned.`

## 2. Bulk copy, while you keep using SATA

```bash
migrate/migrate caesar plan                     # "No refusals."
sudo migrate/migrate caesar open                # the LUKS passphrase; "first open: recorded the clean install"
sudo migrate/migrate caesar bulk                # ends "bulk pass complete."
```

## 3. Freeze

Close Thunderbird, Firefox, Obsidian, **every Claude Code and Codex session** (their state is
what is being copied — use rigel if you want Claude during the cutover) and nvim. Close every
terminal window except this one: a shell writes its history when it exits. Stop editing
repositories.

```bash
sudo migrate/migrate caesar freeze
```

It dumps Revline (`PostgreSQL 16…; N tables, M rows; … read back`), stops its stack, records
the evidence and ends `Frozen.` If it refuses naming a running program, close that and run it
again.

## 4. Final copy, verify, close

```bash
history -a
sudo migrate/migrate caesar final               # ends "final pass complete."
sudo migrate/migrate caesar verify              # ends "Verified: every entry is identical on the new disk."
sudo migrate/migrate caesar close               # "ledger sealed", "unmounted and locked"
```

If `final` fails, fix what it names and run `final` again (it resumes), then `verify`. If
`verify` fails, run `final` and `verify` again. Never boot an unverified copy.

## 5. First boot

```bash
sudo provision/provision caesar --boot-next
systemctl reboot
```

At the Plymouth prompt: the LUKS passphrase. If it does not come up, reset: the firmware goes
back to SATA (BootOrder was never changed), and nothing on SATA has been written.

## 6. On new caesar: the stages (tty1 console, no desktop yet)

Log in as `peter` with the password set in step 1.

```bash
cd ~/Projects/nomarchy
common/scripts/nomarchy install base            # answer y; ends "Done."
common/scripts/nomarchy install desktop         # answer y; builds umbriel at the pins
common/scripts/nomarchy install host            # answer y; it prints two things to do by hand:
sudo passwd meanpete                            #   meanpete's password (the account was created locked)
sudo install -m 0640 -o root -g nut hosts/caesar/nut/upsmon.conf.example /etc/nut/upsmon.conf
sudoedit /etc/nut/upsmon.conf                   #   replace <password> with the monuser password
sudo systemctl restart nut-monitor
common/scripts/nomarchy install host            # again: nothing left but the checks named in step 8
common/scripts/nomarchy install storage         # answer y
common/scripts/nomarchy link                    # answer y; builds shelf and irides from the migrated trees
sudo provision/provision caesar --boot-next     # BootOrder still leads to SATA until step 9
systemctl reboot
```

## 7. On new caesar: accept (in the desktop — tty1 autologin starts it)

Open a terminal (Mod+Enter).

```bash
cd ~/Projects/nomarchy
migrate/migrate caesar restore-revline          # "row counts identical to the freeze"
migrate/migrate caesar accept                   # ends "Accepted."  (a pinentry prompt: your GPG passphrase)
ssh-add ~/.ssh/id_ed25519_github ~/.ssh/id_ed25519_waylab ~/.ssh/id_ed25519_homelab ~/.ssh/id_ed25519_vps ~/.ssh/id_ed25519_caesar_to_rigel
migrate/migrate caesar accept-remote            # github by its reply, every shell host exit 0
nomarchy link                                   # the checks that need Noctalia running
```

By hand, and each must hold:

```bash
# on rigel -- rigel's known_hosts untouched, so any warning means the host keys did not carry:
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes caesar true && echo ok
# from rigel -- meanpete's password login:
ssh meanpete@caesar
```

Then open Thunderbird (the `m4xrexpp.default-release` profile, accounts sync), Obsidian (the
Revline HQ vault), OpenDeck (its profiles), and sign Firefox in to Sync (bookmarks, logins,
extensions). Set Noctalia's location in its settings (the repo never carries coordinates).

## 8. What `nomarchy status` may still list

After step 7, `nomarchy status` shows **0 conflicts**. Anything it lists as to do is named with
its remedy; on real caesar the VM's two expected ones (the address and the GPG key) pass.

## 9. When new caesar has booted more than once and proven itself

```bash
cd ~/Projects/nomarchy
tests/snapper-recovery                          # PASS
sudo provision/provision caesar --finalize-nvram   # our entry first in BootOrder; dead entries removed
```

SATA stays installed and untouched: the rescue system (docs/cutover/02), and the fallback. Its
Revline volumes, Firefox profile and everything not migrated remain there.
