# themer blueprints

Each `<name>.toml` here is a theme's **intent** — its source (a wallpaper, pinned by
SHA-256, or imported colors), adjustments, and the colors the user locked. This directory
is the source of truth for themes.

`themer apply <name>` compiles a blueprint into `~/.config/noctalia/palettes/themer-<name>.json`
and activates it. That palette file is derived state: never edit or version it; regenerate
it from here.

Deployed by symlink: `~/.config/themer/blueprints` → this directory (see
`common/bootstrap/links`). themer: `~/code/themer`.
