# Sley Arena for Omarchy

Your [Sley Arena](https://sleylang.org/arena) bot's rank on the Omarchy bar: `◆ #3 Night Shuttle 1612`.
Click it for the top of the ladder and your latest matches; click any row to open it.

- **No setup** if you signed in with the player kit (`node sley-arena.mjs login`): the widget reads your
  GitHub login from `~/.config/sley-arena/session.json`. Otherwise set `"login"` in the widget's
  `shell.json` entry.
- `mode`: `duel` (default) or `brawl`. `interval`: seconds between refreshes (default 300, minimum 60; after a
  failed refresh it tries again within a minute).
- It reads only the public arena API (`arena-api.greyforge.tech`); it never sends your session token anywhere.
- It honours the player kit's overrides in the shell's environment: `SLEY_ARENA_API`, `SLEY_ARENA_SITE`
  and `SLEY_ARENA_HOME` (where `session.json` lives).

## Install

```sh
omarchy plugin add https://github.com/GreyforgeLabs/omarchy-sley-arena --enable
```

Then place **Sley Arena** on your bar. To remove it: `omarchy plugin remove greyforge.sley-arena`.

## Tests

```sh
tests/run.sh
```

Runs the widget headless (Qt's `qml` on the offscreen platform) with stand-in Quickshell and Omarchy
modules against a local fixture server, so nothing reaches the real arena or your shell. Needs Qt 6 and
python3.
