# waylab — the testbed, audited

Read-only audit over `ssh waylab`, 2026-09-09. Nothing changed.

## Hardware and base

| | |
|---|---|
| Host | `waylab`, Dell ex-enterprise |
| CPU / RAM | Intel i7-8700T @ 2.40 GHz, 16 GB |
| GPU | **Intel UHD 630 (CoffeeLake-S GT2)** — no discrete GPU |
| Kernel | 7.2.4-arch1-2 (caesar is on 7.2.3 — testbed is *ahead*) |
| Distro | Arch Linux, repos core/extra only |
| Filesystem | **ext4** on `/` and `/home` (nvme0n1p3/p4) |
| Bootloader | **rEFInd** |
| Packages | **32 explicit**, 2 foreign |
| Uptime at audit | 10 h, load 1.07, firefox + umbriel ~5 % CPU each |

## The stack, as installed

```
noctalia                       5.0.1-1     ← extra (OFFICIAL Arch repo)
umbriel-git                    .r872.c4d4d6e-1
xdg-desktop-portal-umbriel-git 0.1.0.r36.d7a1bc3-1
wlroots0.20                    0.20.2-1
```

**Correction to my earlier note: Noctalia is in Arch `[extra]`, not the AUR.** It is an
officially packaged Arch package. That's a materially better maturity signal than the
AUR vote counts suggested. Only Umbriel and its portal are AUR-built.

Session: `/usr/share/wayland-sessions/umbriel.desktop` exists, `graphical.target` is
default, but **no display manager is installed** — you're starting from a TTY.
`seatd`, `polkit`, full `pipewire`/`wireplumber` are present.

## Your Umbriel config

`~/.config/umbriel/config.toml` — 794 lines, the shipped example with **six edits**:

| Change | Value |
|---|---|
| Output added | `HDMI-A-1` = Acer VG270K V4, **2560x1440@59.951, scale 1.0** |
| Keyboard | `options = "caps:swapescape"` |
| Repeat | rate 50, delay 200 (caesar: 40 / 250) |
| Mouse | `sensitivity = 0.5` |
| Focus | `follows_mouse = true` |
| Close window | `Mod+Q` → **`Mod+W`** (your Omarchy muscle memory) |
| Layout | `scrolling` → **`dwindle`** |

**You are not testing the hard case.** That Acer is the same panel that runs
**3840x2160@160 at scale 1.5** on caesar. Here it's 1440p at 1×, single monitor, on
Intel graphics. Fractional scaling, mixed-DPI, 160 Hz and NVIDIA are all still
unexercised. A green testbed proves very little about caesar.

## Your Noctalia config

`~/.config/noctalia` is **empty**. Live settings are at
`~/.local/state/noctalia/settings.toml` — 95 lines, near-stock: bar, control-center
shortcuts, location, lockscreen widgets (with **per-output** widget placement,
`lockscreen-login-box@HDMI-A-1`), theme, wallpaper, weather, and widgets
(caffeine, clock, date, spacers, weather).

## The two command surfaces

**`noctalia msg` — ~100 IPC commands.** This is the real replacement for the desktop
half of Omarchy's 441: bar show/hide/layer, bluetooth, brightness (incl. sysfs device
listing), caffeine, clipboard, colour-scheme, dock, desktop-widgets, dpms, EasyEffects
profiles, `greeter-sync`, keyboard backlight + layout cycling, media, mic, network/wifi,
**nightlight**, notifications + DND, OSD, panels, plugins, power profiles,
**screenshot-fullscreen / screenshot-region**, session, settings, taskbar,
`templates-apply`, theme-mode, volume, wallpaper (get/set/next/prev/random per output),
window-switcher, workspace alerts and switching.

**`umbriel msg` — 106 actions** in 8 groups: Apps, Focus, Move & size, Windows,
Scratchpad, Workspaces, Overview, System. Plus `umbriel windows|workspaces|outputs|
layers|submap|color|tearing|keyboard-layouts|subscribe|validate`. `subscribe` streams
JSON-line events (theme, overview, keyboard_layout, windows, workspaces, submap) —
that's your `hyprctl`-scripting replacement, and it's better structured.

## Two ecosystems I did not expect to find

**64 community theming templates** already cached in
`~/.local/state/noctalia/community-templates/`:

> antigravity · bat · blender · brave · brave-origin · claude-code · codex · darktable ·
> discord · driftwm · fastfetch · fcitx5 · feishin · fuzzel · fzf · gimp · glow ·
> halloy · **herdr** · heroiclauncher · hyprtoolkit · inkscape · jay · lazygit ·
> libreoffice · mailspring · micro · musescore · nchat · neovim · obs · obsidian ·
> opencode · papirus-icons · pear-desktop · pi-agent · prismlauncher · pywalfox ·
> qutebrowser · rio · rofi · senpai · siyuan · snappy-switcher · **spicetify** · steam ·
> supersonic · tauon · telegram · tmux · ungoogled-chromium · velo · vicinae · vscode ·
> walker · whitesur-icons · yazi · ytm-player · zathura · zed · zellij · zen-browser

Format is `input_path` → `output_path_dynamic` → `post_hook`, driven by
`noctalia msg templates-apply`. **This is structurally the same idea as your
`theme-set.d` hooks, and it already ships 12 of the ~26 apps you hand-maintain**:
fzf, discord, spicetify (spotify), tmux, vicinae, zed, obsidian, qutebrowser, steam,
zen-browser, heroic, vscode.

**176 plugins** available — 13 official, 163 community, all currently disabled.
Full list in `raw/waylab-noctalia-plugins.txt`. These close most of the gaps:

| Gap | Plugin |
|---|---|
| OCR (`omarchy-capture-text`) | `fel/ocr` |
| QR (`omarchy-capture-qr`) | `yocraft/qrcode` |
| Screen recording | `noctalia/screen_recorder` *(official)*, `h-jangra/region-recorder` |
| Colour picker (`hyprpicker`) | `oldirtty/color_picker` |
| Emoji picker | `liamwh/emoji-picker`, plus `noctalia/kaomoji` |
| Reminders | `nightwatch75/todo`, `noctalia/timer` |
| Agents widget | `lowcache/claude-companion`, `jrohland/claudecode` |
| **Umbriel integration** | `noctalia/umbriel-companion` *(official)* — enable this first |

Others that fit your setup specifically: `cleboost/ssh-launcher` (≈ your `sshmenu`),
`mellotanica/launcher-pass` (you have `pass`), `nightwatch75/dns-switcher`,
`8bury/mini-docker`, `pozzoo/hassio`, `yocraft/web-launcher` and
`yocraft/desktop-launcher` (≈ webapps), `noctalia/notes`, `noctalia/bitwarden`,
`noctalia/wallhaven`, `noctalia/translator`, `nightwatch75/file-search`.

## What's missing on waylab right now

```
xwayland-satellite   ← NO X11 APPS AT ALL until this is installed
wl-clipboard grim slurp tesseract zbar        ← capture toolchain
brightnessctl pamixer xdg-terminal-exec
starship mise zoxide fzf eza bat ripgrep fd tmux btop   ← your whole shell UX
ttf-jetbrains-mono-nerd (only Adwaita + Noto present)
snapper / btrfs-progs                          ← not applicable, ext4
```

`xwayland-satellite` is the significant one — Umbriel has no built-in XWayland, so
Steam, older Electron apps and anything X11 simply won't start until it's on `PATH`.

---

# The open questions, now answered

| # | Question | Answer |
|---|---|---|
| 1 | Per-device disable by name (Stream Deck) | **❌ NO.** See below — this is the one real blocker |
| 2 | Night light | ✅ `nightlight-enable/disable/toggle/force-toggle` |
| 3 | Colour picker | ✅ community plugin `oldirtty/color_picker` |
| 4 | Screen-freeze for capture | ✅ moot — Noctalia has native `screenshot-region` and `screenshot-fullscreen` |
| 5 | Emoji picker | ✅ `noctalia msg panel-open launcher /emo`. **Insert-at-cursor still unverified** |
| 6 | Fractional scaling, mixed-DPI, 160 Hz | ⚠️ **still untested** — waylab is single-monitor 1440p at 1× |
| 7 | Per-window opacity | ✅ and *better* than Hyprland — see below |
| 8 | Per-window VRR | ✅ `vrr = "always"` as a window rule, replacing your global `vrr = 2` |
| 9 | Window grouping | ❌ confirmed absent |
| 10 | Screen shaders | ❌ no Hyprland-style screen shader. (Custom *window* shaders are referenced in `[appearance.shadow]` — different feature, worth a look) |
| 11 | OCR / QR / screen recording | ✅ all three have plugins — `fel/ocr`, `yocraft/qrcode`, `noctalia/screen_recorder` |

## 1. The Stream Deck problem is real

`[[input.device]]` accepts only: `layout`, `variant`, `options`, `repeat_rate`,
`repeat_delay`, `tap`, `disable_while_typing`, `click_method`, `natural_scroll`,
`scroll_button`, `scroll_button_lock`, `accel_profile`, `sensitivity`.

**There is no `enabled = false`.** Confirmed three ways: the shipped example config, the
106-action `umbriel msg` list (no input/device action), and the docs at
`docs.noctalia.dev/umbriel/input/` — which state that `enabled` exists *only* under
`[input.tablet]`.

So your `hl.device({ name = "elgato-stream-deck", enabled = false })` has **no direct
equivalent**. Remember what that fix was actually preventing: idle never settling, and
held-`SUPER` firing workspace switches in bursts. Both would return.

**The fix is a udev rule** — mask the device from libinput rather than from the
compositor:

```
# /etc/udev/rules.d/99-streamdeck-no-keyboard.rules
SUBSYSTEM=="input", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", ENV{LIBINPUT_IGNORE_DEVICE}="1"
```

This is arguably the *correct* layer for it anyway — it was never really a compositor
concern — and it keeps working regardless of which compositor you land on. Stream Deck
software uses hidraw, so nothing is lost. **Test this on waylab before you migrate
caesar.** It's the single highest-risk item in the move.

## 7. Your opacity setup gets simpler

You wrote a long comment in `looknfeel.lua` about fighting Omarchy's `default-opacity`
tag — the tag rule reached the wrong windows, browsers opted out, and the removal didn't
survive `hyprctl reload`. None of that exists here. Umbriel expresses it directly:

```toml
[[window_rule]]
match.is_focused = false
opacity = 0.85

[[window_rule]]
match.is_focused = true
opacity = 1.0
```

State-aware rules update live as focus/floating/pinned/scratchpad state changes.
Your per-class browser and Godot exceptions become ordinary `match.app_id` rules on top.
Rule matching supports `app_id`, `title`, XDG tag, content type, `is_focused`,
`is_floating`, `is_scratchpad` — and rules can set `blur`, `blur_popups`,
`blur_ignore_alpha`, `opacity`, `vrr`, `tearing`, `hdr`, `default_floating`,
`default_size`, `default_position` (with anchor), `default_pinned`, `default_focused`,
`default_output`, `default_workspace`, `default_scrolling_column`.

## Keybinding reality check

Umbriel ships 52 active binds vs Omarchy's ~175. Two direct collisions with your
muscle memory, both on keys you deliberately reclaimed in `bindings.lua`:

| Key | Omarchy (yours) | Umbriel default |
|---|---|---|
| `Mod+Space` | Omarchy menu | `scratchpad-toggle` |
| `Mod+T` | Activity (btop) | `window-toggle-floating` |
| `Mod+O` | Obsidian | `overview-toggle` |
| `Mod+M` | Music | `window-toggle-maximize-to-edges` |
| `Mod+F` | File manager | `window-toggle-fullscreen` |
| `Mod+P` | — | `window-toggle-pinned` |
| `Mod+L` | Lock screen | `window-focus-right` (vim nav) |
| `Mod+Tab` | Next workspace | `scratchpad-focus-next` |

You've already made the one change that matters most (`Mod+Q` → `Mod+W` for close).
The launcher is on bare `Mod`, which is a nicer default than `Mod+Space` — but it means
your app launchers need somewhere to live all over again. Worth doing this deliberately
once rather than porting `bindings.lua` line by line.
