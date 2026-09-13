# rigel — where this stands

A resumption point, written 2026-09-13 while rigel is still on Omarchy and Pete is
travelling with an Arch ISO on USB. Read this first if you are picking the work back up.

## ⚠ The one thing that must not go wrong

**Everything in this repo must be pushed before rigel is wiped.** That is the entire point
of the sequence in `README.md`, and rigel is now within arm's reach of an install USB.

```bash
git status -sb          # must read: ## master...origin/master   (no "ahead")
```

If it says *ahead*, push before touching the installer. `~/.ssh/id_ed25519` is registered
on GitHub as "laptop" and is passphrase-protected; the agent needs `ssh-add` once per boot,
in a real terminal. `gh` is authenticated with a token carrying `repo` scope, so
`gh auth setup-git` is the route that needs no passphrase.

Nothing is recoverable from the old disk afterwards unless it was kept — and keeping it is
worth doing. caesar's old install has been mounted read-only for months and consulted most
days.

## Where the work actually is

| done | |
|---|---|
| Phase 1, survey | `rigel-survey.txt` — committed, and **scrubbed** of wifi names, MACs and tailnet identity in `84e5128` |
| Phase 1, Omarchy sweep | `rigel-omarchy-sweep.md` — the graphics investigation, laptop layer, package separation |
| The `common/` blocker | Raised in `rigel-open-questions.md`, answered and fixed by caesar in `5e9d123` |

| Phase 2, `hosts/rigel/` | **Written.** Seven files; `common/scripts/bootstrap rigel` parses it and prints a clean plan |

| not done | |
|---|---|
| **The lid decision** | The one substantive hole in `hosts/rigel/`. See below |
| Phase 3 — push | Do it before the USB goes in |
| Phases 4–5 | Pete's install, then bootstrap |

## The install, in the terms the installer asks for

Settled: the user is **`peter`** (same as caesar, which is why the umbriel include path
`~/Projects/nomarchy/...` resolves identically on both), locale `en_US.UTF-8`, keymap `us`,
timezone `America/Indianapolis`.

The **old** subvolume layout, recorded because it dies with the partition table and is a
reasonable shape to repeat — it is also what caesar's old disk used:

```
@       -> /
@home   -> /home
@pkg    -> /var/cache/pacman/pkg
@log    -> /var/log
mount options: rw,relatime,compress=zstd:3,ssd,space_cache=v2
/boot   -> a separate 2G vfat ESP
```

The old UUIDs are not worth recording: they die with the disk. Capture the *new* LUKS
container UUID, filesystem UUIDs, `/etc/fstab` and `/etc/crypttab` into `hosts/rigel/`
after installing — publishing UUIDs in this public repo is settled policy.

**Do not install `sddm`.** tty1 autologin is load-bearing, for the PATH reason below.

## rigel has a NAS, which the guide did not expect

The guide says the NAS is caesar's and must not appear in `hosts/rigel/`. That was wrong.
rigel reaches the **same** NAS (`192.168.1.208`), but over **CIFS** rather than caesar's
NFS — and it works from off-site, because Tailscale makes that LAN appear local. Verified
from another house: 31 ms, and the automount triggered and listed the shares.

So `cifs-utils` is in `hosts/rigel/packages/repo.txt`, and the two fstab lines plus the
`/mnt/nas` directories are in `bootstrap/root-steps`. **`/etc/nas-creds` is a credential
file and never enters this repo** — same category as `~/.config/subliminal/subliminal.toml`
and `~/vpn/nord/`. It is root-only `0600` and must be recreated by hand.

## What the install needs to be

Settled in conversation, not derivable from the tree:

- **btrfs on LUKS.** Pete partitions and installs by hand.
- **tty1 autologin, and no display manager.** This is load-bearing, not cosmetic: it is how
  `~/.local/bin` reaches umbriel's `PATH`, and every script bind is a bare name now. An
  sddm session would leave nine keybinds registering, validating, and doing nothing.
- **`[multilib]` enabled before the bootstrap's package step**, or it fails on
  `lib32-nvidia-utils` and `steam`. It is enabled on rigel today only because Omarchy did
  it; a fresh install has it commented out.
- Record afterwards, into `hosts/rigel/`: the LUKS container UUID, filesystem UUIDs, the
  subvolume layout, `/etc/fstab` and `/etc/crypttab`. Publishing UUIDs here is settled
  policy.

## The open decisions, none of them blocking

1. **The NVIDIA stack.** Install the driver (`nvidia-open-dkms`, `nvidia-utils`,
   `lib32-nvidia-utils`, `libva-nvidia-driver`) — steam, moonlight, obs and kdenlive want
   it. Do **not** pre-set `LIBVA_DRIVER_NAME`; the Intel default is correct on a machine
   where Intel drives the panel. Whether to constrain what umbriel opens is a *measurement
   after install*, not a decision now: check umbriel's `/proc/<pid>/fd` and the dGPU's
   `power/runtime_suspended_time`, and only then consider `WLR_DRM_DEVICES` — never by
   `cardN`, never by a `by-path` name full of colons.
2. **The 48 packages** (plus one yes/no on the 39-package retroarch block). Listed in the
   sweep. `1password` and `signal-desktop` are on it only because they are installed; §4
   already settled that neither is wanted.
3. **Lid ownership — the one with a security edge.** Pick exactly one owner: logind with
   something locking on `PrepareForSleep`, or umbriel's `[events]` hooks with logind still
   set to ignore the lid. Never both. Noctalia's `lock-and-suspend` is an *idle* behaviour
   and a lid close does not pass through it, so this gap is real. The test is physical:
   close the lid, open it, and it must be locked.
4. **snapper and the bootloader.** Omarchy chose limine + snapper. Dropping them purely
   because Omarchy chose them inverts the rule. Choose on merit.

## Things that will bite if forgotten

- **`sed -i` detaches symlinks.** Every deployed config here is a symlink into the repo.
- **A probe window tests the file, not the session.** Verify against the live session.
- **Any terminal added to a nomarchy host needs the `ctrl+insert` / `shift+insert`
  mappings**, or `Super+C` is a silent no-op in it. Relevant because `alacritty` and
  `cool-retro-term` are both on the package list.
- **Anything published off rigel gets a privacy check first.** The survey already leaked
  three wifi names, both MACs and the tailnet identity into a public repo. Fixed at the
  tip; still in history at `c1c5fdd`, which is Pete's call to rewrite or leave.
- `brightnessctl` needs `-d nvidia_wmi_ec_backlight`. There is no `intel_backlight` here
  despite Intel driving the panel.
- The panel enumerates as **`eDP-2`**, not `eDP-1`. Confirm with `umbriel outputs` before
  writing the `[output.*]` block.

## Conversation state

Two agents are working this: rigel's (here, pre-wipe) and caesar's (which owns `common/`).
They talk through `rigel-open-questions.md`, which now carries rigel's questions, caesar's
answers, and caesar's review of the sweep. Both of caesar's corrections to the sweep were
checked on rigel and were right — `modeset=1` is the driver's own default, and `[multilib]`
is a real gap. That file is the thread; append to it rather than starting a new one.
