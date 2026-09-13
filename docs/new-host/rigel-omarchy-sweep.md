# rigel — the Omarchy layer, swept before the wipe

Phase 1 of `docs/new-host/README.md` asks for a sweep of the Omarchy-specific layer that
`common/scripts/host-survey` does not cover. This is that sweep, run on rigel's live
Omarchy 4.0.1 install.

**These are notes, not a plan.** Nothing here is a recommendation to carry something over.
The standing instruction is that old config tells you what to investigate, never what to
copy, and the point of writing it down now is that most of it stops being observable the
moment the disk is repartitioned. Where something was measured, the measurement is given.
Where it was not, that is said.

**Read everything below in three layers, because they are easy to conflate and the whole
exercise fails if they are.**

| layer | who owns it | what happens to it |
|---|---|---|
| **NOW** — Omarchy 4.0.1 as it currently sits on this disk | Omarchy's installer | **Dies with the wipe.** Evidence only; nothing here is inherited |
| **The base Arch install** | Pete, by hand | Partitioning, LUKS, btrfs subvolumes, bootloader, kernel, microcode, tty1 autologin |
| **The nomarchy target** | `common/` + `hosts/rigel/`, laid down by the bootstrap | The only layer this repo declares |

A fact about the current machine is evidence about hardware, never a specification. The
running install is Omarchy's opinion about this hardware; the target is a deliberate one.

---

## 1. Graphics — what Omarchy actually does, and what it costs

Pete's question was what Omarchy does here *now*, given that the current behaviour is
fine. The answer is short, and most of what looks like NVIDIA configuration on this
machine is already dead.

### Topology, measured

| PCI | Device | DRM card | render node | drives |
|---|---|---|---|---|
| `0000:00:02.0` | Intel Iris Xe (Alder Lake-P) | `card2` | `renderD129` | **eDP-2, the only connected output** |
| `0000:01:00.0` | NVIDIA RTX 3050 Ti Mobile | `card1` | `renderD128` | nothing |

`boot_vga=1` is on the Intel device. Note the numbering is the inverse of caesar's, where
NVIDIA is `card2`/`renderD129` — which is exactly why §10's node numbers must not be read
across to this machine.

### Every real client is on the Intel node

Read out of `/proc/*/fd`, the technique §10 used:

```
firefox            /dev/dri/renderD129      (Intel)
RDD Process        /dev/dri/renderD129      (Intel)   <- Firefox's video decoder
kitty              /dev/dri/renderD129
quickshell         /dev/dri/renderD129
xdg-desktop-por    /dev/dri/renderD129
Xwayland           /dev/dri/renderD129
Hyprland           card1 card2 renderD128 renderD129 /dev/nvidia0 /dev/nvidiactl
1password          renderD128 renderD129 /dev/nvidia0 /dev/nvidiactl /dev/nvidia-uvm
```

### What Omarchy Quattro sets, in full

`/usr/share/omarchy/default/hypr/nvidia.lua`, reached via `default/hypr/envs.lua`. It
detects the card from cached sysfs IDs and branches on GSP firmware:

```lua
if nvidia and gsp then
  NVD_BACKEND=direct;  LIBVA_DRIVER_NAME=nvidia;  __GLX_VENDOR_LIBRARY_NAME=nvidia
elseif nvidia and not gsp then
  NVD_BACKEND=egl;                                __GLX_VENDOR_LIBRARY_NAME=nvidia
end
```

The GSP branch fired here, and those three are exactly what a child process of the session
inherits — verified by reading the environment of a shell spawned from the session. That
is Omarchy's entire modern NVIDIA treatment, plus `/etc/modprobe.d/nvidia.conf`
(`options nvidia_drm modeset=1`) and the four nvidia modules in `mkinitcpio.conf`.

Its own comment is worth keeping: the detectors read sysfs rather than shelling out to
`lspci`, because `lspci` reads PCI config space, which resumes a runtime-suspended GPU,
and on a hybrid laptop that wake outlasts Hyprland's config-reload budget.

### `~/.config/hypr/envs.conf` is dead config

It still carries the Omarchy 3 block:

```
# Force Hyprland to use NVIDIA GPU
env = WLR_DRM_DEVICES,/dev/dri/card0
env = GBM_BACKEND,nvidia-drm
env = WLR_NO_HARDWARE_CURSORS,1
env = __VK_LAYER_NV_optimus,NVIDIA_only
env = __NV_PRIME_RENDER_OFFLOAD,1
env = __NV_PRIME_RENDER_OFFLOAD_PROVIDER,NVIDIA-G0
```

**`/dev/dri/card0` does not exist on this machine** — the nodes are `card1` and `card2` —
so the line whose comment says "force NVIDIA" names nothing at all, and would not name
NVIDIA even if it resolved. None of these six reach the session: `hyprland.conf` sources
`envs.conf`, but `hyprland.conf` is itself superseded by `hyprland.lua` under Quattro.

This was already found and written down during the Quattro upgrade —
`~/.config/hypr/hyprland.lua:34-42` records the same three points, including that
`WLR_NO_HARDWARE_CURSORS` has been a no-op in modern Hyprland for a while. Re-deriving it
here only confirms it. Under Umbriel the file has no successor and nothing to port.

### The one that is not a no-op — and a hypothesis that testing overturned

§10 concluded on caesar that all three variables are **redundant**, because the Wayland
compositor advertises the NVIDIA render node through dmabuf feedback and both libva and
libglvnd follow it. The mechanism is sound. On rigel it points the other way: the
compositor advertises **Intel**, because Intel drives the only panel.

The prediction from that was that `LIBVA_DRIVER_NAME=nvidia` would *break* VA-API here —
the nvidia driver handed an i915 fd should fail to initialise. **That is wrong.** Measured
against the Intel node that every client actually holds:

```
$ LIBVA_DRIVER_NAME=nvidia ffmpeg -init_hw_device vaapi=va:/dev/dri/renderD129 ...
  libva: Trying to open /usr/lib/dri/nvidia_drv_video.so
  libva: va_openDriver() returns 0
  VAAPI driver: VA-API NVDEC driver [direct backend].

$ LIBVA_DRIVER_NAME=iHD ...
  VAAPI driver: Intel iHD driver for Intel(R) Gen Graphics - 26.2.4
```

Both succeed. The NVDEC driver is a *direct backend* — it reaches the GPU itself rather
than through the fd it was handed, so the fd's vendor does not constrain it. A control run
with a deliberately bogus driver name returns `va_openDriver() returns -1` and
`Failed to initialise VAAPI connection`, which is what makes the two passes above
meaningful rather than vacuous.

So on rigel `LIBVA_DRIVER_NAME=nvidia` is **neither redundant nor broken: it reroutes**.
Video decode that would land on the Intel iGPU is sent to NVDEC on the discrete card
instead. caesar's verdict of "redundant" is correct for caesar and does not transfer.

### The finding that actually matters for a laptop

The discrete GPU is not idle-parked. Runtime PM is enabled (`power/control` = `auto`), and
still:

```
uptime            1796080 ms   (0.5 h)
dGPU suspended         803 ms
dGPU active        1794984 ms
                  -> asleep for 0.045% of uptime
```

Nothing about that is VA-API's doing. **Hyprland holds `/dev/nvidia0` and `/dev/nvidiactl`
open for the life of the session**, and 1password holds those plus `/dev/nvidia-uvm`, so
the card can never reach runtime suspend. `nvidia_drm modeset=1` plus the modules in the
initramfs is what puts it in front of the compositor to be opened in the first place.

Not measured: what that costs in watts. `BAT0` on this machine exposes no
`POWER_SUPPLY_POWER_NOW`, and it was charging throughout, so any number now would be
meaningless. Measuring it properly wants a discharge test, which is a post-install job.

The open question for rigel is therefore **not** which env vars to set. It is whether
Umbriel also opens every DRM node it enumerates, and whether a machine whose only panel is
Intel-driven wants `nvidia_drm modeset=1` and the nvidia modules in its initramfs at all.
That is testable only once Umbriel runs, and it should be tested rather than assumed in
either direction — the dGPU is wanted for steam, moonlight, obs and kdenlive, so "drop
NVIDIA" is not the answer either.

### Where all of it came from, and why that matters

`/usr/share/omarchy/install/hardware/nvidia.sh` is the whole provenance, and its trigger is
one line:

```sh
if lspci | grep -qi 'nvidia'; then
```

Presence of the card, nothing more. It does not ask whether NVIDIA drives a display. On
this machine it then installed `nvidia-open-dkms nvidia-utils lib32-nvidia-utils
libva-nvidia-driver` and wrote both files that shape the boot:

```sh
/etc/modprobe.d/nvidia.conf       -> options nvidia_drm modeset=1
/etc/mkinitcpio.conf.d/nvidia.conf -> MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

That closes the causal chain measured above:

```
lspci sees an NVIDIA card
  -> early KMS + nvidia_drm modeset=1
    -> the nvidia DRM node exists at boot, in front of the compositor
      -> Hyprland opens /dev/nvidia0 and holds it for the session
        -> the dGPU never reaches runtime suspend (asleep 0.045% of uptime)
```

Nothing in that chain is wrong for a machine where NVIDIA drives the panel. Every step of
it was decided on rigel by `grep -qi nvidia`, on a machine where Intel drives the only
panel. **This is the single clearest example on the box of a default that was never a
decision** — and it belongs to the *base install* layer, not to anything this repo
declares, so it is Pete's call during the Arch install rather than a `hosts/rigel/` entry.

---

## 2. The laptop hardware layer

- **logind hands the lid to the compositor, not to systemd.** `/etc/systemd/logind.conf`
  sets `HandleLidSwitch=ignore`, `HandleLidSwitchExternalPower=ignore`,
  `HandleLidSwitchDocked=ignore` and `HandlePowerKey=ignore`. This is directly relevant
  to Umbriel's `[events]` lid hooks, which the base config leaves commented and which
  rigel is the first host to want: if logind keeps ignoring the lid, the hooks are the
  only thing handling it; if it does not, they fight.
- `logind.conf.d/20-inhibit-delay.conf` sets `InhibitDelayMaxSec=15`, which exists to give
  `omarchy-sleep-lock` time to lock before suspend.
- **Backlight has exactly one device, `nvidia_wmi_ec_backlight`** — no `intel_backlight`,
  despite Intel driving the panel. A Dell + hybrid quirk. `brightnessctl` with no `-d`
  picks by heuristic, so this wants pinning explicitly.
- **No fingerprint reader.** No `fprintd`, nothing matching on USB. Settled, needs nothing.
- Three power daemons are enabled at once: `power-profiles-daemon` (currently `balanced`,
  3 profiles), `thermald`, and `intel_lpmd`. Whether all three are wanted together is a
  question, not a finding.

## 3. Omarchy's user units — what each is for

Worth reading before deciding, because several are laptop-shaped and this repo has no
equivalent for any of them:

| unit | description |
|---|---|
| `omarchy-sleep-lock` | Lock before suspend. Noctalia owns locking now; the *before suspend* part still needs an owner |
| `omarchy-recover-internal-monitor` | Recover the internal monitor toggle when no external display is connected. Pure laptop |
| `omarchy-crash-watch` | Announce process crashes and offer an AI diagnosis |
| `omarchy-tailscale-receive` | Save incoming Taildrop files to the downloads directory |
| `omarchy-fcitx5` | fcitx5 for XCompose sequences |
| `bt-agent` | Bluetooth pairing agent, `-c NoInputNoOutput` |

`syncthing` is also enabled and is not Omarchy's.

## 4. `~/.local/bin` and the hooks

`~/.local/bin` is 19 entries and almost entirely Pete's own tooling — agent CLIs (`claude`,
`codex`, `copilot`, `crush`, `gemini`, `grok`, `opencode`, `pi`), `gh`, `pnpm`/`pnpx`,
`playwright`, plus `ghui`, `hunk`, `micropad`, `omnote`, `omp`. The only Omarchy-owned
entry is `omarchy-menu`. None of it is config; it is either reinstalled by its own tool or
it is a personal script that wants a home.

Under `~/.config/omarchy/hooks/` nearly everything is a `.sample` and therefore inert. Two
are real:

- **`hooks/theme-set`** — a substantial piece of Pete's own work, not Omarchy's. It reads
  the rendered `alacritty.toml` as the source of truth for the 16-colour ANSI set (because
  Quattro's `colors.toml` went semantic and dropped `color0`–`color15`), exports the
  palette, and drives 26 `theme-hooks.d/*.sh` scripts. Its own comments record two traps
  worth keeping: matching has to be section-aware because `alacritty.toml` reuses key
  names across `[colors.normal]` and `[colors.bright]`, and the hooks deliberately live
  outside `hooks/` because Quattro's `omarchy-hook` runs `hooks/<name>` *and* globs
  `hooks/<name>.d/*`, which ran everything twice. Noctalia owns theming now, so this is
  reference rather than something to port — but it is the most substantial custom thing
  on the machine.
- **`hooks/post-update.d/setup-agent.hook`** — a one-time "set your default agent"
  invitation. Omarchy-specific, nothing to carry.

## 5. Packages — separated by layer

The earlier reading of this ("~180 applications to curate") was wrong, because it
subtracted only `common/` and never asked which packages Omarchy chose rather than Pete.
Omarchy ships its own manifest at `/usr/share/omarchy/install/*.packages`, so the question
is answerable by subtraction rather than judgement.

```
rigel explicit                        280
  declared by Omarchy's own manifest  175   <- NOW layer; dies with the wipe
  Pete's own additions                105
    omarchy leftovers (omarchy,
    omarchy-keyring, -settings,
    walker, hyprshot)                   5   <- also dies
    already declared by common/        13   <- bootstrap installs these anyway
    genuinely new                      87
      the retroarch/libretro block     39   <- ONE decision, not thirty-nine
      everything else                  48   <- the actual decision list
```

So the real question is **48 packages**, plus one yes/no on emulation.

### Layer 2 — the base Arch install (Pete's, not this repo's)

Decided at install time and mostly not a manifest entry at all: partitioning, the LUKS
container, the btrfs subvolume layout, the bootloader, the kernel, `intel-ucode`, and
tty1 autologin. `common/packages/repo.txt` already declares `base`, `base-devel`, `linux`,
`linux-firmware`, `linux-headers`, `sudo`, `git`, `openssh`, `networkmanager`,
`efibootmgr`, `btrfs-progs` and `ufw`, so those are covered by the target rather than
needing a host entry — `pacman -S --needed` is a no-op on anything pacstrap already put
down.

Two things from the NOW layer are Omarchy's choices and should not be assumed into the
install: **`sddm` and `plymouth`** (rigel goes tty1 autologin, so sddm has no role), and
**`limine` + `snapper` + `limine-snapper-sync`** (Omarchy's bootloader and snapshot
opinion — a fresh install is free to make a different one).

### Layer 3 — what `hosts/rigel/packages/repo.txt` should declare

Hardware and role, following caesar's file as a shape rather than a source:

```
intel-ucode                                    # microcode, machine-specific by definition
intel-media-driver  vpl-gpu-rt  vulkan-intel   # the GPU that actually drives the panel
nvidia-open-dkms  nvidia-utils                 # the dGPU, wanted for steam/moonlight/obs
lib32-nvidia-utils  libva-nvidia-driver
brightnessctl                                  # and it needs -d nvidia_wmi_ec_backlight
power-profiles-daemon  thermald  intel-lpmd    # all three enabled now; is that wanted?
tailscale
bluez  bluez-utils  bluez-tools
wireless-regdb  sof-firmware
```

The NVIDIA entries buy the *driver*. They do not require `nvidia_drm modeset=1` or the
initramfs modules, and per the provenance above those should be a tested decision on the
new install rather than a copied one.

### The 48, for a separate pass

Not listed here as a recommendation — listed so none is forgotten:

```
1password 1password-cli 7zip adw-gtk-theme alacritty arduino-ide-bin bind cmake-extras
cool-retro-term dmidecode dotnet-runtime-9.0 fwupd glew glfw glm gobject-introspection
libqalculate minipro mypy nano net-tools nmap noto-fonts-extra php postgresql qt5-wayland
restic ruff rust signal-desktop spotify steam syncthing tor torbrowser-launcher tree
ttf-cascadia-mono-nerd turbostat typora uv valkey virt-viewer wev wl-clip-persist
xmlstarlet yq
```

`1password` and `signal-desktop` are on that list because they are installed, and §4 of
the post-install audit already settled that neither is wanted. `alacritty` and
`cool-retro-term` are terminals, and CLAUDE.md's universal-clipboard note applies to any
terminal added to a nomarchy host: without the `ctrl+insert`/`shift+insert` mappings,
`Super+C` is a silent no-op there.

Only **5** of rigel's packages are AUR: `arduino-ide-bin`, `libretro-bsnes2014`,
`libretro-mame2016`, `minipro`, `retroarch-assets-git` — and 3 of those are inside the
emulation block, so the emulation yes/no decides most of `packages/aur.txt` too.

## 6. Cruft found along the way

Small things, recorded because they are evidence of how defaults accumulate:

- `/proc/cmdline` contains `quiet splash` **twice** and `initramfs_async=0` **twice**.
- `/etc/modprobe.d/disable-usb-autosuspend.conf` and
  `/etc/modprobe.d/omarchy-usb-autosuspend.conf` are byte-identical
  (`options usbcore autosuspend=-1`).
- `HandlePowerKey=ignore` is set in both `/etc/systemd/logind.conf` and
  `logind.conf.d/10-ignore-power-button.conf`.
- `/etc/modprobe.d/hid_apple.conf` sets `fnmode=2`, but the keyboards present are the
  built-in AT set and a Darfon `0d62:3740`. No Apple keyboard on this machine.
- `~/.config/hypr/` holds 14 `.bak` files from three separate upgrade generations.
