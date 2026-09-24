# Architecture

## Overview

codex-automation is a single-agent overnight supervisor.

It deliberately separates **task orchestration**, **model execution**, **Git/GitHub publication**, and **observation** so that the model is not responsible for enforcing its own safety or deadlines.

```text
systemd timer
    |
    v
codex-nightly supervisor
    |
    +--> GitHub queue (gh)
    |
    +--> managed batch checkout
    |       |
    |       +--> codex exec --json
    |       +--> deterministic validation
    |
    +--> Git commit / push / draft PR
    |
    +--> reports + JSONL + state.json
```

## Trust boundaries

### Codex process

Codex receives:

- the target repository checkout
- the selected issue
- project-local instructions
- workspace-write access

Codex does not need the GitHub token to implement an issue.

The default approval policy is `never`, so an unattended run cannot stop waiting for a human approval prompt. Requests outside the sandbox remain unavailable instead.

### Supervisor

The Bash supervisor owns:

- exclusive run lock
- schedule and cutoff calculations
- GitHub issue selection
- Git branch creation
- network timeouts
- final validation
- commits and pushes
- draft PR creation
- discovery issue publication
- recovery of interrupted work
- per-run state and reports

### systemd

systemd is the independent process-level fuse.

For the bundled 23:30 timer, `RuntimeMaxSec=7h30m` reaches the 07:00 morning boundary. `KillMode=control-group` ensures descendants such as Codex and Gradle are part of the stop operation.

The script also enforces its configured `HARD_STOP` and bounds long subprocesses.

### GitHub

GitHub is the durable coordination surface:

- issues define candidate work
- labels define automation state
- remote branches preserve successful commits
- draft PRs expose reviewable results

No automatic merge is performed.

## Run state machine

```text
preflight
   |
   v
queue
   |
   +--> implementing-issue-N
   |          |
   |          v
   |    validating-issue-N
   |          |
   |          v
   |    publishing-issue-N
   |
   +--> discovery
   |
   v
wrap-up
   |
   v
complete
```

The active phase is written atomically to `state.json`.

## Managed checkout

Batch work lives under:

```text
~/.local/share/codex-automation/repos/OWNER/REPO
```

The checkout contains an internal marker:

```text
.git/codex-automation-managed
```

A clean legacy checkout under the managed path can be adopted.

A dirty checkout without that marker is never automatically reset.

## Interrupted-run recovery

If a managed checkout is dirty at the beginning of a new run, the supervisor preserves tracked and untracked changes using:

```text
git stash push -u
```

The resulting stash is recorded in the run artifacts.

This lets a 07:00 termination remain aggressive without making the next night unrecoverable.

## Time budgets

There are several independent limits:

- `MAX_ISSUES_PER_NIGHT`
- `MAX_DISCOVERY_ISSUES`
- `MAX_VALIDATION_SECONDS`
- `GH_TIMEOUT_SECONDS`
- `GIT_TIMEOUT_SECONDS`
- `DISCOVERY_STOP`
- `WRAP_START`
- `HARD_STOP`
- systemd `RuntimeMaxSec`

The goal is graceful degradation: one slow Gradle build, broken network request or difficult issue must not consume the entire night.

## GitHub mutation policy

Read-only GitHub operations may be retried.

Non-idempotent writes are deliberately not blindly retried because a timeout after a successful server-side write can otherwise create duplicate issues or PRs.

Non-critical GitHub side-effect failures are counted in `summary.json`.

## Discovery

Codex writes findings into a runner-owned side channel:

```text
.codex-automation/discoveries.json
```

The supervisor:

1. validates the JSON shape
2. normalizes finding type
3. searches for likely title duplicates
4. publishes a bounded number of issues
5. optionally queues safe categories for a future night

`idea` findings are never automatically queued.

## Validation boundary

Codex may run project checks during implementation, but publication depends on an outer deterministic `VALIDATE_CMD`.

A failed final validation:

- prevents publication as successful work
- preserves a binary diff patch in run artifacts
- marks the issue blocked
- removes it from the automatic queue

## Observability

Each invocation gets a unique run directory and a `latest` symlink.

Human-readable:

- `NIGHTLY_REPORT.md`
- `run.log`

Machine-readable:

- `state.json`
- `summary.json`
- Codex JSONL
- TSV ledgers for PRs, discoveries and blocked work

The JSONL stream contains exposed Codex events, not private hidden chain-of-thought.

## Scaling

v2 remains single-agent by design.

The safe v3 scaling unit is an independent Git worktree per worker behind a central scheduler. Multiple agents must never share a writable checkout.
