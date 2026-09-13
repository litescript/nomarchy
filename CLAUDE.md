# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Nomarchy is not a distribution and not an application. It is an opinionated bare-Arch
desktop configuration, and this repo is the **policy and integration layer** over
components that own their own domains:

- Arch owns the OS.
- **Umbriel** (wlroots C++ compositor, AUR git build, version 0.1.0) owns composition.
- **Noctalia** (native C++ shell, Arch `[extra]`) owns the desktop shell.
- This repo owns what falls between them.

There is no build system, no test suite, and no lint step. "Testing a change" means
applying it to the live session and observing the machine — see **Verification** below,
which is the single most important section in this file.

## Layout and how files reach the system

```
common/          shared across hosts   (nvim, kitty, scripts, udev)
hosts/<host>/    per-machine           (currently only caesar)
docs/migration/  audit + investigation records
```

Deployment is by **symlink from the system into the repo**, so edits are live
immediately:

| System path | Repo |
|---|---|
| `~/.config/nvim` | `common/nvim` (whole dir) |
| `~/.config/kitty/kitty.conf` | `common/kitty/kitty.conf` |
| `~/.config/umbriel/config.toml` | `hosts/caesar/umbriel/config.toml` |
| `~/.config/systemd/user/ssh-agent.service` | `common/systemd/ssh-agent.service` |
| `~/.bashrc` | `common/bash/bashrc` |
| `~/.bash_profile` | `common/bash/bash_profile` |
| `~/.config/fuzzel/fuzzel.conf` | `common/fuzzel/fuzzel.conf` |
| `~/code/browse_alias` | `common/browse_alias` (whole dir) |
| `~/.ssh/config` | `common/ssh/config` |

**The default is: version it here, symlink it into place.** If a config file is worth
editing twice, it belongs in this repo at the path above, not loose in `$HOME`. Two
reasons, and the second is the one that bites. Config living only on disk does not survive
a rebuild — `.bashrc` and `.bash_profile` were load-bearing for a week (PATH,
`SSH_AUTH_SOCK`, `AddKeysToAgent`) while being invisible to `git status` and absent from
any backup. And a symlink means there is exactly one file: edits are live immediately, and
there is no question of which copy is current.

**The sharp edge:** `sed -i` does not follow symlinks. It writes a temporary file and
renames it over the link, so the symlink becomes a regular file, the repo keeps the old
content, and nothing announces it. Verified here. Anything that edits config in place must
resolve the link first — `readlink -f` — which is why `~/code/browse_alias/ba` does. Most
editors are fine (vim and nvim write through), but check before trusting a tool with a
symlinked config.

Some things are **copies, not symlinks**, and drift silently:

- `~/.local/state/noctalia/settings.toml` — Noctalia rewrites this file itself, so the
  repo copy is a snapshot. Read the live file when you need current state; it is
  routinely ahead of `hosts/caesar/noctalia/settings.toml`.
- `/etc/udev/rules.d/99-streamdeck-no-keyboard.rules` — root-owned, installed with
  `sudo install`.
- `/etc/ssh/sshd_config.d/10-nomarchy.conf` — root-owned. Validate with `sshd -t` and
  apply with `systemctl reload sshd`, never restart.
- `/etc/systemd/system/mnt-nas.{mount,automount}` — root-owned, and necessarily so: a
  mount unit for `/mnt/nas` has to be a system unit, not a `--user` one.
- `~meanpete/Scripts/`, `~meanpete/.bashrc`, `~meanpete/.bash_profile` — another user's
  home, and `/home/peter` is `drwx------`, so a symlink into this repo would dangle for
  him. See `hosts/caesar/meanpete/README.md`; that whole directory is temporary and gets
  deleted after the NVMe cutover.

Two things deliberately live **outside** the repo because they hold credentials:
`~/.config/subliminal/subliminal.toml` (opensubtitles login, `0600`) and `~/vpn/nord/`
(`auth.txt` and `linux_token.txt`). Scripts that read them are tracked; the secrets are
not, and must not be.

The firewall is not a file copy at all: `hosts/caesar/ufw/apply-rules` is a script that
issues `ufw` commands, because the live rules in `/etc/ufw/user.rules` are generated and
owned by `ufw` itself.

**The umbriel config is layered, and the layering is load-bearing.**
`common/umbriel/base.toml` holds everything host-agnostic — keybinds, input, appearance,
layout, rules, animation. `hosts/<host>/umbriel/config.toml` is the main file and holds
only that machine's `[output.*]` blocks plus any overrides. Umbriel applies required
includes, then optional includes, then the main file, so the host always wins.

Four things about it that were established by testing umbriel 0.1.0, not by reading docs:

- **Include paths resolve from the directory of the file as *given* to umbriel, not its
  realpath.** `~/.config/umbriel/config.toml` is a symlink into this repo, so a relative
  include resolves against `~/.config/umbriel` and misses. Use a `~/` path.
- **A missing `[include.optional]` file validates as `config: ok` and applies nothing.**
  The base must therefore be a required `[include]` — otherwise a bad path yields a
  machine with no keybinds and a clean bill of health. A missing required include fails
  loudly.
- **`[[window_rule]]` and `[[layer_rule]]` entries accumulate across files**; every other
  value is replaced by the last file to set it. A host can add rules but cannot remove one
  the base defines, so anything a host might need to *not* have belongs in the host file.
- `~/.config/umbriel/noctalia.toml` is Noctalia's generated palette, pulled in as an
  optional include. It is genuinely optional — Noctalia rewrites it on every theme change
  and it does not exist until that template has run once.

A new host is a deliberately written `hosts/<name>/`, never a copy of another host's.
`hosts/` is not a template directory.

Scripts in `common/scripts/` are referenced from the Umbriel config by **absolute path**,
so the session depends on this checkout staying at `/home/peter/Projects/nomarchy`.

## Bootstrapping a host

```bash
common/scripts/bootstrap caesar            # report drift, change nothing
common/scripts/bootstrap caesar --apply    # make the user-level changes
```

Dry run is the default, so it doubles as a **drift audit**: run it any time to ask whether
this machine still matches the repo. It never runs `sudo` — root steps are printed for a
human — and it never clobbers: a path that exists but is not the expected symlink is
reported as a conflict and left alone.

It is data-driven, and the data is the spec:

| file | what it declares |
|---|---|
| `common/packages/{repo,aur}.txt` | packages on every host |
| `hosts/<host>/packages/{repo,aur}.txt` | packages only that machine gets |
| `common/bootstrap/links`, `hosts/<host>/bootstrap/links` | symlinks to lay |
| `hosts/<host>/bootstrap/copies` | root-owned copies, **diffed** so their drift is reported rather than silent |
| `common/bootstrap/units`, `hosts/<host>/bootstrap/units` | `systemd --user` units to enable |
| `hosts/<host>/bootstrap/root-steps` | printed, never run |

A file living in `common/` means it is *available* to any host; a host's `links` list is
what that machine actually installs. The NAS units are the example — general-purpose files
that only make sense on a machine that can reach that NAS.

**A new host is a `hosts/<name>/` somebody wrote on purpose.** The bootstrap refuses a
host directory that does not exist rather than defaulting to another machine's. `hosts/`
is not a template directory, and a laptop is not a caesar clone: it has different
microcode, no NVIDIA, no NAS, no second user, and lid events caesar has no concept of.

## Verification — read this before changing any config

**Config changes do not reach running processes, and the failure is silent.** This has
caused real bugs here twice. A stale process keeps serving old behaviour, so a changed
keybind simply does nothing, or does the old thing.

| Program | Reload | Symptom when stale |
|---|---|---|
| Umbriel | `umbriel validate && umbriel msg config-reload` | changed keybind does nothing |
| kitty | `Ctrl+Shift+F5` (`reload_config_file`) | new mapping absent; the *default* for that key runs instead |
| Noctalia | writes/reloads its own settings | — |

kitty is the nastier case: a window started **before** `~/.config/kitty/kitty.conf`
existed gets no config watcher at all, because kitty only watches files it loaded at
startup. Check with `pgrep -af __watch_conf__`.

**The testing trap:** any probe window you spawn to verify a change is a *new* process, so
it reads current config and passes — while the live session stays broken. Verifying
against a freshly spawned window tests the file, not the session. Compare process start
time against config mtime, or check the live session directly.

Ways to see what is actually loaded rather than what the file says:

```bash
umbriel msg cheatsheet-open      # renders currently REGISTERED binds
umbriel windows --json           # active:true is the seat-focused window
umbriel subscribe windows        # JSON-line event stream
ps -eo pid,lstart,args | grep kitty   # compare against config mtime
```

Prefer a signal that states what happened over one that implies it. Example: NVDEC
utilisation reads ~1% for working 1080p decode — indistinguishable from noise —
whereas `MOZ_LOG=FFmpegVideo:5` says outright whether hardware decode engaged.

## Working doctrine

The previous system was Omarchy 4.0.3 (Hyprland), on a **LUKS-encrypted btrfs** volume.
It is **not mounted automatically** — there is no fstab entry, so it vanishes on every
reboot and needs unlocking by hand (the passphrase prompt needs a real terminal):

```bash
sudo cryptsetup open /dev/disk/by-uuid/cd84de61-5f81-4968-91e3-434381780328 omarchy-old
sudo mount -o ro,nosuid,nodev,subvolid=5 /dev/mapper/omarchy-old /mnt/omarchy-old
```

Address it **by UUID**: the device name has already shifted once, from `nvme2n1p2` on the
old box to `nvme1n1p2` now. `subvolid=5` mounts the btrfs top level so `@` and `@home`
appear as directories, which is what every path in the migration docs assumes. `nosuid`
and `nodev` because this is another system's root and §11 found a privesc in it.

Once mounted it is read-only at `/mnt/omarchy-old` (`@`, `@home` subvolumes). Note that symlinks under
`/mnt/omarchy-old/@/usr/share/omarchy/bin/` point at `/usr/bin/...` and therefore resolve
against the *live* root — read `/mnt/omarchy-old/@/usr/bin/<name>` directly.

**Old Omarchy config tells you what to investigate, never what to copy.** This is the
owner's explicit standing instruction, and it repeatedly pays off:

- Three NVIDIA env vars carried from Omarchy were measurably no-ops (§10 of the audit).
- Three lines of the old kitty config do not exist in stock kitty at all (§9).
- The real gap found (Firefox RDD sandbox blocking VA-API) was something Omarchy never
  fixed either.

Expected workflow for anything non-trivial: **investigate, propose changes and tests,
get approval, then apply.** Separate a question into independent sub-questions and answer
each on its own evidence rather than as one bundle.

## Non-obvious mechanisms

**Universal clipboard (`Super+C/V/X`) has three legs, and one fails silently.**
`common/scripts/universal-clipboard` reads `umbriel windows --json`, and injects
`Ctrl+Insert`/`Shift+Insert` for terminals or `Ctrl+C`/`Ctrl+V` otherwise, via `wtype`.
That only works because `common/kitty/kitty.conf` maps those Insert chords to the
**clipboard** — stock kitty leaves `ctrl+insert` unbound and maps `shift+insert` to
`paste_from_selection`, i.e. the *primary* selection. Without the terminal half, copy is a
no-op and paste returns the wrong buffer while appearing to work. **Any terminal added to
this machine needs those two lines.**

Umbriel does not merge a physically-held Super into a virtual-keyboard chord the way
Hyprland did, which is why plain `wtype` suffices and no compositor-specific machinery is
needed.

**Umbriel has no key-injection action and no per-device input disable.** `umbriel msg`
reaches outside the compositor only via `spawn:`. Device quirks belong in udev — see
`common/udev/` for the Stream Deck rule.

**`umbriel msg spawn` does not preserve shell quoting.** Anything needing a shell must go
through a script file, not an inline command string.

**Display blanking:** a bare `dpms-off` bind has nothing to wake the screens; Noctalia's
idle behaviors own the resume side. `common/scripts/lock-and-blank` is the deliberate
exception — a manual walk-away key, not an idle policy.

## Git

Two remotes, both kept current:

```
origin   git@github.com:litescript/nomarchy.git   (primary, public, upstream tracking)
waylab   waylab:~/Repos/nomarchy.git              (local-network backup)
```

`git push` goes to GitHub only; waylab needs an explicit `git push waylab master`.

The GitHub repo is **public** — the tree includes `docs/migration/caesar-boot-backup/`
with filesystem UUIDs and PARTUUIDs. Scan before adding anything new that came off the
old machine.

If a git operation fails with `Permission denied (publickey)`, the key is almost certainly
fine. Two different causes look identical:

```bash
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"   # tool shell has no agent
ssh-add -l                                                  # "no identities" = the real cause
```

`ssh-agent.service` (a user unit, symlinked from `common/systemd/`) owns the agent and
binds it to that fixed path; `~/.bash_profile` exports the variable for the login shell,
so the compositor and everything it spawns inherit it. A **tool shell** started outside
that chain still has to export it by hand.

The second cause is that the agent is running but **empty**: `~/.ssh/id_ed25519_github` is
passphrase-protected, and the passphrase must be entered once per boot. `AddKeysToAgent
yes` in `~/.ssh/config` makes the first ssh of the session prompt for it, but no askpass
helper is installed, so that prompt only works in a real terminal — ask the owner to run
the push, or `ssh-add ~/.ssh/id_ed25519_github`, rather than retrying from here.

Do not reintroduce the old `ls ~/.ssh/agent/s.* | head -1` glob. It sorts alphabetically,
and a reboot leaves the previous session's dead socket in that directory.

`sudo` requires a password that cannot be supplied non-interactively; ask the user to run
privileged commands themselves with the `!` prefix.

## Reference

`docs/migration/` holds the pre-migration audit (`01`–`05`, `README`, `SUMMARY`) and
`06-post-install-audit.md`, which records current machine state, what remains unmigrated,
and three full investigations: §7 universal clipboard, §9 the kitty config classified
line by line, §10 NVIDIA. Consult §10 before touching NVIDIA settings — every variable
Omarchy set has already been tested and rejected with evidence.
