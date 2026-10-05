#!/bin/bash
# main.sh — Dispatcher principal DIAG

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core/comun.sh"
source "$SCRIPT_DIR/core/config.sh"

show_menu() {
  echo ""
  echo "════════════════════════════════════════════════════"
  echo "  SCR-DIAG-REP — Gestión de Identidades"
  echo "════════════════════════════════════════════════════"
  echo ""
  echo "1) Diagnóstico"
  echo "2) Usuarios (CRUD)"
  echo "3) Equipos (Grupos)"
  echo "4) Carga masiva (CSV)"
  echo "5) Exportar"
  echo "6) Importar"
  echo "7) Sincronizar"
  echo "0) Salir"
  echo ""
  read -r -p "Opción: " opt

  case "$opt" in
    1) bash "$SCRIPT_DIR/diagnostico/diagnostico.sh" ;;
    2) bash "$SCRIPT_DIR/identidades/usuarios.sh" ;;
    3) bash "$SCRIPT_DIR/identidades/equipos.sh" ;;
    4) bash "$SCRIPT_DIR/identidades/carga_masiva.sh" ;;
    5) bash "$SCRIPT_DIR/migracion/exportar.sh" ;;
    6) bash "$SCRIPT_DIR/migracion/importar.sh" ;;
    7) bash "$SCRIPT_DIR/migracion/sync.sh" ;;
    0) return 0 ;;
    *) warn "Opción inválida" ;;
  esac
}

main() {
  while true; do
    show_menu || break
  done
  log "Salida"
}

main
