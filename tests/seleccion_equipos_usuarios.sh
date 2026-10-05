#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source src/utils.sh
source src/modules/equipos.sh
source src/modules/usuarios.sh
DATA_DIR=$(mktemp -d)
getent() {
  [[ "$1" == group ]] || return 1
  case "${2:-}" in
    IND_PMO) echo 'IND_PMO:x:1002:' ;;
    IND_ITD) echo 'IND_ITD:x:1007:' ;;
    IND_VACIO) echo 'IND_VACIO:x:1008:' ;;
    '') printf 'IND_PMO:x:1002:\nIND_ITD:x:1007:\nIND_VACIO:x:1008:\n' ;;
    *) return 1 ;;
  esac
}
trap 'rm -rf "$DATA_DIR"' EXIT
printf '#grupo|display|gid\nIND_PMO|Oficina PMO|1002\nIND_ITD|IT+D|1007\nIND_VACIO|Vacío|1008\n' > "$DATA_DIR/equipos.db"
printf '#user|nombre|primario|extra|uid\njhonatan.rojas|Jhonatan Rojas|IND_PMO|IND_ITD|1002\nsara|Sara|IND_ITD||1003\n' > "$DATA_DIR/usuarios.db"
[[ $(seleccionar_registro "$DATA_DIR/equipos.db" Equipo <<< $'ITD\n2' 2>"$DATA_DIR/menu") == IND_ITD ]]
grep -q 'Opción inválida' "$DATA_DIR/menu"
[[ $(seleccionar_registro "$DATA_DIR/equipos.db" Equipo varios <<< '1,2,1' 2>/dev/null) == IND_PMO,IND_ITD ]]
[[ $(seleccionar_registro "$DATA_DIR/equipos.db" Equipo varios <<< T 2>/dev/null) == IND_PMO,IND_ITD,IND_VACIO ]]
[[ -z $(seleccionar_registro "$DATA_DIR/equipos.db" Equipo varios <<< N 2>/dev/null) ]]
if seleccionar_registro "$DATA_DIR/equipos.db" Equipo <<< 0 2>/dev/null; then exit 1; fi
usuario_listar > "$DATA_DIR/listado"
grep -q jhonatan.rojas "$DATA_DIR/listado"
grep -q Sara "$DATA_DIR/listado"
equipo_ver_integrantes <<< T > "$DATA_DIR/integrantes" 2>"$DATA_DIR/menu"
grep -q 'Integrantes de IND_PMO' "$DATA_DIR/integrantes"
grep -q 'Integrantes de IND_ITD' "$DATA_DIR/integrantes"
grep -q 'Sin integrantes registrados' "$DATA_DIR/integrantes"
[[ $(grep -c jhonatan.rojas "$DATA_DIR/integrantes") == 2 ]]
grep -q 'T) Todos' "$DATA_DIR/menu"
echo 'OK: selección numerada, Todos, grupos adicionales y listado de usuarios.'
