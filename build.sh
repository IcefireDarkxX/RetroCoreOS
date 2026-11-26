#!/usr/bin/env bash
# RetroCore Linux - build script
# Remasterizza CorePlus (Tiny Core Linux) in una distribuzione per PC vecchi (~2009).
#
# Uso:  ./build.sh [versione     (default: 15.x)]
# Esempio:  ./build.sh 15.x
#
# Requisiti (vedi README.md): wget, squashfs-tools e UNO tra xorriso / 7zip+genisoimage.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TC_VERSION="${1:-${TC_VERSION:-15.x}}"
ARCH="x86"
DIST_NAME="RetroCore"
ISO_LABEL="RETROCORE"
WORK="$SCRIPT_DIR/build"
DIST="$SCRIPT_DIR/dist"
MIRRORS=(
  "http://tinycorelinux.net/${TC_VERSION}/${ARCH}"
  "http://distro.ibiblio.org/tinycorelinux/${TC_VERSION}/${ARCH}"
  "http://repo.tinycorelinux.net/${TC_VERSION}/${ARCH}"
)

SRC_ISO_SRC_NAME="CorePlus-current.iso"
SRC_ISO="$WORK/CorePlus-${TC_VERSION}.iso"
EXTRACT="$WORK/iso"
OUT_ISO="$DIST/${DIST_NAME,,}-$(echo "$TC_VERSION" | tr . -)-pc-vecchi.iso"

log()  { printf '\033[1;36m[retrocore]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[retrocore]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[retrocore] ERRORE:\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ----------------------------------------------------------------- verifica dipendenze
check_deps() {
  have wget || die "installa wget (deb: sudo apt install wget | rpm: sudo dnf install wget | arch: sudo pacman -S wget)"
  have md5sum || die "md5sum mancante (coreutils)"

  HOST_EXTRACT=""
  if have xorriso; then HOST_EXTRACT="xorriso"
  elif have 7z;       then HOST_EXTRACT="7z"
  elif have bsdtar;   then HOST_EXTRACT="bsdtar"
  elif have isoinfo;  then HOST_EXTRACT="isoinfo"
  else die "serve uno tra: xorriso, 7z, bsdtar, isoinfo  (consigliato: xorriso)"
  fi

  HOST_ISO=""
  if have xorriso;        then HOST_ISO="xorriso"
  elif have genisoimage;  then HOST_ISO="genisoimage"
  elif have mkisofs;      then HOST_ISO="mkisofs"
  else die "serve xorriso oppure genisoimage/mkisofs"
  fi

  have mksquashfs || die "installa squashfs-tools (deb: sudo apt install squashfs-tools | rpm: sudo dnf install squashfs-tools | arch: sudo pacman -S squashfs-tools)"

  log "strumenti: estrai=$HOST_EXTRACT, iso=$HOST_ISO, mksquashfs=$(have mksquashfs && echo ok)"
}

# ----------------------------------------------------------------- download con mirror multipli
fetch() { # fetch <percorso-sul-mirror> <destinazione>
  local rel="$1" dest="$2" url ok=1
  for base in "${MIRRORS[@]}"; do
    url="${base}/${rel}"
    if wget -q --show-progress -T 20 -c -O "$dest" "$url"; then ok=0; break; fi
    rm -f "$dest"
  done
  return $ok
}

download_iso() {
  if [[ -s "$SRC_ISO" ]]; then
    log "uso ISO sorgente esistente: $SRC_ISO"
  else
    log "scarico CorePlus ${TC_VERSION} (${ARCH}, ~250 MB) ..."
    fetch "release/${SRC_ISO_SRC_NAME}" "$SRC_ISO" || die "download ISO fallito (controlla la versione ${TC_VERSION})"
  fi
  [[ $(stat -c%s "$SRC_ISO") -gt 10000000 ]] || die "ISO sorgente troppo piccola, file corrotto"
}

# ----------------------------------------------------------------- estrazione ISO
extract_iso() {
  rm -rf "$EXTRACT"; mkdir -p "$EXTRACT"
  case "$HOST_EXTRACT" in
    xorriso) xorriso -osirrox on -indev "$SRC_ISO" -extract / "$EXTRACT" >/dev/null ;;
    7z)      7z x -y -o"$EXTRACT" "$SRC_ISO" >/dev/null ;;
    bsdtar)  bsdtar -xf "$SRC_ISO" -C "$EXTRACT" ;;
    isoinfo) ( cd "$EXTRACT" && isoinfo -R -i "$SRC_ISO" -x / | true ); die "estrazione con isoinfo non supportata, installa xorriso o 7z" ;;
  esac
  [[ -f "$EXTRACT"/boot/core.gz ]] || die "estrazione ISO incompleta: boot/core.gz non trovato"
  # l'ISO estrae i file in sola lettura; su WSL (/mnt/c) i permessi non sono correggibili dopo, quindi li rendiamo scrivibili subito
  chmod -R u+w "$EXTRACT" 2>/dev/null || true
  [[ -w "$EXTRACT/cde/onboot.lst" ]] || chmod u+w "$EXTRACT/cde/onboot.lst" 2>/dev/null || \
    die "$EXTRACT/cde/onboot.lst non scrivibile: sposta il progetto dentro il filesystem Linux di WSL (es. ~/RetroCoreOS) e riprova da li"
}

# ----------------------------------------------------------------- estensioni extra da cde/optional
add_extensions() {
  local list_file="$SCRIPT_DIR/config/onboot-extra.lst"
  local onboot="$EXTRACT/cde/onboot.lst"
  local optdir="$EXTRACT/cde/optional"
  mkdir -p "$optdir"
  : > "$WORK/missing-ext.txt"
  touch "$onboot"

  while IFS= read -r ext; do
    [[ -z "$ext" || "$ext" == \#* ]] && continue
    log "estensione: $ext"
    "$SCRIPT_DIR/tools/fetch-ext.sh" "$ext" "$optdir" \
      || { warn "$ext non trovato, salto (vedi build/missing-ext.txt)"; echo "$ext" >> "$WORK/missing-ext.txt"; continue; }
    grep -qxF "$ext" "$onboot" || echo "$ext" >> "$onboot"
  done < "$list_file"
}

# ----------------------------------------------------------------- estensione custom retrocore.tcz
build_config_extension() {
  local out="$EXTRACT/cde/optional/retrocore.tcz"
  "$SCRIPT_DIR/build-retrocore-tcz.sh" "$out"
  grep -qxF "retrocore.tcz" "$EXTRACT/cde/onboot.lst" || echo "retrocore.tcz" >> "$EXTRACT/cde/onboot.lst"
  grep -qxF "retrocore" "$EXTRACT/cde/xwbar.lst" 2>/dev/null || true
}

# ----------------------------------------------------------------- configurazione di boot
replace_boot_config() {
  local cfg_dir="$EXTRACT/boot/isolinux"
  [[ -d "$cfg_dir" ]] || cfg_dir="$EXTRACT/boot/syslinux"
  [[ -d "$cfg_dir" ]] || die "directory isolinux/syslinux non trovata nell'ISO"
  local orig_kernel orig
  orig_kernel="$(grep -hoE '/boot/vmlinuz[0-9]*' "$cfg_dir"/isolinux.cfg 2>/dev/null | head -1 || true)"
  orig="$(grep -h -E '^\s*APPEND' "$cfg_dir"/isolinux.cfg 2>/dev/null | head -1 | sed 's/^\s*APPEND\s*//' || true)"
  : "${orig_kernel:=/boot/vmlinuz}"
  sed -i "s|@ORIG_APPEND@|${orig:-quiet}|; s|@ORIG_KERNEL@|${orig_kernel}|g; s|@TC_VERSION@|${TC_VERSION}|g" \
    "$SCRIPT_DIR/config/isolinux.cfg"
  cp "$SCRIPT_DIR/config/isolinux.cfg" "$cfg_dir/isolinux.cfg"
  cp "$SCRIPT_DIR/config/isolinux.cfg" "$WORK/isolinux.cfg.retrocore"
}

# ----------------------------------------------------------------- creazione ISO finale
pack_iso() {
  mkdir -p "$DIST"
  local bootbin bootcat
  if [[ -f "$EXTRACT/boot/isolinux/isolinux.bin" ]]; then
    bootbin=boot/isolinux/isolinux.bin; bootcat=boot/isolinux/boot.cat
  elif [[ -f "$EXTRACT/boot/syslinux/isolinux.bin" ]]; then
    bootbin=boot/syslinux/isolinux.bin; bootcat=boot/syslinux/boot.cat
  else
    die "isolinux.bin non trovato nell'ISO estratta"
  fi
  # xorriso emula genisoimage solo tramite '-as mkisofs', altrimenti rifiuta le opzioni
  local -a pre=()
  [[ "$HOST_ISO" == "xorriso" ]] && pre=(-as mkisofs)
  (cd "$EXTRACT" && "$HOST_ISO" "${pre[@]}" -J -R -V "$ISO_LABEL" -o "$OUT_ISO" \
    -b "$bootbin" -c "$bootcat" -no-emul-boot -boot-load-size 4 -boot-info-table .)
  log "suggerimento: la ISO e' avviabile anche da USB con 'dd' (vedi README)"
  (cd "$DIST" && md5sum "$(basename "$OUT_ISO")" > "$(basename "$OUT_ISO").md5.txt")
  log "ISO creata: $OUT_ISO ($(du -h "$OUT_ISO" | cut -f1))"
}

# ----------------------------------------------------------------- main
main() {
  check_deps
  mkdir -p "$WORK" "$DIST"
  download_iso
  extract_iso
  add_extensions
  build_config_extension
  replace_boot_config
  pack_iso
  cat > "$DIST/LEGGIMI.txt" <<EOF
$DIST_NAME Linux - ISO per PC vecchi (~2009), base CorePlus $TC_VERSION ($ARCH)
Test rapido:  qemu-system-i386 -m 1024 -cdrom $(basename "$OUT_ISO")
USB:          sudo dd if=$(basename "$OUT_ISO") of=/dev/sdX bs=4M oflag=sync status=progress
              (attento: /dev/sdX = pennino USB, verificalo con lsblk!)
MD5:          $(basename "$OUT_ISO").md5.txt
EOF
  log "fatto. dist/: $(ls "$DIST")"
  if [[ -s "$WORK/missing-ext.txt" ]]; then
    warn "estensioni non trovate sul mirror (escluse, la ISO funziona lo stesso):"
    warn "$(tr '\n' ' ' < "$WORK/missing-ext.txt")"
  fi
}

main "$@"
