#!/bin/bash
# exportar.sh — Exportar configuración portable

if [[ "$(type -t log)" != "function" ]]; then
  source "${REPO_PATH:-$(dirname "$0")/..}/config/servers.env" 2>/dev/null || source "$(dirname "$0")/../config/servers.env"
  source "${REPO_PATH:-$(dirname "$0")/..}/src/utils.sh" 2>/dev/null || source "$(dirname "$0")/../utils.sh"
fi

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
  echo "tool_version=0.5" >> "$export_dir/manifest.txt"

  # Data files
  cp "${DATA_DIR}/usuarios.db" "$export_dir/" 2>/dev/null || info "No existe usuarios.db local"
  cp "${DATA_DIR}/equipos.db" "$export_dir/" 2>/dev/null || info "No existe equipos.db local"

  # Group membership
  if [[ -f "${DATA_DIR}/equipos.db" ]]; then
    {
      while IFS='|' read -r grupo display gid desc created; do
        [[ -z "$grupo" || "$grupo" =~ ^# ]] && continue
        echo "=== $grupo ==="
        getent group "$grupo" | cut -d: -f4 | tr ',' '\n' | sed 's/^/  /'
      done < "${DATA_DIR}/equipos.db"
    } > "$export_dir/group_membership.txt"
  fi

  # Samba/System configs
  cp /etc/samba/smb.conf "$export_dir/" 2>/dev/null
  testparm -s 2>/dev/null > "$export_dir/testparm.txt"
  cp /etc/fstab "$export_dir/fstab.txt" 2>/dev/null
  sudo pdbedit -L 2>/dev/null > "$export_dir/samba_users.txt" || echo "No access to pdbedit"

  info "✓ Exportación completada: $export_dir"

  # Mostrar instrucciones de transfer
  mostrar_instrucciones_transfer "$export_dir"
}
