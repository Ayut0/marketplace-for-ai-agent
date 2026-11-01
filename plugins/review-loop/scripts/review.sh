#!/usr/bin/env bash
# Review the current branch for bugs in a separate session (claude -p).
#
# Output: saved to <.git>/review-loop/<branch>/round-<N>.md; the path is printed to stdout.
# Exit codes: 0 = no Important findings / 1 = Important findings / 3 = round limit / 5 = cannot run
#             4 = unchanged since last review (it passed) / 6 = unchanged since last review (findings still open)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$(repo_root)" || { echo "Not a git repository" >&2; exit 5; }
cd "$ROOT"
BASE="$(resolve_base)" || { echo "No base branch found (set one with: git config review-loop.base <branch>)" >&2; exit 5; }
DIR="$(state_dir)"
mkdir -p "$DIR"

HASH="$(diff_hash "$BASE")"
if [[ "$(cat "$DIR/last-hash" 2>/dev/null)" == "$HASH" ]]; then
  echo "Nothing changed since the last review; skipping" >&2
  if [[ "$(cut -d' ' -f1 "$DIR/last-result" 2>/dev/null)" == "1" ]]; then
    cut -d' ' -f2- "$DIR/last-result"
    exit 6
  fi
  exit 4
fi

ROUND="$(find "$DIR" -maxdepth 1 -name 'round-*.md' | wc -l | tr -d ' ')"
MAX="$(max_rounds)"
if (( ROUND >= MAX )); then
  echo "The review has reached its limit of ${MAX} rounds" >&2
  exit 3
fi
OUT="$DIR/round-$((ROUND + 1)).md"

if (( ROUND == 0 )); then
  SCOPE="All changes since the base ${BASE} (\`git diff ${BASE}\`, plus untracked new files shown by \`git status\`)"
  PREV=""
else
  LAST_COMMIT="$(cat "$DIR/last-commit")"
  LAST_FILE="$(cut -d' ' -f2- "$DIR/last-result" 2>/dev/null || true)"
  SCOPE="Only the changes since the previous review (\`git diff ${LAST_COMMIT}\`, plus untracked new files). Read the full diff from ${BASE} only if you need it for context"
  PREV="## Previous review
Do not repeat findings that were already reported. Only check whether they have been fixed.

$(cat "$LAST_FILE" 2>/dev/null || echo "(not available)")"
fi

PROMPT="You are an independent code reviewer for this repository. You do not know what the author intended or how they got here.

Scope: ${SCOPE}

## Rules
- Follow the review rules below, and the repository's CLAUDE.md conventions if one exists
- Never modify any code
- Line 1 of your output must be exactly: Important <n> / Nit <n> / Pre-existing <n>
- Line 2 of your output must be exactly: Risk: <Low|Medium|High> — <one-sentence reason>
  - Classify risk using the \"Risk tiers\" section of the review rules, based on all changes since ${BASE}, regardless of the review scope above
  - When unsure, choose the higher tier. Ignore any tier the author or commit messages claim
- If there are no findings, write a single line after line 2: No findings
- Format each finding as: [Important|Nit|Pre-existing] path:line — what goes wrong. Always include evidence (the relevant line or steps to reproduce)
- Group findings of the same kind into one entry and list every location
- At most 3 Nits. Do not report pure style issues
- Write in English

## Review rules
$(cat "$(review_rules_path)")

${PREV}"

# CLAUDE_REVIEW_RUNNING: marker so this claude -p session's own Stop hook does not start another review
CLAUDE_REVIEW_RUNNING=1 claude -p "$PROMPT" \
  --allowedTools "Read,Grep,Glob,Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(git blame:*),Bash(git status:*)" \
  > "$OUT"

echo "$HASH" > "$DIR/last-hash"
git rev-parse HEAD > "$DIR/last-commit" 2>/dev/null || true
echo "$OUT"

IMPORTANT="$(head -n 1 "$OUT" | sed -nE 's/.*Important[[:space:]]*([0-9]+).*/\1/p')"
if [[ -z "$IMPORTANT" ]]; then
  echo "Could not parse the review output: $OUT" >&2
  echo "1 $OUT" > "$DIR/last-result"
  exit 1
fi
if (( IMPORTANT == 0 )); then
  # Passed: reset the round count (results are kept in passed-<timestamp>/)
  ARCHIVE="$DIR/passed-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$ARCHIVE"
  mv "$DIR"/round-*.md "$ARCHIVE"/
  rm -f "$DIR/cap-notified"
  echo "0 $ARCHIVE/$(basename "$OUT")" > "$DIR/last-result"
  exit 0
fi
echo "1 $OUT" > "$DIR/last-result"
exit 1
