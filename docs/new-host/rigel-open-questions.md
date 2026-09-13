# rigel — open questions for the caesar agent

**Written by the Claude instance on the laptop, before the wipe.** It is addressed to the
agent working on caesar, because the decision it asks for mutates `common/` — files caesar
is running live right now — and rigel's agent should not unilaterally change the shared
layer of a machine it cannot see or test.

Status: rigel is still on Omarchy 4.0.1. Phase 1 of `docs/new-host/README.md` is done and
`docs/new-host/rigel-survey.txt` is committed. `hosts/rigel/` is **not** written yet, and
question 1 below is why — it changes what that directory has to contain.

---

## Question 1 — `common/` hardcodes caesar's home path, and rigel is not caesar

This is the blocking one.

`common/` is by definition the layer shared by every host. Three files in it name
`/home/peter/Projects/nomarchy` as an absolute path, and two of those three are installed
on **every** host by `common/bootstrap/links`. On rigel the user is `peterlap` and the
checkout is `~/nomarchy`, so every one of those paths resolves to nothing.

### What is affected, verified by grep on this machine

Installed on every host via `common/bootstrap/links`:

| file | line | what |
|---|---|---|
| `common/bash/bashrc` | 29 | `export SSH_ASKPASS="/home/peter/Projects/nomarchy/common/scripts/askpass-fuzzel"` |
| `common/bash/bash_profile` | 40 | the same export |
| `common/bash/bashrc` | 47 | `alias edcfg='nvim ~/Projects/nomarchy/hosts/caesar/umbriel/config.toml'` |

Included by every host's umbriel config — `common/umbriel/base.toml`, 9 keybinds across 10
occurrences, at lines 276, 280, 281, 282, 307, 308, 309, 310 and 315:

```
"Print"   = "spawn:/home/peter/Projects/nomarchy/common/scripts/screenshot-region"
"Mod+C"   = "spawn:/home/peter/Projects/nomarchy/common/scripts/universal-clipboard copy"
"Mod+V"   = "spawn:/home/peter/Projects/nomarchy/common/scripts/universal-clipboard paste"
"Mod+X"   = "spawn:/home/peter/Projects/nomarchy/common/scripts/universal-clipboard cut"
"Mod+T"   = "spawn:.../launch-or-focus ^btop$ kitty --app-id=btop btop"
"Mod+D"   = "spawn:.../launch-or-focus ^lazydocker$ kitty --app-id=lazydocker lazydocker"
"Mod+O"   = "spawn:.../launch-or-focus obsidian$ obsidian"
"Mod+F"   = "spawn:.../launch-or-focus ^dev\.shelf\.Shelf$ shelf"
"Mod+M"   = "spawn:.../launch-or-focus ^Spotify$ .../spotify-limited"   # twice on one line
```

Not rigel's problem yet, but the same class: `common/systemd/backup-daily.service:14`,
`backup-legal-to-nas.service:14` and `subget-sync.service:35` all have an absolute
`ExecStart`. They are linked only by `hosts/caesar/bootstrap/links`, so rigel never
installs them — but the moment any host wants a timer out of `common/`, it inherits this.

`common/ssh/config` is clean. It is the one every-host file with no home path in it.

### Why this is worse than a broken path

The askpass case actively **falsifies the acceptance test in `docs/new-host/README.md`**.
Test 4 reads:

> Then `ssh-add` should prompt in **fuzzel**, not the terminal. If it prompts in the
> terminal, `SSH_ASKPASS_REQUIRE=prefer` has not reached the shell

On rigel both variables would reach the shell exactly as intended. `SSH_ASKPASS` would
simply name a file that does not exist, and the documented diagnostic points at the wrong
cause. The comment at `common/bash/bashrc:25-28` already warns about the mirror image of
this — "it looks like the askpass helper is broken when it has simply never been
consulted" — and the inverse now also applies: it looks like the variable never arrived
when the helper is simply absent.

rigel reproduced the shape of this live, which is better evidence than the reasoning above.
Stock ssh here has no askpass helper either, so `ssh -T git@github.com` says:

```
ssh_askpass: exec(/usr/lib/ssh/ssh-askpass): No such file or directory
git@github.com: Permission denied (publickey).
```

So the failure is **not** wholly silent — stderr names the missing path, and anyone who
reads it is one step from the cause. That is worth knowing before choosing a fix, and it
softens the case for urgency. What it does not settle is whether ssh falls back to a
terminal prompt when a TTY is present: that run had stdin on /dev/null and this tool shell
has no TTY at all. Test 4's stated diagnostic is still wrong either way, because it blames
`SSH_ASKPASS_REQUIRE` for a fault in `SSH_ASKPASS`. Confirming the TTY-present case against
a real fuzzel is a caesar job.

The nine keybinds fail in this repo's signature way: they register fine, `umbriel validate`
says `config: ok`, `umbriel msg cheatsheet-open` lists them, and pressing them does
nothing. `Super+C/V/X` and `Print` are in that set.

`bashrc:47` is a third flavour — it is not just the home path, it names `hosts/caesar/`
inside a file every host gets. On rigel `edcfg` would open the wrong machine's config.

### Options, with what I can and cannot verify from here

**umbriel is not installed on rigel** — this machine is still Hyprland — so anything about
umbriel's own behaviour has to be settled on caesar. That rules out my testing option A.

- **A. Scripts on `PATH`, referenced by bare name.** Link `common/scripts/*` into
  `~/.local/bin` from `common/bootstrap/links`, and reduce the binds to
  `spawn:universal-clipboard copy`. Removes every home path from `common/` outright.
  Depends entirely on whether umbriel's `spawn:` resolves through `PATH` (execvp) or
  demands an absolute path — **untestable from rigel, trivial to test on caesar.** If it
  does resolve `PATH`, this is the clean answer and it fixes the systemd units too.

- **B. A fixed system path.** One root-step per host symlinks the checkout to
  `/opt/nomarchy`; `common/` refers to `/opt/nomarchy/common/scripts/...` throughout.
  Works today with no assumptions about spawn semantics, and covers bash, umbriel and
  systemd identically. Costs a root step and gives the tree two names.

- **C. Standardise the home layout.** Require every host to clone to `~/Projects/nomarchy`.
  This does **not** actually solve it — `/home/peter` and `/home/peterlap` still differ —
  so it only helps for the `~/`-prefixed references like `bashrc:47`. Recording it as
  considered and rejected unless someone sees something I do not.

- **D. Defer.** Write `hosts/rigel/` now, leave `common/` alone, and treat this as known
  post-install breakage. Cheapest now, but it means rigel's first boot has four dead
  keybinds and a misleading askpass diagnosis, which is precisely the trap `CLAUDE.md`
  says has cost real hours twice.

My read is **A if caesar confirms `spawn:` uses `PATH`, otherwise B**, with `bashrc:47`
fixed separately either way since it is a host-name bug rather than a path bug. But the
decision is caesar's, and so is the test.

---

## Not questions — rigel findings that change `docs/new-host/README.md`

These need no decision from caesar; they are recorded because the guide currently asserts
otherwise and the next reader should not be misled.

- **rigel has an NVIDIA GPU.** `CLAUDE.md` says the laptop has "no NVIDIA" and the guide
  says anything NVIDIA must not appear in `hosts/rigel/`. It is hybrid: Intel Iris Xe
  (Alder Lake-P) plus a GeForce RTX 3050 Ti Mobile, with `nvidia-open-dkms` installed and
  `nvidia_drm`/`nvidia_modeset` loaded. §10 of the post-install audit is therefore
  relevant — but its verdicts were measured on caesar's single desktop card, and hybrid
  laptop graphics is a different question. Not inheriting those conclusions untested.
- **The internal panel reports as `eDP-2`, not `eDP-1`**, at 2560x1600, with `eDP-1`
  disconnected — the two DRM cards enumerating separately under hybrid graphics. The
  `[output.*]` name cannot be confirmed until umbriel runs.
- **Backlight is `nvidia_wmi_ec_backlight`**, not `intel_backlight`. `brightnessctl` with
  no `-d` selects by heuristic, which is another silent no-op waiting to happen.
- The disk is **already** btrfs on LUKS, with limine and snapper. Phase 4 is not new
  ground; the current subvolume layout is worth capturing before it is overwritten.
- rigel is a Dell — `Dell Privacy Driver`, `Dell WMI hotkeys`, and a `DELL0B9B` touchpad.
  `[input.touchpad]` in the base has never run against real hardware.
