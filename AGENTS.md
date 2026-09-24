# AGENTS.md

## Purpose

This repository builds a conservative unattended supervisor around Codex.

Reliability, recoverability and observability are more important than maximizing autonomy.

## Invariants

1. Never remove the absolute morning cutoff.
2. Never work directly on the target repository default branch.
3. Never merge pull requests automatically.
4. Keep GitHub credentials outside the Codex sandbox when practical.
5. Keep discovery bounded and deduplicated.
6. A failed validation must never be presented as successful work.
7. Prefer a blocked issue and a report over destructive recovery.
8. Batch mode must remain usable without Codex Remote.
9. Keep the batch checkout separate from a human development checkout.
10. Preserve interrupted tracked/untracked work before resetting a managed checkout.
11. Never auto-recover a dirty checkout that is not explicitly marked automation-managed.
12. Remote documentation must distinguish documented product behavior from assumptions.
13. Do not claim access to hidden model chain-of-thought. Logs may contain exposed events, command output and agent summaries, not private reasoning.
14. GitHub writes that are not essential to preserving code should fail soft and be reported.
15. A single queued issue must not be allowed to retry forever.

## Shell style

- Bash uses `set -Eeuo pipefail`.
- Quote paths and variables.
- Do not require Python for the core runner.
- Prefer standard GNU/Linux utilities.
- Network operations must be bounded by timeouts.
- Long validation commands must be bounded by both a configured limit and the morning deadline.
- Avoid retrying non-idempotent GitHub writes.
- Keep secrets out of command output and reports.
- Keep configuration in `config.env`.
- Keep target-repository runtime state outside this repository.

## Product behavior

### Batch

`codex exec --json` is the batch primitive.

The outer runner owns:

- schedule
- queue
- Git
- GitHub mutations
- deterministic validation
- publication
- recovery
- reporting

### Remote

Do not create dependencies on undocumented Codex internal state in order to make a batch run appear as a Remote session.

### Future transports

If SDK, app-server or exec-server support is introduced, keep queue/validation/reporting independent from the transport implementation.

## Release gate

Before changing runner behavior, validate:

```bash
bash -n scripts/codex-nightly
bash -n scripts/codex-doctor
bash -n scripts/install.sh
shellcheck scripts/codex-nightly scripts/codex-doctor scripts/install.sh
systemd-analyze verify systemd/codex-nightly.service systemd/codex-nightly.timer
```

Also run the offline doctor against the example config:

```bash
CODEX_AUTOMATION_CONFIG="$PWD/config/config.env.example" scripts/codex-doctor --offline
```
