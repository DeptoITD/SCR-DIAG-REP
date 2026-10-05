#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source src/utils.sh
DATA_DIR=$(mktemp -d)
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
[[ $(wc -l < "$DATA_DIR/equipos.db") == 3 ]]
grep -Fqx 'IND_PMO|Oficina PMO|2000|Descripción original|2026-09-25' "$DATA_DIR/equipos.db"
grep -q '^IND_GTC|IND_GTC|2005|' "$DATA_DIR/equipos.db"
grep -q '^users|users|100|' "$DATA_DIR/equipos.db"
if registrar_grupo_catalogo inexistente; then exit 1; fi
source src/modules/importar.sh
mkdir "$DATA_DIR/export"
printf 'IND_GTC:x:9999:\n' > "$DATA_DIR/export/grupos_linux.txt"
importar_grupos_linux "$DATA_DIR/export" >/dev/null
grep -q '^IND_GTC|IND_GTC|2005|' "$DATA_DIR/equipos.db"
echo 'OK: catálogo completo, GID reales, metadatos conservados y sin duplicados.'
