#!/usr/bin/env bash
# Runs INSIDE the herdr pane (has a TTY, cwd = the invoking pane's project).
# fzf menu -> exec hunk, so quitting hunk closes the pane.
set -uo pipefail

theme_args=()
[ -n "${HUNK_THEME:-}" ] && theme_args=(--theme "$HUNK_THEME")

if ! command -v hunk >/dev/null 2>&1; then
  printf 'hunk not found on PATH (brew install hunk)\n'
  read -r -n1 -s -p 'press any key to close'
  exit 1
fi

if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  printf 'not a git repository: %s\n' "$PWD"
  read -r -n1 -s -p 'press any key to close'
  exit 1
fi

# Session-aware: if a hunk viewer is already open for this repo, reload it
# with the chosen view instead of opening a second one; else become hunk.
view() {
  if hunk session get --repo "$repo_root" >/dev/null 2>&1 &&
     hunk session reload --repo "$repo_root" -- "$@" >/dev/null 2>&1; then
    exit 0
  fi
  exec hunk "$@" ${theme_args[@]+"${theme_args[@]}"}
}

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
    # a live session already watches; only a fresh viewer needs --watch
    if hunk session get --repo "$repo_root" >/dev/null 2>&1 &&
       hunk session reload --repo "$repo_root" -- diff >/dev/null 2>&1; then
      exit 0
    fi
    exec hunk diff --watch ${theme_args[@]+"${theme_args[@]}"}
    ;;
  'Staged')
    view diff --staged
    ;;
  'Last commit')
    view show
    ;;
  'Pick commit')
    sha="$(log_fzf --prompt='commit> ' | awk '{print $1}')"
    [ -n "$sha" ] || exit 0
    view show "$sha"
    ;;
  'Pick range (2 commits)')
    picks="$(log_fzf --multi 2 --prompt='range> ' \
      --header='TAB marks a commit (pick 2). Enter confirms. 1 marked = diff vs working tree.')"
    count="$(printf '%s\n' "$picks" | grep -c .)"
    if [ "$count" -eq 2 ]; then
      # git log lists newest first; diff older..newer
      newer="$(printf '%s\n' "$picks" | sed -n 1p | awk '{print $1}')"
      older="$(printf '%s\n' "$picks" | sed -n 2p | awk '{print $1}')"
      view diff "$older..$newer"
    elif [ "$count" -eq 1 ]; then
      sha="$(printf '%s\n' "$picks" | awk '{print $1}')"
      view diff "$sha"
    fi
    exit 0
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
    view diff "$upstream..$branch"
    ;;
  'Stash')
    ref="$(git stash list |
      fzf --prompt='stash> ' --reverse --height=100% --delimiter=: \
        --preview 'git stash show --stat --color=always {1}' --preview-window=right,55% |
      cut -d: -f1)"
    [ -n "$ref" ] || exit 0
    exec hunk stash show "$ref" ${theme_args[@]+"${theme_args[@]}"}
    ;;
esac
