---
description: Summarise the independent bug and security review results for a PR description
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/pr-evidence.sh:*)"]
---

# Review results for the PR

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/pr-evidence.sh"; echo "[exit: $?]"
```

About the output above:

- `[exit: 0]`: paste everything from `<!-- review-loop:start` to `<!-- review-loop:end -->` into the PR description as is. Do not edit it
- `[exit: 1]`: do not create the PR. Resolve the reasons in the WARNING (uncommitted changes, stale reviews, open findings), then run this command again
- The risk tier is the independent reviewer's call. Do not lower it yourself
