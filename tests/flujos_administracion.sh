#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source src/utils.sh
source src/modules/usuarios.sh
source src/modules/importar.sh
source src/modules/equipos.sh
task_dir=$(mktemp -d)
trap 'rm -rf "$task_dir"' EXIT
DATA_DIR="$task_dir/data"; LOG_DIR="$task_dir/logs"; REPO_PATH="$task_dir"
mkdir -p "$DATA_DIR" "$LOG_DIR" "$task_dir/export"
printf 'IND_PMO|PMO|2004|Inicial|2026-10-05\n' > "$DATA_DIR/equipos.db"
: > "$DATA_DIR/usuarios.db"
require_root() { return 0; }
sudo() { "$@"; }
seleccionar_registro() { [[ "${3:-}" == varios ]] || echo IND_PMO; return 0; }
generate_password() { printf '%s' 'Clave$!Fija12345'; }
mostrar_password_generada() { return 0; }
useradd() { printf '%s\n' "$*" > "$task_dir/useradd"; touch "$task_dir/creado"; }
id() {
  case "$1" in
    -u) echo 2001;;
    -gn) echo IND_PMO;;
    -Gn) echo 'IND_PMO IND_BIM';;
    *) [[ -f "$task_dir/creado" ]];;
  esac
}
getent() {
  case "$1:$2" in
    group:IND_PMO) echo 'IND_PMO:x:2004:';;
    passwd:nuevo) echo 'nuevo:x:2001:2004:Nombre:/nonexistent:/usr/sbin/nologin';;
    *) return 1;;
  esac
}
chpasswd() { cat > "$task_dir/chpasswd"; }
chage() { printf '%s\n' "$*" > "$task_dir/chage"; }
smbpasswd() { if [[ "$1" == -s ]]; then cat > "$task_dir/smbpasswd"; fi; }
pdbedit() { return 0; }
usuario_crear <<< $'nuevo\nNombre' > "$task_dir/resultado"
grep -Fqx 'nuevo:Clave$!Fija12345' "$task_dir/chpasswd"
[[ $(grep -Fcx 'Clave$!Fija12345' "$task_dir/smbpasswd") == 2 ]]
grep -Fq -- '-M -d /nonexistent -s /usr/sbin/nologin' "$task_dir/useradd"
grep -q 'nuevo|Nombre|IND_PMO|IND_BIM|2001|' "$DATA_DIR/usuarios.db"
printf 'nuevo:x:2001:9999:Nombre:/home/nuevo:/bin/bash\nroot:x:0:0:Root:/root:/bin/bash\n' > "$task_dir/export/usuarios_linux.txt"
printf 'IND_PMO:x:9999:\n' > "$task_dir/export/grupos_linux.txt"
importar_usuarios_linux "$task_dir/export" >/dev/null
[[ $(wc -l < "$DATA_DIR/usuarios.db") == 1 ]]
net() {
  if [[ "$*" == 'groupmap list' ]]; then echo 'IND_PMO (S-1-5-21-1-2-3-1000) -> IND_PMO';
  else printf '%s\n' "$*" > "$task_dir/net"; fi
}
equipo_editar <<< $'2\nDescripción con & y /' >/dev/null
grep -Fq '|Descripción con & y /|' "$DATA_DIR/equipos.db"
grep -Fq 'comment=Descripción con & y /' "$task_dir/net"
groupmod() { printf '%s\n' "$*" > "$task_dir/groupmod"; }
equipo_editar <<< $'1\nIND_NUEVO' >/dev/null
grep -q '^IND_NUEVO|' "$DATA_DIR/equipos.db"
grep -q 'nuevo|Nombre|IND_NUEVO|IND_BIM|' "$DATA_DIR/usuarios.db"
grep -Fq 'unixgroup=IND_NUEVO ntgroup=IND_NUEVO' "$task_dir/net"
# Fallo real de creación: la importación no anuncia éxito y conserva los respaldos.
rm "$task_dir/creado"
useradd() { return 1; }
seleccionar_export() { echo "$task_dir/export"; }
menu_seleccionar_importacion() { echo usuarios; }
analizar_migracion() { return 0; }
confirm() { return 0; }
cp() {
  if [[ "$2" == /etc/passwd || "$2" == /etc/group ]]; then printf 'respaldo\n' > "$3";
  else command cp "$@"; fi
}
if importar_run > "$task_dir/importacion"; then exit 1; fi
if grep -q 'Importación completada' "$task_dir/importacion"; then exit 1; fi
[[ $(find "$LOG_DIR" -name passwd.bak | wc -l) == 1 ]]
echo 'OK: altas permanentes, registro sin duplicados, metadatos y Samba coherentes, fallos sin falso éxito y respaldos conservados.'
