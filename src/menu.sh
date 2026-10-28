#!/bin/bash
# Menú principal: cada opción ejecuta una acción de script.sh y vuelve al menú.
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ $(id -u) -eq 0 ]] || { echo "[!] Ejecuta: sudo bash src/menu.sh" >&2; exit 1; }

acciones=(diagnostico exportar importar carga-masiva listar-usuarios listar-grupos limpiar-homes usuarios equipos exportaciones)

menu() {
  echo ""
  echo "=== SCR-DIAG-REP ==="
  echo "1. Diagnóstico del equipo"
  echo "2. Exportar identidades"
  echo "3. Importar identidades"
  echo "4. Carga masiva de usuarios"
  echo "5. Listar usuarios"
  echo "6. Listar grupos de trabajo"
  echo "7. Limpiar homes iniciales"
  echo "8. Administrar usuarios"
  echo "9. Administrar equipos"
  echo "10. Administrar exportaciones"
  echo "0. Salir"
}

while true; do
  menu
  read -r -p "Opción: " opt || exit 0
  case "$opt" in
    0) exit 0 ;;
    [1-9]|10)
      bash "$SCRIPT_DIR/script.sh" "${acciones[$((opt-1))]}"
      echo "[Acción terminada con código $?]"
      ;;
    *) echo "[!] Opción inválida" >&2 ;;
  esac
done
