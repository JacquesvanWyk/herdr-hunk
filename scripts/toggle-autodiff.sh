#!/usr/bin/env bash
# Toggle the agent-idle autodiff on/off and toast the new state.
set -uo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"
cfg_dir="${HERDR_PLUGIN_CONFIG_DIR:-}"
[ -n "$cfg_dir" ] || cfg_dir="$("$herdr_bin" plugin config-dir herdr-hunk 2>/dev/null)"
[ -n "$cfg_dir" ] || exit 1
mkdir -p "$cfg_dir" 2>/dev/null || true

flag="$cfg_dir/autodiff-off"
if [ -e "$flag" ]; then
  rm -f "$flag"
  state="ON"
else
  touch "$flag"
  state="OFF"
fi

exec "$herdr_bin" notification show "hunk autodiff: $state" --position top-right
