#!/bin/bash
# menu.sh — Entry point único (reemplaza RUNME.sh)

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_PATH="$(dirname "$SCRIPT_DIR")"
export CONFIG_DIR="${REPO_PATH}/config"

# Sourcing
source "${REPO_PATH}/config/servers.env"
mkdir -p "${LOG_DIR}" "${DATA_DIR}" "${EXPORT_PATH}" 2>/dev/null
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/modules/diagnostico.sh"
source "${SCRIPT_DIR}/modules/exportar.sh"
source "${SCRIPT_DIR}/modules/importar.sh"
source "${SCRIPT_DIR}/modules/sync.sh"
source "${SCRIPT_DIR}/modules/equipos.sh"
source "${SCRIPT_DIR}/modules/usuarios.sh"
source "${SCRIPT_DIR}/modules/carga_masiva.sh"

main_menu() {
  while true; do
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║     SCR-DIAG-REP v0.5                  ║"
    echo "║  Exportar → Copiar → Importar          ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "1. Diagnóstico de equipo"
    echo "2. Exportar configuración"
    echo "3. Importar configuración (desde export)"
    echo "4. Gestión de exportaciones"
    echo "5. Gestión de equipos"
    echo "6. Gestión de usuarios"
    echo "7. Salir"
    echo ""
    read -r -p "Seleccione una opción: " opt

    case "$opt" in
      1) diagnostico_run ;;
      2) exportar_run ;;
      3) importar_run ;;
      4) menu_sync ;;
      5) menu_equipos ;;
      6) menu_usuarios ;;
      7) echo "Hasta luego."; exit 0 ;;
      *) echo "[!] Opción inválida" ;;
    esac
  done
}

main_menu
