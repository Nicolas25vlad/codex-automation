# AGENTS.md

## Purpose

This repository builds a conservative unattended runner around Codex. Reliability and recoverability are more important than squeezing out maximum autonomy.

## Invariants

1. Never remove the absolute hard stop.
2. Never make direct work on the target repository default branch.
3. Never merge pull requests automatically.
4. Keep GitHub credentials outside the Codex sandbox when practical.
5. Keep discovery bounded and deduplicated.
6. A failed validation must not be presented as successful work.
7. Prefer a blocked issue and a report over destructive recovery.
8. Batch mode must remain usable without Codex Remote.
9. Remote documentation must distinguish supported product behavior from experimental assumptions.
10. Do not claim access to hidden model chain-of-thought. Logs may contain tool events, outputs and model-visible summaries, not private reasoning.

## Coding style

- Bash must use `set -Eeuo pipefail`.
- Quote paths and variables.
- Do not require Python for the v1 runner.
- Prefer standard Linux/GNU utilities.
- Keep configuration in `config.env`.
- Keep target-repository state outside this repository.

## Release gate

Before changing runner behavior, validate with:

```bash
bash -n scripts/codex-nightly
bash -n scripts/install.sh
systemd-analyze verify systemd/codex-nightly.service systemd/codex-nightly.timer
```
