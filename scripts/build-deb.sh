#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PKG_NAME="circumflex"
BIN_NAME="clx"
CONTROL_TEMPLATE="$ROOT_DIR/packaging/deb/control.in"
OUT_DIR="$ROOT_DIR/dist/deb"
BUILD_DIR="$ROOT_DIR/.build/deb"

usage() {
  cat <<'EOF'
Usage: scripts/build-deb.sh <amd64|arm64>

Builds a Debian package for circumflex without using debhelper.
The script cross-compiles the clx binary for the requested target architecture,
stages the package tree, and runs dpkg-deb --build.

Examples:
  scripts/build-deb.sh amd64
  scripts/build-deb.sh arm64
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

map_arch() {
  case "$1" in
    amd64)
      echo "amd64 linux amd64"
      ;;
    arm64)
      echo "arm64 linux arm64"
      ;;
    *)
      echo "error: unsupported architecture '$1' (expected amd64 or arm64)" >&2
      exit 1
      ;;
  esac
}

version_from_source() {
  sed -n 's/^[[:space:]]*Version = "\([^"]*\)"$/\1/p' "$ROOT_DIR/version/version.go" | head -n1
}

main() {
  if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -ne 1 ]]; then
    usage
    [[ $# -eq 1 ]] && exit 0 || exit 1
  fi

  require_cmd go
  require_cmd dpkg-deb
  require_cmd install
  require_cmd sed

  read -r DEB_ARCH GOOS GOARCH <<<"$(map_arch "$1")"

  VERSION=$(version_from_source)
  if [[ -z "$VERSION" ]]; then
    echo "error: could not determine version from version/version.go" >&2
    exit 1
  fi

  PKG_ROOT="$BUILD_DIR/${PKG_NAME}_${VERSION}_${DEB_ARCH}"
  rm -rf "$PKG_ROOT"
  mkdir -p \
    "$PKG_ROOT/DEBIAN" \
    "$PKG_ROOT/usr/bin" \
    "$PKG_ROOT/usr/share/man/man1" \
    "$PKG_ROOT/usr/share/doc/$PKG_NAME/examples"

  echo "==> building ${BIN_NAME} for ${DEB_ARCH}"
  CGO_ENABLED=0 GOOS="$GOOS" GOARCH="$GOARCH" \
    go build -trimpath -ldflags="-s -w" -o "$PKG_ROOT/usr/bin/$BIN_NAME" ./cmd/clx

  echo "==> installing docs and man page"
  install -m 0644 "$ROOT_DIR/share/man/clx.1" "$PKG_ROOT/usr/share/man/man1/clx.1"
  install -m 0644 "$ROOT_DIR/LICENSE" "$PKG_ROOT/usr/share/doc/$PKG_NAME/copyright"
  install -m 0644 "$ROOT_DIR/README.md" "$PKG_ROOT/usr/share/doc/$PKG_NAME/README.md"
  install -m 0644 "$ROOT_DIR/theme.toml.example" "$PKG_ROOT/usr/share/doc/$PKG_NAME/examples/theme.toml.example"

  sed \
    -e "s/__VERSION__/$VERSION/g" \
    -e "s/__ARCH__/$DEB_ARCH/g" \
    "$CONTROL_TEMPLATE" > "$PKG_ROOT/DEBIAN/control"
  chmod 0644 "$PKG_ROOT/DEBIAN/control"
  chmod 0755 "$PKG_ROOT/usr/bin/$BIN_NAME"

  mkdir -p "$OUT_DIR"
  OUTPUT_DEB="$OUT_DIR/${PKG_NAME}_${VERSION}_${DEB_ARCH}.deb"

  echo "==> building $OUTPUT_DEB"
  dpkg-deb --build "$PKG_ROOT" "$OUTPUT_DEB"

  echo
  echo "created: $OUTPUT_DEB"
}

main "$@"
