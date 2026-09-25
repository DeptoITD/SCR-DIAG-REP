#!/bin/bash
# 30_crear_acls.sh
# ⚠️  DEPRECATED: ACLs se configuran en repo separado: SCR-ACL-REP
#
# Este script NO DEBE ser usado. El manejo de ACLs, permisos y inheritance
# se centraliza en repositorio SCR-ACL-REP que:
# - Define ACLs por compartir (share-level)
# - Aplica setfacl/chmod por usuario y grupo
# - Gestiona masks e inheritance
#
# Flujo correcto:
#   1. Este repo (SCR-DIAG-REP): diagnóstico + exportar + crear usuarios/grupos
#   2. Otro repo (SCR-ACL-REP):  aplicar ACLs y permisos
#
# Usar: bash src/scripts/RUNME.sh --create-nas (sin --acls)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/../config/servers.env"

# Definir LOG_FILE antes de sourcear utils.sh
export LOG_FILE="${LOG_DIR}/acls_$(date +%Y%m%d_%H%M%S).log"
[[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"

source "${SCRIPT_DIR}/utils.sh"

DRY_RUN="${1:---dry-run}"

log "===== ⚠️  SCRIPT DEPRECATED ====="
log "ACLs se configuran en repo SCR-ACL-REP, no aquí"
log "NAS: ${NAS_IP}"

# Permisos para directorios SCR-DIAG-REP
info "Configurando permisos directorios..."

dirs_to_fix=(
  "$EXPORT_PATH"
  "$LOG_DIR"
  "${NAS_PATH}/src"
)

for dir in "${dirs_to_fix[@]}"; do
  if [[ -d "$dir" ]]; then
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      sudo chmod -R 755 "$dir"
      sudo chown -R soporte:soporte "$dir"
      log "  ✓ Permisos ajustados: $dir (755, soporte:soporte)"
    else
      info "  [DRY] Ajustar permisos: $dir (755, soporte:soporte)"
    fi
  fi
done

# ACLs para usuarios Samba
info "Configurando ACLs para usuarios Samba..."

# Si archivo export_samba existe, iterar usuarios
if [[ -f "$EXPORT_SAMBA_USERS" ]]; then
  while IFS= read -r linea; do
    [[ -z "$linea" ]] && continue
    user=$(echo "$linea" | cut -d: -f1)

    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      # Ejemplo: dar acceso a /opt/data
      target_dir="/opt/data/${user}"
      [[ ! -d "$target_dir" ]] && sudo mkdir -p "$target_dir"

      sudo setfacl -m "u:${user}:rwx" "$target_dir" 2>/dev/null || \
        info "  ! No se pudo setear ACL para $user"

      log "  ✓ ACL creado: $user en $target_dir"
    else
      info "  [DRY] Crear ACL para usuario: $user"
    fi
  done < "$EXPORT_SAMBA_USERS"
fi

info "===== RESUMEN ACLs ====="
info "Directorios configurados: ${#dirs_to_fix[@]}"
[[ -f "$EXPORT_SAMBA_USERS" ]] && info "Usuarios con ACL: $(wc -l < "$EXPORT_SAMBA_USERS")"
log "===== FIN CONFIGURACIÓN ====="
