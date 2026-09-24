#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$HOME/.local/bin"
CFG_DIR="$HOME/.config/codex-automation"
DATA_DIR="$HOME/.local/share/codex-automation"
STATE_DIR="$HOME/.local/state/codex-automation"
SYSTEMD_DIR="$HOME/.config/systemd/user"

need=(git gh codex jq timeout flock systemctl)
missing=()
for cmd in "${need[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done

if (("${#missing[@]}" > 0)); then
  printf 'Missing commands: %s\n' "${missing[*]}" >&2
  printf 'Install them, authenticate gh/codex, then rerun this installer.\n' >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$CFG_DIR" "$DATA_DIR" "$STATE_DIR" "$SYSTEMD_DIR"

install -m 0755 "$ROOT/scripts/codex-nightly" "$BIN_DIR/codex-nightly"
install -m 0755 "$ROOT/scripts/codex-doctor" "$BIN_DIR/codex-doctor"
install -m 0644 "$ROOT/prompts/nightly.md" "$DATA_DIR/nightly.md"
install -m 0644 "$ROOT/prompts/discovery.md" "$DATA_DIR/discovery.md"
install -m 0644 "$ROOT/systemd/codex-nightly.service" "$SYSTEMD_DIR/codex-nightly.service"
install -m 0644 "$ROOT/systemd/codex-nightly.timer" "$SYSTEMD_DIR/codex-nightly.timer"

if [[ ! -f "$CFG_DIR/config.env" ]]; then
  cp "$ROOT/config/config.env.example" "$CFG_DIR/config.env"
  chmod 0600 "$CFG_DIR/config.env"
fi

if gh auth status >/dev/null 2>&1; then
  gh auth setup-git >/dev/null 2>&1 || true
fi

systemctl --user daemon-reload

cat <<EOF
Installed.

1. Edit:
   $CFG_DIR/config.env

2. Run the preflight:
   codex-doctor

3. Controlled first run (one issue, no discovery):
   codex-nightly --once

4. Watch service logs:
   journalctl --user -fu codex-nightly.service

5. Enable nightly schedule:
   systemctl --user enable --now codex-nightly.timer

6. If this machine runs without a logged-in desktop session overnight:
   sudo loginctl enable-linger "$USER"
EOF

echo
echo "Running doctor..."
"$BIN_DIR/codex-doctor" || {
  echo
  echo "Installation finished, but doctor found items to fix before enabling the timer." >&2
  exit 1
}
