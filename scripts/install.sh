#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$HOME/.local/bin"
CFG_DIR="$HOME/.config/codex-automation"
SYSTEMD_DIR="$HOME/.config/systemd/user"

need=(git gh codex jq timeout systemctl)
missing=()
for cmd in "${need[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done

if (("${#missing[@]}" > 0)); then
  printf 'Missing commands: %s\n' "${missing[*]}" >&2
  printf 'Install them, authenticate gh/codex, then rerun this installer.\n' >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$CFG_DIR" "$SYSTEMD_DIR"

install -m 0755 "$ROOT/scripts/codex-nightly" "$BIN_DIR/codex-nightly"
install -m 0644 "$ROOT/systemd/codex-nightly.service" "$SYSTEMD_DIR/codex-nightly.service"
install -m 0644 "$ROOT/systemd/codex-nightly.timer" "$SYSTEMD_DIR/codex-nightly.timer"

if [[ ! -f "$CFG_DIR/config.env" ]]; then
  cp "$ROOT/config/config.env.example" "$CFG_DIR/config.env"
  chmod 0600 "$CFG_DIR/config.env"
fi

mkdir -p "$HOME/.local/share/codex-automation" "$HOME/.local/state/codex-automation"

systemctl --user daemon-reload

cat <<EOF
Installed.

1. Edit:
   $CFG_DIR/config.env

2. Verify auth:
   gh auth status
   codex login status

3. Dry/manual run:
   systemctl --user start codex-nightly.service
   journalctl --user -fu codex-nightly.service

4. Enable nightly schedule:
   systemctl --user enable --now codex-nightly.timer

5. If this machine runs without a logged-in desktop session overnight:
   sudo loginctl enable-linger "$USER"
EOF
