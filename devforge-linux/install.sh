#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -ne 0 ]] || { echo 'Do not run the installer with sudo.' >&2; exit 1; }
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DEST="$HOME/.local/share/devforge-linux"
BIN="$HOME/.local/bin"
mkdir -p "$BIN" "$(dirname "$DEST")"
if [[ -e "$DEST" ]]; then
  printf 'An installation already exists at %s. Back it up and remove it manually before updating.\n' "$DEST" >&2
  exit 1
fi
if [[ -e "$BIN/devforge" && ! -L "$BIN/devforge" ]]; then
  echo 'A local executable named devforge already exists; it will not be overwritten.' >&2
  exit 1
fi
cp -a "$ROOT" "$DEST"
chmod +x "$DEST/bin/devforge"
ln -sfn "$DEST/bin/devforge" "$BIN/devforge"
printf 'Installed to %s\n' "$DEST"
printf 'Use: %s/devforge --help\n' "$BIN"
printf 'Add ~/.local/bin to your shell PATH if needed.\n'
