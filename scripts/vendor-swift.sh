#!/usr/bin/env bash
# Copy the Swift package (Package.swift + Sources/) into bindings/rust/swift/ so the
# `permission-guide` crate tarball is self-contained. Root Sources/ stays the source of truth.
# Tests/ and Example/ are not vendored; their targets are stripped from the vendored manifest.
# Usage: scripts/vendor-swift.sh   (CI runs it and fails on `git diff`)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dest="$root/bindings/rust/swift"
rm -rf "$dest"
mkdir -p "$dest"
cp -R "$root/Sources" "$dest/Sources"
find "$dest" -name .DS_Store -delete
# Drop the testTarget (1 line) and executableTarget (2 lines) entries.
awk '
  /\.testTarget\(/ { next }
  /\.executableTarget\(/ { skip = 1; next }
  skip { skip = 0; next }
  { print }
' "$root/Package.swift" > "$dest/Package.swift"
