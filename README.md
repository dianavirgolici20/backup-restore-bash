# Backup & Restore (Bash)

An interactive Bash tool that keeps **timestamped versions** of files and folders,
like a tiny version-control system. Built as a university Operating Systems project
(ASE Bucharest) and later hardened: input validation, safe file handling and automated tests.

## Features

- **Backup** a file (copied as `name_YYYY-MM-DD_HH-MM-SS`) or a folder (`name_YYYY-MM-DD_HH-MM-SS.tar.gz`) into `backups/`
- **List** all saved versions of a file/folder, numbered, with sizes
- **Restore** a chosen version under its original name (overwrites the original, after confirmation)
- **Clean up** backups older than N days (with a preview and confirmation)

## Requirements

Bash 4+, `tar`, `find`, `realpath` (standard on Linux).

## Usage

```bash
chmod +x backup.sh
./backup.sh
```

Example session:

```text
1. Backup
2. Listare versiuni
3. Restore
4. Sterge backup-uri vechi
5. Exit
Alege o optiune: 3
Numele ORIGINAL al fisierului/folderului de restaurat: notes.txt
  1) notes.txt_2026-11-18_01-53-02  (4,0K)
  2) notes.txt_2026-11-18_02-10-45  (4,0K)
Alege numarul versiunii (Enter = anulare): 1
Destinatie (Enter = directorul curent, adica suprascrie originalul):
notes.txt exista deja si va fi suprascris. Continui? [d/n]: d
Fisierul a fost restaurat ca ./notes.txt
```

> The interface is in Romanian (without diacritics), as in the original assignment.

## Design decisions

- **Seconds in the timestamp** so two backups made within the same minute don't overwrite each other.
- **Glob patterns instead of `grep` on user input**, so names with `.`, `*` or `[` are treated as plain text
  and `test1` never matches `test1_old`.
- **Names containing `/` are rejected on restore** to prevent path traversal outside `backups/`.
- **`if tar ...; then`** checks the exit code, so success is only reported when it actually succeeded.
- **Confirmation before overwriting or deleting** anything.

## Tests

```bash
bash tests/run_tests.sh
```

15 checks covering versioning, restore, edge cases (trailing slash, nested paths, invalid input,
EOF) and the path-traversal guard.

## Possible improvements

- Non-interactive mode (`./backup.sh backup file.txt`) for use in cron jobs
- Checksums to detect unchanged files and skip duplicate backups
- Backup compression for single files and a retention policy by number of versions
