#!/bin/bash
# RUNME.sh — Script maestro orquestación
# Ejecuta todos los pasos: exportar → transferir → crear identidades → ACLs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/../logs"
[[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"

LOG_FILE="${LOG_DIR}/runme_$(date +%Y%m%d_%H%M%S).log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

MODE="${1:---help}"

if [[ "$MODE" == "--help" || "$MODE" == "-h" ]]; then
  cat << 'EOF'
Uso: bash RUNME.sh [opción]

Opciones:
  --export-server     Exportar identidades del servidor origen
  --create-nas        Crear identidades en NAS (requiere archivos export)
  --acls              Configurar ACLs en NAS
  --full              Ejecutar flujo completo (exportar → crear → ACLs)
  --dry-run           Simular todo sin hacer cambios
  --help              Mostrar esta ayuda

Ejemplos:
  bash RUNME.sh --export-server      # Exportar desde srv-2
  bash RUNME.sh --create-nas         # Crear en NAS (local)
  bash RUNME.sh --full               # Flujo completo
  bash RUNME.sh --dry-run            # Simular sin cambios
EOF
  exit 0
fi

case "$MODE" in
  --export-server)
    log "===== EXPORTAR IDENTIDADES ====="
    bash "${SCRIPT_DIR}/10_exportar_identidades.sh"
    log "✓ Exportación completada"
    ;;

  --create-nas)
    log "===== CREAR IDENTIDADES NAS ====="
    bash "${SCRIPT_DIR}/20_crear_identidades_nas.sh"
    log "✓ Identidades creadas"
    ;;

  --acls)
    log "===== CONFIGURAR ACLs ====="
    bash "${SCRIPT_DIR}/30_crear_acls.sh"
    log "✓ ACLs configurados"
    ;;

  --full)
    log "===== INICIO FLUJO COMPLETO ====="
    bash "${SCRIPT_DIR}/10_exportar_identidades.sh"
    bash "${SCRIPT_DIR}/20_crear_identidades_nas.sh"
    bash "${SCRIPT_DIR}/30_crear_acls.sh"
    log "✓ Flujo completo finalizado"
    ;;

  --dry-run)
    log "===== MODO SIMULACIÓN ====="
    bash "${SCRIPT_DIR}/10_exportar_identidades.sh" --dry-run
    bash "${SCRIPT_DIR}/20_crear_identidades_nas.sh" --dry-run
    bash "${SCRIPT_DIR}/30_crear_acls.sh" --dry-run
    log "✓ Simulación finalizada (sin cambios reales)"
    ;;

  *)
    echo "Opción desconocida: $MODE"
    echo "Usa: bash RUNME.sh --help"
    exit 1
    ;;
esac

log "Log guardado: $LOG_FILE"
