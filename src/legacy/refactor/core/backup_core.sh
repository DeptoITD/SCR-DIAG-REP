#!/bin/bash
# core/backup_core.sh — Primitivas backups/rollback

source "$(dirname "$0")/comun.sh"

backup_critico() {
  require_root

  local ts=$(date +%s)
  local bak_dir="/tmp/backup_diag_${ts}"

  mkdir -p "$bak_dir"

  sudo cp /etc/passwd "$bak_dir/passwd.bak" || true
  sudo cp /etc/shadow "$bak_dir/shadow.bak" || true
  sudo cp /etc/group "$bak_dir/group.bak" || true
  sudo cp /etc/gshadow "$bak_dir/gshadow.bak" || true
  sudo cp /var/lib/samba/private/passdb.tdb "$bak_dir/passdb.tdb.bak" 2>/dev/null || true

  echo "$bak_dir"
}

rollback_linux() {
  local bak_dir="$1"

  require_root
  [[ ! -d "$bak_dir" ]] && error "Backup no existe: $bak_dir"

  [[ -f "$bak_dir/passwd.bak" ]] && sudo cp "$bak_dir/passwd.bak" /etc/passwd
  [[ -f "$bak_dir/shadow.bak" ]] && sudo cp "$bak_dir/shadow.bak" /etc/shadow
  [[ -f "$bak_dir/group.bak" ]] && sudo cp "$bak_dir/group.bak" /etc/group
  [[ -f "$bak_dir/gshadow.bak" ]] && sudo cp "$bak_dir/gshadow.bak" /etc/gshadow

  info "✓ Linux rollback completado"
}

rollback_samba() {
  local bak_dir="$1"

  require_root
  [[ ! -d "$bak_dir" ]] && error "Backup no existe: $bak_dir"

  [[ -f "$bak_dir/passdb.tdb.bak" ]] && {
    sudo cp "$bak_dir/passdb.tdb.bak" /var/lib/samba/private/passdb.tdb
    sudo systemctl restart smbd 2>/dev/null
  }

  info "✓ Samba rollback completado"
}
