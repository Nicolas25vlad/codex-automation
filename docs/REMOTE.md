# Codex / ChatGPT Remote

codex-automation has two different kinds of synchronization:

1. **work synchronization**: code, issues, commits, draft PRs and reports
2. **session synchronization**: a live Codex thread that can be viewed and steered from Remote

They are intentionally treated as separate capabilities.

## Batch mode

The systemd runner launches `codex exec --json` on the Linux homelab.

This mode guarantees the things codex-automation controls itself:

- wall-clock scheduling
- issue selection
- local implementation
- deterministic validation
- JSONL event traces
- Git commits and draft PRs
- discovery issues
- recovery after interruption
- a hard morning stop

A batch run is observable through:

```bash
journalctl --user -fu codex-nightly.service
watch -n 2 cat ~/.local/state/codex-automation/latest/state.json
less ~/.local/state/codex-automation/latest/codex-*.jsonl
```

## Native Remote experience

OpenAI's Remote experience is designed as a control plane for coding work running on development machines. It can expose supported Codex threads, terminal/test activity, diffs, review and steering controls to the ChatGPT mobile app.

Use this when the requirement is:

> I want to open ChatGPT on my phone at 03:00 and actively inspect or steer the coding session.

The documented desktop Codex experience is currently on macOS and Windows. A Linux homelab can still be the machine that stores/builds the code by using the supported remote-host/SSH workflow from that desktop environment.

Conceptually:

```text
ChatGPT mobile
      |
 Codex Remote
      |
supported Codex desktop host
      |
 remote host / SSH
      |
Linux homelab
      |
human/Remote checkout
```

Keep that human/Remote checkout separate from the batch checkout:

```text
batch:
~/.local/share/codex-automation/repos/OWNER/REPO

human/Remote:
~/src/REPO
```

The batch runner is allowed to reset/recover its own checkout. Your human checkout should never be subject to that lifecycle.

## Important limitation

OpenAI documents `codex exec` as the right primitive for scripts, CI and bounded background tasks, and Remote as the native control surface for interactive/persistent Codex work.

It is **not documented that an arbitrary `codex exec` process launched externally by systemd will automatically become a first-class Remote chat**.

Therefore codex-automation does not:

- copy internal files from `~/.codex`
- edit private Codex databases
- forge thread/session identifiers
- depend on undocumented ChatGPT storage formats

Those approaches would be brittle and could corrupt state.

## What JSONL gives you

`codex exec --json` emits structured events. codex-automation keeps them verbatim per run.

That provides an audit trail of useful observable activity such as:

- tool/command events exposed by the CLI
- command output
- task progress events
- final agent output
- failures and timing

It does **not** expose private hidden chain-of-thought.

## Advanced: Codex app-server / SDK

OpenAI also exposes the Codex SDK and `codex app-server` for applications that need to start, resume and stream Codex tasks programmatically.

These are a future direction for codex-automation if it grows from a shell supervisor into a service with its own live control UI.

They are not required for v2.

## Advanced: self-hosted Agents API environment

OpenAI's Agents API can connect a self-hosted environment using:

```text
codex exec-server --remote ...
```

The executor connects outbound over WebSocket, receives agent shell/file operations and returns results.

This is useful if a future version wants an API-owned agent session whose compute runs on the homelab.

It is a different architecture from the current `codex exec` batch runner and should not be treated as proof that its sessions automatically appear in ChatGPT Remote.

## Recommended workflow today

### Normal unattended night

Use the batch runner.

Morning review comes from:

1. `NIGHTLY_REPORT.md`
2. draft PRs
3. discovered issues
4. `summary.json`
5. JSONL traces when deeper inspection is useful

### Night where live supervision matters

Start the work from a native Codex Remote-capable project/session rather than expecting systemd batch work to become a Remote thread after the fact.

The OS-level runner can still remain useful as the scheduling/watchdog layer in a future integration, but native session ownership should remain with the documented Codex/Remote surface.

## Future integration target

A future v3 can introduce an optional control-plane adapter:

```text
scheduler/watchdog
       |
       +-- batch adapter -> codex exec
       |
       +-- remote adapter -> supported Codex session API/app-server
       |
       +-- agents adapter -> self-hosted exec-server
```

The core queue, validation, reporting and hard-stop logic should remain independent of which Codex transport owns the session.
