---
name: code-review-guideline
description: Review methodology — reviewer-mode reset, diff scoping, the severity ladder, evidence format, plus the repo's own lenses from docs/agents/review-lenses.md. Use at the start of any review task: the self-review phase of the cycle, reviewing a pull request, auditing a change, or checking your own diff before calling work done.
---

# Code review guideline

How to review a change. This applies to every review, whether the output is a
posted pull-request review or your own self-review of a diff you just wrote.

This file is the shared method. Two repo files layer on top of it:

- **`docs/agents/review-lenses.md`** — the repo's own lenses (architecture
  boundaries, generated code, domain invariants) and what counts as Critical
  or Major *there*. Read it before reviewing; apply the lenses that overlap
  the diff. If it doesn't exist, apply only this file.
- **`REVIEW.md`** at the repo root — governs a **posted** review (the CI
  reviewer) and **wins on conflict** with this file.

> The dividing rule: a rule that is true whether or not anyone else sees the
> review belongs here (or in the lenses). A rule about the posted artifact
> belongs in `REVIEW.md`.

## Reviewer-mode reset

Self-review is not independent review. It only works if you deliberately stop
being the author first.

- You MUST stop editing before you start reviewing.
- You MUST reread the issue and its acceptance criteria before reading the diff.
- You MUST read the diff *before* the surrounding files, so you see what
  changed rather than what you meant.
- You MUST judge the diff and its behavior, not your intent.
- After fixing any **Critical** or **Major** finding you MUST re-review — the
  fix is new code that nobody has reviewed.

## Scoping the diff

- You MUST establish scope before reporting anything:

  ```bash
  git status                        # untracked files count as part of the change
  git diff origin/main...HEAD       # the branch's own work (use the repo's default branch)
  gh pr diff <n>                    # when reviewing someone else's PR
  ```

- Use **three dots**: branches rebase onto the default branch, so two dots
  would mix unrelated drift into your diff.
- In scope: the diff, and behavior the diff affects.
- Out of scope: problems that predate the diff. You MAY note them, but you
  MUST report them separately.

## Severity ladder

| Tier | Meaning | Always includes |
| --- | --- | --- |
| **Critical** | Wrong results, lost data, or a security hole if merged. | Data loss in a migration. Auth bypass. Hand-edits to generated code. Whatever the lenses file lists as Critical. |
| **Major** | Structural damage or an unguarded behavior change. | New runtime behavior with no test. A missing ADR on an escalation trigger (`AGENTS.md` § Escalation). Whatever the lenses file lists as Major. |
| **Minor** | Hurts readability or maintainability. | Unclear naming. An error returned without context. A test that breaks its siblings' pattern. |
| **Nit** | Cosmetic. | Typos, ordering, comment wording. |

- `AGENTS.md` § Review Independence Gates owns the gate: Critical and Major
  findings MUST be fixed before you report.
- **Minor** and **Nit** findings SHOULD be fixed, but MAY be deferred with a
  note.
- The Approve / Request Changes vocabulary is internal. It MUST NOT appear in
  a posted review.

## Evidence

A finding without evidence is an opinion.

- Every finding MUST cite `file:line`.
- Every finding MUST state **what** is wrong, **why** it matters, and the
  **smallest** fix — as a diff snippet where the fix is concrete.
- You MUST NOT report a finding you cannot locate. If you suspect a problem
  but cannot anchor it, ask it as a question, not a finding.

## Verification

- You MUST report the **actual output** of the commands in `AGENTS.md` §
  Verify, or state plainly which you skipped and why.
- When a change needs verification you cannot run, say so rather than assume
  it passes.

## Lenses

1. The repo's own lenses — `docs/agents/review-lenses.md`.
2. Code quality — [`references/code-quality.md`](references/code-quality.md),
   language-agnostic.
3. Escalation — `AGENTS.md` § Escalation owns which changes escalate. Flag
   such a change that carries no ADR.
4. Branch hygiene — `AGENTS.md` § Conventions owns the branch rules. Flag a
   diff that mixes work for a second issue.

## Escalation

- A review is **report-only**. You MUST NOT mutate the codebase while
  reviewing — fixes belong to a following implementation phase.
- When a finding needs the author's judgment rather than a fix, report it as
  `Decision needed:`.
- When the written guidance is silent on something you keep hitting, report
  a `Guideline gap:` note — and say whether the gap belongs in this shared
  skill or in the repo's lenses file.
- High-risk changes (the repo's escalation triggers) MUST NOT be called
  merge-ready on the strength of a self-review alone.
