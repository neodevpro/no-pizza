#!/bin/bash
# Download and install the vep1400 driver without git.
#
#   wget -qO- https://raw.githubusercontent.com/FusionPlmH/vep1400-linux-non_dsa-driver/main/get.sh | sudo bash
#
# This same file is published on a mirror too, for networks where GitHub is slow
# or blocked. Fetching it from there changes nothing else - the script then
# reaches for the mirror's own tarball when GitHub is unreachable:
#
#   wget -qO- https://neodev.team/get.sh | sudo bash
#
# Where the source archive comes from, in order:
#   1. $VEP1400_TARBALL - one explicit URL, nothing else is tried
#   2. the GitHub archive of branch $VEP1400_REF (default: main)
#   3. the mirror tarball at $VEP1400_MIRROR (default: https://neodev.team)
#
# Options are passed straight to install.sh:
#   wget -qO- ... | sudo bash -s -- --userspace
#
# Only .tar.gz is handled: tar is Essential in Debian/Ubuntu/PVE/VyOS, while
# unzip is Priority: optional and often missing on a minimal install.

set -euo pipefail

REPO=https://github.com/FusionPlmH/vep1400-linux-non_dsa-driver
NAME=vep1400-linux-non_dsa-driver
REF=${VEP1400_REF:-main}
MIRROR=${VEP1400_MIRROR:-https://neodev.team}

[ "$(id -u)" -eq 0 ] || {
	echo "run as root (sudo)" >&2
	exit 1
}

if command -v curl >/dev/null 2>&1; then
	fetch() { curl -fsSL --connect-timeout 10 --max-time 600 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
	# no extra flags: busybox wget (VyOS) only knows a handful of options
	fetch() { wget -qO "$2" "$1"; }
else
	echo "ERROR: curl or wget is required" >&2
	exit 1
fi

if [ -n "${VEP1400_TARBALL:-}" ]; then
	sources=("$VEP1400_TARBALL")
else
	sources=("$REPO/archive/refs/heads/$REF.tar.gz" "$MIRROR/$NAME.tar.gz")
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

archive=""
for url in "${sources[@]}"; do
	echo "== downloading $url"
	if fetch "$url" "$TMP/src.tar.gz"; then
		archive=$url
		break
	fi
	echo "   unreachable, trying the next source"
	rm -f "$TMP/src.tar.gz"
done
[ -n "$archive" ] || {
	echo "ERROR: no archive could be downloaded" >&2
	exit 1
}

echo "== unpacking"
mkdir -p "$TMP/src"
tar -xzf "$TMP/src.tar.gz" -C "$TMP/src"

DIR=$(find "$TMP/src" -mindepth 1 -maxdepth 3 -name install.sh -printf '%h\n' | head -1)
[ -n "$DIR" ] || {
	echo "ERROR: the archive does not contain install.sh" >&2
	exit 1
}
chmod +x "$DIR/install.sh" "$DIR/uninstall.sh" "$DIR"/scripts/*.sh "$DIR"/scripts/*.py 2>/dev/null || true

bash "$DIR/install.sh" "$@"
