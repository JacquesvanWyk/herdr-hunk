#!/usr/bin/env bash
# Action launcher (runs detached, no TTY): open the picker pane in the
# invoking pane's project. Usage: open-hunk-picker.sh [split|tab]
set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"
placement="${1:-split}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
picker="$script_dir/picker.sh"

# Root the picker at the invoking pane's directory, not the plugin install
# dir. Context JSON is injected by herdr on action invoke; fall back to the
# focused pane's cwd, then HOME.
target_cwd() {
  local cwd=""
  if command -v jq >/dev/null 2>&1; then
    cwd="$(printf '%s' "${HERDR_PLUGIN_CONTEXT_JSON:-}" | jq -r '
      (.focused_pane_cwd // .workspace_cwd // .cwd // "")' 2>/dev/null)" || cwd=""
    if [ -z "$cwd" ]; then
      cwd="$("$herdr_bin" pane list 2>/dev/null | jq -r '
        [.result.panes[]? | select(.focused == true)][0].cwd // ""' 2>/dev/null)" || cwd=""
    fi
  fi
  [ -d "$cwd" ] || cwd="$HOME"
  printf '%s' "$cwd"
}

extra=()
[ "$placement" = "split" ] && extra=(--direction right)

exec "$herdr_bin" plugin pane open \
  --plugin herdr-hunk --entrypoint hunk-picker \
  --placement "$placement" ${extra[@]+"${extra[@]}"} --focus \
  --cwd "$(target_cwd)" \
  --env "HERDR_HUNK_PICKER=$picker"
