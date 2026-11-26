#!/usr/bin/env bash
# fetch-ext.sh - scarica un'estensione .tcz (e tutte le sue dipendenze ricorsive) dai mirror.
# Uso: tools/fetch-ext.sh <nome.tcz|nome> <directory-destinazione>
set -euo pipefail

MIRRORS=(
  "http://tinycorelinux.net/15.x/x86/tcz"
  "http://distro.ibiblio.org/tinycorelinux/15.x/x86/tcz"
  "http://repo.tinycorelinux.net/15.x/x86/tcz"
)
if [[ -n "${TC_VERSION:-${RETROCORE_TC_VERSION:-}}" ]]; then
  V="${TC_VERSION:-$RETROCORE_TC_VERSION}"
  MIRRORS=()
  for b in "http://tinycorelinux.net" "http://distro.ibiblio.org/tinycorelinux" "http://repo.tinycorelinux.net"; do
    MIRRORS+=("${b}/${V}/x86/tcz")
  done
fi

have() { command -v "$1" >/dev/null 2>&1; }
die()  { printf '[fetch-ext] ERRORE: %s\n' "$*" >&2; exit 1; }
declare -A SEEN
FAILED=""

download() { # download <file> <dest>
  local f="$1" dest="$2" url
  [[ -s "$dest/$f" ]] && return 0
  for base in "${MIRRORS[@]}"; do
    if wget -q -T 20 -c -O "$dest/$f.part" "$base/$f" && mv "$dest/$f.part" "$dest/$f"; then
      return 0
    fi
    rm -f "$dest/$f.part"
  done
  return 1
}

tcz_name() { # aggiunge ".tcz" se manca
  local n="$1"
  [[ "$n" == *.tcz ]] && { echo "$n"; return; }
  echo "${n}.tcz"
}

fetch_ext() {
  local ext; ext="$(tcz_name "$1")"
  local dest="$2"
  [[ -n "${SEEN[$ext]:-}" ]] && return 0
  SEEN[$ext]=1
  echo "[fetch-ext] $ext"

  if ! download "$ext" "$dest"; then
    FAILED+="${ext} "; echo "  -> NON TROVATO"; return 1
  fi
  if download "${ext}.md5.txt" "$dest"; then
    (cd "$dest" && md5sum -c "${ext}.md5.txt" --quiet) || die "md5 errato per $ext"
  else
    echo "  -> md5 non disponibile, skip verifica"
  fi

  if download "${ext}.dep" "$dest"; then
    while IFS= read -r dep; do
      [[ -z "$dep" ]] && continue
      fetch_ext "$dep" "$dest" || true
    done < "$dest/${ext}.dep"
  fi
}

main() {
  [[ $# -eq 2 ]] || die "uso: fetch-ext.sh <estensione> <dir-destino>"
  have wget || die "wget mancante"
  fetch_ext "$1" "$2"
  [[ -n "$FAILED" ]] && { echo "MANCANTI: $FAILED" >> "$2/../missing-ext.log" 2>/dev/null || true; exit 1; }
  exit 0
}

main "$@"
