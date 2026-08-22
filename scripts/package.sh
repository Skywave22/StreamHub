#!/usr/bin/env bash
# Packages StreamHub release artifacts and generates SHA-256 checksums.
# Usage: scripts/package.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
mkdir -p dist

echo "=== Packaging Linux (tarball + deb) ==="
if [ -d build/linux/x64/release/bundle ]; then
  BUNDLE=build/linux/x64/release/bundle
  tar -czf "dist/streamhub-${VERSION}-linux-x64.tar.gz" -C "$BUNDLE" .
  (cd dist && sha256sum "streamhub-${VERSION}-linux-x64.tar.gz" > "streamhub-${VERSION}-linux-x64.tar.gz.sha256")

  # Build a simple .deb package.
  DEBROOT=dist/debroot
  rm -rf "$DEBROOT"
  mkdir -p "$DEBROOT/opt/streamhub" "$DEBROOT/usr/share/applications" "$DEBROOT/DEBIAN"
  cp -r "$BUNDLE"/. "$DEBROOT/opt/streamhub/"
  cat > "$DEBROOT/usr/share/applications/streamhub.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=StreamHub
Comment=Fast, modern cross-platform streaming application
Exec=/opt/streamhub/streamhub
Icon=streamhub
Terminal=false
Categories=AudioVideo;Player;
EOF
  cat > "$DEBROOT/DEBIAN/control" <<EOF
Package: streamhub
Version: ${VERSION}
Section: video
Priority: optional
Architecture: amd64
Maintainer: Skywave22
Description: StreamHub - fast, modern cross-platform streaming application
EOF
  dpkg-deb --build "$DEBROOT" "dist/streamhub-${VERSION}-linux-x64.deb" > /dev/null
  (cd dist && sha256sum "streamhub-${VERSION}-linux-x64.deb" > "streamhub-${VERSION}-linux-x64.deb.sha256")
  rm -rf "$DEBROOT"
else
  echo "  Linux bundle not found — run 'flutter build linux --release' first."
fi

echo "=== Packaging Android (checksums) ==="
if [ -f build/app/outputs/flutter-apk/app-release.apk ]; then
  cp build/app/outputs/flutter-apk/app-release.apk "dist/streamhub-${VERSION}-android.apk"
  (cd dist && sha256sum "streamhub-${VERSION}-android.apk" > "streamhub-${VERSION}-android.apk.sha256")
fi
if [ -f build/app/outputs/bundle/release/app-release.aab ]; then
  cp build/app/outputs/bundle/release/app-release.aab "dist/streamhub-${VERSION}-android.aab"
  (cd dist && sha256sum "streamhub-${VERSION}-android.aab" > "streamhub-${VERSION}-android.aab.sha256")
fi

echo "=== Artifacts ==="
ls -la dist/
