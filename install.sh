#!/usr/bin/env bash
# install.sh — symlink claude-j scripts into ~/bin (or $PREFIX/bin).
set -euo pipefail

PREFIX=${PREFIX:-$HOME}
BIN_DIR="$PREFIX/bin"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/bin" && pwd)"

mkdir -p "$BIN_DIR"

for f in "$SRC_DIR"/*; do
  name=$(basename "$f")
  dest="$BIN_DIR/$name"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "skipping $name: $dest already exists and is not a symlink" >&2
    continue
  fi
  ln -sfn "$f" "$dest"
  echo "linked $name → $dest"
done

echo
echo "done. ensure $BIN_DIR is on your PATH."
