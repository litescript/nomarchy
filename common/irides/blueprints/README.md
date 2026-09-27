# Irides blueprints

Each `<name>.toml` here is a theme's **intent** — its source (a wallpaper, pinned by
SHA-256, or imported colors), adjustments, and the colors the user locked. This directory
is the source of truth for themes.

`irides apply <name>` compiles a blueprint into `~/.config/noctalia/palettes/irides-<name>.json`
and activates it. That palette file is derived state: never edit or version it; regenerate
it from here.

Deployed by symlink: `~/.config/irides/blueprints` → this directory (see
`common/bootstrap/links`). Irides: `~/code/irides` (github.com/litescript/irides).
