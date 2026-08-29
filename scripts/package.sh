#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ipelet_name=${1:-circles}
ipelet_root="$repo_root/$ipelet_name"
version_file="$ipelet_root/VERSION"

if [[ ! -f "$ipelet_root/$ipelet_name.lua" || ! -f "$version_file" ]]; then
  printf 'Unknown or incomplete ipelet: %s\n' "$ipelet_name" >&2
  exit 2
fi

version=$(tr -d '[:space:]' < "$version_file")
archive_dir=${IPELETS_DIST_DIR:-"$repo_root/dist"}
archive="$archive_dir/$ipelet_name-v$version.zip"
checksum="$archive.sha256"

if [[ -e "$archive" || -e "$checksum" ]]; then
  printf 'Refusing to overwrite an existing release artifact: %s or %s\n' \
    "$archive" "$checksum" >&2
  exit 3
fi

stage_root=$(mktemp -d)
trap 'rm -rf -- "$stage_root"' EXIT
package_root="$stage_root/$ipelet_name-v$version"
mkdir -p -- "$package_root/docs/images" "$package_root/examples" "$archive_dir"

install -m 0644 -- "$ipelet_root/$ipelet_name.lua" "$package_root/$ipelet_name.lua"
sed 's#](../LICENSE)#](LICENSE)#g' "$ipelet_root/README.md" > "$package_root/README.md"
sed 's#](../LICENSE)#](LICENSE)#g' "$ipelet_root/README.pt-BR.md" > "$package_root/README.pt-BR.md"
chmod 0644 "$package_root/README.md" "$package_root/README.pt-BR.md"
install -m 0644 -- "$ipelet_root/CHANGELOG.md" "$package_root/CHANGELOG.md"
install -m 0644 -- "$version_file" "$package_root/VERSION"
install -m 0644 -- "$repo_root/LICENSE" "$package_root/LICENSE"
install -m 0644 -- "$repo_root/NOTICE.md" "$package_root/NOTICE.md"
install -m 0644 -- "$ipelet_root/docs/images/"* "$package_root/docs/images/"
install -m 0644 -- "$ipelet_root/examples/README.md" "$package_root/examples/README.md"
install -m 0644 -- "$ipelet_root/examples/"*.ipe "$package_root/examples/"

(
  cd -- "$stage_root"
  python3 -m zipfile -c "$archive" "$ipelet_name-v$version"
)

python3 - "$archive" "$checksum" <<'PY'
import hashlib
import pathlib
import sys

archive = pathlib.Path(sys.argv[1])
checksum = pathlib.Path(sys.argv[2])
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
checksum.write_text(f"{digest}  {archive.name}\n", encoding="ascii")
PY

printf 'Created %s\n' "$archive"
printf 'Created %s\n' "$checksum"
