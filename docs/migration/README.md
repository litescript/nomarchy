# Omarchy → Noctalia/Umbriel migration audit

Read-only audit of **caesar** (Omarchy 4.0.3 "quattro", kernel 7.2.3-arch1-3), taken
2026-09-09. Nothing on this machine was modified.

| File | What's in it |
|---|---|
| `01-what-omarchy-provides.md` | The full surface area you're actually replacing |
| `02-gap-analysis.md` | Component-by-component map to Umbriel + Noctalia |
| `03-carry-over.md` | Your own config — what to salvage before you wipe anything |
| `04-packages.md` | Package manifests and where each thing comes from after the move |
| `05-waylab-testbed.md` | The Dell testbed, audited — and every open question answered |
| `SUMMARY.md` | Short version, written for reading on your phone |
| `raw/` | Machine-generated lists referenced by the above |

---

## The short version

You are replacing **two independent things**, and it's worth keeping them separate in
your head because they fail differently:

**1. Hyprland (Vaxry).** 12 installed `hypr*` packages. This is a clean swap —
Umbriel is a wlroots C++23 compositor with scrolling/dwindle/master layouts, blur,
shadows, rounded corners, animations, per-output workspaces, named scratchpads, window
rules and an overview. It ships its own portal backend
(`xdg-desktop-portal-umbriel`). Functionally this covers nearly everything your
Hyprland config does. The cost is a **config rewrite** (Lua → TOML) and two real
feature losses (screen shaders, window groups).

**2. Omarchy (DHH / Basecamp).** This is much bigger than the desktop. It is
**441 `omarchy-*` CLI commands**, a Quickshell desktop shell, 22 themes with a
templating engine, a 333-entry system menu, a pacman repo, boot/snapshot integration,
hardware quirk profiles, and an update system. Noctalia replaces the *shell* part of
this well. Nothing replaces the *distro-management* part — after the move, that's
`pacman`, `paru` and your own scripts.

**The migration is not "install two packages."** It's roughly:

- ~2 hours: compositor config rewrite (bindings, monitors, input, window rules)
- ~2–4 hours: theme pipeline (you have 30 hand-maintained hooks; they're portable)
- ~half a day: rebuild or drop your two custom shell plugins (see caveat below)
- ongoing: decide which of the 441 `omarchy-*` commands you actually miss

## One finding that changes the plan

**Noctalia is no longer a Quickshell/QML shell.** Current `noctalia-git` (5.x) builds
against cairo, pango, wayland, tomlplusplus, sdbus-cpp, pam — **no Qt, no Quickshell**.

Your two custom shell plugins, `peter.lock` and `peter.emojis`, are QML
(`LockView.qml`, `Emojis.qml`, `Service.qml`). **They will not port.** They have to be
rebuilt against Noctalia's own plugin system, or replaced with stock Noctalia
equivalents. Budget for that, or decide up front you're dropping them.

## Risk worth naming

Noctalia, Umbriel, `xdg-desktop-portal-umbriel` and `noctalia-greeter` are all from the
same upstream (`noctalia-dev`). You'd be consolidating onto one org rather than
diversifying away from one.

The maturity picture is better than I first thought, though: **Noctalia 5.0.1 is in
Arch `[extra]`** — an officially packaged Arch package, not AUR. Umbriel is the young
half (AUR git build, version 0.1.0), and its README states plainly that "configuration
keys, keybinds, and behavior may change between releases." That's the actual risk in
this move — churn, not ethics — and it argues for keeping caesar on Omarchy until
waylab has survived a few Umbriel releases.

---

## Suggested order of work

1. **Salvage first, on caesar, while everything still runs.** `03-carry-over.md` Tier 1.
   In particular: diff your two QML plugins against stock, and run
   `omarchy-theme-colors-from-alacritty` over the 20 stale themes you want to keep.
2. **On the Dell: prove the compositor.** Bindings, monitors, input, window rules.
   Specifically test per-device disable (Stream Deck) and fractional scaling.
3. **Port the theme runner.** ~40 lines of bash to export the colour vars and run
   `theme-set.d/`. This buys back 30 themed apps in one move.
4. **Rebuild launch-or-focus.** Five of your keybindings depend on it.
5. **Then decide** which of the 441 `omarchy-*` commands you actually miss. You will
   discover this by missing them, not by reading the list.

## Open questions — now answered

All of these were resolved by auditing waylab. Full detail in `05-waylab-testbed.md`.

- Per-device disable (Stream Deck): **no Umbriel equivalent** — needs a udev rule. This
  is the one genuine blocker; test it before caesar moves.
- Night light, colour picker, emoji picker, screenshots: **all covered** (native or
  community plugin).
- Fractional scaling at 4K/160 Hz: **still untested** — waylab runs one 1440p panel at 1×.
- Window grouping and Hyprland screen shaders: **confirmed gone.**
- Per-window opacity and VRR: **supported, and cleaner than what you fight today.**

Still genuinely unknown: whether Noctalia's emoji picker does insert-at-cursor, and
which of the Omacom apps (`cliamp`, `herdr`, `aether`, `omacut`, `omawrite`, `tensaku`,
`omacalc`, `tobi-try`, `omarchy-nvim`) you want to keep — two are wired into your
current config, and Noctalia ships a `herdr` theming template.
