# Packages

291 explicitly-installed packages; 6 foreign/AUR (`glibc-debug`, `nuclei`,
`omnote-git`, `opendeck-bin`, `openssl-1.1`, `paru`). Repos: core, extra, multilib,
**omarchy**. Full list in `raw/pkgs-explicit.txt`.

---

## 1. What you install on the Dell

```
# compositor + shell
umbriel-git  xdg-desktop-portal-umbriel-git  noctalia-git  xwayland-satellite
# optional login
noctalia-greeter        # greetd-based; or keep sddm
# optional
noctalia-unofficial-auth-agent-git   # polkit agent + keyring prompter
```

All four are maintained by the same upstream org, `noctalia-dev`. `umbriel-git` pulls
`wlroots0.20`; neither project depends on Qt or Quickshell.

## 2. The 12 `hypr*` packages you drop

`hyprland` · `hyprcursor` · `hyprgraphics` · `hyprland-guiutils` ·
`hyprland-preview-share-picker` · `hyprlang` · `hyprpicker` · `hyprsunset` ·
`hyprtoolkit` · `hyprutils` · `hyprwayland-scanner` · `hyprwire`

Only two are depended on by anything: `hyprland-preview-share-picker` and `omarchy`
itself. Two need functional replacements:

- `hyprsunset` → `wlsunset` or `gammastep` (⚠️ or Noctalia's own night light)
- `hyprpicker` → Noctalia colour picker; **the screen-freeze use in
  `omarchy-capture-region` / `-qr` needs a separate answer**

## 3. The 33 `[omarchy]`-repo packages — where each comes from afterwards

**Re-source from AUR or official repos (all still available):**

| Package | After |
|---|---|
| `1password`, `1password-cli` | AgileBits' own repo, or AUR |
| `spotify`, `typora`, `localsend`, `gpu-screen-recorder`, `pinta`, `asdcontrol` | AUR |
| `mise-bin`, `yay`, `tzupdate`, `ufw-docker`, `xdg-terminal-exec`, `walker` | AUR |
| `limine-mkinitcpio-hook`, `limine-snapper-sync` | AUR — **keep, your snapshot boot depends on these** |
| `ttf-jetbrains-mono-nerd-basic`, `ttf-ia-writer`, `ttfx`, `yaru-icon-theme` | AUR / extra |

**Omacom (DHH-adjacent) apps — decide individually:**
`aether` · `cliamp` · `herdr` · `omacalc` · `omacut` · `omawrite` · `omarchy-nvim` ·
`tensaku` · `tobi-try`

You have theme hooks and bindings referencing `cliamp` and `herdr`, so those two are in
active use. If leaving the ecosystem is the point, these are where the decision
actually lands — they're small, replaceable tools, but they're the ones you'd be
choosing to keep.

**Dropped outright:** `omarchy`, `omarchy-settings`, `omarchy-keyring`,
`hyprland-preview-share-picker`.

**Not from that repo, and stays yours:** `omnote-git` — that's your own project
(`~/code/OmNote`).

## 4. Keeps — compositor-agnostic, reinstall as-is

**Capture/desktop:** `grim` `slurp` `wl-clipboard` `wtype` `tesseract`
`tesseract-data-eng` `zbar` `qrencode` `brightnessctl` `pamixer` `imv` `mpv`
`gpu-screen-recorder` `obs-studio` `udiskie` `wev`

**Audio/session:** `pipewire{,-alsa,-jack,-pulse}` `wireplumber` `gst-plugin-pipewire`
`uwsm` `xdg-desktop-portal-gtk` `gnome-keyring` `seahorse` `libsecret`
`power-profiles-daemon`

**Boot/FS:** `limine` `snapper` `btrfs-progs` `plymouth` `sddm` `zram-generator`
`kernel-modules-hook`

**Input:** `fcitx5` `fcitx5-gtk` `fcitx5-qt`

**Toolchain/CLI (~120 pkgs):** neovim, git, docker, qemu, rust, go, ruby, npm,
postgresql, ripgrep, fd, fzf, bat, eza, zoxide, starship, tmux, yazi, btop, lazygit,
lazydocker, nmap, tcpdump, termshark, wireshark-adjacent tooling, etc. None of this is
affected by the move.

**Theming targets referenced by your 30 hooks** — install these on the new box or the
hooks no-op (each one guards with `command -v`): `fish` `fzf` `qt6ct` `spicetify`
`superfile` `tmux` `vicinae` `typora` `nwg-dock-hyprland`(❌ Hyprland-only) `zed`
`swaync` `foot` `cursor` `code` `windsurf` `obsidian` `cava` `firefox` `qutebrowser`
`steam` `zen-browser` `cliamp` `heroic` `discord`/vesktop.

## 5. NVIDIA note

Caesar: `nvidia-open-dkms` `nvidia-utils` `lib32-nvidia-utils` `libva-nvidia-driver`
`egl-wayland`, with the three env vars hard-coded in `hyprland.lua` as a quattro
workaround. An ex-enterprise Dell almost certainly has integrated Intel/AMD graphics —
**so the testbed will not exercise the NVIDIA path at all.** Do not treat a working
Dell as evidence caesar will work.
