# Gap analysis: Omarchy/Hyprland → Umbriel/Noctalia

Legend: **✅ covered** · **🔧 rewrite** (function exists, config/syntax differs) ·
**⚠️ verify** on the testbed · **❌ gone** (no replacement — build, substitute, or drop)

---

## Compositor layer

| Omarchy/Hyprland | Umbriel | Notes |
|---|---|---|
| Hyprland | ✅ `umbriel-git` | wlroots 0.20, C++23, MIT |
| dwindle layout | ✅ | plus scrolling and master, per-workspace selection |
| Workspaces per monitor | ✅ | per-output workspaces are native — your `moveworkspacetomonitor` autostart hack goes away |
| Window rules (`o.window(...)`) | 🔧 | Umbriel has window rules; TOML syntax, full rewrite |
| Blur / shadow / rounding | ✅ | umbrielfx (SceneFX fork) |
| Animations | ✅ | |
| Scratchpad (`SUPER+S`) | ✅ | Umbriel has *global named* scratchpads |
| Overview | ✅ | animated overview |
| Directional focus | ✅ | |
| XKB options (`caps:swapescape`, `compose:ralt`) | ✅ | XKB config supported |
| Per-device disable (Stream Deck) | ❌ | **Confirmed absent.** `[[input.device]]` has no `enabled` key; `enabled` exists only under `[input.tablet]`. Needs a udev `LIBINPUT_IGNORE_DEVICE` rule — see `05-waylab-testbed.md` |
| **Window grouping** (`SUPER+G`, group cycling, move-out-of-group) | ❌ | Umbriel documents no group/tabbed container. Real behaviour change |
| **Screen shaders** (138 GLSL files) | ❌ | Confirmed: no Hyprland-style screen shader. Custom *window* shaders are referenced under `[appearance.shadow]` — a different feature |
| `hyprctl` IPC | 🔧 | Umbriel has its own IPC/CLI; every script calling `hyprctl` needs porting |
| `xdg-desktop-portal-hyprland` | ✅ | `xdg-desktop-portal-umbriel-git` (same upstream) |
| `hyprland-preview-share-picker` | ✅ | portal backend handles screencast picking |
| XWayland (built into Hyprland) | 🔧 | Umbriel needs `xwayland-satellite` on `PATH` — **not installed on waylab**, so no X11 app runs there today |
| `hyprsunset` (night light) | ✅ | Noctalia native: `nightlight-enable/disable/toggle/force-toggle` |
| `hyprpicker` (colour picker / freeze) | ✅ | Colour picker: community plugin `oldirtty/color_picker`. Freeze is moot — Noctalia has native `screenshot-region` |
| `hyprcursor` | ✅ | `[input.cursor]` takes a standard Xcursor `theme` + `size` |

## Shell layer

| Omarchy shell plugin | Noctalia | Notes |
|---|---|---|
| `bar` (+ your 12-widget layout) | ✅ | bars, workspaces, tray, media, network, battery, brightness, weather, clipboard, script widgets |
| `menu` (`SUPER+SPACE`) | 🔧 | Noctalia has a launcher; the **333-entry Omarchy catalogue is content, not code** — see below |
| `notifications` | ✅ | toasts + history |
| `osd` | ✅ | |
| `lock` + your `peter.lock` | 🔧 | Noctalia has a lock screen; your QML clone does not port |
| `clipboard` | ✅ | clipboard history |
| `emojis` + your `peter.emojis` | 🔧 | `panel-open launcher /emo` gives an emoji mode. **Insert-at-cursor unverified** — that was the point of your `emoji-insert` helper |
| `background` / `image-picker` | ✅ | wallpaper picker with palette/theme support |
| `polkit` | 🔧 | `noctalia-unofficial-auth-agent-git`, or `lxqt-policykit` / `polkit-gnome`. waylab has `polkit` but no agent yet |
| `panels` | ✅ | control centre |
| `agents` (Claude/Codex/Fireworks usage widget) | 🔧 | candidate: community plugin `lowcache/claude-companion`; also `claude-code`/`codex`/`opencode` theming templates exist |
| `reminders` (`SUPER+CTRL+R`) | 🔧 | candidate: community plugin `nightwatch75/todo` |
| `services` / `dev-gallery` | n/a | internal |
| **Plugin format** | ❌ | **Omarchy = Quickshell/QML. Noctalia 5.x = native C++ (cairo/pango/wayland/tomlplusplus), no Qt.** Plugin APIs are unrelated |
| Config | 🔧 | `shell.json` → Noctalia TOML, hot-reload, GUI-managed overrides |

## Distro / system management — the real gap

| Omarchy | Replacement |
|---|---|
| 441 `omarchy-*` commands | ❌ Nothing. `pacman` + `paru` + your own scripts |
| `omarchy-menu` install/setup/remove catalogue (217 of 333 entries) | ❌ Manual package installs |
| `omarchy-update` (guard hook, log analysis, channels, keyring, orphan prune) | ❌ `pacman -Syu` / `paru -Sua` |
| `[omarchy]` pacman repo (33 installed packages) | 🔧 Re-source from AUR/extra — see `04-packages.md` |
| `hw-*` hardware profiles (~25) | 🔧 Mostly laptop-specific and irrelevant on a Dell desktop; **the NVIDIA env vars are not** (see below) |
| `omarchy-crash-watch` (crash → notification → AI diagnosis) | ❌ Your `diagnose-crash` skill uses `coredumpctl`, which is portable; the *notifier* is not |
| Theme engine (22 themes, 20 templates, hooks) | 🔧 See `03-carry-over.md` — this is your biggest salvage win |
| Plymouth `omarchy` theme | 🔧 Any stock Plymouth theme |
| SDDM `omarchy` theme | 🔧 Keep SDDM, or `noctalia-greeter` (greetd + bundled wlroots compositor) |
| Limine + snapper + `limine-snapper-sync` | ✅ **Independent packages.** Nothing Omarchy-specific but default config — carries over as-is |
| `uwsm` session wrapper | ✅ Compositor-agnostic; keep it or use Umbriel's own session |
| fcitx5 + XCompose (`omarchy-fcitx5.service`) | ✅ Portable; recreate the user unit |
| `bt-agent.service` | ✅ Portable |
| omarchy default bash chain | ✅ Pure bash — copy it out |
| Webapps (`chromium --app` wrappers) | ✅ Plain `.desktop` files, nothing Omarchy-specific |

## Two things that will bite on this hardware

**1. NVIDIA.** Your `hyprland.lua` hard-codes `NVD_BACKEND=direct`,
`LIBVA_DRIVER_NAME=nvidia`, `__GLX_VENDOR_LIBRARY_NAME=nvidia` as a workaround for a
quattro bug. Whatever the Dell box has, these env vars are a **compositor-independent
concern** — set them in the Umbriel session env, not in a compositor config you'll
forget about. (Caesar runs `nvidia-open-dkms` + `lib32-nvidia-utils` +
`libva-nvidia-driver`; the Dell, being ex-enterprise, probably doesn't — one fewer
problem there, and a reason the testbed won't prove out caesar's setup.)

**2. Your three-monitor layout is fractional-scaled.** DP-1 is 3840x2160@160 at
**scale 1.5** with HDMI-A-1 and DP-2 at 1×, positioned to a logical grid that assumes
that scaling. Fractional scaling plus mixed-DPI plus 160 Hz is where young compositors
break. Test this specifically before committing caesar.

## What this stack does *not* let you leave behind

Worth being clear-eyed about: `quickshell` stays installed only if you keep something
using it (you won't). But `wlroots`, `wayland`, `pipewire`, `wireplumber`,
`xdg-desktop-portal`, `grim`, `slurp`, `wl-clipboard` are all shared infrastructure and
are not tied to either project you're leaving.


---

## Addendum after auditing waylab

Two things I did not know when I wrote the above, both of which make the move easier:

**Noctalia ships a theming-template system.** 64 community templates, applied with
`noctalia msg templates-apply`, in the same input→output→post_hook shape as your
`theme-set.d` hooks. **12 of the ~26 apps you hand-maintain are already covered**
(fzf, discord, spicetify, tmux, vicinae, zed, obsidian, qutebrowser, steam,
zen-browser, heroic, vscode). Your porting job shrinks to roughly: fish, gtk, qt6ct,
superfile, typora, swaync, foot, cursor, windsurf, cava, firefox, cliamp,
obsidian-terminal, restart-notify — and GTK/Qt may be handled natively.

**Noctalia has a large plugin ecosystem** — 176 plugins (13 official, 163 community),
all disabled on waylab. It covers OCR, QR, screen recording, colour picker, emoji,
reminders and the agents widget, plus `noctalia/umbriel-companion` for compositor
integration. Not a QML port path — but a real one, and it shrinks the "❌ gone" column
above considerably.

**And one that makes it harder:** `umbriel msg` exposes 106 actions and Umbriel ships
52 default binds against Omarchy's ~175. The compositor genuinely does less. Anything
in that gap moves to `noctalia msg` (~100 IPC commands) or to your own scripts.
