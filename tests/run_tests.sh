#!/bin/bash
# Teste automate pentru backup.sh. Ruleaza din orice loc:  bash tests/run_tests.sh
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/backup.sh"
PASS=0; FAIL=0

ok()   { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# Ruleaza scriptul intr-un director de lucru curat, cu input-ul $1 (printf).
fresh() { WORK=$(mktemp -d); cd "$WORK" || exit 1; }
run()   { printf "$1" | timeout 10 bash "$SCRIPT" 2>&1; }

echo "[1] Backup fisier + restore suprascrie originalul"
fresh
echo v1 > fisier1
run "1\n2\nfisier1\n5\n" > /dev/null
echo v2 > fisier1
run "3\nfisier1\n1\n\nd\n5\n" > /dev/null
check "fisier1 a revenit la v1" '[ "$(cat fisier1)" = "v1" ]'

echo "[2] Doua backup-uri in secunde diferite raman ambele"
fresh
echo a > f
run "1\n2\nf\n5\n" > /dev/null; sleep 1.1; run "1\n2\nf\n5\n" > /dev/null
check "exista 2 versiuni" '[ "$(ls backups | wc -l)" -eq 2 ]'

echo "[3] Backup folder cu slash final si cu cale"
fresh
mkdir -p test1 sub/x; echo a > test1/a.txt; echo b > sub/x/b.txt
out=$(run "1\n1\ntest1/\n5\n")
check "test1/ creeaza arhiva" 'ls backups | grep -q "^test1_.*\.tar\.gz$"'
out=$(run "1\n1\nsub/x\n5\n")
check "sub/x creeaza arhiva x_*.tar.gz" 'ls backups | grep -q "^x_.*\.tar\.gz$"'
check "arhiva contine doar x/b.txt (fara cale lunga)" 'tar -tzf backups/x_*.tar.gz | grep -qx "x/b.txt"'

echo "[4] Eroare tar nu afiseaza succes"
fresh
out=$(run "1\n1\nnu_exista\n5\n")
check "mesaj de eroare, fara 'Backup creat'" 'echo "$out" | grep -q "nu exista" && ! echo "$out" | grep -q "Backup creat"'

echo "[5] Input invalid in meniu nu produce erori Bash"
fresh
out=$(run "abc\n\n9\n5\n")
check "fara 'integer expression'" '! echo "$out" | grep -q "integer expression"'
check "afiseaza Optiune invalida" 'echo "$out" | grep -q "Optiune invalida"'

echo "[6] Listarea nu confunda nume"
fresh
mkdir backups; touch backups/test1_2025-01-01_10-00-00 backups/test1_old_2025-01-01_10-00-00
out=$(run "2\ntest1\n5\n")
check "test1 gaseste doar versiunea lui" 'echo "$out" | grep -q "test1_2025-01-01" && ! echo "$out" | grep -q "test1_old"'
out=$(run "2\n.*\n5\n")
check "'.*' nu listeaza tot (text simplu)" 'echo "$out" | grep -q "Nu exista versiuni"'

echo "[7] Restore blocheaza path traversal"
fresh
echo secret > secret.txt; mkdir backups
out=$(run "3\n../secret.txt\n5\n")
check "respins" 'echo "$out" | grep -q "Nume invalid"'

echo "[8] Restore folder arhivat"
fresh
mkdir proj; echo x > proj/f.txt
run "1\n1\nproj\n5\n" > /dev/null
rm -rf proj
run "3\nproj\n1\n\n5\n" > /dev/null
check "proj/f.txt refacut" '[ "$(cat proj/f.txt)" = "x" ]'

echo "[9] Stergere backup-uri vechi"
fresh
mkdir backups; echo n > backups/nou_2026-01-01_00-00-00
echo o > backups/vechi_2020-01-01_00-00-00; touch -d "40 days ago" backups/vechi_2020-01-01_00-00-00
run "4\n30\nn\n5\n" > /dev/null
check "fara confirmare nu sterge" '[ -e backups/vechi_2020-01-01_00-00-00 ]'
run "4\n30\nd\n5\n" > /dev/null
check "cu confirmare sterge doar vechiul" '[ ! -e backups/vechi_2020-01-01_00-00-00 ] && [ -e backups/nou_2026-01-01_00-00-00 ]'

echo "[10] EOF nu blocheaza scriptul"
fresh
printf "" | timeout 5 bash "$SCRIPT" > /dev/null 2>&1
check "iese cu cod 0" '[ $? -eq 0 ]'

echo
echo "Rezultat: $PASS trecute, $FAIL esuate"
[ "$FAIL" -eq 0 ]
