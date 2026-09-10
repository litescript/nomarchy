# Omarchy → Noctalia + Umbriel

**Summary report · 9 Sep 2026**
Audited caesar (Omarchy 4.0.3) and waylab (bare Arch testbed).
Read-only. Nothing was changed on either box.

---

## Verdict

The move is viable. The desktop half is in better shape than
expected. The distro half is where the work is.

Noctalia 5.0.1 is packaged in **Arch `[extra]`** — official,
not AUR. Umbriel is the young half: AUR git build, version
0.1.0, and its README says config keys and keybinds may
change between releases.

**One genuine blocker found.** Everything else is work,
not risk. See §3.

---

## 1. You are replacing two things

**Hyprland** — 12 `hypr*` packages. Clean swap.
Umbriel covers dwindle, per-output workspaces, blur,
shadows, rounding, animations, named scratchpads, window
rules, overview, XKB. Cost is a Lua → TOML rewrite.

**Omarchy** — much bigger than the desktop:

- 441 `omarchy-*` commands
- a 333-entry system menu
- 22 themes + a 20-template engine
- its own pacman repo
- boot/snapshot integration, hardware profiles

Noctalia replaces the *shell*. Nothing replaces the
*distro management*. After the move that's pacman, paru
and your own scripts.

Rough sizes on the new side:

- `noctalia msg` — ~100 IPC commands
- `umbriel msg` — 106 actions
- Umbriel ships 52 default keybinds vs Omarchy's ~175

The compositor genuinely does less. The gap moves to
Noctalia or to you.

---

## 2. Two good surprises

**Noctalia has a theming-template system.** 64 community
templates, applied with `noctalia msg templates-apply`,
in the same input → output → post-hook shape as your
`theme-set.d` hooks.

**12 of the ~26 apps you hand-maintain are already
covered:** fzf, discord, spicetify, tmux, vicinae, zed,
obsidian, qutebrowser, steam, zen-browser, heroic, vscode.

Left to port: fish, gtk, qt6ct, superfile, typora,
swaync, foot, cursor, windsurf, cava, firefox, cliamp,
obsidian-terminal, restart-notify. GTK and Qt may be
handled natively anyway.

**Noctalia has a large plugin ecosystem.** 176 plugins
available — 13 official, 163 community, all currently
disabled on waylab. They cover nearly every gap I'd
flagged:

- `fel/ocr` → OCR
- `yocraft/qrcode` → QR capture
- `noctalia/screen_recorder` (official) and
  `h-jangra/region-recorder` → screen recording
- `oldirtty/color_picker` → replaces hyprpicker
- `liamwh/emoji-picker` → emoji
- `nightwatch75/todo` → omarchy reminders
- `lowcache/claude-companion`, `jrohland/claudecode` →
  your agents bar widget
- `noctalia/umbriel-companion` (official) → the Umbriel
  integration plugin. Probably enable this one first.

Others worth knowing about given your setup:
`cleboost/ssh-launcher` (≈ your sshmenu),
`mellotanica/launcher-pass` (you have `pass` installed),
`nightwatch75/dns-switcher`, `8bury/mini-docker`,
`yocraft/web-launcher` (≈ webapps), `noctalia/notes`,
`noctalia/bitwarden`, `noctalia/timer`.

Not a QML port path, but a real one.

---

## 3. The one real blocker: the Stream Deck

Your `input.lua` disables the Elgato Stream Deck as a
keyboard. That fix is load-bearing — without it, idle
never settles and held-SUPER fires workspace switches in
bursts.

**Umbriel has no equivalent.** Confirmed three ways:
the config schema, the 106-action CLI, and the docs.
`[[input.device]]` has no `enabled` key — `enabled` exists
only for tablets.

The fix is a udev rule instead:

```
# /etc/udev/rules.d/99-streamdeck-no-keyboard.rules
SUBSYSTEM=="input", ATTRS{idVendor}=="0fd9", \
  ATTRS{idProduct}=="006d", ENV{LIBINPUT_IGNORE_DEVICE}="1"
```

Arguably the correct layer anyway — it was never really a
compositor concern, and it survives whatever you land on.
Stream Deck software uses hidraw, so nothing is lost.

**Test this on waylab before caesar moves.**

---

## 4. What you actually lose

- **Window grouping** (`SUPER+G` and friends). Confirmed
  absent. Real behaviour change.
- **138 screen shaders.** No Hyprland-style screen shader
  in Umbriel.
- **The 441-command surface**, and the install/setup/remove
  catalogue behind `SUPER+SPACE`.

That's genuinely it. OCR, QR and screen recording all have
plugins (see §2) — I was wrong to list them as losses
before I'd seen the plugin catalogue.

## What gets better

- **Per-window opacity.** You wrote a long comment about
  fighting Omarchy's `default-opacity` tag — wrong windows,
  browsers opting out, not surviving reload. None of that
  exists. It's now just `match.is_focused = false` →
  `opacity = 0.85`.
- **Per-window VRR**, replacing your global `vrr = 2` hack.
- **Per-output workspaces are native** — your
  `moveworkspacetomonitor` autostart hack disappears.
- **`umbriel subscribe`** streams JSON-line events. Better
  than scripting against `hyprctl`.

---

## 5. About waylab

Dell, i7-8700T, 16 GB, **Intel UHD 630**, ext4, rEFInd,
32 packages, kernel 7.2.4 (ahead of caesar). Your Umbriel
config is the stock example with six edits: caps:swapescape,
repeat 50/200, sensitivity 0.5, focus-follows-mouse,
`Mod+Q` → `Mod+W`, and dwindle instead of scrolling.

**It is not testing the hard case.**

That Acer is the same panel that runs 3840x2160@160 at
**scale 1.5** on caesar. On waylab it's 1440p at 1×, single
monitor, Intel graphics. Fractional scaling, mixed-DPI,
160 Hz and NVIDIA are all still unexercised.

A green testbed proves very little about caesar.

Also missing on waylab right now: `xwayland-satellite` —
so **no X11 app runs there at all** (Steam included) until
it's installed. Plus your whole shell UX: starship, mise,
zoxide, fzf, eza, bat, ripgrep, fd, tmux, btop.

---

## 6. Salvage list — do this first, on caesar

While everything still runs:

1. `~/.config/omarchy/hooks/theme-set.d/` — 30 hooks plus
   `lib/omarchy3-compat.sh`. Your biggest investment.
2. `/usr/share/omarchy/default/bash/*` — eza/zoxide/fzf/
   starship/mise setup. **Disappears with the package.**
3. Diff `peter.lock` / `peter.emojis` against stock. They
   won't port (Noctalia 5 is native C++, not Quickshell),
   but the diff is the spec for replacing them.
4. Run `omarchy-theme-colors-from-alacritty` over the
   themes you want. You have 27 user themes, 776 MB — and
   **20 of them are already dead**, Omarchy 3 format
   targeting waybar/mako/walker/swayosd, none of which
   still exist on caesar.
5. `~/.config/hypr/*.lua`, `shell.json`, webapp `.desktop`
   files, `~/.bashrc`.

---

## 7. Suggested order

1. Salvage (above), on caesar, now.
2. On waylab: **prove the Stream Deck udev rule.**
3. On waylab: plug in the 4K panel at 160 Hz and scale 1.5.
   This is the test that matters.
4. Install `xwayland-satellite`, then your shell UX.
5. Port the theme runner — ~40 lines of bash to export the
   colour vars and run `theme-set.d`. Buys back ~14 apps;
   Noctalia's templates cover the other 12.
6. Rebuild launch-or-focus. Five of your keybindings need it.
7. Redesign keybindings deliberately rather than porting
   `bindings.lua` line by line. Umbriel's launcher is on
   bare `Mod`, and `Mod+Space`, `Mod+T`, `Mod+O`, `Mod+M`,
   `Mod+F`, `Mod+L`, `Mod+Tab` all collide with yours.
8. Then find out which of the 441 commands you miss. You'll
   learn that by missing them, not by reading the list.

---

## 8. Still unknown

- Does Noctalia's emoji picker insert at cursor? That was
  the point of your `emoji-insert` helper.
- Which Omacom apps do you keep? `cliamp` and `herdr` are
  wired into your current config — and Noctalia ships a
  `herdr` theming template, which is a slightly awkward
  thing to notice.
- Do you want btrfs + snapper on the new box? waylab is
  ext4, so there's no snapshot rollback. That decision has
  to happen at install time, not after.

---

*Detail: `README.md`, `01`–`05` and `raw/` in this directory.*
