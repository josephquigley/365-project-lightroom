#!/usr/bin/env bash
#
# Build the 365Calendar.lrplugin distribution zip.
#
# Usage:
#   scripts/build.sh                 # derive version from Info.lua
#   scripts/build.sh 1.0.0           # assert Info.lua matches 1.0.0, then build
#
# Output: dist/365Calendar-<version>.lrplugin.zip with 365Calendar.lrplugin/
# as the top-level directory inside the archive.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

plugin_dir="365Calendar.lrplugin"
info_file="$plugin_dir/Info.lua"
dist_dir="dist"

if [[ ! -f "$info_file" ]]; then
  echo "error: $info_file not found" >&2
  exit 1
fi

# Parse VERSION = { major = M, minor = m, revision = r, ... } from Info.lua.
# Use sed capture groups so this works on BSD awk (macOS) as well as GNU.
version_line="$(grep -E 'VERSION[[:space:]]*=' "$info_file" | head -n 1)"
extract() {
  printf '%s' "$version_line" \
    | sed -nE "s/.*$1[[:space:]]*=[[:space:]]*([0-9]+).*/\\1/p"
}
major="$(extract major)"
minor="$(extract minor)"
revision="$(extract revision)"

if [[ -z "${major:-}" || -z "${minor:-}" || -z "${revision:-}" ]]; then
  echo "error: could not parse VERSION from $info_file" >&2
  exit 1
fi

info_version="${major}.${minor}.${revision}"

if [[ $# -ge 1 ]]; then
  requested="$1"
  if [[ "$requested" != "$info_version" ]]; then
    echo "error: requested version $requested does not match Info.lua ($info_version)" >&2
    exit 1
  fi
fi

version="$info_version"
zip_name="365Calendar-${version}.lrplugin.zip"
zip_path="$dist_dir/$zip_name"

mkdir -p "$dist_dir"
rm -f "$zip_path"

# Exclude macOS metadata; keep the plugin dir as the archive's top level.
zip -r -q -X "$zip_path" "$plugin_dir" \
  -x "*.DS_Store" "*/.DS_Store" "__MACOSX/*"

echo "built $zip_path"
