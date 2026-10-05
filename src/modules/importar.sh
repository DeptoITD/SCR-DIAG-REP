#!/bin/bash
# importar.sh v0.7 — Importación Completa (Samba + Identidades Linux)

if [[ "$(type -t log)" != "function" ]]; then
  source "${REPO_PATH:-$(dirname "$0")/..}/config/servers.env" 2>/dev/null || source "$(dirname "$0")/../config/servers.env"
  source "${REPO_PATH:-$(dirname "$0")/..}/src/utils.sh" 2>/dev/null || source "$(dirname "$0")/../utils.sh"
fi

seleccionar_export() {
  echo "" >&2
  echo "📂 Carpetas: $EXPORT_PATH" >&2
  local exports=() path num i
  while IFS= read -r path; do
    [[ -d "$path" ]] && exports+=("$path")
  done < <(compgen -G "$EXPORT_PATH/export_*" | sort -r)
  [[ ${#exports[@]} -eq 0 ]] && { error "No hay exports"; return 1; }
  
  for i in "${!exports[@]}"; do
    local folder=$(basename "${exports[$i]}")
    echo "  $((i+1))) $folder" >&2
  done
  read -r -p "Elige [1-${#exports[@]}]: " num || return 1
  if [[ ! "$num" =~ ^[0-9]+$ ]] || (( 10#$num < 1 || 10#$num > ${#exports[@]} )); then
    error "Inválido"
    return 1
  fi
  num=$((10#$num))
  echo "${exports[$((num-1))]}"
}

analizar_migracion() {
  local export_dir="$1"
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Análisis Migración"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  
  local sid_origen=$(detectar_samba_sid "$export_dir/manifest.txt")
  local sid_destino=$(detectar_samba_sid)
  
  echo "  SID Origen:  ${sid_origen:-desconocido}"
  echo "  SID Destino: ${sid_destino:-desconocido}"
  [[ -n "$sid_origen" && -n "$sid_destino" && "$sid_origen" != "$sid_destino" ]] && echo "  ⚠️  (diferente, usaremos destino)"
  
  verificar_conflictos_uid_gid "$export_dir"
}

importar_usuarios_linux() {
  local export_dir="$1"
  [[ ! -f "$export_dir/usuarios_linux.txt" ]] && return 0
  
  echo "👥 Usuarios Linux..."
  cp /etc/passwd /tmp/backup_$$/passwd.bak 2>/dev/null
  cp /etc/group /tmp/backup_$$/group.bak 2>/dev/null
  
  local created=0 sync=0 ok=0
  while IFS=: read -r user _ uid gid gecos home shell; do
    [[ -z "$user" || "$user" =~ ^# ]] && continue
    
    if id "$user" &>/dev/null; then
      local current=$(id -u "$user" 2>/dev/null)
      if [[ "$current" == "$uid" ]]; then
        echo "  [OK] $user"
        ((ok++))
      else
        sudo usermod -u "$uid" "$user" 2>/dev/null
        echo "  [SYNC] $user"
        ((sync++))
      fi
    else
      sudo useradd -M -u "$uid" -g "$gid" -c "$gecos" -d /nonexistent -s /usr/sbin/nologin "$user" 2>/dev/null
      echo "  [CREATE] $user"
      ((created++))
    fi
  done < "$export_dir/usuarios_linux.txt"
  
  echo "  → $created creados, $sync sincronizados, $ok ok"
  echo ""
}

importar_grupos_linux() {
  local export_dir="$1"
  [[ ! -f "$export_dir/grupos_linux.txt" ]] && return 0
  
  echo "👥 Grupos Linux..."
  local created=0 ok=0
  
  while IFS=: read -r grupo _ gid _; do
    [[ -z "$grupo" || "$grupo" =~ ^# ]] && continue
    
    if getent group "$grupo" &>/dev/null; then
      echo "  [OK] $grupo"
      ok=$((ok+1))
    else
      sudo groupadd -g "$gid" "$grupo" 2>/dev/null || { echo "[!] No se pudo crear el grupo $grupo." >&2; return 1; }
      echo "  [CREATE] $grupo"
      created=$((created+1))
    fi
    registrar_grupo_catalogo "$grupo" || return 1
  done < "$export_dir/grupos_linux.txt"
  
  echo "  → $created creados, $ok ok"
  echo ""
}

importar_membresias() {
  local export_dir="$1"
  [[ ! -f "$export_dir/membresias.txt" ]] && return 0
  
  echo "👥 Membresías..."
  while IFS=: read -r grupo miembros; do
    [[ -z "$grupo" || "$grupo" =~ ^# ]] && continue
    [[ -n "$miembros" ]] && {
      IFS=',' read -ra users <<< "$miembros"
      for u in "${users[@]}"; do
        sudo gpasswd -a "$(echo $u | xargs)" "$grupo" 2>/dev/null
      done
      echo "  [SYNC] $grupo"
    }
  done < "$export_dir/membresias.txt"
  echo ""
}

importar_samba_hashes() {
  local export_dir="$1"
  [[ ! -f "$export_dir/passdb.tdb" ]] && return 0
  
  echo "🔒 Samba credenciales..."
  
  sudo cp /var/lib/samba/private/passdb.tdb /tmp/backup_$$/passdb.tdb.bak 2>/dev/null
  sudo cp "$export_dir/passdb.tdb" /var/lib/samba/private/passdb.tdb 2>/dev/null
  sudo chmod 600 /var/lib/samba/private/passdb.tdb
  
  sudo systemctl restart smbd 2>/dev/null
  echo "  ✅ Restaurado (SID destino preservado)"
  echo ""
}

opcion_secrets_tdb() {
  advertencia_secrets_tdb
  
  if confirm "¿Cambiar SID?"; then
    local export_dir="$1"
    [[ ! -f "$export_dir/secrets.tdb" ]] && return 1
    
    echo "⚠️  Cambiando SID..."
    sudo cp /var/lib/samba/private/secrets.tdb /tmp/backup_$$/secrets.tdb.bak 2>/dev/null
    sudo cp "$export_dir/secrets.tdb" /var/lib/samba/private/secrets.tdb 2>/dev/null
    sudo chmod 600 /var/lib/samba/private/secrets.tdb
    sudo systemctl restart smbd 2>/dev/null
    echo "⚠️  SID CAMBIADO"
    echo ""
  fi
}

importar_run() {
  require_root
  
  local export_dir seleccion
  export_dir=$(seleccionar_export) || return 1
  [[ -z "$export_dir" ]] && return 1
  
  mkdir -p /tmp/backup_$$
  analizar_migracion "$export_dir"
  
  seleccion=$(menu_seleccionar_importacion) || return 1
  [[ -z "$seleccion" ]] && return 1
  
  confirm "¿Aplicar?" || return 0

  [[ "$seleccion" =~ fstab ]] && comparar_fstab "$export_dir/fstab.txt"
  
  if [[ "$seleccion" =~ grupos ]]; then
    importar_grupos_linux "$export_dir" || return 1
  fi
  [[ "$seleccion" =~ usuarios ]] && importar_usuarios_linux "$export_dir"
  [[ "$seleccion" =~ membresias ]] && importar_membresias "$export_dir"
  [[ "$seleccion" =~ samba ]] && importar_samba_hashes "$export_dir"
  
  [[ "$seleccion" =~ samba ]] && [[ -f "$export_dir/secrets.tdb" ]] && opcion_secrets_tdb "$export_dir"
  
  echo "✅ Importación completada"
  rm -rf /tmp/backup_$$ 2>/dev/null
}
