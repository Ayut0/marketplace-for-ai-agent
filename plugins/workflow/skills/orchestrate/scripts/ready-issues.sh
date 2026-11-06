#!/usr/bin/env bash
# List a repo's open issues with whether each can be dispatched now, in one GraphQL call.
# Usage: ready-issues.sh [owner/name]   (default: the repo of the current directory)
# Output: tab-separated  number  status  title  detail  parent   (header first, ready issues first;
#         parent is the epic's number when the issue is a sub-issue)
#   ready      no open blockers, no PR, no branch
#   blocked    detail lists the open "blocked by" issues
#   in-flight  an open PR or an existing issue-<n> branch already covers it
#   fixed      a merged PR closes it but the issue is still open (or GitHub has not caught up)
#   epic       it has sub-issues; dispatch those instead
# Exit codes: 0 = listed / 1 = gh or the query failed
set -uo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)}" \
  || { echo "Not in a GitHub repo; pass owner/name" >&2; exit 1; }
[[ "$REPO" == */* ]] || { echo "Expected owner/name, got '$REPO'" >&2; exit 1; }

QUERY='query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    issues(states: OPEN, first: 100, orderBy: {field: CREATED_AT, direction: ASC}) {
      pageInfo { hasNextPage }
      nodes {
        number
        title
        subIssuesSummary { total }
        parent { number }
        blockedBy(first: 50) { nodes { number state } }
        closedByPullRequestsReferences(first: 10, includeClosedPrs: true) { nodes { number state } }
      }
    }
    refs(refPrefix: "refs/heads/", query: "issue-", first: 100) { nodes { name } }
  }
}'

DATA="$(gh api graphql -f query="$QUERY" -F owner="${REPO%%/*}" -F name="${REPO##*/}")" \
  || { echo "GraphQL query failed for $REPO" >&2; exit 1; }

jq -e '.data.repository.issues.pageInfo.hasNextPage' <<<"$DATA" >/dev/null \
  && echo "Warning: more than 100 open issues; only the oldest 100 are listed" >&2

jq -r '
  .data.repository as $r
  | ($r.refs.nodes | map(.name)) as $branches
  | $r.issues.nodes
  | map(
      . as $i
      | ([.blockedBy.nodes[] | select(.state == "OPEN") | "#\(.number)"]) as $open_blockers
      | ([.closedByPullRequestsReferences.nodes[] | select(.state == "OPEN") | "PR #\(.number)"]) as $open_prs
      | ([.closedByPullRequestsReferences.nodes[] | select(.state == "MERGED") | "PR #\(.number)"]) as $merged_prs
      | ([$branches[] | select(test("(^|/)issue-\($i.number)(-|$)"))]) as $own_branches
      | if .subIssuesSummary.total > 0 then {s: "epic", d: "\(.subIssuesSummary.total) sub-issues"}
        elif ($merged_prs | length) > 0 then {s: "fixed", d: ($merged_prs | join(", "))}
        elif ($open_prs | length) > 0 or ($own_branches | length) > 0
          then {s: "in-flight", d: ($open_prs + $own_branches | join(", "))}
        elif ($open_blockers | length) > 0 then {s: "blocked", d: "by \($open_blockers | join(", "))"}
        else {s: "ready", d: ""}
        end
      | {n: $i.number, t: $i.title, p: ($i.parent.number // "")} + .
    )
  | sort_by(.s as $s | (["ready", "in-flight", "fixed", "blocked", "epic"] | index($s)), .n)
  | (["number", "status", "title", "detail", "parent"] | @tsv),
    (.[] | [.n, .s, .t, .d, .p] | @tsv)
' <<<"$DATA"
