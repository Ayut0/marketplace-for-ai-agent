# marketplace-for-ai-agent

One home for the agent working agreement extracted from
[tally-up](https://github.com/Ayut0/tally-up): the
`plan → implement → self-review → verify → report` cycle, the `/address`
orchestrator, the review methodology, and the `@claude review` CI reviewer.

## What lives where

| Shared here (update once, every repo gets it) | Per repo (thin, filled in by `/workflow:adopt`) |
| --- | --- |
| `plugins/workflow/skills/address` — the orchestrator | `AGENTS.md` — the cycle plus the repo's Project map, **Verify** commands, Escalation triggers |
| `plugins/workflow/skills/code-review-guideline` — reviewer-mode reset, scoping, severity ladder, evidence | `docs/agents/review-lenses.md` — the repo's own review lenses and Critical/Major examples |
| `plugins/workflow/skills/adopt` — the bootstrapper and its templates | `REVIEW.md` — posted-review policy (repo-tunable "do not report" list) |
| `.github/workflows/claude-review.yml` — reusable CI reviewer | `docs/agents/{issue-tracker,domain}.md` — config the matt-pocock skills read |
| | `.claude/settings.json` — auto-enables this plugin; `.github/workflows/claude-review.yaml` — 10-line caller |

The dividing rule: if a rule is true in every repo, it lives here; if it names a
command, a directory, or a domain concept of one repo, it lives in that repo.

## Other plugins

| Plugin | What it does |
| --- | --- |
| [`review-loop`](plugins/review-loop/README.md) | Before Claude stops, a separate `claude -p` session reviews the branch for bugs, then security, and sends findings back until they are fixed (max 3 rounds). Machine-wide once installed; opt a repo out with `git config review-loop.enabled false`. |

```
/plugin install review-loop@ayut0-agent-workflow
```

## Adopting a repo

1. Open Claude Code in the target repo and install once (local machine):

   ```
   /plugin marketplace add Ayut0/marketplace-for-ai-agent
   /plugin install workflow@ayut0-agent-workflow
   ```

2. Run `/workflow:adopt`. It inspects the repo, asks for anything it can't
   infer (verify commands, escalation triggers, lenses), and writes the
   per-repo files listed above. Commit them on a branch and open a PR.

3. For the CI reviewer: install the [Claude GitHub App](https://github.com/apps/claude)
   on the repo and add the `CLAUDE_CODE_OAUTH_TOKEN` secret
   (`claude setup-token`). Then comment `@claude review` on a PR.

After step 2, the committed `.claude/settings.json` makes the plugin load
automatically — in cloud sessions and for collaborators too — so step 1 is only
needed the first time on a given machine.

## Visibility

Keep this repo **public** (it holds no secrets). Cloud sessions and the
reusable workflow fetch it anonymously; a private repo would need extra
credentials on both paths.

## Versioning

Callers reference `@main`. To freeze a repo against changes here, tag a
release (`v0.1.0`) and point that repo's caller workflow and
`extraKnownMarketplaces` source at the tag.
