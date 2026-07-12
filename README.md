# herdr-hunk

The interactive [hunk](https://hunk.dev) plugin for [herdr](https://herdr.dev): pick any diff with fzf, review it in a pane or tab, and let it auto-open a live diff whenever a coding agent finishes with uncommitted changes.

Requires herdr ≥ 0.7.0, [hunk](https://hunk.dev) (`brew install hunk`), `fzf`, and `jq`.

## The picker

One shortcut, then choose what to review:

![hunk picker in a split pane](docs/picker-split.jpeg)

| Option | What it runs |
|---|---|
| Working tree (live) | `hunk diff --watch` — auto-refreshes as files change |
| Staged | `hunk diff --staged` |
| Last commit | `hunk show` |
| Pick commit | fzf over the log with stat preview → `hunk show <sha>` |
| Pick range | TAB-mark two commits → `hunk diff <older>..<newer>` (one marked = diff vs working tree) |
| Branch vs upstream | `hunk diff <upstream>..<branch>` (falls back to origin/main, origin/master, main, master) |
| Stash | fzf over `git stash list` → `hunk stash show <ref>` |

Picking a range — TAB marks, preview shows the commit stat:

![range picker with commit preview](docs/range-picker.png)

The chosen diff replaces the picker in place (`q` in hunk closes the pane):

![hunk diff in a split pane](docs/diff-split.png)

Also available full-size in its own tab:

![hunk picker in its own tab](docs/picker-tab.jpeg)

**Session-aware:** if a hunk viewer is already open for the repo, the picker reloads it with your choice instead of stacking a second pane.

## Autodiff — auto-open when an agent finishes

When a coding agent's pane goes idle with uncommitted changes, a live hunk diff opens in a split beside it, unfocused. Works with any agent herdr tracks (claude, codex, pi, opencode, cursor, copilot, and more — `herdr integration install <agent>`).

It stays out of the way:

- skips panes that aren't in a git repo, or repos with nothing uncommitted
- skips when a hunk viewer is already open for that repo (its `--watch` keeps it fresh)
- once you close the pane, it won't reopen until the agent produces *new* changes

**Autodiff is ON by default** once the plugin is installed. Toggle it with the `toggle-autodiff` action — a toast confirms the state:

![autodiff toggle toast](docs/autodiff-toast.jpeg)

Check or set it manually:

```bash
ls "$(herdr plugin config-dir herdr-hunk)"                        # empty = ON
touch "$(herdr plugin config-dir herdr-hunk)/autodiff-off"        # force OFF
rm "$(herdr plugin config-dir herdr-hunk)/autodiff-off"           # force ON
```

Note: quick double-presses of the toggle work, but herdr queues toasts — the second toast appears after the first expires.

## Install

```bash
herdr plugin install JacquesvanWyk/herdr-hunk
herdr plugin list   # confirm herdr-hunk is registered
```

For local development:

```bash
herdr plugin link /path/to/herdr-hunk
```

## Keybindings

Add to `~/.config/herdr/config.toml`:

```toml
[[keys.command]]              # picker in a split
key = "ctrl+alt+d"
type = "shell"
command = "herdr plugin action invoke open-hunk-picker --plugin herdr-hunk"

[[keys.command]]              # picker in its own tab
key = "ctrl+alt+shift+d"
type = "shell"
command = "herdr plugin action invoke open-hunk-picker-tab --plugin herdr-hunk"

[[keys.command]]              # autodiff on/off
key = "ctrl+alt+a"
type = "shell"
command = "herdr plugin action invoke toggle-autodiff --plugin herdr-hunk"
```

> **Pick keys that fit your setup.** These are suggestions. herdr reserves most
> `prefix+<letter>` chords for its built-ins (pane navigation on `prefix+h/j/k/l`, tab
> nav, workspace actions — see the herdr keybindings reference), so this plugin uses
> `ctrl+alt+*` direct chords to stay clear of them and of your other plugins. Rebind to
> whatever is free on your system. If `ctrl+alt+shift+*` doesn't register in your terminal,
> use a plain `ctrl+alt+<letter>` for the tab action instead.

Then reload:

```bash
herdr server reload-config
```

## Actions

| Action | Description |
|---|---|
| `open-hunk-picker` | fzf picker in a split pane |
| `open-hunk-picker-tab` | fzf picker in its own tab |
| `open-hunk-watch` | toggle a live working-tree diff split (open / focus / close) |
| `toggle-autodiff` | turn the agent-idle auto-open on or off |

Invoke any directly:

```bash
herdr plugin action invoke open-hunk-picker --plugin herdr-hunk
```

## Theme

Set `HUNK_THEME` to pass a theme to hunk (e.g. `rose-pine`, `catppuccin-mocha`, `tokyo-night`), or configure hunk itself in `~/.config/hunk/config.toml`.
