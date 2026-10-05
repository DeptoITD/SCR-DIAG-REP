#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source src/revisar_acceso_samba.sh
task_dir=$(mktemp -d)
trap 'rm -rf "$task_dir"' EXIT
export REPO_PATH="$task_dir"
mkdir -p "$task_dir/config/data"
printf 'julian.ochoa|Julian|GEN||1028\nsoporte|Soporte|GEN||1000\n' > "$task_dir/config/data/usuarios.db"
getent() {
  case "$2" in
    soporte) echo 'soporte:x:1000:1000:Soporte:/home/soporte:/bin/bash';;
    sara.albarracin) echo 'sara.albarracin:x:1001:1001:Sara:/home/sara:/bin/bash';;
    juan.rojas) echo 'juan.rojas:x:1002:1002:Juan:/home/juan:/bin/bash';;
    julian.ochoa) echo 'julian.ochoa:x:1028:2004:Julian:/home/julian.ochoa:/bin/sh';;
    daemon) echo 'daemon:x:1:1:Daemon:/usr/sbin:/usr/sbin/nologin';;
    *) return 1;;
  esac
}
pdbedit() { printf 'soporte:1000:Soporte\nsara.albarracin:1001:Sara\njuan.rojas:1002:Juan\njulian.ochoa:1028:Julian\ndaemon:1:Daemon\n'; }
id() { echo 0; }
usermod() { printf '%s\n' "$*" >> "$task_dir/usermod"; }
samba_shell_disponible() { return 0; }
cp() {
  if [[ "$2" == /etc/passwd ]]; then getent passwd soporte > "$3";
  else command cp "$@"; fi
}
revisar_acceso_samba > "$task_dir/revision"
[[ ! -e "$task_dir/usermod" ]]
grep -q 'sara.albarracin.*CONSERVAR' "$task_dir/revision"
grep -q 'juan.rojas.*CONSERVAR' "$task_dir/revision"
grep -q 'soporte.*CONSERVAR' "$task_dir/revision"
grep -q 'julian.ochoa.*CONVERTIR' "$task_dir/revision"
revisar_acceso_samba --aplicar > "$task_dir/resultado"
[[ $(wc -l < "$task_dir/usermod") == 1 ]]
grep -Fxq -- '-d /nonexistent -s /usr/sbin/nologin julian.ochoa' "$task_dir/usermod"
if revisar_acceso_samba --preservar desconocido --aplicar >/dev/null 2>&1; then exit 1; fi
[[ $(wc -l < "$task_dir/usermod") == 1 ]]
echo 'OK: revisión sin cambios, excepciones protegidas y conversión solo de cuentas normales.'
