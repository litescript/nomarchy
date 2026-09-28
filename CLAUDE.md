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

**Session start ritual:** read `CLAUDE_NOTES.md` (gitignored session-to-session
scratchpad — may be absent in fresh clones) before working, and leave a dated note there
when a session ends with anything in flight or anything the next session would otherwise
have to rediscover. Same convention as `~/code/revline` and `~/code/shelf` on caesar.
Durable policy stays here; finished investigations go to `docs/`.

## Layout and how files reach the system

```
common/          shared across hosts   (nvim, kitty, scripts, udev)
hosts/<host>/    per-machine           (caesar desktop, rigel laptop)
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
| `~/.config/irides/blueprints` | `common/irides/blueprints` (whole dir; Irides' theme intent — generated Noctalia palettes are derived, never versioned) |
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
  repo copy, `hosts/caesar/noctalia/settings.toml`, is a snapshot: a **seed** a rebuilt
  caesar starts from, not a link. `noctalia-snapshot` refreshes it from live and always
  strips `[location]` (the coordinates of home; public repo); `nomarchy status` reports
  when live has moved past it. Read the live file when you need current state.
- `/etc/udev/rules.d/99-streamdeck-no-keyboard.rules` — root-owned, installed with
  `sudo install`.
- `/etc/systemd/system/netconsole-listener.service` and `/etc/logrotate.d/netconsole-proxmox`
  — root-owned, from `hosts/caesar/netconsole/`. Receives the Proxmox host's kernel log;
  permanent, and lost once already by living only in `/etc` on Omarchy.
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

`~/.ssh/authorized_keys` is outside the repo for a different reason: it is not a secret, it
is an access grant. Symlinked into a public repo, anything pushed to GitHub would become a
login on the machine. caesar's copy holds rigel's `id_ed25519_caesar` public key, and
`PasswordAuthentication no` means that key is the only way in for peter, so
`ssh-copy-id` cannot bootstrap it. Add keys by hand.

`~/.ssh/config.local` and `~/.bashrc.local` are a third category again: not secrets, not
access grants, just real config that is **nobody else's business in a public repo**. The
tracked files carry host names, **private** addresses and key *paths* quite happily — the
dozen `ssh user@192.168.x.x` aliases in `common/bash/bashrc` are fine, because an
unroutable address tells a reader nothing. A **routable** address is different in kind: with
`User root` it advertises a login target to anyone reading GitHub. So the `vps` machine is
named in those two local files — a `Host` block in one, `alias lnlog='ssh vps'` in the
other — and the tracked files pull them in:

| tracked file | pulls in | placement |
|---|---|---|
| `common/ssh/config` | `Include config.local` | after `AddKeysToAgent`, before the first `Host` |
| `common/bash/bashrc` | `[[ -f ~/.bashrc.local ]] && source ~/.bashrc.local` | last, so it wins |

The address is written **once**, in `~/.ssh/config.local`; the alias is just `ssh vps`. The
trade is explicit: neither file is **backed up by the repo**, so if one is lost, it is lost.

Two things about that include were verified with `ssh -G`, not assumed:

- **Its position is load-bearing in both directions.** It sits *after* `AddKeysToAgent yes`
  so that global value is obtained first and still reaches every host including `vps`
  (`ssh -G vps` reports `addkeystoagent true`), and *before* the first `Host` block so a
  local block can override a tracked one rather than losing to it. ssh keeps the **first**
  value it obtains for a keyword, which is the same rule the `AddKeysToAgent` comment in
  that file already turns on.
- **A missing include is silent.** ssh does not error on an absent included file, so a host
  without `config.local` defines nothing and says nothing; the failure surfaces much later
  as `Could not resolve hostname vps`. Survivable only because these are hosts reached by
  hand. This is the same hazard as umbriel's `[include.optional]`, and the reason the
  umbriel base is a *required* include instead.

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
- **`~/.config/umbriel/noctalia.toml` is pulled in by the *required* include, and that
  entry is not ours to manage.** Noctalia's umbriel template has a `post_hook`,
  `/usr/share/noctalia/assets/templates/umbriel/apply.sh`, which rewrites the host's
  **main config file** on every theme change to append `"noctalia.toml"` to
  `[include].files`. It is idempotent, and it writes with `cp` rather than renaming over
  the path — so the edit lands in the repo instead of silently detaching the symlink,
  which is the one way this could have gone badly. Verified 2026-09-21.

  The consequence is a rule: **never also list that file under `[include.optional]`.**
  Naming it twice makes umbriel log `include cycle or duplicate skipped` and report
  `configuration invalid`, exit 1 — and since `umbriel-update`'s install gate is
  `validate -c` against the live config, a duplicate blocks updates of a compositor that
  is otherwise fine. That is how it was found, on caesar's first reboot after the
  `5eb49b6` merge. Both hosts now keep the optional entry commented out.

  A required include naming a file that does not exist is `configuration invalid` too,
  and on a rebuilt machine the palette does not exist until Noctalia's template has run
  once. `common/bootstrap/seeds` plants it before first login to close that gap.

A new host is a deliberately written `hosts/<name>/`, never a copy of another host's.
`hosts/` is not a template directory.

Scripts in `common/scripts/` are called by **bare name**, from both the Umbriel binds and
the systemd units (`%h/.local/bin/<name>`), so nothing in `common/` names a home directory
or a checkout location. `common/bootstrap/links` makes that true by symlinking the scripts
into `~/.local/bin`; umbriel's `spawn:` resolves through `PATH` (tested, not assumed). The
coupling: `PATH` must reach the compositor, which it does via `~/.bash_profile` on the tty1
login. A compositor started any other way would not inherit it, and every script bind would
register, validate, and do nothing.

## Bootstrapping a host: the `nomarchy` CLI

```bash
nomarchy status  [host]          # drift audit: everything, read-only, never sudo
nomarchy link    [host]          # user level: toolchains, builds, links, seeds, user units
nomarchy install base            # packages, files, units, checks every host needs
nomarchy install desktop         # the graphical session; umbriel built from AUR
nomarchy install host [host]     # this machine's packages, files, units, checks
```

`host` defaults to `/etc/hostname`. Before `~/.local/bin` is linked, call it by path:
`common/scripts/nomarchy`. The old `bootstrap <host> [--apply]` still works — it is a shim
for `status` and `link --yes`.

**The split is who may run what, and it is the whole design.** `status` and `link` never
call `sudo`, so they are safe in an agent's tool shell, where sudo cannot be answered — run
`status` any time to ask whether this machine still matches the repo. `install` **does**
call sudo, because a human at a TTY is the password prompt. Until 2026-09-27 nothing did:
the bootstrap refused sudo everywhere, so it could only *print* root steps, and on rigel's
bare console that meant hand-copying a 100-package `pacman` line nobody could paste. The
repo was a configuration plus instructions; it could not make the promise *repo → working
machine*. `install` keeps the reading without the retyping: it works out everything that is
not already true, prints the whole plan with every diff and command, asks once, then runs
it. Package steps are fatal (later steps assume those binaries); others report and continue.

Nothing clobbers silently. A path that exists but is not the expected symlink is a conflict
and is left alone; a root-owned copy that differs is a conflict in `status` and a *shown
diff* in `install`'s plan.

It is data-driven, and the data is the spec. A **stage** is a directory of manifests:
`common/stages/base/`, `common/stages/desktop/`, and for `host`, `hosts/<host>/packages/`
plus `hosts/<host>/bootstrap/`:

| file | what it declares |
|---|---|
| `repo.txt` | official-repo packages, `pacman -S --needed` |
| `aur.txt` | AUR packages, built **in list order** in `~/builds/<pkg>` with `makepkg -si` — the layout `umbriel-update` relies on, which is why the installer does not use `paru` even though Pete does |
| `copies` | root-owned files, `<repo path> <system path> [mode]`; **diffed**, installed with the reload their path needs (`daemon-reload`, `udevadm`, `sysctl --system`, `sshd -t` + reload) |
| `system-units` | `enable <unit>` or `mask <unit>`; a `static` unit (enabled by its package) only needs starting |
| `checks` | state that is not a file or unit — timezone, locale, the firewall. `check`, then `probe` (no sudo, read-only, what `status` runs) and `fix` (may sudo), or `manual` for what needs a human |
| `root-steps` | host only: printed, never run |

And the user level, read by `link`:

| file | what it declares |
|---|---|
| `common/bootstrap/links`, `hosts/<host>/bootstrap/links` | symlinks to lay |
| `common/bootstrap/seeds`, `hosts/<host>/bootstrap/seeds` | files an app owns but that must **exist** before it first runs; copied once if absent, never overwritten, deliberately **not** diffed |
| `common/bootstrap/units`, `hosts/<host>/bootstrap/units` | `systemd --user` units to enable |
| `common/bootstrap/toolchains`, `hosts/<host>/bootstrap/toolchains` | language toolchains — the gap between *package installed* and *thing works* |
| `common/bootstrap/builds`, `hosts/<host>/bootstrap/builds` | source builds that are not packages; a GitHub ssh URL is **cloned over https** with the ssh URL as its push URL, so a fresh host builds before any key is loaded |
| `hosts/<host>/bootstrap/user-checks` | as `checks`, but `fix` must not sudo — caesar's rootless docker context |

**A credential is a `manual` check, never a file here, and existence is not the probe.**
caesar's UPS monitor needs the monuser password in `/etc/nut/upsmon.conf`, but the `nut`
package ships a stock `upsmon.conf` — so "the file exists" is true on a machine that will
never shut down on low battery. The probe is `nut-monitor` running, because upsmon refuses
to start with no UPS configured. Prefer a probe that states the outcome over one that
implies it.

A file living in `common/` means it is *available* to any host; a host's `links` list is
what that machine actually installs. The NAS units are the example — general-purpose files
that only make sense on a machine that can reach that NAS.

**Two of those rows exist because a package manifest cannot express everything a working
machine needs, and both gaps were found the same way — by something being silently
absent.**

`builds` is for what has no PKGBUILD and no AUR entry. `shelf` — Peter's own GTK4 file
manager, bound to `Mod+F` — is the case that created the file. Before it, nothing in the
repo mentioned shelf at all, and on rigel 2026-09-20 the result was a dead key that every
check called healthy: `umbriel validate` said `config: ok`, the bind registered, and
`bootstrap rigel` reported *25 ok, 0 to do, 0 conflicts*, while `launch-or-focus` died on
`exec shelf` with status 127. Nothing in the repo could have reported it, because nothing in
the repo knew shelf should be there. **A bind whose target is undeclared is a bind that can
fail while the drift audit says the machine is clean.**

Builds run from `link`, which never sudoes, because `make install` here is
`PREFIX=$HOME/.local` and needs no root. Ordering follows the dependency chain — `install
desktop` (which brings `gtk4` and `rustup`), then `link` (toolchain, then builds).

`toolchains` is the subtler one. Arch's `rustup` package installs **shims only**:
`/usr/bin/cargo` and `/usr/bin/rustc` exist and answer `command -v`, so `rustup` appearing
in `packages/repo.txt` was satisfied on rigel while `~/.rustup` was 0 bytes and every build
failed with *"could not choose a version of cargo to run"*. The probe is
`rustup show active-toolchain`, which exits nonzero when no default is set. Checking that
the toolchain *list* is non-empty would not do — a toolchain can be installed without being
default, and that state still fails to build.

**A new host is a `hosts/<name>/` somebody wrote on purpose.** `nomarchy` refuses a
host directory that does not exist rather than defaulting to another machine's. `hosts/`
is not a template directory, and a laptop is not a caesar clone: it has different
microcode, hybrid Intel + NVIDIA graphics rather than one desktop card, no NAS, no second
user, and lid events caesar has no concept of.

**Standing up a new machine has its own document: `docs/new-host/README.md`.** It is
written for the agent running on that machine's *old* OS, and covers the sequence that
matters — survey and write `hosts/<name>/` **before** the wipe, push, then install, then
`nomarchy install` and `link`. `common/scripts/host-survey` captures what only exists while the old OS is
alive: connected outputs and their modes, CPU vendor, GPU, lid and battery, wifi profile
names, enabled services. It prints no secrets, by design.

## Updating umbriel

Umbriel is a young project on `main`, packaged here as an AUR **git** build. It moves
fast enough that this is a real hazard rather than a theoretical one: in the five days
after the install, upstream landed 34 commits, two of them marked breaking, and one of
those renamed four things `common/umbriel/base.toml` was using. A plain `makepkg -si`
would have installed it happily and left a session whose `Mod+R` silently did nothing.

`common/scripts/umbriel-update` exists for that. Dry run by default, like `bootstrap`.

```bash
umbriel-update                        # what upstream has, and what it would break
umbriel-update --merge-config         # preview upstream's config changes, merged
umbriel-update --merge-config --apply # write it; resolve conflicts; --merge-accept
umbriel-update --apply                # build the merged rev, gate, install, move the pins
umbriel-update --sync --apply         # install EXACTLY the pinned revs, gated (after a pull)
umbriel-update --rollback             # reinstall the previous package
umbriel-update --find-pin             # re-derive which rev base.toml forked from
```

**Every host builds the pins, never upstream `main`.** `common/umbriel/UPSTREAM` records
three revs: `config`, the upstream rev `base.toml` is merged to, and one **build pin** each
for `umbriel-git` and `xdg-desktop-portal-umbriel-git`. The AUR PKGBUILDs say
`#branch=main`, so `nomarchy install desktop` and `umbriel-update` build a copy with
`#commit=<pin>` (`makepkg -p`), which also keeps the AUR checkout clean. Before this, a
fresh machine got whatever `main` was that minute: the VM rehearsal compiled `fd870c1`,
a rev nothing had validated. `config` moves at `--merge-config`; the build pins move only
at `--apply`, after the new binary validated the live config, so a pin is always a rev
some host has proved. The portal has no config and follows umbriel: the newest portal
commit no later than the umbriel rev. Another host picks up moved pins with
`--sync --apply`.

**Two invariants, checked separately** (`nomarchy status`, via `--check-pins` and
`--check-config`): the installed revs equal the pins, and the installed umbriel accepts the
live config. The second can fail with the first exact — Arch ships Noctalia, a
`pacman -Syu` can bring a palette template in a different umbriel vocabulary, and the pair
breaks without anyone touching umbriel. `umbriel-update`'s survey reports Noctalia
installed, what Arch serves, and upstream's newest release, so that lag is on screen.

It rests on three things, each established by testing umbriel 0.1.0 rather than by
reading docs:

- **`umbriel validate` exits nonzero on a renamed key AND on a renamed keybind action.**
  Both are only *warnings* at runtime, so a stale config yields a compositor that starts
  clean and quietly drops the affected binds — but validate calls it `configuration
  invalid` and exits 1. That is the difference between catching this and not.
- **The built binary runs before it is installed**, out of `pkg/umbriel-git/usr/bin/`.
  So the script builds, points the *new* binary at the *live* config, and installs only
  if that passes. A breaking rename costs a refused install, not a broken session.
- **`base.toml` is a fork of upstream's `examples/config.toml`**, so config drift is a
  three-way merge, not a diff to read by hand. Upstream's renames land automatically
  wherever this repo had not customised the line; what conflicts is what a human should
  decide. The 2026-09-18 update produced four conflicts, all four genuine.

**The `config` pin in `common/umbriel/UPSTREAM` has to be right, and a wrong one fails
quietly.** It records the rev `base.toml` was forked from — the base leg of that merge. A pin set
too late makes the merge read upstream's own changes as this repo's customisations and
keep them out, with no conflict and no warning. That happened on the first run: the pin
was seeded with the installed rev, which was two days too late, and the tell was
`base.toml` carrying `# left or right master area` when upstream had said
`left, right, or center` since before the fork. Merging from the real fork point turned
8 conflicts into 4 and recovered doc fixes the wrong pin had discarded. `--find-pin`
re-derives it; run it whenever a merge conflicts somewhere this repo never touched.

**A merge that applies cleanly is not a merge that is correct.** The same update renamed
`default_size = [W, H]` to `default_floating_size_px = { width = W, height = H }`.
Upstream's own example rules were renamed by the merge; the two rules nomarchy had
customised — btop/lazydocker and shelf — kept the old spelling, because a customised line
is exactly what a three-way merge preserves. Left alone, those two windows would have
opened at the wrong size with nothing at runtime saying why. The validate gate is what
caught it. Expect this class of leftover after any rename, and grep for the old spelling.

**The worse case is a clean merge that deletes.** Upstream `12f4123` (2026-09) cut its
example from 836 lines to 258, dropping ~30 whole sections. Wherever `base.toml` still
carried a line unchanged from the old example, the three-way merge deleted it: 74 of 220
live settings — all animation, blur, shadow, hot-corner and master/dwindle values — with no
conflict, and nothing for validate to catch, because a missing key is valid. Each would have
reverted to a built-in default, in the same range that changed those defaults. Upstream
shrinking its *sample* is not a reason to shrink this config; that update was taken by
keeping `base.toml` whole and changing only what the new binary rejected. `--merge-config`
now lists every live setting the clean part of a merge removes, changes or adds, and only
auto-promotes a merge that touches nothing but comments; anything else goes to
`base.toml.new` and `--merge-accept`, the same path conflicts take.

**Validate is `umbriel config validate` from upstream `f66d6a8` on.** A binary asked the
old way prints its usage and exits nonzero, which by exit code reads as "configuration
invalid" — the gate refused a good build on rigel that way before `validate_with` asked each
binary which spelling it speaks. The commands elsewhere in this file still say `umbriel
validate`, which is right for the builds installed on 2026-09-27 (caesar `5eb49b6`, rigel
`31601e0`); once a host runs a newer build, the same checks are `umbriel config validate`.

**Ordering: merge the config first, then install.** The new binary wants the new
vocabulary and the running one wants the old, so whichever moves first is briefly
mismatched. Writing `base.toml` is the survivable direction — umbriel treats unknown keys
as warnings and keeps its last working configuration, and the live session was verified
to keep serving IPC and keybinds through exactly that state. Installing first is the case
the gate refuses outright.

**Installing does not update the running compositor.** `umbriel msg config-reload`
reloads config, not code; the session keeps the replaced binary until it restarts. The
script reports this from `/proc/<pid>/exe`, which reads `(deleted)` once the file behind
a running process has been replaced — a signal that states what happened rather than
implying it. Log out and back in to actually land a new build.

Rollback packages live in `~/builds/.rollback/`, three deep. That directory is the only
rollback that exists: pacman does **not** cache packages installed with `-U`, verified
here against a cache holding 600+ downloaded ones. **`--rollback` restores the binary,
not the config** — a `base.toml` already merged forward then speaks a vocabulary the
restored binary does not know, which is the update mismatch pointing the other way. The
script says so and names the `git checkout` that undoes the merge; that only works if the
merge was committed, which is the argument for committing it alongside the update.

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
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"   # bashrc sets it; harmless to repeat
ssh-add -l                                                  # "no identities" = the real cause
```

`ssh-agent.service` (a user unit, symlinked from `common/systemd/`) owns the agent and
binds it to that fixed path; `~/.bash_profile` exports the variable for the login shell,
so the compositor and everything it spawns inherit it. A **tool shell** started outside
that chain still has to export it by hand.

The second cause is that the agent is running but **empty**: every key here
(`id_ed25519_github`, `id_ed25519_caesar`, `id_ed25519_homelab`) is passphrase-protected,
and the passphrase must be entered once per boot. `AddKeysToAgent yes` in `~/.ssh/config`
makes the first ssh of the session prompt for it.

**A tool shell can serve that prompt itself** — it does not have to be handed back to the
owner. `common/scripts/askpass-fuzzel` is installed, and a tool shell sources
`common/bash/bashrc`, so `SSH_AUTH_SOCK`, `SSH_ASKPASS`, `SSH_ASKPASS_REQUIRE=prefer`,
`WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR` are **already set** — verified on rigel
2026-09-18, where a bare `ssh-add ~/.ssh/id_ed25519_caesar` put a fuzzel prompt on the
owner's screen and loaded the key. Nothing needs exporting. The owner still types the
passphrase; this moves the prompt somewhere they can answer it rather than bypassing it.
With no compositor to draw on, ask them to run the command instead.

**The trap is `BatchMode=yes`.** It disables every interactive prompt, askpass included,
so `ssh -o BatchMode=yes` fails `Permission denied (publickey)` against an empty agent and
looks exactly like a broken key. Use it to *test* whether the agent is already loaded;
drop it when you want the prompt.

`SSH_ASKPASS_REQUIRE=force` is not needed and was tested rather than assumed: a tool shell
has no controlling terminal (`{ : < /dev/tty; }` fails), so `prefer` — and even leaving the
variable unset — consults the helper anyway. `force` only matters where a TTY exists.

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
