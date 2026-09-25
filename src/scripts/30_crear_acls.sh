#!/bin/bash
# 30_crear_acls.sh
# Configura permisos y ACLs en NAS para identidades replicadas
# Uso: bash 30_crear_acls.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/../config/servers.env"

DRY_RUN="${1:---dry-run}"

[[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"

log "===== INICIO CONFIGURACIÓN ACLs ====="
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
