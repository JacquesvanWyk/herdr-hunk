#!/usr/bin/env bash
# Event hook for pane.agent_status_changed: when an agent goes idle with
# uncommitted changes, open a live hunk diff split beside its pane (unfocused).
# Opt out: touch "$(herdr plugin config-dir herdr-hunk)/autodiff-off"
set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"
command -v jq >/dev/null 2>&1 || exit 0

cfg_dir="${HERDR_PLUGIN_CONFIG_DIR:-}"
[ -n "$cfg_dir" ] && [ -e "$cfg_dir/autodiff-off" ] && exit 0

evt="${HERDR_PLUGIN_EVENT_JSON:-}"
# skip reasons go to stdout -> visible via `herdr plugin log list`
log() { printf '%s\n' "$*"; }
[ -n "$evt" ] || exit 0
status="$(printf '%s' "$evt" | jq -r '.data.agent_status // .agent_status // empty' 2>/dev/null)" || exit 0
[ "$status" = "idle" ] || { log "skip: status=$status"; exit 0; }
pane_id="$(printf '%s' "$evt" | jq -r '.data.pane_id // .pane_id // empty' 2>/dev/null)" || exit 0
[ -n "$pane_id" ] || exit 0

# herdr runs hooks with a minimal PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"
command -v hunk >/dev/null 2>&1 || { log "skip: no hunk on PATH"; exit 0; }

info="$("$herdr_bin" pane get "$pane_id" 2>/dev/null)" || { log "skip: pane get failed"; exit 0; }
cwd="$(printf '%s' "$info" | jq -r '.result.pane.foreground_cwd // .result.pane.cwd // empty' 2>/dev/null)" || exit 0
[ -d "$cwd" ] || { log "skip: bad cwd=$cwd"; exit 0; }
root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || { log "skip: not git repo cwd=$cwd"; exit 0; }

# nothing uncommitted -> nothing to review
[ -n "$(git -C "$root" status --porcelain 2>/dev/null)" ] || { log "skip: no changes in $root"; exit 0; }

# a live hunk session for this repo keeps itself fresh via --watch
hunk session get --repo "$root" >/dev/null 2>&1 && { log "skip: session live for $root"; exit 0; }

# reopen only when the diff changed since we last opened a pane for it, so a
# manually closed hunk pane stays closed until the agent produces new changes
# hash tracked diff AND untracked file contents (git diff can't see untracked)
sig="$( {
  git -C "$root" status --porcelain
  git -C "$root" diff HEAD 2>/dev/null || git -C "$root" diff
  git -C "$root" ls-files --others --exclude-standard | while IFS= read -r f; do
    shasum "$root/$f" 2>/dev/null
  done
} | shasum | awk '{print $1}')"
state_dir="${HERDR_PLUGIN_STATE_DIR:-$HOME/.cache/herdr-hunk}"
mkdir -p "$state_dir" 2>/dev/null || true
key="$state_dir/$(printf '%s' "$root" | shasum | awk '{print $1}').sig"
[ -f "$key" ] && [ "$(cat "$key" 2>/dev/null)" = "$sig" ] && { log "skip: same sig"; exit 0; }
printf '%s' "$sig" >"$key" 2>/dev/null || true

log "OPENING beside $pane_id in $root"
exec "$herdr_bin" plugin pane open \
  --plugin herdr-hunk --entrypoint hunk-diff \
  --placement split --direction right --no-focus \
  --target-pane "$pane_id" \
  --cwd "$root"
