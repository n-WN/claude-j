#!/usr/bin/env bash
# demo/record.sh — record an asciinema cast of claude-j in action.
#
# Run this *inside* a fresh zellij session. It will spawn a recording
# of `claude-j`, you trigger a few subagents, then exit claude. The
# resulting cast can be uploaded with:
#
#   asciinema upload demo/claude-j.cast
#
# and the resulting URL pasted into README.md.
set -euo pipefail

if [ -z "${ZELLIJ:-}" ]; then
  echo "demo/record.sh: must run inside a zellij session" >&2
  exit 1
fi

if ! command -v asciinema >/dev/null 2>&1; then
  echo "demo/record.sh: install asciinema first (e.g. brew install asciinema)" >&2
  exit 1
fi

CAST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/claude-j.cast"
echo "recording to $CAST"
echo "tip: trigger 2-3 subagents in parallel, then type /exit"
echo
asciinema rec --overwrite -t "claude-j demo" -c "claude-j" "$CAST"
echo
echo "next:  asciinema upload $CAST"
