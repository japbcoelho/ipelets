#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

if ! command -v luac5.4 >/dev/null 2>&1; then
  printf 'luac5.4 is required for Lua syntax validation.\n' >&2
  exit 2
fi

if ! command -v lua5.4 >/dev/null 2>&1; then
  printf 'lua5.4 is required for the geometry regression suite.\n' >&2
  exit 2
fi

ipelets=()
if (( $# > 0 )); then
  ipelets=("$@")
else
  for version_file in "$repo_root"/*/VERSION; do
    [[ -f "$version_file" ]] || continue
    ipelets+=("$(basename -- "${version_file%/VERSION}")")
  done
fi

for ipelet_name in "${ipelets[@]}"; do
  ipelet_root="$repo_root/$ipelet_name"
  source_file="$ipelet_root/$ipelet_name.lua"
  tests_dir="$ipelet_root/tests"
  if [[ ! -f "$source_file" || ! -d "$tests_dir" ]]; then
    printf 'Unknown or incomplete ipelet: %s\n' "$ipelet_name" >&2
    exit 3
  fi
  printf 'Validating %s\n' "$ipelet_name"
  luac5.4 -p "$source_file"
  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$tests_dir" -v
done

if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$repo_root" diff --check
fi
