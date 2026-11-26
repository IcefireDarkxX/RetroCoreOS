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

L'ISO è in `dist/RetroCoreOS-15.x-x86.iso` con relativo MD5.

### Costruire la ISO da Windows (WSL2)

Il kit è pensato per Linux: su Windows basta **WSL2** (una Ubuntu integrata in Windows, gratuita e ufficiale Microsoft).

1. Apri PowerShell come amministratore e installa Ubuntu:
   ```powershell
   wsl --install -d Ubuntu
   ```
   Riavvia il PC quando richiesto e imposta utente/password di Ubuntu.
2. Nella barra di ricerca di Windows cerca "Ubuntu" e aprilo.
3. Copia la cartella del progetto in un percorso accessibile da WSL (es. scaricando il progetto dentro Linux, oppure dal disco Windows):
   ```bash
   cd /mnt/c/Users/<tuo-utente>/Downloads/TestLinuxVibeOS-main
   ```
4. Installa i prerequisiti (dentro Ubuntu):
   ```bash
   sudo apt update && sudo apt install -y wget squashfs-tools xorriso
   ```
5. Costruisci la ISO:
   ```bash
   chmod +x build.sh tools/fetch-ext.sh build-retrocore-tcz.sh && ./build.sh
   ```
6. La ISO compare in `dist/` ed è un file Windows normale: la trovi in `C:\Users\<tuo-utente>\Downloads\...\dist\RetroCoreOS-15.x-x86.iso`.

   > ℹ️ Se la versione di Windows non supporta `wsl --install`, segui la guida [Attiva WSL](https://learn.microsoft.com/it-it/windows/wsl/install).

### Costruire la ISO da macOS (Homebrew)

Prerequisito: [Homebrew](https://brew.sh/it/) (una riga di terminale, vedi il sito).

```bash
brew install wget xorriso squashfs e2fsprogs
cd /percorso/di/TestLinuxVibeOS
chmod +x build.sh tools/fetch-ext.sh build-retrocore-tcz.sh
./build.sh
```

La ISO è in `dist/RetroCoreOS-15.x-x86.iso`.

> ℹ️ Lo script richiede anche `md5sum`: se non è disponibile, prova `brew install md5sha1sum`.

### Costruire senza installare nulla: build nel cloud (GitHub Actions)

Nel progetto c'è già il workflow `.github/workflows/build.yml`:

1. Su GitHub vai nella scheda **Actions** → seleziona **build-iso** sulla sinistra.
2. Clicca **Run workflow** → conferma.
3. Dopo ~3-4 minuti, apri il run completato e scarica l'artifact **retrocore-iso**: contiene `RetroCoreOS-15.x-x86.iso` + file MD5.
4. I prerequisiti (`xorriso`, `squashfs-tools`, ...) sono già installati dal workflow: non devi installare niente sul tuo PC.

## Provare senza toccare hardware

```bash
qemu-system-i386 -m 1024 -cdrom dist/RetroCoreOS-15.x-x86.iso
```

## Installare sul PC del 2009

### Da Windows: Rufus o balenaEtcher (consigliato)

1. Scarica e installa [Rufus](https://rufus.ie/it/) o [balenaEtcher](https://etcher.balena.io/).
2. Inserisci il disc USB (**verrà cancellato tutto** — non serve formattare prima).
3. **Rufus**: scegli il dispositivo e la ISO, tipo di partizione MBR, e quando lo chiede seleziona **DD mode** (modalità immagine). **balenaEtcher**: *Flash from file* → scegli la ISO → *Select target* → *Flash!*.
4. Al termine, espelli la chiavetta e avviala nel PC del 2009.

### Da macOS: balenaEtcher o dd

1. Installa [balenaEtcher](https://etcher.balena.io/) e flasha la immagine come sopra; oppure da terminale:
   ```bash
   diskutil list                          # individua il disco della chiavetta, es. disk4
   diskutil unmountDisk /dev/disk4
   sudo dd if=dist/RetroCoreOS-15.x-x86.iso of=/dev/rdisk4 bs=4m oflag=sync
   diskutil eject /dev/disk4
   ```
   > ⚠️ su macOS il device è `/dev/rdiskN` (con "r"): è più veloce. Controlla bene il numero del disco con `diskutil list`, sbagliare cancella il disco indicato.

### Da Linux: dd

```bash
lsblk                                  # individua la chiavetta, es. sdb
sudo dd if=dist/RetroCoreOS-15.x-x86.iso of=/dev/sdX bs=4M oflag=sync status=progress
sync
```

> ⚠️ `/dev/sdX` è il PENNINO, controllalo con `lsblk`. Alcuni PC 2009 non avviano da USB: usa il BIOS con "USB-HDD" o la modalità CD.

### Tramite CD

- Windows: [ImgBurn](https://www.imgburn.com/) o CDBurnerXP, opzione **Write image file to disc** (non "data disc")
- macOS: Utility Disco → menu **Immagini** → **Masterizza...**
- Linux: `wodim -v dev=/dev/cdrom dist/retrocore-*.iso` o Brasero/K3b "masterizza immagine"

### Installazione su disco fisso

Dal menu di RetroCore, lancia il programma `tc-install` già incluso per **installare su disco fisso** (dopo di che userà il "backup" della home su disco e l'avvio sarà più veloce del CD/USB).

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
