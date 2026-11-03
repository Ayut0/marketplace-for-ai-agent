---
name: orchestrate
description: Orchestrator for several issues at once — lists the repo's open issues that have no open "blocked by" issues, starts one implementation session per issue (each in its own worktree, running /workflow:address), then reviews each PR itself when the sessions report back. Use when asked to work through the unblocked issues, a milestone or an epic in parallel, or with sub-agents / separate sessions.
argument-hint: [epic issue number | issue numbers | (empty = every ready issue)]
---

# Orchestrate

Fans the repo's ready issues out to parallel sessions and reviews what comes
back. Each session runs `/workflow:address` on one issue, so this skill owns
only the picking, the briefs and the review of results — never the cycle
itself. The orchestrator MUST NOT implement an issue it has dispatched.

Everything repo-specific (Verify commands, Escalation triggers, branch
naming) comes from the repo's `AGENTS.md`. If the repo has no `AGENTS.md`,
stop and suggest `/workflow:adopt`.

## 1. List what is ready

Run `scripts/ready-issues.sh` (in this skill's directory) from the repo. It
reads every open issue, its "blocked by" relations, the PRs that would close
it and any `issue-<n>` branch in one GraphQL call, and prints one line per
issue with a status:

| Status | Meaning | Action |
| --- | --- | --- |
| `ready` | No open blockers, no PR, no branch | Candidate for this batch |
| `in-flight` | An open PR or an `issue-<n>` branch exists | Do not dispatch; resume it with `/workflow:address <pr>` only if asked |
| `fixed` | A merged PR closes it, issue still open | Report it; do not dispatch |
| `blocked` | Lists the open blockers | Wait for them |
| `epic` | Has sub-issues | Dispatch its sub-issues, not the epic |

With an epic number as the argument, keep only the lines whose `parent` is that
epic; with issue numbers, keep only those. Re-run the script immediately
before dispatching: an issue can be merged between listing and dispatch.

## 2. Pick the batch

- Take the `ready` issues, at most **4** per batch (more is slower to review
  than to run).
- At most **one** issue per batch that hits an `AGENTS.md` § Escalation
  trigger, so each escalated change gets a full review on its own.
- Read each picked issue's body and predict the files it touches. Two issues
  that will edit the same file MAY still run together, but each brief MUST
  name the other issue and say which side keeps its changes minimal there.
  If the overlap is the core of both, run them in separate batches.
- Prefer issues that unblock the most others (count how many `blocked`
  lines name them).

Show the human the batch (issue, why it's ready, overlaps) before starting
it. Their go-ahead on the batch stands in for each session's plan-approval
gate in `/workflow:address`; a session MUST still stop and ask on a genuine
product, UX or scope decision.

## 3. Write one brief per issue

A fresh session sees only its brief. Each brief MUST include:

- **Task:** deliver `#<n>` with `/workflow:address <n>`, on a branch named per
  `AGENTS.md` § Conventions, cut from the default branch.
- **Area:** the files/directories it should touch, and the ones other
  sessions in this batch own (stay out of them, or keep edits there minimal).
- **Existing work:** any branch or earlier attempt found in step 1.
- **Escalation:** if a trigger applies, the ADR it owes.
- **Done when:** every `AGENTS.md` § Verify command passes with its actual
  output reported; a PR with `Closes #<n>`; `@claude review` posted if the
  repo has the CI reviewer. It MUST NOT merge.
- **Background:** the epic, that this is one of several parallel sessions,
  and the sync rule (`git rebase origin/<default>`, ask before force-pushing).

## 4. Dispatch

- **Claude desktop app (sessions available):** start one session per brief
  with `start_session` (`initiation: "user_asked"`, `context: "fresh"`,
  `use_worktree: true`). Mark a chapter first when starting two or more.
- **CLI (no separate sessions):** one `Agent` subagent per brief with
  `isolation: "worktree"`, run in the background.

Then end the turn. MUST NOT poll; each session reports back when its turn
ends.

## 5. Review each result

A session's report is not proof. For each one, before telling the human it
is done:

- [ ] `gh pr view <n>`: state, mergeable, CI conclusion.
- [ ] `gh pr diff <n>`: read it in reviewer mode with
      `workflow:code-review-guideline`. Check it stays inside its brief's area.
- [ ] Each "Done when" item in the issue: met, or named as not done.
- [ ] Escalation: the ADR exists and says what was decided.
- [ ] Anything the session says it did not verify (a device, a browser, an
      offline path): verify it yourself, or tell the human exactly what is
      left and how to check it.
- [ ] Notes for later issues in the epic (assumptions a dependent issue must
      honour): put them in the report, or comment them on that issue.

Send fixes back to the session that wrote the PR (it has the context), not to
a new one. MUST NOT merge; merging is the human's gate.

## 6. Next batch

After the human merges, run step 1 again: merged PRs turn their dependents
`ready`. Report the new batch rather than starting it unasked.

## Report

Per batch: one line per issue (PR link, CI, review verdict, open items), what
was verified by the orchestrator itself versus taken from a session's
report, and which issues the merges will unblock next.
