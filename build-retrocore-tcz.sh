#!/usr/bin/env bash
# build-retrocore-tcz.sh - impacchetta retrocore-tcz/ nella personalizzazione retrocore.tcz
# Uso: ./build-retrocore-tcz.sh <output.tcz>
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/retrocore-tcz" && pwd)"
OUT="${1:?uso: $0 <output.tcz>}"
have() { command -v "$1" >/dev/null 2>&1; }
have mksquashfs || { echo "serve mksquashfs (pacchetto squashfs-tools)" >&2; exit 1; }
tmp="$(mktemp -d)"
mksquashfs "$SRC" "$tmp/retrocore.tcz" -all-root -noappend -comp xz >/dev/null
mv "$tmp/retrocore.tcz" "$OUT"
base="$(basename "$OUT")"
(cd "$(dirname "$OUT")" && md5sum "$base" > "$base.md5.txt")
: > "$OUT.dep"
rm -rf "$tmp"
echo "creato: $OUT"
