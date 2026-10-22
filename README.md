# Sley Arena for Omarchy

Your [Sley Arena](https://sleylang.org/arena) bot's rank on the Omarchy bar: `◆ #3 Night Shuttle 1612`.
Click it for the top of the ladder and your latest matches; click any row to open it.

- **No setup** if you signed in with the player kit (`node sley-arena.mjs login`): the widget reads your
  GitHub login from `~/.config/sley-arena/session.json`. Otherwise set `"login"` in the widget's
  `shell.json` entry.
- `mode`: `duel` (default) or `brawl`. `interval`: seconds between refreshes (default 300, minimum 60).
- It reads only the public arena API (`arena-api.greyforge.tech`); it never sends your session token anywhere.

## Install

```sh
omarchy plugin add https://github.com/GreyforgeLabs/omarchy-sley-arena --enable
```

Then place **Sley Arena** on your bar. To remove it: `omarchy plugin remove greyforge.sley-arena`.
