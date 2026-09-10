# What Omarchy actually provides on caesar

Audit of Omarchy 4.0.3-1 ("quattro"), `/usr/share/omarchy` (symlinked from
`~/.local/share/omarchy`).

## 1. The CLI surface — 441 commands

`/usr/share/omarchy/bin` contains 441 `omarchy-*` commands. Full list in
`raw/omarchy-commands.txt`. By functional group:

| Group | Count (approx) | Examples |
|---|---|---|
| `install-*` / `remove-*` | ~70 | app, browser, editor, gaming, dev-env, services, fonts |
| `hw-*` | ~25 | nvidia, intel, framework16, laptop, touchpad, fingerprint, clamshell |
| `theme-*` | ~30 | set, list, install, bg-set, bg-switcher, set-vscode, set-obsidian |
| `update-*` | ~25 | system-pkgs, aur-pkgs, firmware, keyring, analyze-logs, guard |
| `hyprland-*` | ~25 | monitor-*, window-*, workspace-layout-toggle, focus-app |
| `launch-*` | ~25 | terminal, editor, browser, webapp, or-focus, tui, screensaver |
| `menu-*` | ~14 | clipboard, emoji, file, keybindings, share, timezone |
| `capture-*` | ~9 | screenshot, region, screenrecording, text (OCR), qr, webcam |
| `audio-*` / `network-*` / `bluetooth-*` | ~20 | device switching, volume, QR, speedtest, status |
| `plugin-*` | ~10 | add, clone, enable, disable, catalog, validate |
| `toggle-*` | ~12 | bar, idle, nightlight, screensaver, touchpad, hybrid-gpu |
| everything else | ~180 | agents, reminders, snapshot, voxtype, webapp, provision, dev-* |

This is the part with **no replacement**. Umbriel is a compositor and Noctalia is a
shell; neither manages your distro.

## 2. The desktop shell — `omarchy-shell` (Quickshell/QML)

`/usr/share/omarchy/shell` — a QML shell with a plugin architecture. Plugins present:

`agents` · `background` · `bar` · `clipboard` · `dev-gallery` · `emojis` ·
`image-picker` · `lock` · `menu` · `notifications` · `osd` · `panels` · `polkit` ·
`reminders` · `services`

Your bar layout (`~/.config/omarchy/shell.json`):

- **left:** menu, workspaces
- **centre:** indicators, clock (`dddd HH:mm`), keyboard-layout, weather, system-update
- **right:** tray, agents, bluetooth, network, audio, monitor, power
- `position: top`, `transparent: true`
- **idle:** screensaver at 1200 s, lock at 1800 s (stock is 150/300 — you 8×'d it)
- **plugins:** `peter.lock`, `peter.emojis` (clones), with `omarchy.lock` and
  `omarchy.emojis` in `disabledPlugins`

## 3. The menu — 333 entries

`/usr/share/omarchy/default/omarchy/omarchy-menu.jsonc`, bound to `SUPER+SPACE`:

| Section | Entries |
|---|---|
| install | 91 |
| setup | 66 |
| remove | 60 |
| trigger | 47 |
| update | 28 |
| style | 21 |
| learn | 10 |
| system | 8 |

Your extension file `~/.config/omarchy/extensions/omarchy-menu.jsonc` contains
**comments only** — nothing custom to port.

## 4. Keybindings — ~175 defaults + your overrides

Defaults live in `/usr/share/omarchy/default/hypr/bindings/` across six files
(`applications`, `clipboard`, `media`, `tiling`, `utilities`, `voxtype`). Full
key→description list in `raw/default-keybindings.txt`.

Notable classes: window focus/swap/resize (arrow + `code:20/21` pairs at three
granularities), grouping (`SUPER+G`, `SUPER+ALT+arrows`, group cycling), scratchpad,
monitor scaling, workspace-to-monitor moves, universal copy/cut/paste
(`SUPER+C/X/V`), capture menu, colour picker, OCR, zoom, dictation (`F9`,
`SUPER+CTRL+X`), reminders, media keys with `locked`+`repeating` flags.

## 5. Theming engine

- **22 stock themes** in `/usr/share/omarchy/themes` (current: **Tokyo Night**).
  Each is a `colors.toml` + `icons.theme` + `preview*.png` + `unlock.png`, with
  optional `neovim.lua` (15), `vscode.json` (16), `hyprland.lua` (5),
  `chromium.theme` (5), `btop.theme` (4).
- **27 user-installed themes** in `~/.config/omarchy/themes` (**776 MB**) — third-party
  themes you collected. `omarchy-theme-list` reports 49 themes total. See
  `03-carry-over.md`: most of these are stale Omarchy 3 format.
- **20 templates** in `default/themed/*.tpl` rendered per theme: alacritty, btop,
  chromium, claude, foot, ghostty, gum, helix, hermes, hyprland, kitty, keyboard RGB,
  neovim, obsidian, pi, shell, t3code, vscode, share-picker CSS.
- **Hook system**: `omarchy-hook` runs `~/.config/omarchy/hooks/<event>.d/*`.
  Events seen: `theme-set`, `post-update`, `post-boot`, `battery-low`, `font-set`,
  `pre-refresh-pacman`.

## 6. Session / boot / system layer

| Piece | Detail |
|---|---|
| Session | `uwsm start -g -1 -e -D Hyprland hyprland.desktop` |
| Login | SDDM, theme `omarchy`, autologin `peter` → `omarchy.desktop` |
| Boot splash | Plymouth, theme `omarchy` |
| Bootloader | Limine + `limine-mkinitcpio-hook` + `limine-snapper-sync` |
| Snapshots | snapper on btrfs, `snapper-cleanup.timer`, `btrfs-scrub-home.timer` |
| pacman hooks | `00-omarchy-update-guard`, `10/90-omarchy-hyprland-reload-pause/resume`, `omarchy-chromium-desktopfix` |
| `/etc` overrides | `nsswitch.conf`, `os-release`, faillock, plymouthd, cups ×2, `dot.bashrc` |
| zram | `zram-generator.conf.d/90-omarchy.conf` |
| systemd user units | `bt-agent`, `omarchy-crash-watch`, `omarchy-fcitx5`, `omarchy-migrate-notify`, `omarchy-recover-internal-monitor`, `omarchy-sleep-lock` (all 6 enabled) |
| sleep hooks | `force-igpu`, `keyboard-backlight`, `unmount-fuse` |

## 7. Shell environment

`~/.bashrc` sources `$OMARCHY_PATH/default/bash/rc`, which pulls in
`aliases`, `completions`, `env-bootstrap`, `envs`, `fns`, `functions`, `init`,
`inputrc`, `shell`. That chain sets up **mise, starship, zoxide (`cd` → `zd`), fzf
keybindings, eza aliases, `ff`/`eff`/`sff` fzf helpers, and `open`**.

It also exports `EDITOR="omarchy-launch-editor --inline"` and
`TERMINAL=xdg-terminal-exec` via `uwsm/default`.

**This is pure bash and fully portable** — copy it out and keep it.

## 8. Capture toolchain (all compositor-agnostic)

| Command | Uses |
|---|---|
| `capture-screenshot` | `grim`, `slurp`, `wl-copy` |
| `capture-region` | `hyprpicker` (freeze), `slurp` |
| `capture-screenrecording` | `gpu-screen-recorder`, `ffmpeg`, `slurp` |
| `capture-text` (OCR) | `grim`, `slurp`, `tesseract`, `wl-copy` |
| `capture-qr` | `grim`, `slurp`, `zbarimg`, `wl-copy` |

Only `hyprpicker` (used as a screen-freeze) is Hyprland-tied. Everything else survives
the move untouched.

## 9. Fonts

`JetBrainsMono Nerd`, `CaskaydiaMono Nerd`, `iA Writer` (Duo/Duospace/Mono/Quattro),
`Symbols Nerd Font`, plus `omarchy.ttf` (the shell's own icon font — not needed after
the move).
