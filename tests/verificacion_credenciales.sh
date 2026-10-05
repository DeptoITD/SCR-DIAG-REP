#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source src/verificar_credenciales_csv.sh
task_dir=$(mktemp -d)
trap 'rm -rf "$task_dir"' EXIT
id() { echo 0; }
openssl() { return 0; }
iconv() { return 0; }
calcular_hash_nt() { printf '%s\n' 8846F7EAEE8FB117AD06BDD830B7586C; }
pdbedit() { echo 'nuevo:2001:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:8846F7EAEE8FB117AD06BDD830B7586C:[UX]:LCT-1'; }
printf 'usuario|nombre|grupo|dominio|uid|password\nnuevo|Nombre|IND_PMO|COR|2001|password\n' > "$task_dir/input"
verificar_credenciales_csv "$task_dir/input" > "$task_dir/resultado"
grep -q '\[COINCIDE\] nuevo' "$task_dir/resultado"
if grep -q '8846F7\|password' "$task_dir/resultado"; then exit 1; fi
pdbedit() { echo 'nuevo:2001:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:00000000000000000000000000000000:[UX]:LCT-1'; }
if verificar_credenciales_csv "$task_dir/input" > "$task_dir/resultado"; then exit 1; fi
grep -q 'NO COINCIDE' "$task_dir/resultado"
pdbedit() { echo 'nuevo:2001:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:8846F7EAEE8FB117AD06BDD830B7586C:[UDX]:LCT-1'; }
if verificar_credenciales_csv "$task_dir/input" > "$task_dir/resultado"; then exit 1; fi
grep -q DESHABILITADA "$task_dir/resultado"
pdbedit() { return 1; }
if verificar_credenciales_csv "$task_dir/input" > "$task_dir/resultado"; then exit 1; fi
grep -q 'NO EXISTE' "$task_dir/resultado"
echo 'OK: coincidencia, diferencias, cuenta deshabilitada y ausencia sin exponer secretos.'
