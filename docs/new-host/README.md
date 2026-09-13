# Standing up a new nomarchy host

**You are a Claude Code instance running on a machine that is about to become a nomarchy
host.** Right now that machine is still running its old OS — probably Omarchy, as caesar
was. Your job is everything that has to happen *before* it is wiped, plus the sequence
afterwards.

Read `CLAUDE.md` at the repo root first. It is the doctrine; this file is the procedure.

**The machine being stood up next is `rigel`.** Use that name everywhere: `hosts/rigel/`,
`common/scripts/bootstrap rigel`, `docs/new-host/rigel-survey.txt`. Hosts here are named
after stars and Romans — caesar is the desktop, waylab the testbed, rigel the laptop — and
the name is load-bearing, not decorative: every manifest path keys off it.

### What is already known about rigel

Settled in conversation before you existed, so do not spend Pete's time rediscovering it:

- It runs **Omarchy** today. Its migration is therefore a second run of the one
  `docs/migration/` records — read that before surveying, and treat the old install as
  *reference for what to investigate*, never a template to copy.
- It uses **Tailscale**. caesar does not, so there is no precedent in this repo; see the
  Tailscale section below.
- It is a **laptop** — lid, battery, backlight, touchpad, one internal panel. caesar has
  none of those and three external monitors.
- Its graphics are **hybrid**: Intel Iris Xe plus a GeForce RTX 3050 Ti Mobile. The panel
  enumerates as `eDP-2` under the old OS (`eDP-1` disconnected), and the backlight device is
  `nvidia_wmi_ec_backlight`, not `intel_backlight` — so `brightnessctl` needs an explicit
  `-d`. It is a Dell (`DELL0B9B` touchpad), and `[input.touchpad]` in the base has never
  run against real hardware. Found by rigel's own survey.
- It will be installed **btrfs on LUKS** — already its layout under Omarchy, with limine
  and snapper, so capture the subvolumes before they are overwritten. caesar is currently plain ext4 and unencrypted;
  it gets the same treatment at its own cutover. That difference is worth remembering when
  reasoning about the ssh key passphrase: on an encrypted disk the argument changes.

One thing you cannot see: `CLAUDE_NOTES.md` is gitignored, so the working notes from
caesar's migration are not in your checkout. Everything you actually need was committed —
`docs/migration/` and `CLAUDE.md` — and this file carries the rest.

---

## Where this is going

A second machine running the same desktop: bare Arch, Umbriel, Noctalia. Installed
**btrfs on LUKS**, which caesar (currently plain ext4, unencrypted) is not — caesar gets
the same treatment at its own cutover.

**This is not a caesar clone, and the repo is built to refuse one.** `hosts/` is not a
template directory and `common/scripts/bootstrap` errors on a host directory that does not
exist, rather than defaulting to another machine's. A laptop has different microcode, a
hybrid Intel + NVIDIA GPU, one internal panel, a lid, a battery, a touchpad, and Tailscale. caesar has
three monitors, an NVIDIA card, a NAS, a Stream Deck and a second user account. Almost
nothing about the *hardware* layer transfers; almost everything about the *desktop* layer
does, and that is exactly the split `common/` and `hosts/<host>/` already encode.

## The order, and why

Pete's sequence, which is the right one:

1. clone this repo on the **existing OS**
2. survey the machine and write down what only exists while that OS is alive
3. write `hosts/<name>/`
4. **push** — this is the step that survives the wipe
5. install Arch, btrfs on LUKS
6. clone again, bootstrap, follow the acceptance tests

Steps 2 and 3 cannot be done afterwards. Which outputs the panel reports, what the wifi
networks are called, which services were relied on, what is in `$HOME` — all of it goes
away with the disk.

---

## Phase 1 — survey, on the old OS

```bash
common/scripts/host-survey > docs/new-host/rigel-survey.txt
```

Read it yourself, then commit it. It captures identity, CPU (which decides the microcode
package), GPU, connected outputs with preferred modes, laptop hardware, disks, network,
Tailscale, enabled services, explicit packages and what is in `$HOME`. It prints **no
secrets** — keys, wifi profiles and VPN configs appear by name only, and that rule holds
because this repo is public.

Then sweep the Omarchy-specific layer, which the survey does not cover. caesar's
equivalent is `docs/migration/` — read `06-post-install-audit.md` §4 before starting,
because several decisions are already made and re-litigating them wastes Pete's time:

- **Webapps, Signal and 1Password: not wanted.** Settled 2026-09-10. 1Password is a
  browser plugin, not an app. Do not rebuild the `chromium --app` wrapper for them.
- **`launch-or-focus` is rebuilt** and lives at `common/scripts/launch-or-focus`.
- **The kitty config is classified line by line** in §9, and the NVIDIA environment
  variables are settled with evidence in §10 — three of them measured as no-ops. rigel does
  have an NVIDIA GPU, so read §10 — but its verdicts were measured on caesar's single
  desktop card, and hybrid laptop graphics is a different question. Re-test, don't inherit.

What is worth sweeping on a laptop specifically: `~/.local/bin`, `~/.config/omarchy/hooks`,
its systemd user units, its shell config, and anything hardware-adjacent Omarchy set up
that this repo has no equivalent for yet — power profiles, suspend behaviour, backlight
keys, fingerprint readers.

## Phase 2 — write `hosts/rigel/`, before the wipe

Minimum contents. This is a checklist, not a template — write each file for this machine:

| file | contents |
|---|---|
| `umbriel/config.toml` | the `[include]` of `common/umbriel/base.toml`, then this machine's `[output.*]`. Copy the include block from `hosts/caesar/umbriel/config.toml` and nothing else |
| `packages/repo.txt` | the **right microcode** (`intel-ucode` vs `amd-ucode`), the right GPU stack, `tailscale`, and anything laptop-specific: `brightnessctl`, power management, bluetooth |
| `packages/aur.txt` | AUR packages; there is no AUR helper, they are built with `makepkg -si` |
| `bootstrap/links` | host-specific symlinks; probably just the umbriel config |
| `bootstrap/units` | `systemd --user` units this host enables |
| `bootstrap/copies` | root-owned files, which get **diffed** by the bootstrap so their drift is reported |
| `bootstrap/root-steps` | printed for Pete to run, never executed |

Do **not** copy `hosts/caesar/` wholesale. Specifically, these are caesar's and must not
appear: `meanpete/` (a second user with a NAS staging role — see §11, it carried a
privesc), the NAS mount units, the Stream Deck udev rule, the netconsole ufw rule, and
caesar's NVIDIA configuration. rigel needs its own GPU stack, written from its own survey
for hybrid graphics — not caesar's, which describes a different card in a different role.

Umbriel's `[events]` lid hooks sit commented in the base config. A laptop is the first
host that wants them; set them in the host file, which is applied last and wins.

### Tailscale

caesar does not run it, so there is no precedent in this repo. It needs the package, the
`tailscaled` service enabled, and then `tailscale up` authenticated **interactively** by
Pete. The node key and auth state are not config: nothing about them goes in the repo.
Put the package in `packages/repo.txt`, the service in `bootstrap/root-steps`, and the
`tailscale up` step in the post-install checklist with a note that it is interactive.

## Phase 3 — push, and get `$HOME` off the machine

Commit the survey and `hosts/rigel/` and **push before the machine is wiped**. This is
the whole point of the sequence. Follow the repo's commit style: explain why, not just
what, and record what was rejected along with what was chosen.

### The `$HOME` archive

The repo carries config. It does not carry `$HOME` — ssh keys, GPG keyrings, browser
profiles, anything under `~/Documents`. That needs its own archive, built under
`/var/tmp` as three files:

```
/var/tmp/rigel-home-20260913.tar.zst     the archive
/var/tmp/rigel-home-20260913.manifest    its file list
/var/tmp/rigel-home-20260913.sha256      the plaintext archive's digest
```

Then encrypt it, send it, and confirm what landed:

```bash
common/scripts/pre-wipe-backup rigel 20260913   # gpg prompts — Pete runs this, not you
common/scripts/pre-wipe-verify rigel 20260913
```

`pre-wipe-backup` encrypts with `gpg --symmetric`, rsyncs all four files to
`/mnt/nas/Public/Backups/laptop/`, and compares sizes. It resumes, so re-run it if the
link drops. Both scripts stay out of `common/bootstrap/links` on purpose: they run on the
old OS, before `~/.local/bin` exists.

**`pre-wipe-verify` computes the digest on the NAS over ssh, and that is the entire point
of it.** Checksumming through `/mnt/nas` is the obvious move and it is wrong twice over —
read the script's header before reaching for it. Set `NOMARCHY_NAS_SSH` and
`NOMARCHY_NAS_DEST_PATH` once; the script tells you what they should be.

## Phase 4 — the install (Pete's, not yours)

btrfs on LUKS. Pete does the partitioning and install by hand. What you should ask him to
record into `hosts/rigel/` afterwards, because it is painful to recover later:

- the LUKS container UUID, and the filesystem UUIDs
- the btrfs subvolume layout (caesar's old disk used `@`, `@home`, `@log`, `@pkg`)
- the resulting `/etc/fstab` and `/etc/crypttab`

Publishing UUIDs in this public repo is settled policy — Pete was asked directly and is
unconcerned; they are useful to him at exactly this moment. Credentials remain a different
category entirely.

If the old disk can be kept readable rather than overwritten, keep it. caesar's old
install is still mounted read-only at `/mnt/omarchy-old` and has been consulted on most
days since — CLAUDE.md documents the unlock.

## Phase 5 — after the install

```bash
git clone git@github.com:litescript/nomarchy.git ~/Projects/nomarchy
cd ~/Projects/nomarchy
common/scripts/bootstrap rigel            # read what it intends to do
common/scripts/bootstrap rigel --apply    # user-level changes
```

Then the root steps it printed, which it will not run itself. Then `tailscale up`.

**Verify against the live session, not a fresh process.** This is the single most
load-bearing paragraph in `CLAUDE.md` and it has cost real hours twice. A probe window you
spawn reads current config and passes while the running session stays broken. Compare
process start times against config mtimes; use `umbriel msg cheatsheet-open` to see what
is actually registered rather than what the file says.

Acceptance tests, in order:

1. `common/scripts/bootstrap rigel` → `0 to do, 0 conflicts`
2. `id` (bare, not `id <user>`) → the groups you expect. The group database is ahead of
   session credentials until the next login, so `id <user>` will look right while the
   session is stale
3. A terminal opens, `ls` is eza, the prompt is starship
4. `ssh-add -l` → "no identities" is *correct* on a fresh boot: the agent is up and the
   passphrase has not been given. Then `ssh-add` should prompt in **fuzzel**, not the
   terminal. If it prompts in the terminal, `SSH_ASKPASS_REQUIRE=prefer` has not reached
   the shell. If it prints `ssh_askpass: exec(<path>): No such file or directory` and
   **never prompts at all**, the variables arrived and `SSH_ASKPASS` names a missing file —
   check the `~/.local/bin/askpass-fuzzel` link. Tested on caesar: with a TTY present, a
   missing helper does not fall back to the terminal, it just exits 1
5. `tailscale status` → connected
6. Keybinds: the ones in `common/umbriel/base.toml` all work, which proves the include
   resolved. If they do not, check the include path — it resolves from the directory of
   the file **as given** to umbriel, and `~/.config/umbriel/config.toml` is a symlink, so
   relative includes miss. If built-in binds work but the script ones (`Super+C/V/X`,
   `Print`, `Super+T/D/O/F/M`) do nothing, the include is fine and `PATH` is not: check the
   `~/.local/bin` links exist and that `~/.local/bin` is in the compositor's environment
   (`tr '\0' '\n' < /proc/$(pgrep -x umbriel)/environ | grep ^PATH`)

---

## Rules, in short

- **Old config tells you what to investigate, never what to copy.** Pete's standing
  instruction, and it keeps paying: three NVIDIA variables were no-ops, three kitty lines
  did not exist in stock kitty, and the one real gap found was something Omarchy never
  fixed either.
- **Secrets never enter this repo.** Keys, wifi PSKs, VPN credentials, API tokens. They
  are migrated by hand and named — never copied — in surveys. The two on caesar live at
  `~/.config/subliminal/subliminal.toml` and `~/vpn/nord/`.
- **Version it here and symlink it into place.** If a config file is worth editing twice
  it belongs in the repo. Watch for `sed -i`, which replaces a symlink with a regular file
  and silently detaches it.
- **Never verify a NAS copy by reading it back.** Compute the digest on the NAS over
  ssh; `pre-wipe-verify` does. `/mnt/nas` is cifs, and cifs multiplexes every request to a
  server over one TCP connection, so a large read head-of-line blocks every *other*
  process touching that mount — on 2026-09-13 it held an unrelated session in
  uninterruptible sleep for fifty minutes. Off-site over a relayed Tailscale route the
  same read ran at 35-70 KB/s.
- **A NAS that answers ping but drops new connections is usually you, blocked.** Failed
  ssh logins trip DSM-style Auto Block, which DROPs the guarded ports while ports with no
  listener still answer RST and already-established mounts keep working. Do not retry into
  a ban; clear it from the NAS admin UI.
- **`sudo` needs a password that cannot be supplied non-interactively.** Ask Pete to run
  privileged commands himself; in Claude Code he can prefix them with `!`.
- **Investigate, propose, get approval, then apply.** Separate a question into independent
  sub-questions and answer each on its own evidence.
