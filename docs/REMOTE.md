# Codex / ChatGPT Remote

The goal of Remote is different from Git synchronization.

Git synchronizes code. Remote synchronizes the live Codex experience: supported threads, project context, terminal output, diffs, tests, approvals and steering controls.

## Current practical setup for a Linux homelab

Direct Linux-host Remote pairing is not currently the documented supported path. Use a supported Codex desktop host and add the homelab through **Remote SSH**.

Recommended topology:

```text
ChatGPT mobile Remote
        |
secure Codex relay
        |
Codex desktop on Windows/macOS
        |
Remote SSH project
        |
Linux homelab
        |
Marvel repository
```

The Codex desktop app can detect SSH hosts from your SSH configuration and open projects on the remote machine.

Example SSH config on the desktop machine:

```sshconfig
Host homelab
    HostName YOUR_HOMELAB_IP_OR_DNS
    User vlad
    IdentityFile ~/.ssh/id_ed25519
```

Then add the target checkout created by this project as a Remote SSH project.

By default it lives under:

```text
~/.local/share/codex-automation/repos/<owner>/<repo>
```

## Important limitation

The batch runner starts `codex exec` from systemd. The Codex CLI records structured run data and this project saves JSONL traces, but OpenAI does not document a guarantee that every externally launched background `codex exec` run will appear as a first-class Remote chat in the desktop/mobile UI.

Therefore:

- **Guaranteed unattended behavior:** use this repository's batch mode.
- **Guaranteed native Remote UX:** start the work as a Codex Remote thread/automation/Goal on the SSH project.
- **Guaranteed audit trail for batch mode:** use JSONL traces, systemd logs, Git commits, GitHub issues and draft PRs.

Do not build automation around undocumented files inside `~/.codex` just to force a chat to appear. Those are implementation details and can change.

## Best workflow today

For normal nights, let the Linux runner do the work and use GitHub + JSONL as the durable record.

When you specifically want to watch and steer a long run from the ChatGPT app:

1. Open the homelab repository as a Remote SSH project in Codex desktop.
2. Start a Codex thread there.
3. Turn the objective into a Goal if it is multi-turn.
4. Use the ChatGPT mobile Remote tab to inspect progress, diffs, terminal/test output and to steer or approve.
5. Keep the 07:00 boundary in the automation/goal instructions and use OS-level supervision for any runner-managed job.

## What “see what it thought” means

Remote and JSONL can expose useful progress, tool activity, commands, outputs, diffs, test results and model-visible summaries. They do not expose private hidden chain-of-thought.

## Future direction

If direct Linux Remote hosting becomes officially supported, this repository can make the homelab itself the native Remote host and remove the desktop SSH hop.
