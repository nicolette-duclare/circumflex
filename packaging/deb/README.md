# Debian packaging

This directory contains a lightweight Debian packaging setup for `circumflex`.

## Supported architectures

- `amd64`
- `arm64`

## Build locally

From the repository root:

```bash
scripts/build-deb.sh amd64
scripts/build-deb.sh arm64
```

The script will:

1. read the version from `version/version.go`
2. cross-compile `./cmd/clx`
3. stage the binary, man page, license, README, and example theme
4. generate a Debian `control` file from `packaging/deb/control.in`
5. build `dist/deb/circumflex_<version>_<arch>.deb`

## Requirements

- `go`
- `dpkg-deb`
- standard Unix tools like `install` and `sed`

This packaging flow is intentionally simple and does not require `debhelper`.
