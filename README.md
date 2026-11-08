# Workspace Layout

Per-workspace tiling ratios for Hyprland on Omarchy. Drag the dividers and the
real windows follow: 25/50/25, main and side, thirds, a grid, or your own shape.

![The panel](screenshots/panel.png)

This is a fork of [bjarneo/omarchy-workspace-layout](https://github.com/bjarneo/omarchy-workspace-layout).

## Install

```bash
omarchy plugin add https://github.com/spaghetticodez/omarchy-workspace-layout --enable
```

Update:

```bash
omarchy plugin update bjarneo.workspace-layout
```

The plugin id stays `bjarneo.workspace-layout`, so your layouts, pins and bar
position carry over from the original.

## Use

Click the bar icon. Pick a workspace, drag the dividers, pin apps to slots, and
save the arrangement as a profile. The full manual is in
[docs/guide.md](docs/guide.md), every feature is listed in
[docs/features.md](docs/features.md), and the command line is in
[docs/cli.md](docs/cli.md).

## What this fork changes

- **A pin can open where you launch it.** Upstream, every pin is a fixed
  Hyprland rule, so a pinned terminal always jumped to its workspace. `Edit` on
  a pin now has **New windows**: *always* (the old behaviour, still the
  default), *first window* only, or *where launched*, which keeps the app's
  slot on its own workspace but never moves a window.
- **Omarchy 4.5 Super+L works again.** 4.5 writes `o.workspace_mode(...)`
  files that the plugin could not read, so every Hyprland reload put dwindle
  back over your Super+L choice and over the default layout chosen in
  Appearance. Both formats are read now, the 4.5 default layout is followed,
  a workspace cycled back to the default follows it, a Super+L press on a
  workspace running one of the plugin's layouts sticks instead of being undone
  at the next sync, and floating is left to Omarchy.
- **Borders that only show when focus moves.** Optional (`borders → flash on
  focus` at the foot of the panel): all borders stay transparent and the
  active one shows in your theme's colour for two seconds after a focus
  change. Made for OLED panels. It changes colours only, so windows are not
  resized on every focus change the way a `border_size` toggle does.
- **One background sync instead of two.** Omarchy 4.x mounts the plugin's
  service next to its bar widget, so both ran a file watcher and applied every
  change twice (upstream issue #14). The service now owns that work.

Each change has tests that fail on the original code (`node --test
tests/model.test.js`).

## Remove

```bash
omarchy plugin remove bjarneo.workspace-layout
rm ~/.config/hypr/omarchy-workspace-layout.lua
```

The guarded `dofile` line in `~/.config/hypr/hyprland.lua` can stay; it does
nothing once the generated file is gone.

## Development

```bash
node --test tests/model.test.js   # needs lua for the Lua cross-checks
```

Notes on how the pieces fit: [docs/development.md](docs/development.md).

## Credits

Written by [Bjarne Oeverli](https://github.com/bjarneo), with contributions
from the upstream contributors. MIT licensed, see [LICENSE](LICENSE).
