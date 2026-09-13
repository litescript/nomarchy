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
common/scripts/bootstrap <host>            # report drift; change nothing
common/scripts/bootstrap <host> --apply    # apply the user-level changes
```

Standing up a new machine: **`docs/new-host/README.md`**.
