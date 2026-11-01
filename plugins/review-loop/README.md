# review-loop

When Claude is about to stop, **a separate `claude -p` session that has not seen the implementation conversation**
reviews the changes. If it finds problems, Claude is kept working and asked to fix them.
Once installed, it runs in every git repository on the machine.

Based on: [How the Claude Code team does code review](https://claude.dev/blog/solving-code-review-at-anthropic/)

## How it works

1. When Claude tries to stop, the Stop hook runs
2. **Bug review**: a separate session reviews the changes. Line 1 of its output is the finding count, line 2 is the risk tier. Important findings are sent back to Claude
3. **Security review**: once the bug review passes, a separate session reviews with the same approach as the official `/security-review`. High and Medium findings are sent back (Low is informational)
4. Later rounds only look at changes since the previous round and do not repeat earlier findings. Each review stops after 3 rounds and asks Claude to summarise instead
5. If Claude tries to stop again without changing anything while findings remain, it is sent back once. The second time it is allowed to stop, to avoid an endless loop

## When it does nothing

In these cases nothing runs and no plan usage is spent:

- Not a git repository
- Working directly on the base branch (`main`, etc.)
- Nothing changed against the base
- The contents have not changed since the last review (committing or staging alone does not count as a change)
- Disabled with `git config review-loop.enabled false`
- The repository has its own review loop (`.claude/hooks/review-on-stop.sh` or `scripts/review.sh`), so the two never run together

## Commands

| Command | What it does |
|---|---|
| `/review-loop:review` | Run the bug and security reviews right now, part-way through the work |
| `/review-loop:evidence` | Build the "Independent review" block for a PR description. Fails if the reviews are stale, have open findings, or there are uncommitted changes |

For a manual second opinion you can also use the `reviewer` subagent.

## Per-repository settings (all optional)

Settings that add no files to the repository live in git config:

```bash
git config review-loop.enabled false   # disable for this repository
git config review-loop.base develop    # base branch (default: origin/HEAD → origin/main → origin/master → main → master)
git config review-loop.maxRounds 5     # round limit (default: 3)
```

To change what the reviews look for, add files:

| File | Purpose |
|---|---|
| `REVIEW.md` (repository root) | Bug review rules. Without it, the bundled [defaults/REVIEW.md](defaults/REVIEW.md) is used. Keep the line 1 / line 2 output rules |
| `.claude/review-loop/security-extra.md` | Extra security categories specific to the repository |
| `CLAUDE.md` | If present, the reviewer also treats it as conventions to check |

In repositories where the same finding keeps coming up, add it to REVIEW.md. The back-and-forth gets shorter over time.

## Where results are stored

Results are saved in `.git/review-loop/<branch>/`. Nothing is added to the working tree, so no `.gitignore` change is needed.

## Requirements

- `claude` (signed in), `git`, `jq`, `bash`
- Each review run starts one `claude -p` session and uses your plan's usage

## License

`prompts/security-review.md` is based on the `/security-review` command from
[anthropics/claude-code-security-review](https://github.com/anthropics/claude-code-security-review)
(MIT License, Copyright (c) 2025 Anthropic). The full license text is in `prompts/LICENSE-claude-code-security-review`.
