# Nomarchy

Nomarchy is not a Linux distribution. It's an opinionated Arch configuration.

The opinions are mine.

## Architecture

- Arch owns the operating system.
- Umbriel owns composition.
- Noctalia owns the desktop shell.
- Small Unix/Linux components own the layers beneath them.
- This repository owns policy and integration.

## Hosts

Machine-agnostic configuration lives in `common/`; each machine's own in `hosts/<name>/`.
A host is written deliberately, never cloned from another — `hosts/` is not a template
directory.

```bash
nomarchy status             # report drift; change nothing, never sudo
nomarchy install base       # then desktop, then host: packages and root-owned state,
nomarchy install desktop    #   shown as a plan and confirmed before anything runs
nomarchy install host
nomarchy link               # the user level: symlinks, builds, user units
```

Standing up a new machine: **`docs/new-host/README.md`**.
