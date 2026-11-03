# Code quality

Language-agnostic checks that apply regardless of architecture. Apply these
alongside the repo's own lenses (`docs/agents/review-lenses.md`), which hold
language- and codebase-specific conventions (doc-comment style, file naming,
error conventions). Severity tiers are the ones in
[`SKILL.md`'s severity ladder](../SKILL.md#severity-ladder).

## Magic values

- SHOULD flag a literal with no obvious meaning that isn't bound to a named
  constant — Minor.
- SHOULD flag a string literal that drives a comparison or dispatch (route,
  method, status, event name) inline instead of through a named constant —
  Minor, even when the literal reads as self-describing.
- MUST flag a magic value that feeds a Critical area named in the lenses
  (money, auth, …) — Critical.

## Dead code

- MUST flag commented-out code introduced by the diff — Minor.
- SHOULD flag an unused import in a changed file — Nit.
- MUST flag an exported/public symbol added with zero callers — Minor.
- MUST flag a field or return value the diff computes that no caller reads —
  Minor. Wire it up or drop it until it has a reader.

## Comments

- SHOULD flag a comment that only restates the code it precedes — Nit.
- Public-API doc-comment rules are language-specific: see the lenses file.

## Type reuse

- SHOULD flag an inline shape repeated more than once in the diff — Minor.
  Extract a named type.

## Control flow

- SHOULD flag a deeply nested `if`/`else` chain flattenable with guard
  clauses / early returns — Minor.
- SHOULD flag a `switch` over an enum-like value with no default /
  exhaustiveness check — Minor.

## Type assertions

- SHOULD flag an unchecked cast/assertion the type checker cannot verify
  (TypeScript `as`, `!`) — Minor, test code included. Prefer a type guard,
  an explicit narrow, or a schema parse. Skip it when the repo's linter
  already enforces this (see `REVIEW.md` § Do not report).
- On data crossing an untyped boundary (JSON, network, mock args) that feeds
  a Critical area — Critical.

## Naming

- SHOULD flag a new file or identifier that breaks its neighbors' naming
  pattern — Minor.
- SHOULD flag package/module-name stutter (`ledger.LedgerPosting`) — Minor.
- SHOULD flag opaque abbreviations (`amt`, `mem`) — Nit.

## YAGNI

- MUST flag a new abstraction (helper, interface, parameter, generic) with
  exactly one caller and no documented future caller — Minor. Inline it.

## DRY (done right)

- SHOULD flag near-identical duplicates of the *same* concern — Minor, by the
  rule of three.
- MUST NOT recommend extracting a helper for blocks that are only
  coincidentally similar.

## KISS

- SHOULD flag a one-liner that takes more than ten seconds to parse when
  named steps would read more clearly — Minor.

## Diff size

- SHOULD flag a diff touching more than ~15 unrelated files or ~600 net lines
  as Minor "consider splitting". Leave the split decision to the human.
