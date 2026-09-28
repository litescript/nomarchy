# caesar's Noctalia

`settings.toml` is a **snapshot** of `~/.local/state/noctalia/settings.toml`, which Noctalia
owns and rewrites. `hosts/caesar/bootstrap/seeds` plants it on a rebuilt caesar before first
login, so the shell comes up configured rather than at Noctalia's defaults. Refresh it with
`noctalia-snapshot`; `nomarchy status` reports when live has moved past it.

`[location]` is never in it: the coordinates of home do not belong in a public repo. Set it
in Noctalia's settings after a rebuild; a `manual` check in `common/bootstrap/user-checks`
reminds.

`setup-complete` is an empty marker, seeded to `~/.local/state/noctalia/.setup-complete`.
Without it Noctalia runs its first-run setup wizard, whose steps choose a wallpaper and a
palette -- the very things the seeded settings already carry.

The theme is `custom_palette = "irides-NSX"`: a palette Irides GENERATES, not a versioned
file. After Irides is built, a check runs `irides apply` to regenerate it; that needs
Noctalia running, so it passes from the first graphical login on. It also needs the
wallpaper the blueprint pins, in `~/Pictures` -- which is why `backup-daily` carries
`~/Pictures`.
