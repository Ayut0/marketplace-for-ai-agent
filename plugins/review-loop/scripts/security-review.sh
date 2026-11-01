#!/usr/bin/env bash
# Review the current branch for security issues only, in a separate session (claude -p).
# The instructions are in prompts/security-review.md (based on the official /security-review).
# If the repository has .claude/review-loop/security-extra.md, it is added as extra categories.
#
# Output: saved to <.git>/review-loop/<branch>/security-<N>.md; the path is printed to stdout.
# Exit codes: 0 = no High/Medium findings / 1 = High/Medium findings / 3 = round limit / 5 = cannot run
#             4 = unchanged since last review (it passed) / 6 = unchanged since last review (findings still open)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$(repo_root)" || { echo "Not a git repository" >&2; exit 5; }
cd "$ROOT"
BASE="$(resolve_base)" || { echo "No base branch found (set one with: git config review-loop.base <branch>)" >&2; exit 5; }
DIR="$(state_dir)"
mkdir -p "$DIR"

HASH="$(diff_hash "$BASE")"
if [[ "$(cat "$DIR/security-last-hash" 2>/dev/null)" == "$HASH" ]]; then
  echo "Nothing changed since the last security review; skipping" >&2
  if [[ "$(cut -d' ' -f1 "$DIR/security-last-result" 2>/dev/null)" == "1" ]]; then
    cut -d' ' -f2- "$DIR/security-last-result"
    exit 6
  fi
  exit 4
fi

ROUND="$(find "$DIR" -maxdepth 1 -name 'security-*.md' | wc -l | tr -d ' ')"
MAX="$(max_rounds)"
if (( ROUND >= MAX )); then
  echo "The security review has reached its limit of ${MAX} rounds" >&2
  exit 3
fi
OUT="$DIR/security-$((ROUND + 1)).md"

EXTRA=""
if [[ -f .claude/review-loop/security-extra.md ]]; then
  EXTRA="ADDITIONAL SECURITY CATEGORIES FOR THIS REPOSITORY:
$(cat .claude/review-loop/security-extra.md)"
fi

PROMPT="You are a senior security engineer conducting a focused security review of the changes on this branch.

CHANGES TO REVIEW:
- Committed and uncommitted changes against the base: run \`git diff ${BASE}\` (run \`git diff --name-only ${BASE}\` first to see the files)
- New files that are not tracked yet: run \`git status --porcelain\` and read the files marked with ??
- Commits on this branch: \`git log --no-decorate ${BASE}..HEAD\`

${EXTRA}

$(sed '/^<!--/,/^-->/d' "$PLUGIN_ROOT/prompts/security-review.md")"

# Write to a temp file first so a failed claude run leaves no output file (see review.sh); exit 5 = cannot run
TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT
if ! CLAUDE_REVIEW_RUNNING=1 claude -p "$PROMPT" \
  --allowedTools "Read,Grep,Glob,LS,Task,Agent,Bash(git diff:*),Bash(git status:*),Bash(git log:*),Bash(git show:*)" \
  < /dev/null > "$TMP_OUT"; then
  echo "The reviewer (claude -p) failed to run; skipping the security review" >&2
  exit 5
fi
mv "$TMP_OUT" "$OUT"

echo "$HASH" > "$DIR/security-last-hash"
echo "$OUT"

HEAD_LINE="$(head -n 1 "$OUT")"
HIGH="$(sed -nE 's/.*High[[:space:]]*([0-9]+).*/\1/p' <<<"$HEAD_LINE")"
MEDIUM="$(sed -nE 's/.*Medium[[:space:]]*([0-9]+).*/\1/p' <<<"$HEAD_LINE")"
if [[ -z "$HIGH" || -z "$MEDIUM" ]]; then
  echo "Could not parse the security review output: $OUT" >&2
  echo "1 $OUT" > "$DIR/security-last-result"
  exit 1
fi
if (( HIGH + MEDIUM == 0 )); then
  ARCHIVE="$DIR/security-passed-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$ARCHIVE"
  mv "$DIR"/security-*.md "$ARCHIVE"/
  rm -f "$DIR/security-cap-notified"
  echo "0 $ARCHIVE/$(basename "$OUT")" > "$DIR/security-last-result"
  exit 0
fi
echo "1 $OUT" > "$DIR/security-last-result"
exit 1
