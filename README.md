# codex-automation

A conservative overnight supervisor for Codex on a self-hosted Linux machine.

It turns a GitHub issue queue into bounded unattended coding work: Codex implements one issue at a time, deterministic checks validate the result, successful work becomes a draft PR, new bugs/improvements become issues, and the entire process stops before the morning cutoff.

The first real target is the Marvel Android project, but the runner is repository-agnostic.

## Design goals

- useful work while nobody is watching
- GitHub as the durable queue and review surface
- strict wall-clock and work-count budgets
- no automatic merges
- narrow Codex sandbox by default
- GitHub credentials kept outside the Codex process
- deterministic validation before publication
- recoverable interruptions
- machine-readable traces for morning review
- a clean path to Codex/ChatGPT Remote without pretending batch sessions are native Remote chats

## Night lifecycle

```text
23:30  start
  |
  +-- preflight + lock
  +-- recover interrupted managed checkout if needed
  |
  +-- queue loop
  |     |
  |     +-- read one "nightly" issue
  |     +-- create isolated branch
  |     +-- codex exec --json
  |     +-- deterministic validation
  |     +-- commit + push
  |     +-- draft PR
  |     +-- collect side discoveries
  |
  +-- no queued work?
  |     |
  |     +-- bounded discovery pass
  |     +-- deduplicate findings
  |     +-- create GitHub issues
  |
06:15  no new discovery
06:30  no new implementation
07:00  hard stop
```

The bundled systemd service also has an independent 7h30 runtime fuse for the default 23:30 schedule.

## Safety model

The Codex process defaults to:

```text
sandbox: workspace-write
approval policy: never
```

For unattended execution, `never` means the agent does not pause waiting for a human. Operations outside the configured sandbox remain unavailable.

The outer runner owns:

- GitHub reads/writes
- Git branch lifecycle
- commits and pushes
- PR creation
- final validation
- deadlines and process termination

Codex owns:

- repository inspection
- implementation
- local project commands allowed by the sandbox
- structured discovery output

The runner never auto-merges a PR.

## Quick start

### Arch Linux prerequisites

```bash
sudo pacman -S --needed git github-cli jq coreutils util-linux bubblewrap nodejs npm
npm install -g @openai/codex@latest
```

Authenticate:

```bash
gh auth login
codex login
```

Install:

```bash
git clone https://github.com/Nicolas25vlad/codex-automation.git
cd codex-automation
./scripts/install.sh
```

Edit:

```bash
nano ~/.config/codex-automation/config.env
```

Run the preflight:

```bash
codex-doctor
```

Run exactly one queued issue before enabling the timer:

```bash
codex-nightly --once
```

Then enable the nightly schedule:

```bash
systemctl --user enable --now codex-nightly.timer
sudo loginctl enable-linger "$USER"
```

## Default Marvel config

The sample config is already pointed at:

```bash
TARGET_REPO="Nicolas25vlad/projeto-android-marvel"
BASE_BRANCH="main"
MODEL="gpt-6-luna"
VALIDATE_CMD="./gradlew test lint assembleDebug"
```

Safe discoveries of type `bug`, `quality` and `ux` can be queued for a future night. `idea` findings are created for human review but are never auto-queued.

## Commands

```bash
codex-doctor
codex-nightly --once
codex-nightly --discover-only
codex-nightly
systemctl --user start codex-nightly.service
systemctl --user stop codex-nightly.service
journalctl --user -fu codex-nightly.service
```

### `codex-nightly --once`

A controlled smoke test:

- processes at most one queued issue
- validates and publishes it normally
- skips discovery
- exits

### `codex-nightly --discover-only`

Skips implementation and performs one bounded discovery pass.

## Queue labels

The runner creates and uses:

- `nightly`: eligible for implementation
- `nightly:pr-open`: a draft PR was produced
- `nightly:blocked`: human attention is required
- `nightly:discovered`: created from automated discovery
- `kind:bug`
- `kind:quality`
- `kind:ux`
- `kind:idea`

A blocked issue is removed from the automatic queue so one bad task cannot eat every night.

## Observability

Every invocation gets a unique run ID:

```text
~/.local/state/codex-automation/
├── latest -> runs/<run-id>
├── runner.lock
└── runs/
    └── <run-id>/
        ├── state.json
        ├── summary.json
        ├── NIGHTLY_REPORT.md
        ├── run.log
        ├── nightly-prompt.md
        ├── codex-*.jsonl
        ├── codex-*.stderr.log
        ├── prs.tsv
        ├── discoveries.tsv
        └── blocked.tsv
```

Useful commands:

```bash
watch -n 2 cat ~/.local/state/codex-automation/latest/state.json
cat ~/.local/state/codex-automation/latest/summary.json
cat ~/.local/state/codex-automation/latest/NIGHTLY_REPORT.md
```

`codex exec --json` provides structured JSONL events suitable for later metrics and dashboards.

## Interrupted runs

The automation checkout is marked as runner-managed.

If a run is killed while edits are present, the next run preserves tracked/untracked work with a recovery stash instead of deleting it, then resets to the configured base branch.

The runner refuses to auto-recover a dirty checkout that is not marked as automation-managed.

The batch checkout is intentionally separate from your normal human checkout.

## ChatGPT / Codex Remote

Git synchronization and session synchronization are different things.

Batch mode guarantees unattended Linux execution, JSONL traces, reports, GitHub issues and PRs. OpenAI does not document that an arbitrary systemd-launched `codex exec` process will automatically appear as a native Remote chat.

For native phone/desktop supervision, use Codex Remote on a supported desktop host and connect to the Linux homelab/project through the Remote workflow. Remote is the surface for live steering, diffs, tests, terminal output and persistent Codex work.

See [docs/REMOTE.md](docs/REMOTE.md).

## Documentation

- [Operations runbook](docs/OPERATIONS.md)
- [Architecture and trust boundaries](docs/ARCHITECTURE.md)
- [Codex / ChatGPT Remote](docs/REMOTE.md)

## Repository structure

```text
.
├── AGENTS.md
├── config/
│   └── config.env.example
├── docs/
│   ├── ARCHITECTURE.md
│   ├── OPERATIONS.md
│   └── REMOTE.md
├── prompts/
│   └── nightly.md
├── scripts/
│   ├── codex-doctor
│   ├── codex-nightly
│   └── install.sh
└── systemd/
    ├── codex-nightly.service
    └── codex-nightly.timer
```

## Current scope

v2 remains deliberately single-agent.

The next safe scaling step is multiple independent worktrees with a central scheduler, not multiple agents sharing one checkout.
