# caesar cutover — what moves, what is declared, what retires

Proposed manifest, 2026-09-28, from a **read-only** inventory of the running SATA install
(`/home/peter` and the system around it). Nothing was copied, moved or changed. Secrets appear
by name, size and mode only. **For review — nothing here is applied.**

Decisions from Pete and Atlas (2026-09-28) are in **§0** and supersede the open questions in
§6. The declarations they imply are proposed in **§8**, and the migration and its acceptance
tests in **§9** — neither is implemented yet.

The question it answers is not "what should be copied" but **"does nomarchy know about
everything that matters?"** Every item gets an owner and a disposition.

## 0. Decisions, 2026-09-28 (Pete + Atlas)

| # | question | decision |
|---|---|---|
| 1 | Revline dev database | **Authoritative.** Consistent `pg_dump` during the final cutover freeze; the rootless-docker volumes stay untouched on SATA as fallback until the migration is accepted. Restore what is wanted; never make recoverability depend on remembering what was seeded. |
| 2 | Firefox | **Clean profile + Sync.** Fresh profile on new caesar; the SATA profile stays untouched as fallback until bookmarks, logins and extensions are verified. |
| 3 | `sda3` "FreeSpace" | **KEEP UNTOUCHED.** ext4, UUID `1953f264-eed7-4b82-acc9-7e0f23ac8b34`, ~453 G of deliberate archive: `kali_usb_backup.img` (29 G), `nvme_backup/` (262 G), `Steam/` (163 G), `Proxmox-Backup/` (empty), `lost+found`. On the SATA disk that stays. **Not copied, not mounted by the migration, not altered in any way.** |
| 4a | Codex | **Yes.** Declare the install; its auth and history are private/user data, handled separately. |
| 4b | keyboard-rgb | **Superseded — verified.** Irides `bfb95ba` "irides-lighting: G213 keyboard, ported from keyboard-rgb to Rust"; `irides-lighting` drives the G213 (`0xC336`), G502 and ASUS Aura, and its udev rule's first line is **identical** to keyboard-rgb's G213 rule. The only active Noctalia lighting template is Irides'. The source is preserved (it moves with `~/code`); nothing installs or runs it. nomarchy's `70-logitech-g213.rules` retires in favour of Irides' rule. |
| 4c | OpenDeck | **Yes.** Declare it; restore its profiles from `Archive/omarchy-rescue/opendeck`. |
| 4d | Nord VPN | **Not migrated.** Reinstall/reconfigure deliberately later if wanted. |
| 4e | `browse_alias.pre-repo` | Preserved if cheap (it moves with `~/code`); never installed as live config. |
| 4f | `.stfolder` | A Syncthing marker; Syncthing is not installed. Not migrated on its own account. |
| 4g | `~/Archive` | **Preserve** (migrate). |
| 5 | Obsidian | **Authoritative; migrate and verify on its own.** The vault is `~/Legal/Revline/Revline HQ` (its `.obsidian/` is there). It travels with `~/Legal`, but gets its own acceptance check. |
| 6 | `.bash_history` | **Migrate**, in the final delta after the last SATA shell activity. |
| 7 | Irides lighting | **Declare now**, nomarchy-owned: the udev rule and the template link. |
| — | accounts | **Declare** meanpete (uid 1001, gid 1003) and `media` (gid 1004: peter, meanpete) with those exact ids (NAS/NFS permissions are numeric). Password stays private/by hand. On an existing machine, an id collision **fails closed** — never renumber or chown. |
| — | `192.168.1.200` | Owned by the router's DHCP reservation, **not** nomarchy. Declared and verified as an external dependency; a mismatch is surfaced by `status`, never "fixed". |
| — | untracked config | Per file: intentional non-secret config becomes nomarchy-owned; auth/private state stays external, migrated and bootstrap-verified separately. |
| — | `pacman.conf` / mirrorlist | Not copied wholesale. Declare the intended `pacman.conf` settings; no accidental mirror ordering preserved. |
| — | cutover | Two-pass: bulk while SATA is live → quiesce Revline/DB, Thunderbird, Firefox, Obsidian, Claude/Codex, active git work → Revline dump → final delta → verify. SATA untouched afterwards as the immediate fallback. **Executable order: §9** — the XPG is provisioned first and is itself the destination of both passes. |

## Principles and decisions already made

- **Bias toward not migrating.** Migrate only what we know why we are migrating. SATA stays
  installed after cutover as the immediate fallback, so a forgotten file costs a copy later,
  not a loss. The NAS raw image remains the permanent archive of old Omarchy.
- **The migration never overwrites anything the clean install created** — a nomarchy link,
  seed, build output, declared copy or generated file — unless an entry here explicitly
  authorises that overwrite. `$HOME` migration must not quietly undo the clean-room work.
- **Verification is semantic**, not "copied": GPG key listed → `pass` decrypts → SSH
  authenticates → Thunderbird opens the expected profile → wallpapers exist → repos keep
  their dirty/unpushed state → Claude history exists → Legal/Notes counts and hashes match.
- **Decided, not reopened:**
  - (a) **SSH host keys are preserved.** New caesar is the same host rebuilt.
  - (b) **Git working trees move whole, never re-clone.** GitHub is authoritative only for
    pushed objects — not `.env`, ignored `CLAUDE_NOTES.md`, untracked files, local branches
    or stashes.
  - (c) **Two-pass cutover**, in the one order §9 gives: provision the XPG → bulk pass into it
    while SATA is live → freeze → evidence → final delta → first boot → stages → restore →
    semantic acceptance. Never copy a live Thunderbird/Claude/Codex profile, a running
    database, or a repo being written to.
  - (d) **meanpete stays**, deliberately — see *Beyond `$HOME`*.

Record format used below:
`item | purpose | current owner → desired owner | migration | action | repo | verification`

Desired owner is one of **nomarchy** (declared, reproducible), **private machine state**
(real, never in the repo), **user data** (carried across), **retire** (deliberately let go).

---

## 1. `$HOME`, every top-level entry

| entry | size | class | note |
|---|---|---|---|
| `code/` | 13 G (2.3 G without build artifacts) | **MIGRATE** — working trees | §3; 13 non-repo dirs have no other copy |
| `Projects/nomarchy` | 46 M | **MIGRATE** — working tree | has ignored `CLAUDE_NOTES.md` and unpushed commits |
| `Legal/` | 33 M, 46 files | **MIGRATE** — user data | backed up to NAS (plain) |
| `Notes/` | 501 M, 55 files | **MIGRATE** — user data | backed up nightly |
| `Pictures/` | 117 M, 19 files | **MIGRATE** — user data | Irides blueprints + Noctalia pin these by path/hash |
| `.gnupg/` | 200 K | **MIGRATE** — private | 1 key (8B52A5D2637434B3 + cv25519 subkey) |
| `.password-store/` | 36 K | **MIGRATE** — working tree | also on GitHub; move whole per (b) |
| `.ssh/` | 14 K | **MIGRATE** — private | see §2 |
| `.thunderbird/` | 23 M | **MIGRATE** — user data | profile `m4xrexpp.default-release` (IMAP + logins) |
| `.claude/`, `.claude.json` | 148 M + 66 K | **MIGRATE** — user data | history, project memory, settings, skills; `.claude.json` holds login state |
| `.codex/` (selected) | ~20 M of 520 M | **MIGRATE** — user data | `sessions/`, `history.jsonl`, `memories_1.sqlite`, `config.toml`, `rules/`, `hooks.json`, `skills/`; `auth.json` private |
| `vpn/` | 3 K | **NOT MIGRATED** (§0 4d) | Nord credentials + 2 untracked scripts; stays on SATA; reinstall deliberately later if wanted |
| `.config/` | 283 M | mixed | §2 |
| `.local/` | 9.6 G | mixed | §2; 7.7 G is docker |
| `Archive/` | 427 M | **MIGRATE** — user data (§0 4g) | omarchy-rescue: Proton/RetroArch saves, OpenDeck profiles (restored from here, §8 B4), vBIOS. Also in the NAS image |
| `isos/` | 1.5 G | DISCARD | archlinux-2026.09.01 ISO; re-downloadable, not needed (provisioning runs from SATA) |
| `builds/` | 1.2 G | DISCARD | AUR build trees; the installer rebuilds at the pins |
| `.cache/`, `.npm/`, `go/`, `.cargo/`, `.rustup/` | 4.1 G, 124 M, 121 M, 449 M, 2.6 G | DISCARD / RECREATE | caches; rustup toolchains are recreated (nomarchy toolchains + Irides' pin) |
| `.docker/` | 213 B | RECREATE | `config.json` has an empty `auths` and the context; the rootless context is a nomarchy check |
| `Logs/` | 39 K | DISCARD | backup/subget logs; recreated |
| `Backups/`, `Downloads/`, `.nv/` | empty | DISCARD | |
| `.bash_history` | 16 K | **MIGRATE** (§0 6) | in the **final delta**, after the last SATA shell activity |
| `.lesshst` | 26 B | DISCARD | |
| `.gitconfig` | 88 B | **declare** (gap) | identity; rigel's fresh install had none |
| `.bashrc`, `.bash_profile` | links | RECREATE-by-nomarchy | never overwrite |
| `.bash_logout` | 21 B | DISCARD | /etc/skel |

**MIGRATE total ≈ 3.8 G** (code 2.3 G without `target/`, `node_modules/`, venvs, `dist/`, `build/`; `Archive` 0.43 G; the rest 1.1 G), plus the Revline database as a `pg_dump -Fc` file (§4). The docker volumes themselves are not carried; they stay on SATA as fallback.

## 2. Inside `.config`, `.local`, `.ssh`, `.claude`, `.codex`

**Owned by nomarchy — RECREATE, never overwrite:** `.config/nvim`, `kitty/kitty.conf`,
`fuzzel/fuzzel.conf`, `umbriel/config.toml` (links); `umbriel/noctalia.toml`,
`.local/state/noctalia/settings.toml` + `.setup-complete` (seeds); `irides/blueprints` (link);
`.config/systemd/user/*` (links + enabled units); `~/.local/bin/*` links to nomarchy scripts,
`shelf`, `irides*` (builds); `~/.ssh/config` (link).

**Generated by Noctalia's templates — RECREATE (regenerated on the first theme apply):**
`qt5ct/`, `qt6ct/`, `gtk-3.0/noctalia.css`, `gtk-4.0/noctalia.css`, `kitty/themes`,
`fuzzel/themes`, `lazygit/themes`, `btop/themes`, `tmux/themes`, `bat/themes`, `starship.toml`,
`kdeglobals`, `.local/share/color-schemes`, `noctalia/palettes/irides-*.json` (Irides regenerates).

| item | purpose | owner now → desired | migration | action | repo | verification |
|---|---|---|---|---|---|---|
| `.config/mozilla` (2 profiles, default `b6wgzdg1.default-release`, 273 M) | Firefox | user data → **not migrated** (§0 2) | **clean profile + Sync**; the SATA profile stays untouched as fallback until verified | sign in to Sync on new caesar | NEVER | bookmarks, logins and extensions present after Sync |
| `.thunderbird/m4xrexpp.default-release` | mail accounts, logins | user data | move profile (app stopped) | — | NEVER | opens the expected profile, accounts sync |
| `.config/obsidian` (9.7 M) | app state, vault list | user data | **MIGRATE** (the vault list points at the vault) | — | NEVER | Obsidian opens the vault |
| **`~/Legal/Revline/Revline HQ`** (the Obsidian vault) | Revline notes | user data (§0 5) | travels with `~/Legal`, **own acceptance check** | — | NEVER | vault opens; note count equals the recorded count |
| `.config/herdr/config.toml` (158 B) | herdr config ("a keeper") | → nomarchy | none | **declare** as a link | declare | herdr starts with it |
| `btop/btop.conf`, `git/ignore`, `~/.gitconfig` | authored config | → nomarchy | none | **declare** (§8 D) | declare | the tool uses it |
| `bat/config` | **generated** — Noctalia's bat template writes its one line, `--theme=noctalia` | RECREATE | none | — | — | the template regenerates it |
| `.config/lazygit/config.yml`, `.config/gh/config.yml` | **generated** — lazygit's is inlined NSX theme state (Pete did not author it); gh's is its defaults | RECREATE | none | — | — | the theming system / gh regenerate them |
| `.config/gh/hosts.yml` | **GitHub CLI token** | private | preserve exact file + mode | — | NEVER | `gh auth status` |
| `.config/subliminal/subliminal.toml` (0600) | **opensubtitles login** (subget) | private | preserve file + mode | declare its required existence (manual check) | NEVER | `subget` dry run authenticates |
| `.config/ai-usagebar/config.toml` | ai-usagebar config | → nomarchy | inspected: **token-free** (provider on/off switches and the UI's primary provider only) | declare (§8 D) | declare | bar shows usage |
| `.config/irides/lighting.toml`, `.local/state/irides/*`, `.local/share/irides/lighting.colors` | Irides lighting choices/state | Irides (user) | small; ask the Irides session which are state vs output | — | NEVER | lighting follows theme |
| `.config/caddy`, `.local/share/caddy` | caddy client state | **retire** | inspected: an `autosave.json` of 09-23 and lock/instance files; caddy is not installed — a one-off run | not migrated | — | — |
| `.config/spotify`, `.local/share/spotify-launcher` (370 M) | Spotify prefs / binary | RECREATE | none | re-login | — | Mod+M plays |
| `.local/share/docker` (7.7 G) | rootless docker: **Revline dev stack** + images | **not migrated** — stays on SATA as fallback | the database moves as a `pg_dump -Fc` (§4, §9) | — | NEVER | dump restores; stack up with the data |
| `.local/share/claude` (1.4 G), `.codex/packages` (369 M) | Claude Code / Codex **binaries** | → nomarchy as AUR packages (§8 B2, B3) | none | — | declare | `claude --version`, `codex --version` |
| `.local/share/pipx` (subliminal 2.7.1) | subget's dependency | → nomarchy (**gap**) | none | declare `pipx install subliminal` | declare | `subliminal --version`; subget dry run |
| `.local/share/nvim` (218 M), `.local/state/nvim` | plugins, shada/undo | RECREATE / DISCARD | none | lazy restores from the repo's lockfile | — | nvim starts clean |
| `.local/state/noctalia`: notification history, usage counts, `recently_used.json`, `wallpaper_shuffle.json`, `plugin-cache/`, `community-*` | Noctalia runtime state | DISCARD | none | — | — | — |
| `.local/state/noctalia/state.toml` (0600) | Noctalia's own bookkeeping | **RECREATE** | inspected: only `[security_migrations]` and `[theme_templates]` — no credential | Noctalia writes it fresh | NEVER | — |
| `.local/state/herdr` | herdr agent-detection state | DISCARD | — | — | — | — |
| `.local/share/pki/nssdb` | NSS cert/key db | **discard** | inspected: `certutil -L` lists no certificates | — | NEVER | — |
| `.ssh/id_ed25519_{github,homelab,waylab,vps,caesar_to_rigel}` (+ `.pub`) | outbound identities | private | preserve exact files + modes | — | NEVER | `ssh -T git@github.com`; `ssh waylab true`; `ssh rigel true` |
| `.ssh/authorized_keys` | **access grant** (rigel's key) | private | preserve | — | NEVER | `ssh caesar` from rigel |
| `.ssh/config.local` | local-only hosts (vps) | private | preserve | declare required existence | NEVER | `ssh -G vps` resolves |
| `.ssh/known_hosts` | host pins | user data | copy | — | NEVER | no new-host prompts |
| `.ssh/agent/` | dead-glob leftover | DISCARD | — | — | — | — |
| `.claude/projects/*` (126 M, incl. `*/memory/`), `history.jsonl`, `settings.json`, `skills/`, `plugins/`, `hooks/` | Claude Code history, **project memory**, config | user data | move (Claude stopped) | — | NEVER | `/resume` lists sessions; memory files present |
| `.claude/{cache,shell-snapshots,paste-cache,file-history,backups,*.bak}` | caches/backups | DISCARD | — | — | — | — |
| `.codex/{sessions,history.jsonl,memories_1.sqlite,config.toml,rules,hooks.json,skills}` | Codex history/config | user data | move (Codex stopped) | — | NEVER | history visible |
| `.codex/auth.json` | **Codex login** | private | preserve, or re-login | — | NEVER | `codex` authenticated |
| `.codex/{.tmp,cache,logs_*,queue_*,state_*,models_cache.json}` | runtime | DISCARD | — | — | — | — |

## 3. Git repositories — move as working trees

State compared against existing remote-tracking refs (no fetch was run; `lastfetch` shows how
stale that comparison is).

| repo | branch @ commit | local-only state | precious ignored files |
|---|---|---|---|
| `Projects/nomarchy` | nomarchy-cli @ c72c252 | **+2 unpushed** (origin, waylab) | `CLAUDE_NOTES.md` |
| `code/revline` | dev @ 2c00788 | **1 stash**, 2 untracked, **2 unpushed** on other branches (`cb2eae7 wip: auth pages/hooks…`, `3bc5247 frontend(prod)…`) | `.env`, `.env.dev`, `.env.minio`, `.env.prod`, `api/.env`, `infra/.env*`, `CLAUDE_NOTES.md` |
| `code/salonline` | main @ e4e3fc8 | **10 dirty** | `.env` |
| `code/detective_game` | main @ 7a9d36c | **5 dirty, 12 untracked** | — |
| `code/ls-torrent-tui` | dev @ eea3291 | **3 dirty** | `CLAUDE_NOTES.md` |
| `code/portal` | master @ 41657b5 | **1 dirty** | — |
| `code/dms-interface` | master @ b832be4 | **+1 unpushed** (fetch 09-03) | `CLAUDE_NOTES.md` |
| `code/horizons` | master @ f99629b | **+1 unpushed** (fetch 08-12) | — |
| `code/kitty-fork/kitty` | pete/mouse-selection-from-gutter @ fd124c241 | branch on **no** remote, **2 unpushed** | — |
| `code/ls-rails` | dev, **no commits** | 5 untracked | — |
| `code/ls-horizons` | master @ ccbb6ef | 1 untracked | `claude_notes.md` |
| `code/destiny-tui`, `gifmaker`, `pi_display/eink_dev` | clean | — | `.env` |
| `code/irides`, `shelf` | clean | — | `CLAUDE_NOTES.md` |
| `code/{asm4mo-preserved, c/coreutils, c/hard_way/lcthw, dude-walk, litescript.net, OmNote(+aur), python_projects, revline.dev, unix_game}`, `.password-store` | clean, in sync | — | — |

**`~/code` also holds 13 directories that are NOT repos** — no remote, so this disk and the
nightly tar are their only copies: `asm`, `chirper` (70 M), `destiny-cipher`, `go`, `godot`,
**`keyboard-rgb`** (superseded by Irides' lighting, §0 4b; source preserved, never installed), `ls-box`, `ls-budget`,
`ls-netfield` (57 M), `ls-scp`, `torrent_tui`, `wm`, `xmas`; plus loose files (Atlas context
`.md`, `kitty-gutter-selection-report.md`, `omnote-1.3.0.tar.gz`), `browse_alias.pre-repo`
(parked, 27 M — preserved by the move, never installed, §0 4e), an empty `ai-bar`, and `.stfolder` (a Syncthing marker; Syncthing is not installed — not migrated on its own account, §0 4f).
Moving `~/code` whole, minus build artifacts, covers all of them.

**Two-pass note:** `code/revline` and `code/portal` have live dev processes; stop them before
the final pass.

## 4. Beyond `$HOME`: what makes caesar caesar

Classified as **DECLARED** in nomarchy, or **NOT-DECLARED** (a gap unless deliberately retired).

### meanpete — decided: stays, as declared host state

| item | now | desired owner | action |
|---|---|---|---|
| account `meanpete` uid 1001, gid 1003 (`meanpete`), groups `meanpete,media`, `/bin/bash` | README steps (manual) | **nomarchy** | declare the account and groups (NOT-DECLARED today — the stages do not create users) |
| group `media` gid 1004 (members peter, meanpete) | manual | **nomarchy** | declare: NAS `Movies`/`TV` are `media`-owned setgid; peter's writes depend on it too |
| `~meanpete/Scripts` (`movie`, `tv`, `move-to-plex*.sh`), `.bashrc`, `.bash_profile` | copies from `hosts/caesar/meanpete/` | **nomarchy** | declared as files; installed by hand — fold into `install host` |
| `~meanpete/incoming` and anything else in his home | `drwx------`, **unreadable without root**; home mtime 09-27 11:57 | **user data** | inventory with sudo (below), migrate |
| linger / user units / timers for meanpete | Linger=no; no session; units unreadable | — | confirm none with sudo |
| sshd `Match User meanpete` (password auth) | DECLARED copy `10-nomarchy.conf` | nomarchy | keep |

Doc fixes owed: `CLAUDE.md` and `hosts/caesar/meanpete/README.md` still call this setup
temporary, "deleted after the NVMe cutover" — now wrong. And **audit §11's privesc** (the old
root-owned wrapper exec'ing a meanpete-writable script under a sudo grant) must stay out: the
declared version has no sudo grant and no `/usr/local/bin/plex-*` — keep it that way.

### System units and timers

Enabled on SATA but not declared: `NetworkManager-dispatcher`, `NetworkManager-wait-online`
(pulled in with NetworkManager), `remote-fs.target`, `systemd-userdbd.socket`, `getty@.service`
(defaults), `ufw.service` (enabled by `apply-rules`, which the firewall check covers). **No
real gap.** Timers: `logrotate` (DECLARED), `plocate-updatedb`, `man-db`, `shadow`,
`systemd-tmpfiles-clean`, `archlinux-keyring-wkd-sync` (package defaults). No `.path` units
beyond systemd's; sockets are defaults plus user `docker.socket` (DECLARED).

peter's user units: `ssh-agent`, `backup-daily.timer`, `backup-legal-to-nas.timer`,
`subget-sync.timer`, `docker.socket` — all DECLARED; `pipewire*`/`wireplumber`/`p11-kit` are
package defaults. Linger: no.

### Custom files under `/etc`, `/usr/local`

| file | status |
|---|---|
| `/etc/systemd/system/{mnt-nas.mount,mnt-nas.automount,netconsole-listener.service}`, `/etc/logrotate.d/netconsole-proxmox`, `/etc/modprobe.d/nvidia.conf`, `/etc/udev/rules.d/{70-logitech-g213,99-streamdeck-no-keyboard}.rules` | DECLARED copies |
| **`/etc/udev/rules.d/70-irides-lighting.rules`** | **NOT-DECLARED** — installed by hand (Irides' RGB lighting). Gap |
| `/etc/systemd/system/getty@tty1.service.d/override.conf` | SATA's autologin; the new install gets nomarchy's `autologin.conf` — covered |
| `autovt@.service`, `dbus-org.*` aliases, `/etc/systemd/user/pipewire-session-manager.service` | created by `systemctl enable` — not gaps |
| `/opt`, `/usr/local/{bin,sbin,lib}`, `/etc/polkit-1/rules.d`, `/etc/tmpfiles.d`, `/etc/modules-load.d`, `/etc/X11` | empty / absent |
| cron, at | not installed — no scheduled jobs outside systemd |

### Modified package config (`pacman -Qii` says `[modified]`)

| file | status |
|---|---|
| `/etc/pacman.conf` | **NOT-DECLARED**: `Color` + `ILoveCandy` (cosmetic). Declare as a check, or retire |
| `/etc/pacman.d/mirrorlist` | NOT-DECLARED: every server uncommented, unranked. pacstrap copies it from SATA to the new install; consider `reflector` or a declared list |
| `/etc/locale.gen` | DECLARED (locale check) |
| `/etc/ufw/{ufw.conf,user.rules,user6.rules}` | DECLARED (generated by `apply-rules`) |
| `/etc/fstab` | written by the provisioner from the spec |
| `/etc/passwd`, `group`, `shadow`, `gshadow`, `subuid`, `subgid`, `shells` | users/groups: **meanpete and `media` NOT-DECLARED** (above); peter by the provisioner |
| `/etc/resolv.conf` | NetworkManager-managed |
| `/etc/nut/upsmon.conf` (unreadable) | DECLARED as a manual check (password) |
| `/etc/nut/upsd.conf`, `upsd.users`, `/etc/sudoers`, `/etc/crypttab`, `/etc/default/useradd`, `/etc/libaudit.conf` | unreadable as peter — **modified status unknown**; see the sudo list |

### Privilege

`/etc/sudoers.d/` unreadable (the new install gets the provisioner's `10-wheel`). No polkit
rules, no file capabilities or setuid/setgid outside package files and docker image layers.
`/mnt/nas` is world-rwx at the mount root (NAS-side). Nothing else found.

### Hardware

`MODULES=()` (late NVIDIA KMS, audit §10 — DECLARED as a choice). udev: Stream Deck
(DECLARED), Irides lighting (**NOT-DECLARED → §8 C**, which also covers the G213; nomarchy's own G213 rule retires). No X11 config, no `modules-load.d`. Wi-Fi
`wlp9s0` present but unused (no profile). Bluetooth: not installed (retired on caesar).

### Network

| item | now | desired | action | verification |
|---|---|---|---|---|
| **caesar = `192.168.1.200`** on `eno1`, by DHCP | router-side reservation (by MAC) | private machine state (router) | **declare its required existence**: netconsole (Proxmox sends to .200:6666), ufw, the NAS export and every ssh alias depend on it | `ip -4 addr show eno1` = .200 after cutover |
| DNS `192.168.1.178` (pi-hole), search `internal` | DHCP | router | — | resolves `*.internal` |
| NetworkManager profile "Wired connection 1" | auto | RECREATE (NM makes it) | — | online |
| ufw: deny in; allow 22 from LAN, 6666/udp from .50 | DECLARED (`apply-rules`) | nomarchy | — | `ufw status` |
| mDNS | avahi disabled on SATA | DECLARED (nss-mdns + avahi) for the new install | — | `ping smartspeaker.local` |
| Tailscale | not installed on caesar | retire (rigel only) | — | — |
| listening: 22 (sshd), 6666/udp (netconsole) | DECLARED | | | |
| listening: Revline dev stack 5173, 8000 (all interfaces, firewalled), 5432, 6379, 9000/9001 (localhost) | rootless docker | user data (below) | — | — |

### Filesystem

fstab: root and `/boot` only (the provisioner replaces both); NAS by DECLARED automount units.
**`sda3` "FreeSpace", 1.6 T ext4, UUID `1953f264-…`, in no fstab and unmounted — KEEP UNTOUCHED (§0 3).** Inspected read-only by Pete: ~453 G of deliberate archive (`kali_usb_backup.img`, `nvme_backup/`, `Steam/`, an empty `Proxmox-Backup/`). On the SATA disk that stays; never copied, mounted or altered by the cutover.
No symlinks from `$HOME` into other disks. No ACLs that matter found.

### Local software outside pacman — "still wanted?"

| thing | status | recommendation |
|---|---|---|
| Claude Code (native, `~/.local/share/claude/versions/*`, `~/.local/bin/claude`) | **NOT-DECLARED** | AUR `claude-code` (§8 B2), self-updater disabled |
| Codex CLI (`~/.codex/packages/standalone`) | **NOT-DECLARED** | **wanted** (§0 4a): AUR `openai-codex-bin` (§8 B3); auth and history handled separately |
| pipx `subliminal 2.7.1` | **NOT-DECLARED** — `subget`/`subget-sync.timer` break without it | declare `pipx install subliminal` + a check |
| `cargo install`, `go install`, npm -g, `/opt`, `/usr/local` | nothing user-installed | — |
| OpenDeck (Stream Deck app) | not installed; profiles in `Archive/omarchy-rescue/opendeck`; udev rule DECLARED | **wanted** (§0 4c): AUR `opendeck-bin` (§8 B4), profiles restored from `Archive` |
| `~/code/keyboard-rgb` (G213 lighting) | not a repo | **superseded** by Irides' lighting (§0 4b); source preserved by the `~/code` move; nothing installs or runs it |
| Nord VPN: `~/vpn/nord/*.sh` (2 untracked scripts) + credentials; `openvpn` not installed | half-configured | **not migrated** (§0 4d); stays on SATA; a deliberate reinstall later if wanted |

### Application behaviour — what caesar does

| behaviour | pieces | status |
|---|---|---|
| nightly `~/code`, `~/.claude`, `~/Notes`, `~/Pictures` → NAS | `backup-daily` + timer | DECLARED |
| `~/Legal` mirror → NAS | `backup-legal-to-nas` + timer | DECLARED |
| subtitles for the Plex library | `subget` + timer + **subliminal (pipx, gap)** + `subliminal.toml` (private, **existence not declared**) | partly |
| Proxmox kernel log receiver | netconsole listener + logrotate + ufw | DECLARED |
| UPS shutdown | NUT (`nut.target` + monitor) + password | DECLARED (+ manual) |
| Plex staging for meanpete | his account + scripts + `media` + NAS | account **NOT-DECLARED** |
| Revline dev stack | rootless docker, compose in `code/revline` | see below |
| Irides theming + RGB lighting | build DECLARED; plugin check DECLARED; **lighting udev rule and `~/.config/noctalia/irides-lighting.toml` link NOT-DECLARED** | gap |

**Revline dev stack (rootless docker):** containers `revline-{db,redis,minio,api,web}` up 4–5
days; named volumes `revline_pg_data` (105 M), `revline_minio_data` (44 K),
`revline_redis_data` (198 K), `revline_web_node_modules` (204 M); images rebuildable. **INSPECT:
is the dev database authoritative or re-seedable?** **Decided: authoritative (§0 1).** PostgreSQL
**16.13** (container `revline-db-1`). In the freeze: `pg_dump -Fc` run **inside the container**
(custom format, so `pg_restore` can read it), with `postgres --version` recorded next to it;
validated with `pg_restore --list` from the same major version. The volumes stay on SATA as
fallback until the migration is accepted. `node_modules` volume: recreate.

### Items the last migration missed — now?

| item | now |
|---|---|
| netconsole receiver | DECLARED (copies + units) |
| NUT client | DECLARED (+ `nut.target`, fixed 09-27) |
| zram | DECLARED |
| sleep masks, power button | DECLARED |
| timesyncd | DECLARED (base) |
| G213 udev rule | **superseded**: Irides' rule carries the identical line (§0 4b); nomarchy's copy retires |
| backups (code, claude, notes, pictures, legal) | DECLARED |
| meanpete | **NOT-DECLARED as automation** — README only; decided to declare |
| gnome-keyring / libsecret (audit §4 "misc services") | not installed; nothing found that needs it — retire |
| `btop.conf`, `.gitconfig`, `git/ignore` (flagged in notes as "real config, untracked") | still **NOT-DECLARED** |

## 5. The nomarchy gaps, in one list (each now addressed in §8/§10)

1. **Users and groups**: meanpete (uid 1001/gid 1003) and `media` (gid 1004, peter + meanpete) — nomarchy manages neither.
2. **User-level tools**: pipx `subliminal` (subget breaks without it), Claude Code, Codex CLI.
3. **Irides lighting**: `/etc/udev/rules.d/70-irides-lighting.rules` and the `irides-lighting.toml` link (caesar-only, RGB).
4. **Untracked real config**: `.gitconfig`, `.config/git/ignore`, `btop.conf`, `herdr/config.toml`, `bat/config`, `ai-usagebar/config.toml` (§8 D). `lazygit/config.yml` and `gh/config.yml` turned out to be generated — not declared.
5. **Required existence of private files**, which nothing checks: the five SSH keys, `authorized_keys`, `config.local`, `~/.gnupg` key, `subliminal.toml`, `gh/hosts.yml`, Claude/Codex logins, Nord credentials (not kept, §0 4d). `/etc/nut/upsmon.conf` is the one already declared.
6. **caesar's address** (`192.168.1.200` by DHCP reservation) — required by netconsole, ufw, NAS, ssh; declare as an expectation and verify.
7. `pacman.conf` (`Color`, `ILoveCandy`) and the mirrorlist.
8. Doc debt: meanpete "temporary" wording in `CLAUDE.md` and his README.

## 6. Open decisions for Pete — resolved in §0

1. **Revline dev database** — authoritative (dump/copy it) or re-seedable (let it go)?
2. **Firefox** — move the profile (continuity: cookies, sessions, add-on state) or re-sign-in to Sync?
3. **`sda3` "FreeSpace" (1.6 T)** — what is on it, and does new caesar mount it?
4. **Still wanted?** Nord VPN (half-configured), OpenDeck/Stream Deck, `keyboard-rgb`, Codex CLI, `browse_alias.pre-repo`, `.stfolder`, `Archive/omarchy-rescue` (leave on SATA?).
5. **Obsidian** — where does the vault live (the config names it)?
6. **`.bash_history`** — carry or start fresh?
7. **Irides lighting** — caesar-only declared state now, or with the Irides session later?

## 7. Unreadable without root — one command for Pete

```bash
sudo bash -c 'ls -la /home/meanpete /home/meanpete/* 2>&1; du -sh /home/meanpete; ls -la /etc/sudoers.d /etc/NetworkManager/system-connections; ls /var/spool/cron 2>&1; loginctl show-user meanpete 2>&1 | head -3; ls /var/lib/systemd/linger; pacman -Qii nut sudo filesystem shadow audit 2>/dev/null | grep -E "\[(modified|unreadable)\]"; blkid /dev/sda3; ls /home/meanpete/.config/systemd/user 2>&1'
```

It lists meanpete's home (names only), sudoers fragments and NM profile names, crontabs,
linger, which of the root-only package configs are modified, and what `sda3` carries.

---

## 8. Nomarchy declarations — implemented 2026-09-28, each tested in the VM rehearsal

Each is the declaration a §0 decision or §5 gap implies. Where the mechanism is new it says so.
Two things the implementation found are recorded in the rows: the AUR `claude-code` package
itself disables Claude's updater (its `/usr/bin/claude` wrapper exports `DISABLE_UPDATES=1`),
and `bat/config` is generated by Noctalia, not authored. Pete added one more on the way:
**`[multilib]`** is enabled by the base stage (G), for Steam later.

| # | what | how (proposed) | verified by `status` as |
|---|---|---|---|
| A | **accounts** — `media` gid 1004 (peter, meanpete); `meanpete` uid 1001 / gid 1003, `/home/meanpete`, `/bin/bash`, groups `media` | **new manifest** `hosts/<host>/bootstrap/accounts` (`group NAME GID`, `user NAME UID GID HOME SHELL GROUPS`, `member GROUP USER`), applied by `install host` with `groupadd -g` / `useradd -u -g`. **Fail closed** on any collision: a name with a different id, or an id held by another name, is a conflict to resolve by hand — never renumbered, never chowned. His password: a root step (it cannot be probed without root). | `getent` matches exactly |
| A2 | meanpete's `Scripts/`, `.bashrc`, `.bash_profile` | already in `hosts/caesar/meanpete/`; installed by `install host` as copies **owned by him** (the copies format gains an optional `owner:group` column). No sudo grant, no `/usr/local/bin/plex-*` (audit §11's privesc stays out). Doc fix: drop "temporary" from `CLAUDE.md` and his README. | copies diffed |
| B1 | `subliminal` (subget's dependency) | user-check: probe `command -v subliminal`; fix `pipx install subliminal==2.7.1` (pinned: subget depends on its behaviour). `pipx` itself is already declared (`python-pipx`, desktop stage). | present |
| B2 | Claude Code | **Decided:** the AUR package `claude-code` (a community-maintained PKGBUILD, not an official Arch repository package; 2.1.284 = the version running now) in the desktop stage. That packaged install is the **sole owner**: Claude's own self-updater is disabled, so updates come only through a rebuild of the package. Login (`~/.claude.json`) is private/migrated. | installed; `claude --version`; updater off |
| B3 | Codex | AUR `openai-codex-bin` in the desktop stage. `auth.json` private; history migrated. | installed |
| B4 | OpenDeck | AUR `opendeck-bin` for caesar; the Stream Deck udev rule is already declared. Profiles: a migration entry (§9). | installed |
| C | **Irides lighting** | the rule and the link are **Irides' files**, so nomarchy installs them *from the Irides checkout* rather than keeping duplicates: `copies` and `links` accept a `~/code/irides/…` source, allowed only inside a declared `builds` checkout (which `link` builds first). caesar: `~/code/irides/data/udev/70-irides-lighting.rules` → `/etc/udev/rules.d/` (host stage), `~/code/irides/data/noctalia/irides-lighting.toml` → `~/.config/noctalia/` (link). **Retire** `hosts/caesar/udev/70-logitech-g213.rules` (superseded, identical first line). | copies diffed; link verified |
| D | **authored config** | Tested against a symlinked copy, 2026-09-28. **Links:** `~/.gitconfig` (git writes `config --global` *through* the link: lock file renamed onto the resolved target) and `~/.config/git/ignore` (never written). **Seeds**, because the app rewrites its file: `btop/btop.conf` (whole-file rewrite whenever its header names another btop version — every upgrade; 15 authored lines became 286), `herdr/config.toml` (writes in place: onboarding, settings, `config reset-keys`), `ai-usagebar/config.toml` (saves by **renaming** a temp file over the path — a link would silently become a regular file). **Not declared:** `bat/config` (generated by Noctalia's bat template), `lazygit/config.yml` (generated theme state), `gh/config.yml` (gh's defaults). | links verified; seeds present |
| E | **required private state** (existence, never content) | user-checks, `manual`, each with a semantic probe: the five `~/.ssh/id_ed25519_*` keys (0600); `authorized_keys` holds rigel's key (fingerprint); `~/.ssh/config.local` (`ssh -G vps` resolves a real host); GPG secret key `8B52A5D2637434B3`; `~/.config/subliminal/subliminal.toml` (0600); `gh` logged in; Claude and Codex logins present. | each probe |
| F | **caesar = 192.168.1.200** | host check, `manual`: probe `ip -4 -o addr` shows `.200/24`; the manual step names the router's DHCP reservation. Never configures the address. | probe |
| G | `pacman.conf` + mirrors | base checks: `Color` and `ILoveCandy` set, and **`[multilib]` enabled** (Pete, for Steam; the fix syncs with a full `-Syu`, never a bare `-Sy`) — probes `grep`/`pacman-conf`, fixes targeted edits, not a whole-file copy. **Mirrorlist — decided: `reflector`** (US, HTTPS, ranked by speed) with a declared `/etc/xdg/reflector/reflector.conf` and `reflector.timer` weekly; the mirrorlist is generated state owned by that policy, never migrated. | check; timer enabled |
| H | `sda3` | the spec declares it `keep.untouched` (its UUID); `migrate/guard.sh` + `migrate/check-path` are the migration's path gate, built before the tool; the provisioner's never gate refuses any disk carrying it too. Otherwise nothing to install. The provisioner's never gate already refuses the whole SATA disk (rescue root + Windows ESP); the migration tool (§9 step 2) refuses any source or destination on `sda3`, identified by its filesystem UUID, not a device name. | — |

## 9. Migration and acceptance — the one sequence

A separate, human-run `migrate/` tool reading this manifest's MIGRATE entries — never part of
`nomarchy install`. There is **one** topology, and every step below is in execution order:

> **The source is the running SATA install. The destination is the XPG itself, provisioned
> first and mounted on SATA.** Everything is copied *before* new caesar ever boots; once it
> boots, SATA is never read again. It is the fallback, not a source.

Nothing here runs on new caesar before step 8, and nothing here mounts or reads `sda3`.

| # | where | step |
|---|---|---|
| 0 | SATA | **Prerequisites.** Install the provisioner's tools, which the SATA install lacks (§10): `gptfdisk dosfstools parted` (`arch-install-scripts` is present). The SATA checkout of nomarchy is at the **frozen release commit** the final RC passed. |
| 1 | SATA | **Provision** the XPG: `sudo provision/provision caesar --apply` — **without `--clone`**: nomarchy's own working tree arrives with `~/Projects` in step 3, whole, so a fresh clone would only be a collision. The provisioner creates `peter` (uid 1000 / gid 1000, the same numbers as SATA's), the nested docker subvolume, and closes the mapping when done. It does **not** boot it. |
| 2 | SATA | **Open the XPG as a destination**: `cryptsetup open` by the spec's LUKS UUID, mount `subvol=@home` and `subvol=@` under one root (e.g. `/mnt/caesar-new/{home,root}`). The tool refuses any source or destination on `sda3` (§8 H) and any destination that is not on the spec's btrfs UUID. |
| 3 | SATA, live | **Bulk pass**: `rsync -aHAX --numeric-ids` of the MIGRATE entries only (§1–§3) into the XPG's `/home/peter`. Include-list, never "all of `$HOME`": nomarchy-owned paths (links, seeds, build outputs, `~/.local/bin`) are never in it. Apps keep running; this pass only makes the final one short. |
| 4 | SATA | **Freeze.** Revline: `docker exec revline-db-1 sh -c 'pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB"' > revline.dump`, then `docker exec revline-db-1 postgres --version` recorded next to it (**16.13** today), then `docker compose stop`. Validate the dump with `pg_restore --list` from the **same major** (16) image. Close Thunderbird, Firefox, Obsidian, Claude, Codex; commit or leave repos alone — no editor holds a file open. |
| 5 | SATA, frozen | **Record the evidence** the acceptance tests compare against — *after* the freeze, so it describes exactly what the delta copies: SSH client and host key fingerprints, modes and owners (§11); per-repo branch, HEAD, stash list, dirty/untracked lists and unpushed counts; sha256 lists of `Legal`, `Notes`, `Pictures`, `Archive`; the Obsidian vault's note count; Claude project/session counts; the dump's sha256 and Postgres version. The evidence file goes into the XPG too (`~/cutover-evidence/`). |
| 6 | SATA, frozen | **Final delta**: the same rsync, now with `--delete` *inside* each migrated tree (never above one). Plus what only the freeze makes safe: `.bash_history`, the Thunderbird/Claude/Codex state, the dump file into `~/cutover-evidence/`, and the **SSH host keys** into the XPG's `/etc/ssh/` (`0600`/`0644`, root). openssh is in the pacstrap list, but sshd has never run there, so no host keys exist yet to be overwritten. |
| 7 | SATA | **Close and hand over**: unmount, `cryptsetup close`, `sudo provision/provision caesar --boot-next`, reboot. BootOrder still starts SATA: a failed first boot is one reset away from the untouched fallback. |
| 8 | new caesar | **Stages**: `nomarchy install base && install desktop && install host && install storage && nomarchy link`. The home already holds the migrated trees; `link` finds no conflicts because the migration never wrote a nomarchy-owned path, and `builds` finds `~/code/shelf` and `~/code/irides` already checked out (the migrated working trees) and builds them in place. `install host` creates `media` and `meanpete` with their exact ids; meanpete's home is created fresh and gets his declared files (§8 A, A2). |
| 9 | new caesar | **Revline restore**: bring the stack up (a fresh volume), `pg_restore` the dump into it; its database is then the authoritative copy. The SATA volumes stay as they were. |
| 10 | new caesar | **Acceptance**, semantic, against the step-5 evidence: GPG key listed → `pass` decrypts → SSH (§11: fingerprints equal; GitHub by its "successfully authenticated" reply; every shell host exit 0; rigel → caesar with no host-key warning) → every repo's recorded state matches → Legal/Notes/Pictures/Archive hash lists match → the Obsidian vault opens with the recorded note count → Thunderbird opens the expected profile → Claude history lists the recorded sessions → Revline's restored database answers → wallpapers exist and `irides apply NSX` succeeds → OpenDeck sees its profiles → Firefox Sync has brought bookmarks, logins and extensions → `nomarchy status` clean. |
| 11 | new caesar | Only after acceptance, and after new caesar has booted more than once: `sudo provision/provision caesar --finalize-nvram`. SATA stays installed and untouched as the fallback. |

**Rules**: the migration writes only paths an entry here names; never over anything nomarchy
owns or the clean install created unless an entry authorises that exact path; never reads or
writes `sda3`; host keys keep exact modes. SATA is read in steps 3–6 and never written.

## 10. Software census — everything installed vs everything declared (2026-09-28)

So there are no silent omissions: every installed-but-undeclared package or tool on the SATA
install, classified. **724** packages installed, **125** explicitly; nomarchy declares **118**.

**Explicit but undeclared (14):**

| package(s) | class | why |
|---|---|---|
| `qemu-base`, `qemu-ui-{egl-headless,opengl,gtk}`, `qemu-hw-display-virtio-{gpu,gpu-gl,gpu-pci,gpu-pci-gl,vga,vga-gl}`, `arch-install-scripts` (+ `edk2-ovmf`, present only as a dependency) | **declare** (caesar) | the rehearsal harness (`tests/vm/`) needs every one; its preflight names them. caesar is where rehearsals run. |
| `paru-debug`, `umbriel-git-debug`, `xdg-desktop-portal-umbriel-git-debug` | **intentionally omit** | makepkg byproducts; `common/stages/desktop/aur.txt` already says they are never installed on their own |

**Foreign (AUR) packages:** all declared except the three `-debug` above.

**Orphans (5): `compiler-rt`, `lld`, `meson`, `nasm`, `nlohmann-json`** — traced, not guessed:
`compiler-rt` and `lld` came with Arch's `rust` on 09-09 and stayed when rustup replaced it;
`nasm` is ai-usagebar's make-dependency; `meson` and `nlohmann-json` are **umbriel's** — and
those two are not leftovers at all: `umbriel-update` rebuilds umbriel *without* `makepkg -s`, so
removing them as orphans would break the next update. **Implemented (I):** the installer builds
AUR packages with `makepkg -sri` (with `-i`, `-r` removes only the make-dependencies it
installed); umbriel's build deps are **declared** in the desktop stage; and a declared package
found installed *as a dependency* is marked explicit (`pacman -D --asexplicit`), so "declared"
always means "not an orphan". Removing `compiler-rt`, `lld` and `nasm` here is optional housekeeping.

**Declared but not installed here:** `plymouth`, `snapper`, `snap-pac` — expected: this is the
rescue install, where `nomarchy install` is refused.

**Outside pacman:**

| source | found | class |
|---|---|---|
| pipx | `subliminal 2.7.1` | **declare** (B1) |
| native / standalone installers | `claude` (native, 2.1.284), `codex` (standalone, 0.156.0) | **declare** as AUR packages (B2, B3) |
| `cargo install`, `go install`, `/usr/local`, `/opt` | nothing | — |
| npm "globals" | `acorn`, `eslint`, `node-gyp`, `nopt`, `npm`, `semver` — npm's prefix is `/usr`: these are **pacman's** | generated/dependency |
| `~/.local/bin` (not links) | `shelf`, `irides`, `irides-gtk`, `irides-lighting` | declared builds |

**Commands nomarchy's own scripts call, whose package is only a dependency** — the same
silent-omission risk one level down:

| command | used by | package | class |
|---|---|---|---|
| `python3` | **`launch-or-focus`** (Mod+M/F/T/D/O), **`universal-clipboard`** (Super+C/V), `subget` | `python` — dependency only | **declare** (desktop) |
| `ffprobe` | `subget` | `ffmpeg` — a dependency of mpv | **declare** (caesar, with subget) |
| `sgdisk`, `mkfs.fat`, `partprobe` | `provision/provision` | `gptfdisk`, `dosfstools`, `parted` — **not installed on SATA at all** | **declare** (base: any host can provision another) — and a **pre-cutover prerequisite on the SATA install**, which runs the provisioner. The provisioner's dry run should report missing tools, not only `--apply`. |
| `pacstrap`, `arch-chroot` | provisioner, rehearsal | `arch-install-scripts` | **declare** (base; see above) |
| `cryptsetup`, `bootctl`, `udevadm`, `mkinitcpio`, `gpg`, `makepkg`, util-linux/coreutils/procps/iproute2/iputils/tar/zstd tools | many | dependencies of `base`/`linux`/`pacman` — always present | generated/dependency |
| `notify-send` | only named in a comment | — | nothing |

**Investigate:** none left.

## 11. SSH identity — preserved, and proven (decided 2026-09-28)

A disk replacement must not require re-authorising any existing SSH relationship: new caesar is
the same client and the same server.

**Preserved exactly (bytes, mode, owner):**

| side | files | mode / owner |
|---|---|---|
| client (peter) | `~/.ssh/id_ed25519_{github,homelab,waylab,vps,caesar_to_rigel}` + `.pub` | `0600` / `0644`, peter |
| client | `~/.ssh/authorized_keys` (rigel's access grant), `~/.ssh/known_hosts`, `~/.ssh/config.local` | `0600`, peter |
| client | `~/.ssh/` itself | `0700`, peter |
| server | `/etc/ssh/ssh_host_{ed25519,ecdsa,rsa}_key` + `.pub` | `0600` / `0644`, root |

**Recreated, not migrated:** `~/.ssh/config` (a nomarchy link), `sshd_config.d/10-nomarchy.conf`
(a nomarchy copy). **Discarded:** `~/.ssh/agent/` (dead glob leftover).

**Before cutover**, on SATA, record (fingerprints are not secrets): `ssh-keygen -lf` of every
client key and every host key, and the mode/owner of each file above.

**After**, on new caesar, all must hold:
1. every client and host key fingerprint equals its recorded value; modes and owners equal;
2. **caesar → remote**, all with `BatchMode=yes` and `StrictHostKeyChecking=yes` (no prompts):
   - **GitHub:** `ssh -T git@github.com` — it has no shell and **exits 1 even on success**, so
     the check is its reply naming the account (`successfully authenticated`), not the exit code;
   - **shell hosts, exit 0 required:** `ssh waylab true`, `ssh proxmox true`, each homelab
     alias, `ssh vps true`, `ssh rigel true`;
3. **rigel → caesar**: `ssh -o StrictHostKeyChecking=yes caesar true` succeeds with rigel's
   `known_hosts` untouched — the server identity survived;
4. meanpete's password login still works (`Match User meanpete`).

