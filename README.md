# RetroCore Linux

Distribuzione Linux per **PC vecchi (circa 2009)** basata su **CorePlus** (l'edizione completa di [Tiny Core Linux](http://tinycorelinux.net/)).

## Perché Tiny Core

Un PC del 2009 ha tipicamente 1–2 GB di RAM, GPU Intel/NVIDIA dell'epoca e poco spazio. CorePlus:

- pesa ~250 MB e gira **interamente in RAM** (reattivo come mai lo era il PC)
-usa un'interfaccia FLTK/FLWM/JWM che consuma pochi MB
- funziona su CPU a 32 bit i686 (Pentium 4, Core 2 Duo, Athlon…) e 64 bit

## Cosa fa questo kit

`build.sh` scarica CorePlus, lo remasterizza e produce `dist/retrocore-*.iso`:

| Modifica | Dettaglio |
|---|---|
| Menu di avvio dedicato | default, modalità "**512 MB di RAM**" (senza copia in RAM), "**video sicuro**" (`nomodeset`, per schermate nere di GPU era), "solo console" |
| Browser | firefox, netsurf (ultra-leggero), links (testuale/console) |
| WiFi | firmware intel/realtek/atheros per laptop dell'epoca |
| Dischi | ntfs-3g (leggere volumi Windows), dosfstools, gparted |
| Extra | mtpaint, alsa-utils |
| Estensione custom | `retrocore.tcz`: banner di benvenuto, `retrocore-info`, `retrocore-wifi`, sfondo scuro |

Ogni estensione viene **verificata sul mirror** (con dipendenze risolte ricorsivamente e checksum MD5): se il progetto l'ha sospesa, viene automaticamente saltata senza rompere la build.

## Requisiti (PC dove costruisci la ISO)

- Linux con `wget`, `squashfs-tools` e **uno** tra `xorriso`, `7zip + genisoimage`, `bsdtar`

```bash
# Debian / Ubuntu / Linux Mint
sudo apt install -y wget squashfs-tools xorriso

# Fedora
sudo dnf install -y wget squashfs-tools xorriso

# Arch
sudo pacman -S --needed wget squashfs-tools xorriso
```

## Costruire la ISO

```bash
./build.sh            # default: Tiny Core 15.x
./build.sh 14.x       # nuova release, se indicato
```

L'ISO è in `dist/retrocore-15-x-pc-vecchi.iso` con relativo MD5.

### Provare senza toccare hardware

```bash
qemu-system-i386 -m 1024 -cdrom dist/retrocore-15-x-pc-vecchi.iso
```

## Installare sul PC del 2009

1. **Chiavetta USB** (consigliata): `sudo dd if=dist/retrocore-*.iso of=/dev/sdX bs=4M oflag=sync status=progress`

   > ⚠️ `/dev/sdX` è il PENNINO, controllalo con `lsblk`. Alcuni PC 2009 non avviano da USB: usa il BIOS con "USB-HDD" o la modalità CD.

2. **CD-R/RW**: brucia l'ISO con `wodim`/Brasero (`burn` — non "image to disc").

3. Dal menu di Tiny Core, lancia il programma `tc-install` già incluso per **installare su disco fisso** (dopo di che userà il "backup" della home su disco e l'avvio sarà più veloce del CD).

## Personalizzare

- `config/onboot-extra.lst` — elenco delle estensioni incluse nella ISO (decommenta `libreoffice` se il PC ha ≥ 1 GB di RAM)
- `config/isolinux.cfg` — menu di avvio (voci, timeout, `nomodeset`, ecc.)
- `retrocore-tcz/` — albero dei file della tua estensione personale (binari in `usr/local/bin`, avvio utente in `etc/skel/.X.d`)
- `tools/fetch-ext.sh <nome>.tcz <dir>` — scarica un'estensione con tutte le dipendenze, per test fuori dalla ISO

Dopo ogni modifica: `./build.sh` per rigenerare l'ISO.

## Note per PC 2009

- **RAM**: con 512 MB usa la voce "512 MB di RAM"; evita firefox → netsurf
- **Schermo nero all'avvio**: usa la voce "video sicuro" (`nomodeset`)
- **Persistenza**: le modifiche alla home si salvano con `filetool.sh -b`
- **Credits**: progetto [Tiny Core Linux](http://tinycorelinux.net/) (licenza GPL/MIT per i componenti di base); questo kit licenza: MIT
