#!/bin/bash
# =====================================================================
# Backup & Restore cu versionare (Bash)
# Meniu interactiv: backup fisier/folder, listare versiuni, restore,
# stergere backup-uri vechi.
# =====================================================================

BACKUP_DIR="backups"                 # directorul in care se salveaza tot
FORMAT_DATA="%Y-%m-%d_%H-%M-%S"      # sufixul de data+ora (cu secunde!)
GLOB_DATA="????-??-??_??-??-??"      # acelasi format, ca pattern de cautare

# ---------- functii ajutatoare ----------

# Citeste o linie in $REPLY. -r = nu interpreta backslash-urile.
# Daca input-ul se inchide (Ctrl+D), iesim curat, fara bucla infinita.
citeste() {
  printf '%s' "$1"
  read -r REPLY || { echo; echo "Input inchis. Ies."; exit 0; }
}

# Intreaba da/nu. Returneaza 0 (adevarat) doar pentru d / da / y / yes.
confirma() {
  citeste "$1 [d/n]: "
  case "${REPLY,,}" in
    d|da|y|yes) return 0 ;;
    *)          return 1 ;;
  esac
}

# Numele cautat nu are voie sa fie gol sau sa contina "/"
# (altfel cineva ar putea iesi din directorul backups, ex: ../fisier).
nume_valid() {
  if [ -z "$1" ] || [[ "$1" == */* ]]; then
    echo "Nume invalid (nu poate fi gol si nu poate contine '/')."
    return 1
  fi
  return 0
}

# Pune in vectorul VERSIUNI toate backup-urile pentru numele $1.
# Pattern-ul "nume_AAAA-LL-ZZ_HH-MM-SS*" nu confunda "test1" cu "test1_old",
# iar "$1" intre ghilimele inseamna ca ., *, [ sunt tratate ca text simplu.
colecteaza_versiuni() {
  VERSIUNI=()
  local f
  for f in "$BACKUP_DIR/$1"_$GLOB_DATA*; do
    [ -e "$f" ] && VERSIUNI+=("$(basename "$f")")
  done
}

# Afiseaza VERSIUNI numerotat, cu dimensiunea. Returneaza 1 daca e goala.
afiseaza_versiuni() {
  if [ "${#VERSIUNI[@]}" -eq 0 ]; then
    return 1
  fi
  local i=1 v
  for v in "${VERSIUNI[@]}"; do
    printf '%3d) %s  (%s)\n' "$i" "$v" "$(du -h "$BACKUP_DIR/$v" | cut -f1)"
    i=$((i + 1))
  done
}

# ---------- 1. BACKUP ----------

backup_folder() {
  citeste "Introdu numele folderului: "
  local cale="${REPLY%/}"            # scoatem '/' de la final (test1/ -> test1)
  [ -z "$cale" ] && { echo "Nu ai introdus nimic."; return; }

  if [ ! -d "$cale" ]; then
    echo "$cale nu exista sau nu este folder"
    return
  fi

  # Calea reala -> separam parintele de numele folderului,
  # ca arhiva sa nu contina cai lungi si sa nu avem '/' in numele ei.
  local real base parinte
  real=$(realpath "$cale")
  base=$(basename "$real")
  parinte=$(dirname "$real")

  if [ "$real" = "$(realpath -m "$BACKUP_DIR")" ]; then
    echo "Nu poti face backup folderului $BACKUP_DIR in el insusi."
    return
  fi

  mkdir -p "$BACKUP_DIR"
  local nume="${base}_$(date +"$FORMAT_DATA").tar.gz"

  if [ -e "$BACKUP_DIR/$nume" ]; then
    echo "Exista deja un backup creat in aceeasi secunda. Mai incearca."
    return
  fi

  # 'if comanda' verifica codul de iesire: afisam succes doar daca tar a mers.
  if tar -czf "$BACKUP_DIR/$nume" -C "$parinte" "$base"; then
    echo "Backup creat: $BACKUP_DIR/$nume"
  else
    rm -f "$BACKUP_DIR/$nume"        # nu lasam o arhiva stricata
    echo "Eroare: backup-ul nu a putut fi creat."
  fi
}

backup_fisier() {
  citeste "Introdu numele fisierului: "
  local cale="$REPLY"
  [ -z "$cale" ] && { echo "Nu ai introdus nimic."; return; }

  if [ ! -f "$cale" ]; then
    echo "$cale nu exista sau nu este fisier"
    return
  fi

  mkdir -p "$BACKUP_DIR"
  local nume
  nume="$(basename "$cale")_$(date +"$FORMAT_DATA")"

  if [ -e "$BACKUP_DIR/$nume" ]; then
    echo "Exista deja un backup creat in aceeasi secunda. Mai incearca."
    return
  fi

  if cp -- "$cale" "$BACKUP_DIR/$nume"; then
    echo "Fisierul a fost salvat in $BACKUP_DIR/$nume"
  else
    echo "Eroare: fisierul nu a putut fi copiat."
  fi
}

meniu_backup() {
  echo "Ce doresti sa salvezi?"
  echo "1. Folder"
  echo "2. Fisier"
  citeste "Alege: "
  case "$REPLY" in
    1) backup_folder ;;
    2) backup_fisier ;;
    *) echo "Optiune invalida" ;;
  esac
}

# ---------- 2. LISTARE ----------

listare() {
  citeste "Numele fisierului/folderului pentru care vrei versiunile: "
  local nume="$REPLY"
  nume_valid "$nume" || return

  colecteaza_versiuni "$nume"
  echo "Versiuni existente pentru $nume:"
  afiseaza_versiuni || echo "Nu exista versiuni salvate pentru acest fisier"
}

# ---------- 3. RESTORE ----------

restore() {
  citeste "Numele ORIGINAL al fisierului/folderului de restaurat: "
  local nume="$REPLY"
  nume_valid "$nume" || return

  colecteaza_versiuni "$nume"
  if ! afiseaza_versiuni; then
    echo "Nu exista versiuni salvate pentru $nume"
    return
  fi

  citeste "Alege numarul versiunii (Enter = anulare): "
  local n="$REPLY"
  [ -z "$n" ] && { echo "Anulat."; return; }

  # Acceptam doar numere intre 1 si cate versiuni avem.
  if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "${#VERSIUNI[@]}" ]; then
    echo "Numar invalid."
    return
  fi
  local sel="${VERSIUNI[$((n - 1))]}"

  citeste "Destinatie (Enter = directorul curent, adica suprascrie originalul): "
  local dest="${REPLY:-.}"
  mkdir -p "$dest" || { echo "Nu pot crea destinatia."; return; }

  if [[ "$sel" == *.tar.gz ]]; then
    # Folder arhivat. ${sel%_$GLOB_DATA.tar.gz} scoate sufixul -> numele original.
    local orig="${sel%_$GLOB_DATA.tar.gz}"
    if [ -e "$dest/$orig" ] && ! confirma "$dest/$orig exista deja si va fi suprascris. Continui?"; then
      echo "Anulat."; return
    fi
    if tar -xzf "$BACKUP_DIR/$sel" -C "$dest"; then
      echo "Folderul $orig a fost restaurat in $dest"
    else
      echo "Eroare la dezarhivare."
    fi
  else
    # Fisier simplu: il restauram cu numele ORIGINAL (fara sufixul de data).
    local orig="${sel%_$GLOB_DATA}"
    if [ -e "$dest/$orig" ] && ! confirma "$dest/$orig exista deja si va fi suprascris. Continui?"; then
      echo "Anulat."; return
    fi
    if cp -- "$BACKUP_DIR/$sel" "$dest/$orig"; then
      echo "Fisierul a fost restaurat ca $dest/$orig"
    else
      echo "Eroare la restaurare."
    fi
  fi
}

# ---------- 4. STERGERE BACKUP-URI VECHI ----------

sterge_vechi() {
  if [ ! -d "$BACKUP_DIR" ]; then
    echo "Nu exista inca niciun backup."
    return
  fi
  citeste "Sterge backup-urile mai vechi de cate zile? "
  local zile="$REPLY"
  if ! [[ "$zile" =~ ^[0-9]+$ ]]; then
    echo "Introdu un numar intreg."
    return
  fi

  # Cautam fisierele mai vechi de $zile zile (dupa data modificarii).
  local vechi
  vechi=$(find "$BACKUP_DIR" -maxdepth 1 -type f -mtime +"$zile")
  if [ -z "$vechi" ]; then
    echo "Nu exista backup-uri mai vechi de $zile zile."
    return
  fi

  echo "Se vor sterge:"
  echo "$vechi" | sed 's|^|  |'
  if confirma "Sigur vrei sa le stergi?"; then
    find "$BACKUP_DIR" -maxdepth 1 -type f -mtime +"$zile" -delete
    echo "Sterse."
  else
    echo "Anulat."
  fi
}

# ---------- MENIU PRINCIPAL ----------

while true; do
  echo
  echo "1. Backup"
  echo "2. Listare versiuni"
  echo "3. Restore"
  echo "4. Sterge backup-uri vechi"
  echo "5. Exit"
  citeste "Alege o optiune: "

  case "$REPLY" in
    1) meniu_backup ;;
    2) listare ;;
    3) restore ;;
    4) sterge_vechi ;;
    5) echo "Ai iesit din meniu"; exit 0 ;;
    *) echo "Optiune invalida" ;;
  esac
done
