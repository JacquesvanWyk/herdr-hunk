#!/usr/bin/env bash
# Runs INSIDE the herdr pane (has a TTY, cwd = the invoking pane's project).
# fzf menu -> exec hunk, so quitting hunk closes the pane.
set -uo pipefail

theme_args=()
[ -n "${HUNK_THEME:-}" ] && theme_args=(--theme "$HUNK_THEME")

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  printf 'not a git repository: %s\n' "$PWD"
  read -r -n1 -s -p 'press any key to close'
  exit 1
fi

log_fzf() {
  git log --oneline --color=always -200 |
    fzf --ansi --no-sort --reverse --height=100% "$@" \
      --preview 'git show --stat --color=always {1}' --preview-window=right,55%
}

choice="$(printf '%s\n' \
  'Working tree (live)' \
  'Staged' \
  'Last commit' \
  'Pick commit' \
  'Pick range (2 commits)' \
  'Branch vs upstream' \
  'Stash' |
  fzf --prompt='hunk> ' --reverse --height=100%)" || exit 0

case "$choice" in
  'Working tree (live)')
    exec hunk diff --watch "${theme_args[@]}"
    ;;
  'Staged')
    exec hunk diff --staged "${theme_args[@]}"
    ;;
  'Last commit')
    exec hunk show "${theme_args[@]}"
    ;;
  'Pick commit')
    sha="$(log_fzf --prompt='commit> ' | awk '{print $1}')"
    [ -n "$sha" ] || exit 0
    exec hunk show "$sha" "${theme_args[@]}"
    ;;
  'Pick range (2 commits)')
    picks="$(log_fzf --multi 2 --prompt='pick 2 commits (tab to select)> ')"
    [ "$(printf '%s\n' "$picks" | grep -c .)" -eq 2 ] || exit 0
    # git log lists newest first; diff older..newer
    newer="$(printf '%s\n' "$picks" | sed -n 1p | awk '{print $1}')"
    older="$(printf '%s\n' "$picks" | sed -n 2p | awk '{print $1}')"
    exec hunk diff "$older..$newer" "${theme_args[@]}"
    ;;
  'Branch vs upstream')
    branch="$(git branch --show-current)"
    [ -n "$branch" ] || branch="HEAD"
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" || upstream=""
    if [ -z "$upstream" ]; then
      for candidate in origin/main origin/master main master; do
        if git rev-parse --verify -q "$candidate" >/dev/null 2>&1; then
          upstream="$candidate"
          break
        fi
      done
    fi
    if [ -z "$upstream" ]; then
      printf 'no upstream or base branch found\n'
      read -r -n1 -s -p 'press any key to close'
      exit 1
    fi
    exec hunk diff "$upstream..$branch" "${theme_args[@]}"
    ;;
  'Stash')
    ref="$(git stash list |
      fzf --prompt='stash> ' --reverse --height=100% --delimiter=: \
        --preview 'git stash show --stat --color=always {1}' --preview-window=right,55% |
      cut -d: -f1)"
    [ -n "$ref" ] || exit 0
    exec hunk stash show "$ref" "${theme_args[@]}"
    ;;
esac
