#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source src/utils.sh
source src/modules/carga_masiva.sh
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
DATA_DIR="$temp_dir/data"; EXPORT_PATH="$temp_dir/export"
require_root() { return 0; }
getent() {
  [[ "$1" == group && "${2:-}" != FALTANTE ]] || return 1
  printf '%s:x:2004:\n' "${2:-IND_PMO}"
}
id() {
  if [[ "$1" == -u ]]; then echo 2001; return 0; fi
  [[ "$1" == existente ]]
}
useradd() { printf '%s\n' "$*" >> "$temp_dir/useradd"; }
chpasswd() { cat > "$temp_dir/password_linux"; }
chage() { printf '%s\n' "$*" > "$temp_dir/chage"; }
smbpasswd() {
  if [[ "$1" == -s ]]; then cat > "$temp_dir/password_samba"; fi
}
pdbedit() {
  [[ "$*" != *'[UX]'* ]] || return 1
  printf '%s\n' "$*" > "$temp_dir/pdbedit"
}
printf '\357\273\277usuario|nombre|grupo|dominio|uid|password\r\nnuevo|Nombre Ñ|IND_PMO|COR|2001| pass$! fijo \r\nexistente|Existente|IND_PMO|OPE|2002|OtraClave' > "$temp_dir/input"
leer_csv "$temp_dir/input" > "$temp_dir/resumen"
[[ ${#USUARIOS_LEIDOS[@]} == 2 ]]
[[ "${USUARIOS_LEIDOS[0]}" == 'nuevo|Nombre Ñ|IND_PMO|COR|2001| pass$! fijo ' ]]
aplicar_carga_masiva > "$temp_dir/resultado"
grep -Fq -- '-M -d /nonexistent -s /usr/sbin/nologin' "$temp_dir/useradd"
if grep -q -- '-m ' "$temp_dir/useradd"; then exit 1; fi
grep -Fqx 'nuevo: pass$! fijo ' "$temp_dir/password_linux"
[[ $(grep -Fc ' pass$! fijo ' "$temp_dir/password_samba") == 2 ]]
grep -Fq -- '-M -1 -I -1 -E -1' "$temp_dir/chage"
grep -Fq -- '-c [X]' "$temp_dir/pdbedit"
grep -q '1 creados, 1 omitidos, 0 errores' "$temp_dir/resultado"
if grep -Fq 'pass$!' "$EXPORT_PATH/usuarios_entrada.csv" "$DATA_DIR/usuarios.db" "$temp_dir/resumen" "$temp_dir/resultado"; then exit 1; fi
[[ $(wc -l < "$DATA_DIR/usuarios.db") == 1 ]]
printf 'usuario|nombre|grupo|dominio|uid|password\nnuevo|Nombre|FALTANTE|COR|2001|Clave\n' > "$temp_dir/input"
if leer_csv "$temp_dir/input" > /dev/null 2>&1; then exit 1; fi
[[ ${#USUARIOS_LEIDOS[@]} == 0 ]]
printf 'nuevo|Nombre|IND_PMO|COR|2001|Clave\nnuevo|Nombre|IND_PMO|COR|2002|Clave\n' > "$temp_dir/input"
if leer_csv "$temp_dir/input" > /dev/null 2>&1; then exit 1; fi
printf 'nuevo|Nombre|IND_PMO|COR|2001|Clave\n' > "$temp_dir/input"
leer_csv "$temp_dir/input" >/dev/null
chpasswd() { cat >/dev/null; return 1; }
if aplicar_carga_masiva > "$temp_dir/resultado" 2>/dev/null; then exit 1; fi
grep -q '0 creados, 0 omitidos, 1 errores' "$temp_dir/resultado"

menu_carga_masiva <<< 3 > "$temp_dir/menu"
grep -q '1. Cargar usuarios desde archivo' "$temp_dir/menu"
if grep -q '^4\.' "$temp_dir/menu"; then exit 1; fi
if declare -F recuperar_vigencia_samba >/dev/null; then exit 1; fi
echo 'OK: contraseñas exactas y permanentes, existentes omitidos, errores detectados y auditoría sin secretos.'
