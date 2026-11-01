#!/usr/bin/env bash
# review-loop Stop hook.
# When Claude is about to stop, run in a separate session:
#   1. a bug review (scripts/review.sh)
#   2. if that passes, a security review (scripts/security-review.sh)
# If there are findings, keep Claude working and hand the findings back.
set -uo pipefail

cat >/dev/null   # the hook's stdin JSON is not used

# Do nothing when called from the reviewer's own claude -p session (prevents recursion)
[[ -n "${CLAUDE_REVIEW_RUNNING:-}" ]] && exit 0

SCRIPTS="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/scripts"
source "$SCRIPTS/lib.sh"

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
ROOT="$(repo_root)" || exit 0          # not a git repository
cd "$ROOT"
loop_enabled || exit 0                 # git config review-loop.enabled false
has_own_kit && exit 0                  # the repository has its own review loop
BASE="$(resolve_base)" || exit 0       # no base branch (e.g. no commits yet)
on_base_branch "$BASE" && exit 0       # working directly on main etc.
no_changes "$BASE" && exit 0           # nothing changed against the base

DIR="$(state_dir)"
mkdir -p "$DIR"
TMP_ERR="$(mktemp)"
trap 'rm -f "$TMP_ERR"' EXIT

block() {
  # Keep Claude working and pass the reason as its next instruction
  jq -n --arg r "$1" '{decision: "block", reason: $r}'
  exit 0
}

# Claude tried to stop again without changing anything while findings remain.
# Send it back once; the second time, move on (prevents an endless loop).
unchanged_with_findings() {
  local kind="$1" out="$2" marker="$DIR/$3-repeat-notified"
  if [[ "$(cat "$marker" 2>/dev/null)" != "$out" ]]; then
    echo "$out" > "$marker"
    block "The findings from the previous ${kind} review (${out}) are still open and the code has not changed.
Either fix them, or briefly explain why you are not fixing them (for example, why a finding is a false positive), then stop."
  fi
  return 0
}

# ---- 1. Bug review ----
OUT="$(bash "$SCRIPTS/review.sh" 2>"$TMP_ERR")"
CODE=$?

case $CODE in
  0|4) ;;
  6) unchanged_with_findings "bug" "$OUT" "bug" ;;
  1)
    block "The independent review found issues (${OUT}).

$(cat "$OUT" 2>/dev/null || cat "$TMP_ERR")

Fix every Important finding. For any you decide not to fix, explain why here. When a finding is one instance of a class of bug, fix every instance, not just the line that was flagged."
    ;;
  3)
    if [[ ! -f "$DIR/cap-notified" ]]; then
      touch "$DIR/cap-notified"
      block "The automated review has reached its round limit. Do not keep patching. Briefly summarise the open findings (latest round in ${DIR}/) and whether the approach itself should be reconsidered, then stop. Also state that the security review has not been run yet."
    fi
    exit 0
    ;;
  *)
    echo "review-loop: could not run the bug review: $(cat "$TMP_ERR")" >&2
    exit 0
    ;;
esac

# ---- 2. Security review ----
OUT="$(bash "$SCRIPTS/security-review.sh" 2>"$TMP_ERR")"
CODE=$?

case $CODE in
  0|4) exit 0 ;;
  6) unchanged_with_findings "security" "$OUT" "security" ;;
  1)
    block "The independent security review found issues (${OUT}).

$(cat "$OUT" 2>/dev/null || cat "$TMP_ERR")

Fix every High and Medium finding. For any you judge to be a false positive, explain why here (which input is validated, and where)."
    ;;
  3)
    if [[ ! -f "$DIR/security-cap-notified" ]]; then
      touch "$DIR/security-cap-notified"
      block "The security review has reached its round limit. Do not keep patching. Briefly summarise the open findings (latest security-*.md in ${DIR}/), then stop."
    fi
    exit 0
    ;;
  *)
    echo "review-loop: could not run the security review: $(cat "$TMP_ERR")" >&2
    exit 0
    ;;
esac
