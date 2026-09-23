# codex-automation

Nightly autonomous Codex runner for a self-hosted Linux machine.

The first target is an Android project: an agent works through a GitHub issue queue overnight, validates its changes, opens draft PRs, discovers bugs/improvements, and stops at a hard morning cutoff.

## What it does

- starts from a systemd user timer (default: 23:30)
- clones/updates a target GitHub repository into a dedicated workspace
- reads open issues carrying the configured queue label
- gives one issue at a time to `codex exec --json`
- keeps GitHub credentials outside the Codex sandbox
- runs project validation before publishing work
- pushes a dedicated branch and opens a draft PR
- marks blocked work instead of looping forever
- when the queue is empty, runs a bounded discovery pass for bugs, quality issues and UX improvements
- creates new GitHub issues from structured discovery output
- enters wrap-up mode before the deadline
- hard-stops at 07:00 even if Codex is still running
- stores JSONL traces and a nightly report for review

## Two operating modes

### 1. Batch mode: recommended for unattended Linux

This repository installs a systemd user timer and a runner around `codex exec`.

This is the mode with the strongest operational guarantees: deterministic start time, hard cutoff, bounded issue count, logs, validation and PR handoff.

### 2. Codex Remote mode: recommended when live supervision matters most

Codex Remote can expose live project context, terminal output, diffs, tests, approvals and supported Codex threads in the ChatGPT/Codex apps. For a Linux homelab today, the supported route is to add the Linux box as a **Remote SSH** project from a supported Codex desktop host.

Direct Linux-host pairing is not currently the supported Remote path, so a background `codex exec` launched by systemd is **not guaranteed to appear as a first-class Remote chat**. See [docs/REMOTE.md](docs/REMOTE.md).

The JSONL trace remains available even when a run is not represented as a Remote thread.

## Install

Requirements:

- Linux with systemd
- Git
- GitHub CLI (`gh`)
- OpenAI Codex CLI
- `jq`
- GNU `timeout`
- SSH access if you want Codex Remote

Authenticate first:

```bash
gh auth login
codex login
```

Then:

```bash
git clone https://github.com/Nicolas25vlad/codex-automation.git
cd codex-automation
./scripts/install.sh
```

Edit:

```bash
nano ~/.config/codex-automation/config.env
```

For the Marvel Android project, set for example:

```bash
TARGET_REPO="Nicolas25vlad/projeto-android-marvel"
BASE_BRANCH="main"
MODEL="gpt-6-luna"
VALIDATE_CMD="./gradlew test lint assembleDebug"
```

Test without waiting for the timer:

```bash
systemctl --user start codex-nightly.service
journalctl --user -fu codex-nightly.service
```

Enable the schedule:

```bash
systemctl --user enable --now codex-nightly.timer
```

If the machine has no logged-in user overnight, enable user lingering once:

```bash
sudo loginctl enable-linger "$USER"
```

## Default night

```text
23:30 start
  |
  +-- GitHub issue queue
  |     |
  |     +-- Codex implementation
  |     +-- validation
  |     +-- commit + push
  |     +-- draft PR
  |
  +-- no queued issue?
  |     |
  |     +-- bounded discovery
  |     +-- create issues
  |
06:15 stop discovery
06:30 stop starting implementation
06:30-07:00 wrap-up
07:00 hard stop
```

## Queue model

The runner uses labels:

- `nightly`: eligible for implementation
- `nightly:pr-open`: implementation produced a PR
- `nightly:blocked`: agent or validation could not finish safely
- `nightly:discovered`: issue was created by discovery

Discovery is capped. New findings are not allowed to grow an unbounded self-feeding backlog in one night.

## Safety model

The Codex process defaults to:

```text
sandbox: workspace-write
approval policy: never
```

The runner, not Codex, performs authenticated GitHub actions. This reduces how much credential-bearing network access the model needs.

Do not point this at production infrastructure or a repository containing secrets.

## Logs

Default location:

```text
~/.local/state/codex-automation/
  nightly-YYYY-MM-DD/
    run.log
    codex-*.jsonl
    codex-*.stderr.log
    discoveries.json
    NIGHTLY_REPORT.md
```

Watch live:

```bash
journalctl --user -fu codex-nightly.service
```

## Manual stop

```bash
systemctl --user stop codex-nightly.service
```

## Repository structure

```text
.
├── AGENTS.md
├── config/
│   └── config.env.example
├── docs/
│   ├── ARCHITECTURE.md
│   └── REMOTE.md
├── prompts/
│   └── nightly.md
├── scripts/
│   ├── install.sh
│   └── codex-nightly
└── systemd/
    ├── codex-nightly.service
    └── codex-nightly.timer
```

## Status

v1 is intentionally single-agent. Parallel worktrees can come later after the single-runner workflow proves reliable.
