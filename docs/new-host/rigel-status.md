# rigel — where this stands

A resumption point. First written 2026-09-13 while rigel was still on Omarchy; **rewritten
the same day after the install**, from the running machine. Read this first if you are
picking the work back up. The pre-wipe version, with the push-before-wipe checklist and the
installer instructions, is in git history before this rewrite.

## Where the work actually is

| done | |
|---|---|
| Phase 1, survey | `rigel-survey.txt` — scrubbed of wifi names, MACs and tailnet identity in `84e5128`. Describes the **old** OS |
| Phase 1, Omarchy sweep | `rigel-omarchy-sweep.md` — the graphics investigation, laptop layer, package separation. Also the old OS |
| The `common/` blocker | Raised in `rigel-open-questions.md`, answered and fixed by caesar in `5e9d123` |
| Phase 2, `hosts/rigel/` | Written in `3bc98c3` |
| Phase 3, push | Done; the install happened |
| Phase 4, install | Done. Recorded in **`hosts/rigel/install/`** — disk, UUIDs, subvolumes, fstab, boot |
| Phase 5, bootstrap | `common/scripts/bootstrap rigel` reports **24 ok, 0 to do, 0 conflicts**: every package, link and user unit |

| not done | |
|---|---|
| **The lid** | Live security gap today. See the open decisions |
| **Firewall** | `ufw` installed but `inactive` and `disabled`. Root step §5 not run |
| **NAS** | `/etc/nas-creds` exists `0600` but is **empty**; `/mnt/nas/{PlexMedia,Public}` exist; the fstab lines are not added. Root step §6 half done |
| snapper | `@snapshots` is mounted at `/.snapshots`, but snapper is not installed |

Root steps confirmed done by inspection: `[multilib]` enabled, timezone
`America/Indiana/Indianapolis`, tty1 autologin drop-in in place, `tailscaled` enabled and
active. The bootstrap cannot tell done from not-done for root steps and prints all of them
every run, so its output is not evidence either way.

## The install

Recorded in full in `hosts/rigel/install/README.md`. The headlines:

- **btrfs on LUKS2**, one NVMe. No `/etc/crypttab`: root is unlocked from
  `rd.luks.name=` on the command line, with the `systemd` + `sd-encrypt` initramfs hooks.
- Subvolumes `@`, `@home`, `@var_log`, `@snapshots`, `swap` (8G swapfile). **No `@pkg`**,
  unlike the old layout.
- **systemd-boot**, not limine. Secure Boot disabled.
- User `peter`, so the umbriel include path `~/Projects/nomarchy/...` resolves identically
  on caesar and rigel. No display manager.

## Confirmed on the running session

- **umbriel inherits `PATH` with `~/.local/bin` first**, and `SSH_AUTH_SOCK` at the fixed
  socket, via tty1 autologin → `start-umbriel`. This is the coupling the bare-name script
  binds depend on.
- **The panel is `eDP-1`**, a BOE 0x0AD5 at 2560x1600, 165.004 Hz or 60.002 Hz. The old OS
  called it `eDP-2`; the name did not survive the reinstall, and every pre-install doc that
  says `eDP-2` was describing the old OS.
- **DRM numbering moved too.** Now Intel (`0000:00:02.0`) is `card1` / `renderD128` and
  NVIDIA (`0000:01:00.0`) is `card0` / `renderD129`. The old OS had Intel at `card2` /
  `renderD129`. This is the concrete case for never naming a card by number.
- Backlight is still `nvidia_wmi_ec_backlight`, and still the only backlight device.

## rigel has a NAS

rigel reaches the **same** NAS as caesar (`192.168.1.208`), but over **CIFS** rather than
NFS — and it works from off-site, because Tailscale makes that LAN appear local. Verified on
the old OS from another house: 31 ms, and the automount triggered and listed the shares.

`cifs-utils` is installed. The fstab lines and directories are in `bootstrap/root-steps`.
**`/etc/nas-creds` is a credential file and never enters this repo** — same category as
`~/.config/subliminal/subliminal.toml` and `~/vpn/nord/`. It must be filled in by hand.

## The open decisions

1. **The NVIDIA stack — measured once, not yet settled.** The driver is installed
   (`nvidia-open-dkms 615.71.09`, `nvidia-utils`, `lib32-nvidia-utils`,
   `libva-nvidia-driver`). Do **not** set `LIBVA_DRIVER_NAME`; the Intel default is right
   where Intel drives the panel.

   The first measurement, 2026-09-13, about 14 minutes after boot, **on AC at 100%
   battery**:
   - umbriel is the **only** process holding NVIDIA nodes — about 20 fds across
     `/dev/nvidia0`, `/dev/nvidiactl`, `/dev/nvidia-modeset`, `card0` and `renderD129`,
     plus an NVIDIA GL shader cache. Noctalia holds none.
   - Despite that, the dGPU **runtime-suspends**: `runtime_status` read `suspended` across
     three samples five seconds apart, with `runtime_suspended_time` advancing in step with
     the clock and `runtime_active_time` frozen at ~57 s.

   So holding the fds does not by itself keep the card awake, and `WLR_DRM_DEVICES` looks
   unnecessary. What is not yet measured: the same check **on battery**, and after
   something has actually woken the dGPU (a game, NVDEC) to see that it goes back down.
   If it holds, record the decision as "not pinned, with evidence". If pinning is ever
   needed: never by `cardN` (see above), never by a `by-path` name full of colons.
2. **The 48 packages** (plus one yes/no on the 39-package retroarch block). Listed in the
   sweep. `1password` and `signal-desktop` are on it only because they were installed; §4
   already settled that neither is wanted.
3. **Lid ownership — the one with a security edge, and it is live now.** There is no
   `/etc/systemd/logind.conf.d/`, so logind has its default `HandleLidSwitch=suspend`, the
   `[events]` lid hooks are commented out, and nothing locks on `PrepareForSleep`. **Closing
   the lid today suspends and resumes unlocked.** Pick exactly one owner: logind with
   something locking on `PrepareForSleep`, or umbriel's `[events]` hooks with logind set to
   ignore the lid. Never both. Noctalia's `lock-and-suspend` is an *idle* behaviour and a
   lid close does not pass through it. The test is physical: close the lid, open it, and it
   must be locked. The design notes are in the lid section of
   `hosts/rigel/umbriel/config.toml`.
4. **snapper.** The bootloader question is settled: systemd-boot. Snapshots are not —
   there is a mounted `@snapshots` and nothing using it. Dropping snapper purely because
   Omarchy chose it inverts the rule. Choose on merit. Note that with no `@pkg`, a root
   snapshot now includes the pacman cache.

## Things that will bite if forgotten

- **`sed -i` detaches symlinks.** Every deployed config here is a symlink into the repo.
- **A probe window tests the file, not the session.** Verify against the live session.
- **Any terminal added to a nomarchy host needs the `ctrl+insert` / `shift+insert`
  mappings**, or `Super+C` is a silent no-op in it. Relevant because `alacritty` and
  `cool-retro-term` are both on the package list.
- **Anything published off rigel gets a privacy check first.** The survey already leaked
  three wifi names, both MACs and the tailnet identity into a public repo. Fixed at the
  tip; still in history at `c1c5fdd`, which is Pete's call to rewrite or leave.
- `brightnessctl` needs `-d nvidia_wmi_ec_backlight`. There is no `intel_backlight` here
  despite Intel driving the panel.
- **Output and card names are per-install facts.** `eDP-2` became `eDP-1` across the
  reinstall. `HDMI-A-1`, commented in the host config, is also an old-OS name — read
  `umbriel outputs` with something plugged in before trusting it.

## Conversation state

Two agents have worked this: rigel's and caesar's (which owns `common/`). They talk through
`rigel-open-questions.md`, which carries rigel's questions, caesar's answers, caesar's
review of the sweep, and now rigel's post-install corrections. That file is the thread;
append to it rather than starting a new one.
