# Post-install audit — caesar on Nomarchy

Read-only audit of **caesar** after the bare-Arch reinstall, taken 2026-09-09, checked
against `01`–`05` and `SUMMARY.md` in this directory. The old Omarchy root is mounted
read-only at `/mnt/omarchy-old` (btrfs, subvolumes `@`, `@home`, `@log`, `@pkg`) and was
used only as reference.

Nothing on the machine was reconfigured for this audit. The one exception is documented
in §7: three temporary keybinds added to test the clipboard question, marked in the
config and intended for removal.

---

## 1. Where the machine actually is

| | Old (Omarchy 4.0.3 "quattro") | Now (Nomarchy) |
|---|---|---|
| Root filesystem | btrfs on LUKS, `subvol=@` | **ext4 on `/dev/sda2`**, unencrypted |
| Bootloader | Limine + `limine-mkinitcpio-hook` + `limine-snapper-sync` | **systemd-boot**, `Nomarchy` EFI entry |
| ESP | dedicated | **shared with Windows and Ubuntu** (`/dev/sda1`, 512 MB) |
| Snapshots | snapper + `snapper-cleanup.timer` | **none** |
| Session start | SDDM autologin → uwsm → Hyprland | **agetty autologin on tty1** → `.bash_profile` → `start-umbriel` |
| Compositor | Hyprland | `umbriel-git .r885.ac83d8e` (waylab tested r872) |
| Shell | omarchy-shell (Quickshell/QML) | `noctalia 5.0.1` + `noctalia/umbriel-companion` |
| Explicit packages | 291 | **59** |
| Foreign packages | 6 (paru-built) | 4 (umbriel + portal, plus their `-debug` splits) |
| AUR helper | paru | **none installed** |
| pacman repos | core, extra, multilib, omarchy | **core, extra only** |

### Install-time decisions now closed

`SUMMARY.md` §8 left three questions open that could only be answered at install time.
All three are now answered, by action rather than by decision record:

- **btrfs + snapper: no.** Root is ext4. There is no snapshot rollback on this machine.
  `btrfs-progs` is installed, but only that — it is what makes `/mnt/omarchy-old`
  readable.
- **Bootloader: systemd-boot, not Limine.** The old `Limine` EFI entry still exists in
  NVRAM (`Boot0001`) pointing at the *old* disk's ESP. It is stale but harmless.
- **Encryption: dropped.** The old cmdline carried
  `cryptdevice=PARTUUID=…:root root=/dev/mapper/root`. The new one is a bare
  `root=UUID=… rw`.

---

## 2. What has been migrated

**Compositor configuration.** `hosts/caesar/umbriel/config.toml`, symlinked to
`~/.config/umbriel/config.toml`. Real caesar geometry is in place:

```
HDMI-A-2  1920x1080@60   at  320x0        scale 1
DP-2      3840x2160@160  at  0x1080       scale 1.5
DP-3      1920x1080@60   at -1920x1080    scale 1
```

Connector names changed from the Hyprland era (`HDMI-A-1`/`DP-1`/`DP-2` → `HDMI-A-2`/
`DP-2`/`DP-3`), but the logical layout matches `03-carry-over.md` exactly. **This is the
fractional-scaling, mixed-DPI, 160 Hz case that `05-waylab-testbed.md` flagged as
untested — it is now the daily driver.**

**Input carry-over.** `caps:swapescape`, `repeat_rate = 50`, `repeat_delay = 200`,
`follows_mouse = true`, `Mod+W` for close.

**Look and feel.** Blur (3 passes, radius 3, optimized), shadows (softness 10, offset
2/2), `corner_radius = 10`, `gap = 8`, dwindle layout, full animation set, overview at
zoom 0.5, top-left hot corner → overview, `prefer_no_csd`.

**Window and layer rules.** Noctalia's own surfaces float at fixed sizes, the share
picker floats, Picture-in-Picture floats bottom-right, Steam notification toasts are
pinned and unfocused, and the Noctalia layer namespaces get blur with
`blur_ignore_alpha`.

**Noctalia shell.** Bar layout (launcher/wallpaper/workspaces/bar · date/clock/weather ·
media/tray/notifications/clipboard/network/volume/brightness/control-center/session),
`background_opacity = 0.49`, location set, imperial weather, Tokyo Night, polkit agent
enabled, `noctalia/umbriel-companion` enabled, and per-output lockscreen login boxes
positioned for all three real outputs.

**Neovim.** Full LazyVim config in `common/nvim`, symlinked to `~/.config/nvim`.

**Screenshot.** `common/scripts/screenshot-region` (`slurp` → `grim` → `wl-copy`) bound
to `Print`. Behaviourally equivalent to `omarchy-capture-screenshot`.

**XWayland.** `xwayland-satellite 0.8.2` installed, `xwayland = true`. Confirmed working
— Spotify was running under it during the audit. This was the item
`05-waylab-testbed.md` called out as missing on the testbed.

---

## 3. The one blocker — found live, now resolved

At the time of the audit the Stream Deck was plugged in, `/etc/udev/rules.d/` was
**empty**, and Umbriel r885 still had no `enabled` key under `[[input.device]]`
(re-confirmed against the shipped `/usr/share/umbriel/config.toml`, where `enabled`
appears only under `[input.tablet]`). Nothing was suppressing the old symptoms — idle
never settling, and held-`SUPER` firing workspace switches in bursts.

Fixed with `common/udev/99-streamdeck-no-keyboard.rules`, installed to
`/etc/udev/rules.d/`:

```
SUBSYSTEM=="input", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", ENV{LIBINPUT_IGNORE_DEVICE}="1"
```

The IDs were re-derived on this machine rather than taken from `SUMMARY.md`
(`udevadm info -a -n /dev/input/event2` → `0fd9:006d`, `product == "Stream Deck"`), on
the principle that a wrong ID in a udev rule fails silently — the same failure shape as
§7's stale config.

**Verified in two independent ways, because the first one alone is not evidence:**

1. `udevadm info -q property -n /dev/input/event2` reports `LIBINPUT_IGNORE_DEVICE=1`.
2. The compositor actually released the device. Umbriel (pid 724) holds `event0`,
   `event1`, `event3`–`event9` and `event11` — **`event2` is the only gap in the
   sequence.**

The second check is the one that counts. `udevadm trigger` updates the property database,
but libinput only reads `LIBINPUT_IGNORE_DEVICE` when a device is *added*, so an
already-open device keeps working and the property looks correct while nothing has
changed. The device had to be physically replugged; `/dev/input/event2` shows a creation
time of 22:38, after the 22:37 rule install.

`hidraw0` is untouched — a different subsystem — so Stream Deck control software is
unaffected.

This also lands the fix at the right layer. It was never a compositor concern, and the
rule survives whatever compositor comes next.

---

## 4. What remains

| Area | Status |
|---|---|
| **Shell UX** | `~/.bashrc` is 12 lines; the old one is 238. Missing `eza`, `bat`, `zoxide`, `tmux`, `btop`, `mise`, `lazydocker`. The ~50 SSH aliases, `refreshrl`, `hw`, `suben`/`subvi`/`subs` and the backup-status login banner are all still only on `/mnt/omarchy-old`. Present already: `fd`, `fzf`, `ripgrep`, `starship`, `lazygit`. |
| **Theme pipeline** | All 26 `theme-set.d` hooks intact at `/mnt/omarchy-old/@home/peter/.config/omarchy/hooks/theme-set.d/`, plus `lib/omarchy3-compat.sh` and the `.disabled` runner. Nothing ported. Noctalia's 64 community templates are cached under `~/.local/state/noctalia/community-templates/` but no `templates-apply` wiring exists. |
| **`~/.local/bin`** | 40 scripts on the old disk (`sshmenu`, `subget`, `spotify-limited`, `hermes`, `muse`, `shelf`, `astroterm-saver`, `merge-show-dirs`, …). The new `~/.local/bin` contains only the `claude` symlink. |
| **Webapps** | ~15 `.desktop` launchers on the old disk (ChatGPT, Figma, GitHub, Google Contacts/Maps/Messages/Photos, Proxmox, Twitch, WhatsApp, YouTube, Zoom). None recreated, and no `chromium --app` wrapper exists. |
| **launch-or-focus** | Not rebuilt. `03-carry-over.md` called this the first thing to rebuild; five old keybindings depended on it. None of those keys are bound today. |
| **Application launchers** | Effectively zero. `Mod+B/M/N/T/D/G/O/A/E/Y/Slash` are either unbound or sitting on Umbriel defaults. Only `Mod+Return` → kitty exists. |
| **Capture toolchain** | `grim`, `slurp`, `wl-clipboard` present. Missing `tesseract`, `zbar`, `qrencode`, `gpu-screen-recorder`, `imv`, `mpv`, `wev`. OCR, QR and screen recording are gone; the Noctalia plugins that cover them are not enabled. |
| **Fonts** | JetBrains Mono Nerd and Noto only. Missing CaskaydiaMono Nerd, iA Writer, Symbols Nerd Font. |
| **Input method** | No `fcitx5`, no XCompose. |
| **Misc services** | No `bt-agent`, no `gnome-keyring`/`libsecret`/`seahorse`, no `udiskie`, no personal timers (`backup-daily`, `backup-legal-to-nas`, `subget-sync`). |
| **Audio completeness** | `pipewire`, `pipewire-pulse`, `pipewire-jack`, `wireplumber` present. Missing `pipewire-alsa` and `gst-plugin-pipewire`. |
| **Terminal config** | Ported deliberately — see §9. `common/kitty/kitty.conf` is symlinked to `~/.config/kitty/kitty.conf`. Two behaviours were dropped on purpose and one is blocked: the custom kitty fork at `~/.local/opt/kitty-pete` is not rebuilt, so `mouse_selection_from_gutter` is unavailable. |
| **Multilib** | Disabled, so no `lib32-nvidia-utils` and no Steam. |

---

## 5. Material differences from the old behaviour

These are places where the new machine does something different from documented old
behaviour, rather than simply not doing it yet.

1. **The NVIDIA environment variables are gone.** `[environment]` in the Umbriel config
   is empty, and `NVD_BACKEND`, `LIBVA_DRIVER_NAME` and `__GLX_VENDOR_LIBRARY_NAME` are
   all unset in the live session. `02-gap-analysis.md` specifically said to move these
   out of the compositor config and into the session environment; instead they were
   dropped. `libva-nvidia-driver` is installed, so hardware video decode is most likely
   falling back silently.

2. **NVIDIA modules are not in the initramfs.** Old: `MODULES=(nvidia nvidia_modeset
   nvidia_uvm nvidia_drm btrfs)`. New: `MODULES=()`, with only
   `options nvidia_drm modeset=1` from `/etc/modprobe.d/nvidia.conf`. That is late KMS —
   expect a mode-set flicker during boot. Not dangerous, but it is a regression from a
   deliberately-configured state.

3. **Mouse sensitivity is `0.0`.** Both old caesar and waylab used `0.5`.

4. **No idle or lock timings are configured.** The old `shell.json` set the screensaver
   at 1200 s and lock at 1800 s — a deliberate 8× over Omarchy's stock 150/300, called
   out in `01-what-omarchy-provides.md` §2 as one of only two settings that were
   *choices*. Noctalia's `settings.toml` has no idle section, so stock defaults apply.

5. **`lockscreen_widgets.enabled = false`** — despite three fully positioned per-output
   login boxes being configured underneath it.

6. **Per-window opacity was never expressed.** The old `looknfeel.lua` ran `0.75 0.55` on
   general windows and `1.0 0.90` on browsers and Godot. `05-waylab-testbed.md` §7 showed
   this becomes *simpler* under Umbriel (`match.is_focused = false` → `opacity`). It has
   not been done; everything is fully opaque. `[animation.dim_unfocused]` is disabled,
   which does match the old "all dimming off" Atlas override.

7. **VRR is unset.** The old box ran a global `vrr = 2` (fullscreen-only) specifically to
   stop FreeSync flicker on the third panel. Umbriel supports `vrr` as a per-window rule;
   no rule sets it.

8. **New choices with no old-side equivalent:** `focus_on_activate = false`,
   `honor_restored_maximize = false`, `show_cheatsheet = true`, and a top-left hot corner.
   Worth confirming these are intentional rather than inherited from the example config.

---

## 6. Repository drift

- **`hosts/caesar/noctalia/settings.toml` is stale and not symlinked.** The live file at
  `~/.local/state/noctalia/settings.toml` has bar layout, location, lockscreen,
  lockscreen widgets, plugins, polkit, weather and seven `[widget.*]` blocks that the
  committed copy lacks. Noctalia rewrites this file itself, so a symlink is probably the
  wrong answer — but the committed copy currently misrepresents the machine. It needs
  either a sync step or a note saying it is a snapshot.

- **`common/umbriel/config.toml` is the waylab config, not a shared base.** It still
  describes the Acer on `HDMI-A-1` at 2560x1440@59.951, `sensitivity = 0.5`,
  `follows_focus = false`, and its comment text is from an older Umbriel release than the
  caesar copy. Nothing includes it — `[include]` and `[include.optional]` are both empty
  in the caesar config. It reads as a base layer and is not one.

- **The `Print` keybind hardcodes `/home/peter/Projects/nomarchy/common/scripts/`.** It
  works, but the session now has a hard dependency on the checkout living at exactly that
  path.

- **`umbriel msg spawn` does not preserve shell quoting.** A quoted multi-word argument
  passed through `umbriel msg spawn kitty --title X bash -c "…"` is split, and the
  intended window never maps. Relevant to how `[general] autostart` entries and
  `spawn:` binds are written — anything needing a shell should go through a script file
  rather than an inline command string.

- **Config changes do not reach running processes, and they fail silently.** This bit
  twice in one session, from two different programs, with the same shape both times: the
  file on disk was correct, a fresh process read it correctly, and the running session
  kept serving stale behaviour.

  | Program | Reload | Symptom when stale |
  |---|---|---|
  | Umbriel | `umbriel msg config-reload` | A changed keybind does nothing at all |
  | kitty | `Ctrl+Shift+F5` (`reload_config_file`) | A new mapping is absent; the *default* for that key runs instead |

  The kitty case is the nastier of the two, because a window started before
  `~/.config/kitty/kitty.conf` existed gets no config watcher at all — kitty watches the
  files it loaded at startup, and a file that did not exist then is never picked up.
  Confirm with `pgrep -af __watch_conf__`: windows with a watcher hot-reload, windows
  without one never will.

  **The testing trap:** every probe window spawned to verify this behaviour is a *new*
  process, so it always reads the current config and always passes. Verifying a config
  change against a freshly spawned window tests the file, not the session. Check the
  live session, or compare process start time against config mtime.

  Quickest ways to see what is actually loaded rather than what the file says:
  `umbriel msg cheatsheet-open` renders the currently registered binds, and
  `ps -eo pid,lstart,args | grep kitty` against the config's mtime shows which terminal
  windows predate it.

---

## 7. Super+C / Super+V — investigation and result

### How Omarchy actually did it

`/mnt/omarchy-old/@/usr/share/omarchy/default/hypr/bindings/clipboard.lua`. It is stock
quattro — `~/.config/hypr/bindings.lua:110` carries an explicit comment leaving
`SUPER+C` and `SUPER+X` to the defaults, and moves clipboard history to `SUPER+SHIFT+V`.

```lua
local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end
```

Four decisions, each load-bearing:

1. **The compositor injects the chord itself**, through Hyprland's `sendkeystate`
   dispatcher — not through a virtual keyboard. The file's header comment says why:
   *"A virtual keyboard (wtype) won't do: the physically held SUPER merges into the
   injected chord at the seat."*
2. **No window target is passed**, so the chord reaches whatever holds keyboard focus —
   including layer-shell surfaces such as the Omarchy panels.
3. **Down and up are split by a 50 ms one-shot timer**, working around Hyprland leaving
   synthetic key state stuck or repeating
   ([hyprwm/Hyprland#14099](https://github.com/hyprwm/Hyprland/discussions/14099)).
4. **Dispatch is terminal-aware**, via the `terminal` tag defined in
   `default/hypr/apps/terminals.lua`:
   `(Alacritty|kitty|com\.mitchellh\.ghostty|foot|org\.codeberg\.dnkl\.foot|wezterm|org\.omarchy\..*|TUI\..*)`

| Key | Terminal | Everything else |
|---|---|---|
| `SUPER+C` | `Ctrl+Insert` | `Ctrl+C` |
| `SUPER+V` | `Shift+Insert` | `Ctrl+V` |
| `SUPER+X` | `Ctrl+X` | `Ctrl+X` |

Cut has no terminal variant, because terminals do not cut.

**The behaviour to reproduce:** one modifier for copy and paste that works everywhere,
without the user having to know whether the focused thing is a terminal.

### The half that is not in the compositor

The Insert chords are not a universal terminal convention, and the compositor half is
inert without a matching terminal configuration. Every terminal on the old box carried
an explicit pair of mappings pointing those chords at the **clipboard**:

| Terminal | Old config |
|---|---|
| kitty | `map ctrl+insert copy_to_clipboard` · `map shift+insert paste_from_clipboard` |
| ghostty | `control+insert=copy_to_clipboard` · `shift+insert=paste_from_clipboard` |
| alacritty | `Ctrl+Insert` → `Copy` · `Shift+Insert` → `Paste` |
| foot | `clipboard-copy=Control+Insert …` · `clipboard-paste=Shift+Insert …` |

This matters because the defaults are actively wrong for the purpose. In stock kitty:

- `ctrl+insert` is **unbound**, so copy is a no-op.
- `shift+insert` is `paste_from_selection` — it pastes the **primary selection**, not the
  clipboard.

Measured on this machine with an empty `~/.config/kitty/`: injecting `Shift+Insert`
into a kitty window with `CLIPBOARD-VALUE` on the clipboard and `PRIMARY-VALUE` on
primary delivered **`PRIMARY-VALUE`**. Super+C did nothing and Super+V pasted the wrong
buffer. `foot`'s stock `Shift+Insert` is `primary-paste` for the same reason, so the old
`foot.ini` was overriding a default too.

**So this is a three-legged mechanism, not two:** a keybind, an injector, and a terminal
configured to agree with them. Losing the third leg is silent — the keys do *something*,
just not the right thing.

### Why the mechanism does not port

`umbriel msg --help` on r885 lists actions in eight groups — Apps, Focus, Move & size,
Windows, Scratchpad, Workspaces, Overview, System. The only action that reaches outside
the compositor is `spawn:<cmd>`. **There is no key-injection action and no on-release
binding.** Table-form binds accept `action`, `repeat`, `cooldown_ms`, `submap` and
`allow_when_locked`, and nothing else.

`noctalia msg` offers `clipboard-copy <text>`, `clipboard-text` and `clipboard-clear` —
clipboard *contents*, not keystrokes. Useful for scripting, useless for "make the focused
app copy its own selection".

So Omarchy's mechanism has no equivalent, and the specific reason its author rejected
`wtype` is exactly the thing that had to be measured here.

### Two things that carry over better than before

- **`umbriel windows --json` returns `active: true` for the seat-focused window**, with
  `app_id`, `title` and an `xwayland` flag. That is a cleaner and more honest terminal
  test than Hyprland's tag system, and the whole lookup measures **14 ms** including
  Python startup.
- Umbriel's shipped config states *"Virtual keyboards provide their own keymaps"*, so
  `zwp_virtual_keyboard_v1` is supported and `wtype` runs.

### Test results

`wtype 0.4-2` installed. Probe: a `kitty` window running a `bash` loop with a `SIGINT`
trap appending to a log. Injection was guarded by a focus check that aborts unless the
probe window is the active one.

| Test | Method | Result |
|---|---|---|
| **1 — chord delivery** | `wtype -M ctrl -k c -m ctrl` into the focused probe | **PASS** — `SIGINT` logged. A real Ctrl+C reaches the focused surface. |
| **2 — modifier merge** | Same injection, while a *second* virtual keyboard held `logo` down for 2.5 s (`wtype -M logo -s 2500 -m logo &`) | **PASS** — `SIGINT` logged, uncorrupted. The held Super did **not** merge into the injected chord, and focus was unchanged afterwards. |
| **3 — physical keyboard** | `Mod+C` then `Mod+V` bound to the wrapper script, pressed by hand: copy a selection out of Firefox, paste it into a text field | **PASS** — copy and paste both behaved correctly with Super physically held. |
| **4 — terminal, before fix** | `Shift+Insert` into kitty with distinct clipboard and primary values, empty `~/.config/kitty/` | **FAIL** — delivered `PRIMARY-VALUE`. Confirms the missing third leg. |
| **5 — terminal, after fix** | Same, with `common/kitty/kitty.conf` symlinked in | **PASS** — delivered `CLIPBOARD-VALUE`. |
| **6 — terminal, end to end** | `universal-clipboard paste` with a kitty window focused | **PASS** — script detected the terminal, injected `Shift+Insert`, clipboard content arrived. |
| **7 — live session** | Copy in a pre-existing kitty window, paste in Firefox, with the script logging its decisions and `wl-paste --watch` logging clipboard changes | **FAIL, then PASS.** Initially the script chose the right window and branch but the clipboard never changed — those kitty windows predated the config file. After `Ctrl+Shift+F5` the clipboard changed in the same second as the copy. |

Test 7 is the one worth remembering. Tests 1–6 all passed against freshly spawned
windows while the real session was broken, and the failure presented as something else
entirely: copy was a silent no-op, while paste appeared to work because stock
`shift+insert` pastes the **primary selection** — which, right after a mouse selection,
is usually the text you wanted. Copy failing and paste succeeding-by-accident together
look convincingly like a per-window clipboard. Wayland has exactly one clipboard; the
giveaway was `primary` holding the terminal selection while `clipboard` still held
something Firefox had set minutes earlier.

**This settles it.** Umbriel does not merge a held physical modifier into a
virtual-keyboard chord the way Hyprland did, so the single reason Omarchy's author
rejected `wtype` does not apply here. The mechanism Omarchy needed a compositor
dispatcher for is reproducible with an ordinary `spawn:` and a 20-line script.

Test 3 also cleared the secondary worry: the bare-`Mod` launcher bind did **not** fire
when Super was released after the chord.

To run test 3, three keybinds were added to `hosts/caesar/umbriel/config.toml`,
immediately under the `Print` bind and marked:

```toml
# TEMPORARY — wtype universal-clipboard test. Remove these three lines after verifying.
"Mod+C" = "spawn:…/universal-clipboard copy"
"Mod+V" = "spawn:…/universal-clipboard paste"
"Mod+X" = "spawn:…/universal-clipboard cut"
```

They point at a scratchpad copy of the script and **must be repointed or removed**; the
scratchpad does not survive.

### Options, and the recommendation

**A — `wtype` driven by a wrapper script.** The closest port. A `spawn:` script reads
`umbriel windows --json`, checks the active `app_id` against the terminal set, and runs
the appropriate chord. No root, no daemon, no system-wide scope, roughly 20 lines.
**All three tests pass, including by hand.** No known remaining risk.

**B — `keyd`, at the evdev layer.** Rewrites the event stream *before* the compositor
sees it, so Super is consumed and a clean `Ctrl+C` is emitted. The merge problem cannot
occur by construction, and it behaves identically in XWayland, layer-shell surfaces and
the TTY. Costs a root daemon and system-wide scope; per-application conditionality needs
a small watcher on `umbriel subscribe windows` calling `keyd bind`. It would also solve
the Stream Deck problem in the same layer.

**C — collapse the terminal branch instead of configuring it.** kitty's
`copy_or_interrupt` copies when there is a selection and sends `SIGINT` otherwise, so
`map ctrl+c copy_or_interrupt` plus `map ctrl+v paste_from_clipboard` would make an
unconditional `Ctrl+C`/`Ctrl+V` correct everywhere and remove both the window inspection
*and* the Insert chords. It trades a compositor-side branch for a terminal-side one, and
it rebinds two keys that carry a lot of terminal muscle memory.

**Recommendation: A, plus the terminal config.** A is measured working end to end,
needs no root, and its detection step costs 14 ms. The terminal branch is worth keeping
rather than collapsing: it is what makes the behaviour terminal-agnostic, it leaves
`Ctrl+C` alone, and it reproduces what the old box actually did.

That means carrying the two-line clipboard block into **every terminal installed on this
machine**, not just kitty. It is the leg most likely to be forgotten, because losing it
fails quietly rather than loudly — the keys still do something, just the wrong thing.

B is not needed for this problem, though it remains the tidiest single place to solve
the Stream Deck issue if a udev rule proves insufficient.

---

## 8. Suggested order

1. ~~**Stream Deck udev rule.**~~ Done — see §3.
2. ~~**Finish the clipboard work.**~~ Done — `common/scripts/universal-clipboard` plus
   `common/kitty/kitty.conf`, verified in the live session. See §7.
3. **NVIDIA environment variables** into `[environment]`, and decide on early KMS in
   `mkinitcpio.conf`.
4. **Restore the shell.** `~/.bashrc` from the old disk, plus `eza`/`bat`/`zoxide`/
   `tmux`/`btop`/`mise`. This is the largest quality-of-life gap and it is pure copying.
5. **Application launchers and launch-or-focus.** Five old bindings need it, and the
   launcher keys are the most-missed muscle memory.
6. **Idle and lock timings**, and per-window opacity rules.
7. **Theme runner**, once there is something worth theming. ~40 lines of bash buys back
   26 hooks.
8. **Repo hygiene** — resolve `common/umbriel/config.toml` and the stale Noctalia
   snapshot.

---

## 9. The kitty config, line by line

The old `~/.config/kitty/kitty.conf` was 52 lines. It was ported deliberately rather
than copied, because three of its lines do not work on this machine and four served
Omarchy plumbing that no longer exists. Result: `common/kitty/kitty.conf`, symlinked to
`~/.config/kitty/kitty.conf`, parsing with zero warnings (verified by launching kitty
and capturing stderr).

**Ported — still useful**

| Line | Note |
|---|---|
| `font_size 9.0` | Chosen against a 3840x2160 panel at scale 1.5. Same panel, same scale, so rendering is unchanged. |
| `window_padding_width 14` | |
| `confirm_os_window_close 0` | |
| `map F11 toggle_fullscreen` | |
| `map ctrl+insert copy_to_clipboard` · `map shift+insert paste_from_clipboard` | The third leg of §7. |
| `map shift+enter send_text all \e[13;2u` | CSI-u so TUIs can distinguish Shift+Enter from Enter. |
| `map alt+shift+enter send_text all \e[13;4u` | CSI-u so tmux can match `M-S-Enter`. |
| `cursor_shape block` · `enable_audio_bell no` · `shell_integration no-cursor` | `no-cursor` is what stops shell integration overriding `cursor_shape`. |
| `mouse_hide_wait 0` | Never hide. Consistent with `[input.cursor] hide_timeout_ms = 0` in the Umbriel config and with the old `hyprland` `cursor.inactive_timeout = 0`. |
| tab bar block (4 lines) | |
| `BEGIN_KITTY_FONTS` block (4 lines) | `ttf-jetbrains-mono-nerd` is installed. |

**Dropped — Umbriel or Noctalia owns it now**

- `hide_window_decorations yes` — Umbriel sets `prefer_no_csd = true` and draws the
  border itself. Decoration policy is the compositor's.
- `include ~/.local/state/omarchy/current/theme/kitty.conf` — the Omarchy theme
  pipeline. Noctalia's template system can regenerate an equivalent once the theme
  runner is ported.
- `listen_on unix:${XDG_RUNTIME_DIR}/omarchy-kitty-{kitty_pid}` — existed so
  `omarchy-launch-terminal` could look up the cwd. That caller is gone, and the line was
  already inert with `allow_remote_control` commented out.

**Dropped — historical cruft**

- `# font_family CaskaydiaMono Nerd Font` and `# bold_italic_font auto` — commented out,
  superseded by the `BEGIN_KITTY_FONTS` block, and CaskaydiaMono is not installed.
- `# allow_remote_control yes` — commented out.

**Three lines that never worked, or no longer do**

These were found by launching kitty and reading its warnings, not by inspection:

- `mouse_selection_from_gutter yes` — **not a stock kitty option.** It comes from the
  local fork that still exists at `~/.local/opt/kitty-pete` on the old disk. Under kitty
  0.48.2 from `[extra]` it is an unknown key. **This is a real behaviour loss**: rebuild
  the fork, or let it go. It is the only item in the whole kitty port that is a genuine
  regression rather than a tidy-up.
- `window_padding_height 14` — never a stock option. `window_padding_width` takes
  CSS-style edges, so a single value already covers all four sides. This line was doing
  nothing on the old box either.
- `show_window_resize_notification no` — the option no longer exists; kitty dropped the
  resize notification upstream, so "no" is simply the current behaviour.

**Left off pending a decision**

- `single_instance yes` — grouped with `listen_on` under "Allow remote access", serving
  Omarchy's cwd lookup. That purpose is gone. It still buys fast window spawn, at the
  cost of every terminal sharing one process — including whatever is running an agent.
  Off by default; the trade is documented in the config.

---

*Prior context: `README.md`, `SUMMARY.md`, `01`–`05` and `raw/` in this directory.*
