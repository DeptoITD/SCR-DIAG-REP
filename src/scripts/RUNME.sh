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
  --diagnostico       Diagnóstico máquina (SMB, storage, RAID, LVM, ACLs)
  --export-server     Exportar identidades + config del servidor
  --create-nas        Crear usuarios/grupos en NAS (NO ACLs)
  --full              Flujo completo (diagnostico → exportar → crear)
  --dry-run           Simular sin cambios
  --help              Mostrar esta ayuda

Notas:
  • ACLs se configuran en repo separado (SCR-ACL-REP)
  • --acls DEPRECATED (no usar)

Ejemplos:
  bash RUNME.sh --diagnostico        # Diagnóstico en servidor
  bash RUNME.sh --export-server      # Exportar desde srv-2
  bash RUNME.sh --create-nas         # Crear en NAS
  bash RUNME.sh --full               # Flujo completo
  bash RUNME.sh --dry-run            # Simular sin cambios
EOF
  exit 0
fi

case "$MODE" in
  --diagnostico)
    log "===== DIAGNÓSTICO MÁQUINA ACTUAL ====="
    bash "${SCRIPT_DIR}/scripts/01_diagnostico_completo.sh"
    log "✓ Diagnóstico completado"
    ;;

  --export-server)
    log "===== EXPORTAR IDENTIDADES (desde máquina actual) ====="
    bash "${SCRIPT_DIR}/scripts/10_exportar_identidades.sh"
    log "✓ Exportación completada"
    ;;

  --create-nas)
    log "===== CREAR IDENTIDADES (desde exports locales) ====="
    bash "${SCRIPT_DIR}/scripts/20_crear_identidades_nas.sh"
    log "✓ Identidades creadas (usuarios/grupos)"
    ;;

  --acls)
    log "⚠️  DEPRECATED: ACLs en repo SCR-ACL-REP"
    log "No ejecutar aquí"
    exit 1
    ;;

  --full)
    log "===== FLUJO COMPLETO ====="
    bash "${SCRIPT_DIR}/scripts/01_diagnostico_completo.sh"
    bash "${SCRIPT_DIR}/scripts/10_exportar_identidades.sh"
    bash "${SCRIPT_DIR}/scripts/20_crear_identidades_nas.sh"
    log "✓ Flujo completado (diagnóstico + exportar + crear)"
    log "Siguiente: aplicar ACLs con repo SCR-ACL-REP"
    ;;

  --dry-run)
    log "===== MODO SIMULACIÓN ====="
    bash "${SCRIPT_DIR}/scripts/01_diagnostico_completo.sh"
    bash "${SCRIPT_DIR}/scripts/10_exportar_identidades.sh" --dry-run
    bash "${SCRIPT_DIR}/scripts/20_crear_identidades_nas.sh" --dry-run
    log "✓ Simulación finalizada (sin cambios reales)"
    ;;

  *)
    echo "Opción desconocida: $MODE"
    echo "Usa: bash RUNME.sh --help"
    exit 1
    ;;
esac

log "Log guardado: $LOG_FILE"
