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

luac5.4 -p "$repo_root/circles/circles.lua"
python3 -m unittest discover -s "$repo_root/circles/tests" -v

if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$repo_root" diff --check
fi
