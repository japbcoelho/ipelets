#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ipelet_name=${1:-circles}
source_file="$repo_root/$ipelet_name/$ipelet_name.lua"

if [[ ! -f "$source_file" ]]; then
  printf 'Unknown ipelet or missing source: %s\n' "$source_file" >&2
  exit 2
fi

if [[ -n "${IPELETS_DIR:-}" ]]; then
  target_dir=$IPELETS_DIR
elif command -v flatpak >/dev/null 2>&1 && flatpak info org.otfried.Ipe >/dev/null 2>&1; then
  target_dir="$HOME/.var/app/org.otfried.Ipe/.ipe/ipelets"
elif [[ "$(uname -s)" == "Darwin" ]]; then
  target_dir="$HOME/Library/Ipe/Ipelets"
else
  target_dir="$HOME/.ipe/ipelets"
fi

mkdir -p -- "$target_dir"
install -m 0644 -- "$source_file" "$target_dir/$ipelet_name.lua"

printf 'Installed %s at %s\n' "$ipelet_name" "$target_dir/$ipelet_name.lua"
printf 'Restart Ipe to load the ipelet.\n'
