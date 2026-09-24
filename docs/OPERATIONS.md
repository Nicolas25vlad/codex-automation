# Operations guide

This document is the runbook for installing, testing and recovering codex-automation on a small Linux homelab.

## 1. Host prerequisites

The runner expects:

- Linux with systemd user services
- Git
- GitHub CLI (`gh`)
- Codex CLI
- `jq`
- GNU coreutils (`timeout`)
- util-linux (`flock`)
- `bubblewrap` recommended for the Codex Linux sandbox

### Arch Linux

```bash
sudo pacman -S --needed git github-cli jq coreutils util-linux bubblewrap nodejs npm
npm install -g @openai/codex@latest
```

Then authenticate:

```bash
gh auth login
codex login
```

The installer runs `gh auth setup-git` when GitHub authentication is already available.

## 2. Install

```bash
git clone https://github.com/Nicolas25vlad/codex-automation.git
cd codex-automation
./scripts/install.sh
```

The installer places:

```text
~/.local/bin/codex-nightly
~/.local/bin/codex-doctor
~/.config/codex-automation/config.env
~/.local/share/codex-automation/nightly.md
~/.config/systemd/user/codex-nightly.service
~/.config/systemd/user/codex-nightly.timer
```

## 3. Configure

Edit:

```bash
nano ~/.config/codex-automation/config.env
```

The default example targets the Marvel Android repository.

Important knobs:

- `TARGET_REPO`: GitHub `owner/repo`
- `MODEL`: Codex model
- `VALIDATE_CMD`: deterministic final gate
- `MAX_ISSUES_PER_NIGHT`: implementation budget
- `MAX_DISCOVERY_ISSUES`: discovery budget
- `MAX_VALIDATION_SECONDS`: per-issue validation ceiling
- `DISCOVERY_STOP`, `WRAP_START`, `HARD_STOP`: morning boundaries

## 4. Preflight

Run:

```bash
codex-doctor
```

It checks commands, config syntax, schedule order, writable state paths, disk space, systemd availability, GitHub auth, Codex auth, repository access and the configured base branch.

The repository CI uses:

```bash
codex-doctor --offline
```

to verify config behavior without credentials.

## 5. First-night test

Do not enable the timer first. Run exactly one issue:

```bash
codex-nightly --once
```

This mode:

- takes at most one `nightly` issue
- runs Codex
- validates the result
- opens a draft PR if successful
- does not run the discovery pass

Inspect:

```bash
cat ~/.local/state/codex-automation/latest/NIGHTLY_REPORT.md
cat ~/.local/state/codex-automation/latest/summary.json
less ~/.local/state/codex-automation/latest/run.log
```

If that works, test discovery separately:

```bash
codex-nightly --discover-only
```

## 6. Enable overnight execution

```bash
systemctl --user enable --now codex-nightly.timer
systemctl --user list-timers codex-nightly.timer
```

For a headless machine that must keep user services alive after logout:

```bash
sudo loginctl enable-linger "$USER"
```

## 7. Observe a run

Systemd:

```bash
journalctl --user -fu codex-nightly.service
```

Structured state:

```bash
watch -n 2 cat ~/.local/state/codex-automation/latest/state.json
```

Artifacts:

```text
~/.local/state/codex-automation/
├── latest -> runs/<run-id>
├── runner.lock
└── runs/
    └── <run-id>/
        ├── run.log
        ├── state.json
        ├── summary.json
        ├── NIGHTLY_REPORT.md
        ├── nightly-prompt.md
        ├── codex-*.jsonl
        ├── codex-*.stderr.log
        ├── prs.tsv
        ├── discoveries.tsv
        └── blocked.tsv
```

## 8. Stop immediately

```bash
systemctl --user stop codex-nightly.service
```

The systemd service uses `KillMode=control-group`, so Codex, Gradle and other child processes are stopped with the service.

## 9. Interrupted-run recovery

The batch checkout is explicitly marked as automation-managed.

If a previous run is interrupted after editing files, the next run does not throw those changes away. It performs:

```bash
git stash push -u -m "codex-automation recovery <run-id>"
```

and records the recovered stash in the new run report.

Inspect recovery stashes:

```bash
cd ~/.local/share/codex-automation/repos/OWNER/REPO
git stash list
git stash show -p stash@{0}
```

The runner refuses to auto-recover a dirty checkout that is not marked as automation-managed.

## 10. Failure meanings

### `nightly:blocked`

The issue could not be safely completed. Typical causes:

- Codex failed or timed out
- validation failed
- no project changes were produced
- Git push or draft PR publication failed

A blocked issue is removed from the automatic queue so it cannot burn the whole night retrying the same failure.

### GitHub side-effect errors

`summary.json` records `github_errors`. These mean the code task may have succeeded while a comment/label operation failed.

### Failed validation patch

If validation fails, the diff is preserved under:

```text
issue-<number>-failed.patch
```

## 11. Batch checkout vs human checkout

Do not use the batch checkout as your normal development directory.

Batch workspace:

```text
~/.local/share/codex-automation/repos/OWNER/REPO
```

Human/Remote workspace:

```text
~/src/REPO
```

Keeping them separate prevents a morning manual edit from being mistaken for interrupted agent work.

## 12. Updating codex-automation

```bash
cd ~/path/to/codex-automation
git pull
./scripts/install.sh
```

The installer preserves an existing `config.env`.
