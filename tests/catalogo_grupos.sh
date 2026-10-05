#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source src/utils.sh
DATA_DIR=$(mktemp -d)
net() {
  printf '%s\n' "$*" >> "$DATA_DIR/net.log"
  if [[ "$*" == 'groupmap list' ]]; then
    [[ ! -f "$DATA_DIR/mapas" ]] || cat "$DATA_DIR/mapas"
  else
    local grupo="${3#unixgroup=}"
    printf '%s (S-1-5-21-1-2-3-1000) -> %s\n' "$grupo" "$grupo" >> "$DATA_DIR/mapas"
  fi
  return 0
}
trap 'rm -rf "$DATA_DIR"' EXIT
printf 'IND_PMO|Oficina PMO|1002|Descripción original|2026-09-25\n' > "$DATA_DIR/equipos.db"
getent() {
  [[ "$1" == group ]] || return 1
  case "${2:-}" in
    IND_PMO) echo 'IND_PMO:x:2000:' ;;
    IND_GTC) echo 'IND_GTC:x:2005:' ;;
    users) echo 'users:x:100:' ;;
    '') printf 'IND_PMO:x:2000:\nIND_GTC:x:2005:\nusers:x:100:\n' ;;
    *) return 1 ;;
  esac
}
sincronizar_catalogo_grupos
sincronizar_catalogo_grupos
[[ $(wc -l < "$DATA_DIR/equipos.db") == 2 ]]
grep -Fqx 'IND_PMO|Oficina PMO|2000|Descripción original|2026-09-25' "$DATA_DIR/equipos.db"
grep -q '^IND_GTC|IND_GTC|2005|' "$DATA_DIR/equipos.db"
if grep -q '^users|' "$DATA_DIR/equipos.db"; then exit 1; fi
grep -Fq 'groupmap add unixgroup=IND_GTC ntgroup=IND_GTC type=local' "$DATA_DIR/net.log"
[[ $(grep -c 'groupmap add unixgroup=IND_GTC' "$DATA_DIR/net.log") == 1 ]]
if grep -q 'unixgroup=users' "$DATA_DIR/net.log"; then exit 1; fi
if registrar_grupo_catalogo inexistente; then exit 1; fi
source src/modules/importar.sh
mkdir "$DATA_DIR/export"
printf 'IND_GTC:x:9999:\n' > "$DATA_DIR/export/grupos_linux.txt"
importar_grupos_linux "$DATA_DIR/export" >/dev/null
grep -q '^IND_GTC|IND_GTC|2005|' "$DATA_DIR/equipos.db"
echo 'OK: catálogo completo, GID reales, metadatos conservados y sin duplicados.'
