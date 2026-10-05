#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source src/utils.sh
source src/modules/carga_masiva.sh
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
DATA_DIR="$temp_dir/data"; EXPORT_PATH="$temp_dir/export"
require_root() { return 0; }
getent() { [[ "$1" == group && "$2" != FALTANTE ]]; }
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

# Recuperar el fallo anterior sin crear cuentas ni tocar contraseñas.
printf 'usuario|nombre|grupo|dominio|uid|estado\nnuevo|Nombre Ñ|IND_PMO|COR|2001|ERROR_VIGENCIA_SAMBA\n' > "$EXPORT_PATH/usuarios_entrada.csv"
id() { case "$1" in -u) echo 2001;; -gn) echo IND_PMO;; *) return 0;; esac; }
pdbedit() {
  if [[ "$1" == -L ]]; then echo 'nuevo:2001:Nombre Ñ';
  else [[ "$*" == '-u nuevo -c [X]' ]]; fi
}
useradd() { echo 'NO debe crear usuarios' >&2; exit 1; }
chpasswd() { echo 'NO debe cambiar contraseñas' >&2; exit 1; }
smbpasswd() { echo 'NO debe cambiar contraseñas' >&2; exit 1; }
confirm() { return 0; }
recuperar_vigencia_samba > "$temp_dir/recuperacion"
grep -q RECUPERADO "$EXPORT_PATH/usuarios_entrada.csv"
[[ $(wc -l < "$DATA_DIR/usuarios.db") == 1 ]]
recuperar_vigencia_samba >/dev/null
[[ $(wc -l < "$DATA_DIR/usuarios.db") == 1 ]]
printf 'usuario|nombre|grupo|dominio|uid|estado\nnuevo|Nombre Ñ|IND_PMO|COR|9999|ERROR_VIGENCIA_SAMBA\n' > "$EXPORT_PATH/usuarios_entrada.csv"
if recuperar_vigencia_samba > /dev/null 2>&1; then exit 1; fi
grep -q ERROR_VIGENCIA_SAMBA "$EXPORT_PATH/usuarios_entrada.csv"
[[ $(wc -l < "$DATA_DIR/usuarios.db") == 1 ]]
echo 'OK: contraseñas exactas y permanentes, existentes omitidos, errores detectados y auditoría sin secretos.'
