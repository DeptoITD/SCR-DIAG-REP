#!/bin/bash
if [[ "$(type -t log)" != function ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/iniciar.sh" || return 1
fi

exportar_run() {
  require_root
  local host ts export_dir archivo
  host=$(hostname -s); ts=$(date +%Y%m%d_%H%M%S)
  export_dir=$(mktemp -d "${EXPORT_PATH}/export_${host}_${ts}.XXXXXX") || return 1
  chmod 700 "$export_dir" || return 1
  # El manifiesto se escribe únicamente cuando todos los datos son válidos.
  getent passwd > "$export_dir/usuarios_linux.txt" || return 1
  getent group > "$export_dir/grupos_linux.txt" || return 1
  pdbedit -L -w > "$export_dir/credenciales_samba.txt" || return 1
  validar_credenciales_samba "$export_dir/credenciales_samba.txt" || return 1
  # soporte administra Linux; no se transporta como cuenta Samba.
  awk -F: '$1!="soporte"' "$export_dir/credenciales_samba.txt" > "$export_dir/filtrado" || return 1
  mv "$export_dir/filtrado" "$export_dir/credenciales_samba.txt" || return 1
  awk -F: '$4!="" {print $1 ": " $4}' "$export_dir/grupos_linux.txt" > "$export_dir/membresias.txt" || return 1
  for archivo in usuarios.db equipos.db; do
    cp "$DATA_DIR/$archivo" "$export_dir/$archivo" || return 1
  done
  cp /etc/fstab "$export_dir/fstab.txt" || return 1
  [[ ! -f /etc/samba/smb.conf ]] || cp /etc/samba/smb.conf "$export_dir/smb.conf" || return 1
  validar_export_importacion "$export_dir" || return 1
  chmod 600 "$export_dir/"* || return 1
  {
    printf 'hostname=%s\nexport_ts=%s\ntool_version=1.0\nexport_type=merge\n' "$host" "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'samba_sid=%s\n' "$(detectar_samba_sid)"
  } > "$export_dir/manifest.txt" || return 1
  chmod 600 "$export_dir/manifest.txt" || return 1
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]]; then
    chown -R "$SUDO_USER" "$export_dir" || return 1
  fi
  log "Exportación completa: $export_dir (contiene hashes sensibles)."
  mostrar_instrucciones_transfer "$export_dir"
}
