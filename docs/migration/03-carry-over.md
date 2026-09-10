# Your own config — what to salvage

Everything below is **yours**, not Omarchy's. Copy it off caesar before anything gets
wiped. Ordered by how painful it would be to lose.

---

## Tier 1 — irreplaceable, no upstream copy exists

### `~/.config/omarchy/hooks/theme-set.d/` — 30 hand-maintained hooks

Your largest single investment. These were ported forward from Omarchy 3 and are
maintained by you, not shipped by the package:

```
00-fish  00-fzf  10-discord  10-gtk  10-qt6ct  10-spotify  10-superfile  10-tmux
10-vicinae  15-typora  20-nwg-dock-hyprland  20-zed  25-swaync  26-foot-live-colors
30-cursor  30-vscode  30-windsurf  35-obsidian-terminal  40-cava  40-firefox
40-qutebrowser  40-steam  40-zen  50-cliamp  50-heroic  99-restart-notify
```

plus `lib/omarchy3-compat.sh` (provides `success`/`skipped`/`require_restart`/
`change_shade` and the `normal_*`/`bright_*`/`primary_*` colour variables) and
`post-update.d/setup-agent.hook`.

**These are plain bash and they are the single most portable thing you own.** Each one
reads colour variables from the environment and writes an app config. To keep the
entire pipeline on Noctalia you only need to reimplement *one* thing: a runner that
exports `normal_red`, `primary_background`, etc. from Noctalia's active palette and
executes the `.d` directory. That is maybe 40 lines of bash. Do that and 30 apps stay
themed for free.

`theme-set.omarchy3-runner.disabled` in the same directory is the old runner — read it,
it's most of the reference implementation for the above.

### `~/.config/omarchy/themes/` — 27 third-party themes, 776 MB

`omarchy-theme-list` shows 49 themes: 22 stock + these 27 you installed yourself.

**Only 7 are in the current (Omarchy 4) format** — i.e. have a `colors.toml`:

`base16-tarot` · `beta` · `bmw-gt3-omarchy` · `deep-solar` · `lilly` · `moon-orbit` ·
`ethereal.OLD.2026-01-20`

**The other 20 are Omarchy 3 format and are effectively already dead.** They ship
`waybar.css`, `mako.ini`, `walker.css`, `swayosd.css`, `wofi.css`, `hyprlock.conf` —
targeting components that **no longer exist on this machine** (waybar, mako, swayosd
and hyprlock were all removed in the quattro upgrade; their configs are sitting in
`~/.config/*.omarchy-upgrade-to-quattro.*.bak` directories):

`aether` `aetheria` `all-hallows-eve` `amberbyte` `arc-blueberry` `archriot`
`archwave` `ash` `aura` `batou` `bauhaus` `blade-runner` `dreamwave` `emberstone`
`fireside` `futurism` `grudark` `lowlight` `mars` `monokai`

**What to actually carry:** the `colors.toml` from the 7 current ones, plus — if you
like any of the 20 — their palettes are still recoverable from `alacritty.toml` /
`kitty.conf` / `btop.theme`. Omarchy even has `omarchy-theme-colors-from-alacritty`
for exactly this; run it before you lose access to the tool. Everything else in those
directories (waybar/mako/walker/wofi CSS, hyprlock configs, preview PNGs) is landfill.

Most of the 776 MB is wallpapers. Pull the ones you want into a plain
`~/Pictures/Wallpapers` and let Noctalia's wallpaper picker take it from there — its
palette generation means you may not need per-theme colour files at all for the ones
you only kept for the wallpaper.

Also present: `~/.config/omarchy/theme-backups/colors.toml.bak.*` (3 files, 2026-08-15)
and `~/.config/omarchy/shell.json.bak.20260814-224105`.

### `~/.config/omarchy/plugins/peter.lock` and `peter.emojis`

QML clones of the stock plugins, diverging in `LockView.qml` / `Service.qml` /
`Emojis.qml` / `manifest.json`, and `peter.emojis` adds an `emoji-insert` helper.

**These will not port** — Noctalia 5.x is native C++, not Quickshell. Salvage them for
*intent* (what you changed and why), then rebuild or drop. Diff them against
`/usr/share/omarchy/shell/plugins/{lock,emojis}` while you still can — that diff is the
spec for whatever replaces them.

### `~/.config/hypr/input.lua` — the Stream Deck fix

```lua
hl.device({ name = "elgato-stream-deck", enabled = false })
```

Read the comment above it before you rebuild anything. The Elgato Stream Deck
(`0fd9:006d`) is exposed by `hid-generic` as an evdev keyboard emitting continuous
`KEY_UNKNOWN`, which (a) prevents idle from ever settling and (b) made held-`SUPER`
fire workspace switches in a burst. **This is a kernel/evdev problem, not a Hyprland
problem — it will follow you to Umbriel.** Confirm Umbriel can disable a device by name
before you migrate; if it can't, you need a udev rule instead.

### `~/.config/hypr/shaders/` — 138 GLSL screen shaders

Hyprland-specific (`decoration:screen_shader`). No Umbriel equivalent is documented.
Keep the directory — they're generic fragment shaders and could be reused elsewhere —
but plan on losing the feature.

---

## Tier 2 — semantics to re-express, not files to copy

### `~/.config/hypr/bindings.lua` — ~20 personal bindings

Your deliberate departure from quattro: **launchers back on `SUPER+<key>`**, window
controls displaced to `SUPER+SHIFT+<key>`. Every displacement is documented with what
it cost. The mapping to preserve:

| Key | Action |
|---|---|
| `SUPER+F` | File manager (shelf) |
| `SUPER+SHIFT+F` | Full screen (true fullscreen, the one Steam wants) |
| `SUPER+B` / `SUPER+SHIFT+B` | Firefox / Firefox private |
| `SUPER+M` | `spotify-limited` |
| `SUPER+N` | Editor |
| `SUPER+T` | btop |
| `SUPER+D` | lazydocker |
| `SUPER+G` | Signal |
| `SUPER+O` | Obsidian |
| `SUPER+SLASH` | 1Password |
| `SUPER+SHIFT+V` | Clipboard history |
| `SUPER+CTRL+E` | Emojis |
| `SUPER+L` / `SUPER+SHIFT+L` | Lock / toggle idle lock |
| `SUPER+A` / `SUPER+SHIFT+A` | ChatGPT / Grok (webapps) |
| `SUPER+E` | Hey mail (webapp) |
| `SUPER+Y` | YouTube (webapp) |
| `SUPER+SHIFT+G` | WhatsApp (webapp) |
| `SUPER+ALT+G` | Google Messages (webapp) |

Three of these lean on Omarchy plumbing you'd have to replace:
`{ omarchy = "editor" }`, `{ omarchy = "1password" }`, `{ webapp = ... }` (a
`chromium --app` wrapper), and `{ launch =, focus = }` (launch-or-focus by window
class). **Launch-or-focus is the one worth rebuilding first** — you use it on five keys.

### `~/.config/hypr/looknfeel.lua` — your visual identity

- gaps 3/5, rounding 5
- shadow: range 15, render_power 3, `rgba(0,0,0,0.66)`
- blur: size 8, passes 2
- **all dimming disabled** (`dim_inactive/modal/around/special` = off) — your "Atlas override"
- opacity: `0.75 0.55` on general windows, `1.0 0.90` on browsers and Godot
- `vrr = 2` (fullscreen-only VRR — avoids FreeSync flicker on DP-2)
- `cursor.hide_on_key_press = false`, `inactive_timeout = 0`
- shelf floats centred at 1100×660

The opacity setup is subtle and you documented why: Omarchy's `default-opacity` **tag**
rule is what actually reaches windows, and browsers opt out of it, so a global setting
hit exactly the wrong windows. Umbriel window rules won't have that tag concept — you
get to express this directly, which is simpler.

### `~/.config/hypr/monitors.lua`

```
HDMI-A-1  1920x1080@60   at  320x0      scale 1     (top, BenQ Zowie)
DP-1      3840x2160@160  at  0x1080     scale 1.5   (bottom centre, Acer VG270K V4)
DP-2      1920x1080@60   at -1920x1080  scale 1     (bottom left)
```
Plus `GDK_SCALE=1` and a catch-all `output=""` rule first. See the fractional-scaling
warning in `02-gap-analysis.md`.

### `~/.config/omarchy/shell.json` — bar layout + idle timings

Widget order is in `01-what-omarchy-provides.md`. The two settings that are *choices*,
not defaults: `transparent: true`, and **idle screensaver 1200 s / lock 1800 s**
(stock is 150/300).

---

## Tier 3 — copy verbatim, works anywhere

| What | Where | Note |
|---|---|---|
| Bash aliases/functions | `~/.bashrc` | ~50 SSH aliases across the homelab, `refreshrl`, `pete-kitty-update`, `hw`, `suben`/`subvi`/`subs`, backup-status login banner, PATH exports |
| Omarchy's bash chain | `/usr/share/omarchy/default/bash/*` | eza/zoxide/fzf/starship/mise setup — **copy this out, it disappears with the package** |
| Starship prompt | `~/.config/starship.toml` | |
| Webapp launchers | `~/.local/share/applications/*.desktop` | ChatGPT, Figma, GitHub, Google {Contacts,Maps,Messages,Photos}, Proxmox, Twitch, WhatsApp, YouTube, Zoom, Discord |
| Terminal configs | `~/.config/{kitty,alacritty,foot,ghostty}` | note: `kitty` is **your own fork** at `~/.local/opt/kitty-pete` (mouse-selection-from-gutter patch) |
| Branding | `~/.config/omarchy/branding/{about,screensaver}.txt` | |
| Theme colours | `/usr/share/omarchy/themes/tokyo-night/colors.toml` | grab any themes you like — they're just palettes |
| Your GTK scripts | `~/.config/omarchy/bin/omarchy-{gen-gtk-css,gtk-sync}` | note `autostart.lua` says the old call site referenced a *non-existent* `omarchy-gtk-css` and has been failing silently since Omarchy 3 |
| Personal timers | `backup-daily.timer`, `backup-legal-to-nas.timer`, `subget-sync.timer` | user units, nothing to do with Omarchy |
| Local bin | `~/.local/bin/` | `subget`, `sshmenu`, `astroterm-saver`, `merge-show-dirs`, `spotify-limited`, `waybar-weather.py`, `hermes`, `muse` |

## Nothing to port

- `~/.config/omarchy/extensions/omarchy-menu.jsonc` — comments only
- `~/.config/omarchy/hooks/*.sample` — shipped samples, untouched
- `*.omarchy-upgrade-to-quattro.*.bak` and `*.bak.YYYYMMDD-*` files — old backups from
  the Omarchy 3→4 upgrade (mako, swayosd, walker, waybar configs). Dead weight.
