---
name: address
description: Thin orchestrator that drives one unit of work (a GitHub issue, a pull request, or a free-form prompt) through the repo's plan/implement/self-review/verify/report cycle (defined in its AGENTS.md) to a review-ready PR, composing the tdd and handoff skills instead of reimplementing them. Use when asked to address/deliver/work an issue or PR end-to-end, or to resume one with `continue`.
argument-hint: <issue-or-pr number/URL | free-form prompt | continue>
---

# Address

Thin orchestrator for the cycle in the repo's `AGENTS.md`
(`plan → implement → self-review → verify → report`). It resolves what
`$ARGUMENTS` names, drives it through that cycle, opens a PR, requests the
independent review, and addresses findings. It does not restate any phase's
rules — `AGENTS.md`, `tdd`, and `handoff` own those.

Everything repo-specific — verify commands, the docs to read, escalation
triggers — comes from the repo's `AGENTS.md` and `docs/agents/`. If the repo
has no `AGENTS.md`, stop and suggest `/workflow:adopt` instead of guessing.

## Resolve the argument

| `$ARGUMENTS` | Meaning | Start at |
| --- | --- | --- |
| Issue number/URL | Plan and deliver that issue | Plan |
| PR number/URL | Resume an open PR — read its diff, CI, and existing review comments before continuing | Wherever that state points (Verify, or Address) |
| Free-form prompt | Ad hoc task with no issue yet | Open a tracking issue (per `docs/agents/issue-tracker.md`), then Plan |
| `continue` (bare) | Resume — see [Resuming](#resuming-continue) | Wherever the resumed state points |

Assume the operator has already checked out the branch/worktree for the
target, per `AGENTS.md`'s Conventions — this skill MUST NOT create one.

## Plan

Read the issue/PR (`gh issue view <n> --comments` / `gh pr view <n>`) and the
docs `docs/agents/domain.md` says to read before exploring. If the issue is
already closed, or a merged PR already closes it, stop and report that
instead of planning. If the spec leaves a genuine product/UX/scope decision
unstated, you MUST ask the human before writing the plan — you MUST NOT guess.

Use Claude Code's plan mode for the plan-approval gate: enter it, write the
plan, then exit it for approval. You MUST NOT proceed to Implement until the
human approves.

**Orchestrated run.** When `/workflow:orchestrate` started this session, its
brief says which of two modes applies:

- *Plan pre-approved* (the human approved the batch): skip plan mode, put the
  plan at the top of the PR body, and go on to Implement. The open-question
  rule above still applies — stop and ask rather than guess.
- *Stop after the plan* (an Escalation issue): use the plan-approval gate as
  above.

Either way, the gates in `workflow:orchestrate` § Gates apply: never merge,
ask before rewriting pushed history, and write follow-ups into the PR body
instead of opening issues.

## Implement, self-review, verify

- **Implement** — hand the approved plan to the `tdd` skill for the
  red-green-refactor loop.
- **Self-review** — reset into reviewer mode with
  `workflow:code-review-guideline` and read the diff before opening the PR,
  judging the diff itself rather than your intent (`AGENTS.md` § Review
  Independence Gates). Fix Critical/Major findings, then re-review.
- **Verify** — run exactly the commands `AGENTS.md` § Verify names and carry
  the actual output into the PR body, not a claim. If the change touches
  nothing those commands cover, say so instead of running them for form's
  sake.

## Open the PR and request review

- `gh pr create` with `Closes #<n>`, a summary, and the verification output,
  per `docs/agents/issue-tracker.md`.
- If the repo has `.github/workflows/claude-review.yaml`, trigger the
  independent reviewer: `gh pr comment <n> --body "@claude review"`.
  Otherwise note in the report that no independent reviewer is wired up.

## Address findings

Once the review posts (check `gh pr view <n> --comments` a few minutes after
triggering), fix every **Important** finding, re-run whatever verify commands
the fix touches, push, and re-trigger with the same comment. You MUST cap this
loop at 5 rounds; on the 5th without convergence, you MUST stop and report to
the human — a stuck review needs a human call.

## Resuming (`continue`)

There's no separate state machine — this session's context is the record of
where a run is. `continue` means: re-read the target's current state
(issue/PR body, comments, CI, review threads) and resume the one pending step,
rather than restarting. If the human instead hands over a `/handoff` document
from another session, treat it as the resume point.

## Report

Summarize per `AGENTS.md` § The cycle, step 5: changed files, verification
evidence, trade-offs, residual risk, deferred follow-ups, and skill
maintenance status.
