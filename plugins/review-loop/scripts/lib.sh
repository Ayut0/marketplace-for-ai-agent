#!/usr/bin/env bash
# Shared helpers for review-loop. Sourced by the other scripts.
#
# Per-repository settings (all optional; stored in git config, so no files are added to the repo):
#   git config review-loop.enabled false     # disable for this repository
#   git config review-loop.base develop      # base branch to compare against
#   git config review-loop.maxRounds 5       # round limit (bug and security reviews)

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

repo_root() { git rev-parse --show-toplevel 2>/dev/null; }

loop_enabled() {
  [[ "$(git config --get review-loop.enabled 2>/dev/null)" != "false" ]]
}

# If the repository ships its own review loop (e.g. a work kit), the plugin stays out of the way
has_own_kit() {
  [[ -x .claude/hooks/review-on-stop.sh || -x scripts/review.sh ]]
}

# Base: git config > origin/HEAD > origin/main > origin/master > main > master
resolve_base() {
  local b
  b="$(git config --get review-loop.base 2>/dev/null)"
  if [[ -n "$b" ]] && git rev-parse --verify -q "$b" >/dev/null; then echo "$b"; return; fi
  for b in origin/HEAD origin/main origin/master main master; do
    if git rev-parse --verify -q "$b" >/dev/null; then echo "$b"; return; fi
  done
  return 1
}

# Are we on the base branch itself?
on_base_branch() {
  local base="$1" cur
  cur="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$cur" == "HEAD" ]] && return 0   # detached HEAD
  [[ "$cur" == "${base#origin/}" ]] && return 0
  [[ "$base" == "origin/HEAD" ]] && [[ "$cur" == "$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's#^origin/##')" ]] && return 0
  return 1
}

max_rounds() {
  local n
  n="$(git config --get review-loop.maxRounds 2>/dev/null)"
  [[ "$n" =~ ^[0-9]+$ ]] && echo "$n" || echo 3
}

# State lives inside .git (keeps the working tree clean, no .gitignore needed)
state_dir() {
  local gitdir branch
  gitdir="$(cd "$(git rev-parse --git-dir)" && pwd)"
  branch="$(git rev-parse --abbrev-ref HEAD)"
  echo "$gitdir/review-loop/${branch//\//_}"
}

# Review rules: the repository's REVIEW.md if present, otherwise the bundled default
review_rules_path() {
  if [[ -f REVIEW.md ]]; then echo "REVIEW.md"; else echo "$PLUGIN_ROOT/defaults/REVIEW.md"; fi
}

# Fingerprint of the change. Depends only on the working tree contents and the fork point
# from the base, so committing or staging alone does not change it.
# Includes uncommitted changes and untracked new files (ignored files are excluded).
diff_hash() {
  local idx tree fork
  idx="$(mktemp)"
  cp "$(git rev-parse --git-dir)/index" "$idx" 2>/dev/null || rm -f "$idx"
  GIT_INDEX_FILE="$idx" git add -A >/dev/null 2>&1
  tree="$(GIT_INDEX_FILE="$idx" git write-tree)"
  rm -f "$idx"
  fork="$(git merge-base "$1" HEAD 2>/dev/null || git rev-parse "$1")"
  echo "$tree $fork" | git hash-object --stdin
}

# Nothing changed against the base?
no_changes() {
  git diff --quiet "$1" && [[ -z "$(git ls-files --others --exclude-standard)" ]]
}
