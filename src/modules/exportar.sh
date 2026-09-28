#!/bin/bash
# exportar.sh — Exportar configuración portable

[[ -z "$REPO_PATH" ]] && source "$(dirname "$0")/../config/servers.env"
[[ -z "$log" ]] && source "$(dirname "$0")/../utils.sh"

exportar_run() {
  require_root
  local host=$(hostname -s)
  local ts=$(date +%Y%m%d_%H%M%S)
  local export_dir="${EXPORT_PATH}/export_${host}_${ts}"

  mkdir -p "$export_dir"

  log "Exportando configuración a: $export_dir"

  # Manifest
  echo "hostname=${host}" > "$export_dir/manifest.txt"
  echo "export_ts=$(date '+%Y-%m-%d %H:%M:%S')" >> "$export_dir/manifest.txt"
  echo "tool_version=0.3" >> "$export_dir/manifest.txt"

  # Data files
  cp "${DATA_DIR}/usuarios.db" "$export_dir/" 2>/dev/null || info "No existe usuarios.db local"
  cp "${DATA_DIR}/equipos.db" "$export_dir/" 2>/dev/null || info "No existe equipos.db local"

  # Group membership (NEW - this is the key file that fixes the bug)
  {
    while IFS='|' read -r grupo display gid desc created; do
      [[ -z "$grupo" || "$grupo" =~ ^# ]] && continue
      echo "=== $grupo ==="
      getent group "$grupo" | cut -d: -f4 | tr ',' '\n' | sed 's/^/  /'
    done < "${DATA_DIR}/equipos.db"
  } > "$export_dir/group_membership.txt"

  # Samba/System configs
  cp /etc/samba/smb.conf "$export_dir/" 2>/dev/null
  testparm -s 2>/dev/null > "$export_dir/testparm.txt"
  cp /etc/fstab "$export_dir/fstab.txt"
  sudo pdbedit -L 2>/dev/null > "$export_dir/samba_users.txt" || echo "No access to pdbedit"

  info "Exportación local completa: $export_dir"
  echo ""
  echo "Contenido:"
  ls -lh "$export_dir"
  echo ""

  # Sincronizar con NAS si está habilitado
  if [[ "$NAS_ENABLED" == "true" && -d "$NAS_EXPORT_PATH" ]]; then
    echo ""
    info "Sincronizando con NAS..."
    mkdir -p "$NAS_EXPORT_PATH"

    if cp -r "$export_dir" "$NAS_EXPORT_PATH/" 2>/dev/null; then
      info "✓ Exportación replicada en NAS: $NAS_EXPORT_PATH/$(basename $export_dir)"
      echo "  Cualquier máquina en red puede importar desde NAS"
    else
      warn "✗ Error al copiar a NAS. Verificar montaje: $NAS_MOUNT_POINT"
    fi
  else
    echo ""
    echo "💡 Alternativa manual (si NAS no está accesible):"
    echo "  scp -r $export_dir <destino>:/opt/scripts/SCR-DIAG-REP/src/export/"
  fi
}
