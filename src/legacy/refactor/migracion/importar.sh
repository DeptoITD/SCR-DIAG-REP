#!/bin/bash
# migracion/importar.sh v1.0 — Importar exportación (llama core)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/core/comun.sh"
source "$SCRIPT_DIR/core/config.sh"
source "$SCRIPT_DIR/core/usuarios_core.sh"
source "$SCRIPT_DIR/core/grupos_core.sh"
source "$SCRIPT_DIR/core/samba_core.sh"
source "$SCRIPT_DIR/core/backup_core.sh"

importar_run() {
  require_root

  echo "=== Importar Exportación ==="
  echo ""

  # Seleccionar export
  local exports=($(ls -d /tmp/export_* 2>/dev/null | sort -r))
  [[ ${#exports[@]} -eq 0 ]] && error "No hay exports"

  for i in "${!exports[@]}"; do
    echo "$((i+1))) $(basename "${exports[$i]}")"
  done
  read -r -p "Elige [1-${#exports[@]}]: " num
  [[ ! "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > ${#exports[@]} )) && error "Inválido"

  local exp="${exports[$((num-1))]}"
  [[ ! -f "$exp/manifest.txt" ]] && error "Manifest no existe"
  [[ ! -f "$exp/usuarios_linux.txt" ]] && error "Usuarios no existen"
  [[ ! -f "$exp/shadow_export.txt" ]] && error "Shadow no existe"

  echo ""
  echo "Usuarios a importar:"
  cut -d: -f1 "$exp/usuarios_linux.txt" | head -10
  echo ""

  confirm "¿Continuar?" || return 0

  # Backup
  bak=$(backup_critico)
  log "Backup: $bak"

  # Importar grupos
  log "Importando grupos..."
  while IFS=: read -r grp _ gid _; do
    [[ -z "$grp" || "$grp" =~ ^# ]] && continue
    crear_grupo "$grp" "$gid" || true
  done < "$exp/grupos_linux.txt"

  # Importar usuarios
  log "Importando usuarios..."
  while IFS=: read -r user _ uid gid gecos home shell; do
    [[ -z "$user" || "$user" =~ ^# ]] && continue
    
    if id "$user" &>/dev/null; then
      info "Usuario existe: $user"
    else
      grp=$(getent gid "$gid" | cut -d: -f1)
      crear_usuario "$user" "$uid" "$grp" "$gecos" || true
    fi
  done < "$exp/usuarios_linux.txt"

  # Restaurar hashes (shadow)
  log "Restaurando contraseñas Linux..."
  sudo cp "$exp/shadow_export.txt" /etc/shadow 2>/dev/null
  sudo chmod 600 /etc/shadow

  # Restaurar Samba (passdb)
  log "Restaurando passdb.tdb..."
  [[ -f "$exp/passdb.tdb" ]] && {
    sudo cp "$exp/passdb.tdb" /var/lib/samba/private/passdb.tdb
    sudo chmod 600 /var/lib/samba/private/passdb.tdb
    sudo systemctl restart smbd 2>/dev/null
  }

  log "✓ Importación completada"
  confirm "¿Rollback?" && { 
    rollback_linux "$bak"
    rollback_samba "$bak"
  }
}

importar_run
