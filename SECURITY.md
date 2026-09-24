# Security

codex-automation executes an AI coding agent unattended on a real machine. Treat it as automation infrastructure, not as a harmless prompt wrapper.

## Security model

The default design keeps responsibilities separated:

- Codex edits the target workspace inside its configured sandbox.
- The outer supervisor owns GitHub credentials and Git/GitHub publication.
- Pull requests are draft by default and are never auto-merged.
- Long-running operations are bounded by timeouts.
- systemd terminates the entire service control group at the runtime fuse.
- The batch checkout is separate from a human development checkout.

## Secrets

Do not store secrets in:

- this repository
- target repository source files
- `config.env`
- Codex prompts
- issue bodies
- run reports

Authentication should remain in the normal credential stores used by `gh` and Codex.

Run artifacts can contain repository paths, command output, issue content and model/tool events. The systemd unit uses a restrictive umask, but the state directory should still be treated as sensitive developer data.

## Untrusted issues

A GitHub issue becomes model input.

Do not automatically queue issues written by untrusted users. On public repositories, use repository permissions, triage, labels or a separate trusted queueing process so arbitrary issue text cannot directly become an unattended coding instruction.

The runner only selects issues carrying the configured queue label.

## Target repositories

Do not point the runner at:

- production deployment repositories with live credentials
- infrastructure roots that can directly mutate production
- directories outside the dedicated managed workspace
- repositories where generated build scripts can access privileged host resources

## Reporting security problems

If you find a security weakness in this automation, do not demonstrate it against third-party repositories or credentials. Open a minimal report describing the trust-boundary failure and a safe reproduction using dummy data.
