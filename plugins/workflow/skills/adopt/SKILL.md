---
name: adopt
description: Bootstrap the shared plan/implement/self-review/verify/report working agreement into the current repository — writes AGENTS.md, CLAUDE.md, REVIEW.md, docs/agents/*, .claude/settings.json and the @claude review caller workflow from templates, filling repo-specific facts. Use when asked to adopt, apply, or set up the workflow / working agreement in a repo.
argument-hint: "[--no-ci]"
disable-model-invocation: true
---

# Adopt

Write this plugin's per-repo files into the current repository, filled in for
this repo. The templates live in this skill's base directory, under
`templates/` — `dot-claude/` maps to `.claude/` and `dot-github/` to
`.github/`.

## 1. Survey

Before asking anything, infer what you can:

- `git remote -v` → `{{OWNER_REPO}}`, `{{REPO_NAME}}`;
  `git symbolic-ref refs/remotes/origin/HEAD` → `{{DEFAULT_BRANCH}}`.
- README, manifests (`go.mod`, `package.json`, `pyproject.toml`, `Cargo.toml`,
  …), `Makefile` / scripts, and `.github/workflows/` → description, project
  map, and the commands CI already runs (the best source for
  `{{VERIFY_COMMANDS}}` and `{{TOOLING_ENFORCED}}`).
- Code generators (sqlc, openapi, prisma, protobuf, …) →
  `{{GENERATED_CODE_LENS}}`.
- Existing `docs/`, `docs/adr/`, `CONTEXT.md` → `{{EXTRA_DOCS}}`.

Check for files the templates would overwrite (`AGENTS.md`, `CLAUDE.md`,
`REVIEW.md`, `docs/agents/*`, `.claude/settings.json`,
`.github/workflows/claude-review.yaml`). You MUST NOT overwrite an existing
one: merge into it (for `.claude/settings.json`, merge the two keys into the
JSON) and show the human the merge.

## 2. Ask

Ask in one batch only for what the survey could not settle — typically:

- the escalation triggers (default: migrations, data loss, auth);
- what counts as Critical / Major in this domain (`{{CRITICAL_EXAMPLES}}`,
  `{{MAJOR_EXAMPLES}}`);
- whether to wire the CI reviewer (skip it if `$ARGUMENTS` has `--no-ci`).

Propose a concrete default for each so the human can just confirm.

## 3. Write

Copy each template to its target path and replace every `{{PLACEHOLDER}}`.
A lens with nothing to say becomes a single line ("None yet — add as review
findings recur."), not an invented rule. No `{{` may remain:
`grep -rn '{{' AGENTS.md CLAUDE.md REVIEW.md docs/agents .claude .github`.

Keep the repo files thin: nothing that is already in this plugin's shared
skills gets copied in.

## 4. Hand off

Do not commit on the default branch. Create
`doc/adopt-agent-workflow`, commit, and report:

- the files written or merged, and every value you inferred rather than were
  told (so the human can correct them);
- remaining one-time setup: for CI review, install the Claude GitHub App on
  the repo and add the `CLAUDE_CODE_OAUTH_TOKEN` secret.

Open a PR only if the human asks.
