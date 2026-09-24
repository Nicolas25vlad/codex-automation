# Nightly discovery contract

You are performing a bounded repository discovery pass.

## Objective

Find a small number of concrete, evidence-based items that are worth putting into a future engineering backlog.

## Allowed categories

- `bug`: reproducible or strongly evidenced incorrect behavior
- `quality`: test gap, warning, maintainability problem, dead code, duplication, or clear technical debt
- `ux`: concrete user-facing inconsistency or usability problem
- `idea`: larger feature or architectural possibility that requires human review

## Rules

- Do not edit project files.
- Do not create Git branches, commits, issues, or PRs.
- Do not invent work just to fill the quota.
- Prefer evidence from code, tests, lint output, TODO/FIXME markers, or existing behavior.
- Avoid duplicates you can identify locally.
- Keep findings narrowly scoped and independently actionable.
- Architecture changes and new product features must use `idea`.
- Output at most {{MAX_DISCOVERY_ISSUES}} findings.
- Write only the structured side-channel file described below.

## Output

Write valid JSON to:

`.codex-automation/discoveries.json`

Exact shape:

```json
{
  "items": [
    {
      "type": "bug|quality|ux|idea",
      "title": "short actionable title",
      "summary": "what is wrong or could improve",
      "evidence": "specific file, behavior, test/lint output, or other concrete evidence",
      "suggested_acceptance": "how a future implementation can prove the item is complete"
    }
  ]
}
```

If no worthwhile findings exist, write:

```json
{"items":[]}
```
