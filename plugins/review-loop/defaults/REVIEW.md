# Review rules (review-loop default)

If the repository has a REVIEW.md at its root, that file is used instead of this one.
In repositories where the same finding keeps coming up, add a REVIEW.md and grow it over time.

## What "broken" means

- A main screen or feature stops working, or an error leaves a blank screen
- Data is corrupted, lost or cannot be restored (migrations, save and delete paths)
- Someone who is not signed in, or another user, can see or change data they should not
- Secrets (API keys, tokens, passwords) leak into code, logs or the client
- A failing or slow external API stops everything, or leaves data half-written
- Docs or the README say something the code does not do

## Focus on

- For bug fixes: does it fix the root cause, not just the symptom?
- Does the change do what it is meant to do without breaking anything else?
- If there are tests, do they really exercise the changed behaviour?
- If there is a CLAUDE.md: does the change break its conventions, or make any of it out of date?

## Skip

- Lock files (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `go.sum`, etc.)
- Generated files (`**/generated/**`, `**/__generated__/**`, `*.gen.*`) and build output
- Snapshot files

## Risk tiers

Decide from what the change touches. When unsure, choose the higher tier.

- **High**: authentication and authorisation, handling of secrets, server-side processing of external input (URL import, file upload, webhooks, etc.), deleting data or migrations, deployment and infrastructure config, adding dependencies
- **Medium**: any other change that alters behaviour
- **Low**: changes that do not alter behaviour (docs, comments, copy, tests only, type-only refactors)

## Output rules

- Line 1 is the count: `Important n / Nit n / Pre-existing n`
- Line 2 is the risk tier: `Risk: Low|Medium|High — reason`
- With no findings, say so explicitly: `No findings`
- Every finding needs `file:line` and evidence. Do not guess from names alone
- Severity: Important (should be fixed) / Nit (optional, at most 3) / Pre-existing (not introduced by this change)
- Group findings of the same kind into one entry and list every location
- Do not report pure style issues or anything a linter would catch
