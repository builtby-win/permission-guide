#!/usr/bin/env bash
# Builds dist/PermissionGuide.xcframework (static, macOS arm64+x86_64) and dist/PermissionGuide.xcframework.zip (+ .sha256).
# The xcframework exposes the C ABI (permission_guide.h). Consumers must link
# AppKit/CoreGraphics/ApplicationServices/Foundation/QuartzCore and pass `-rpath /usr/lib/swift`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
rm -rf "$OUT"; mkdir -p "$OUT"

for arch in arm64 x86_64; do
  # Clean scratch per arch and one --product per invocation (stale/missing .a otherwise).
  scratch="$WORK/scratch-$arch"
  for product in CPermissionGuide PermissionGuide; do
    swift build -c release --product "$product" --arch "$arch" \
      --package-path "$ROOT" --scratch-path "$scratch"
  done
  bin="$(swift build -c release --arch "$arch" --show-bin-path --package-path "$ROOT" --scratch-path "$scratch")"
  libtool -static -o "$WORK/libPermissionGuide-$arch.a" "$bin/libCPermissionGuide.a" "$bin/libPermissionGuide.a"
done
lipo -create "$WORK"/libPermissionGuide-arm64.a "$WORK"/libPermissionGuide-x86_64.a -output "$WORK/libPermissionGuide.a"

mkdir -p "$WORK/Headers"
cp "$ROOT/Sources/CPermissionGuide/include/permission_guide.h" "$WORK/Headers/"
cat > "$WORK/Headers/module.modulemap" <<'M'
module PermissionGuide {
    header "permission_guide.h"
    export *
}
M
xcodebuild -create-xcframework -library "$WORK/libPermissionGuide.a" -headers "$WORK/Headers" \
  -output "$OUT/PermissionGuide.xcframework"
(cd "$OUT" && ditto -c -k --keepParent PermissionGuide.xcframework PermissionGuide.xcframework.zip \
  && shasum -a 256 PermissionGuide.xcframework.zip | tee PermissionGuide.xcframework.zip.sha256)
echo "built $OUT/PermissionGuide.xcframework"
