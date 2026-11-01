---
description: Run the independent bug and security reviews on the current changes right now
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/review.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/security-review.sh:*)", "Read"]
---

# Run the independent reviews now

These normally run automatically when you finish. Use this to check part-way through.

## Bug review

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/review.sh"; echo "[exit: $?]"
```

## Security review

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/security-review.sh"; echo "[exit: $?]"
```

## Reading the results

Exit codes: 0 = passed / 1 = findings / 3 = round limit / 4 = unchanged since last review (passed) / 5 = cannot run / 6 = unchanged since last review (findings still open)

Read the files at the printed paths and give the user a short summary of any findings.
Do not fix anything here. Ask the user whether to fix them.
