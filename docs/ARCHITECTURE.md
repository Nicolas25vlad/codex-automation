# Architecture

## Trust boundaries

The runner deliberately separates three responsibilities.

### Codex

Codex edits and tests the checked-out project in a workspace-write sandbox. It does not need the GitHub token to implement an issue.

### Runner

The runner owns scheduling, deadlines, Git state, validation, GitHub issue mutations, pushes and PR creation.

### GitHub

GitHub is the durable task and review surface. Issues define work; draft PRs expose results.

## Lifecycle

1. systemd starts the runner.
2. runner calculates the next absolute 07:00 cutoff.
3. runner creates/updates the dedicated target checkout.
4. runner ensures standard labels exist.
5. runner selects a queued issue.
6. runner creates a branch from the configured base branch.
7. runner invokes `codex exec --json` with a deadline enforced by GNU `timeout`.
8. runner executes `VALIDATE_CMD`.
9. successful work is committed, pushed and opened as a draft PR.
10. blocked work is labeled and reported.
11. when the queue is empty, discovery may run until the discovery cutoff.
12. discovery output is parsed and deduplicated before issues are created.
13. wrap-up begins at the configured time.
14. at 07:00 the active Codex child is terminated even if it has not finished.

## Why GitHub access lives outside Codex

An unattended coding agent does not need broad authenticated network access merely to edit a local checkout.

Keeping `gh` calls in the supervisor:

- reduces secret exposure to agent-generated commands
- makes issue/PR side effects explicit
- makes retries easier
- lets the Codex sandbox remain narrower
- keeps policy deterministic

## Why v1 is single-agent

Parallel worktrees are straightforward technically, but they multiply failure modes: duplicate issue selection, branch collisions, simultaneous Gradle load, token bursts and harder morning review.

v1 intentionally proves the lifecycle first. A future v2 can introduce a worker pool once one agent behaves reliably.
