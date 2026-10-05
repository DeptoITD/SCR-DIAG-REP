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
  local export_dir="$1" user uid gid nombre home shell grupo registro actual
  local creados=0 existentes=0
  [[ -f "$export_dir/usuarios_linux.txt" ]] || return 0
  [[ -f "$export_dir/grupos_linux.txt" ]] || { echo '[!] Faltan los grupos del origen.' >&2; return 1; }
  while IFS=: read -r user _ uid gid nombre home shell; do
    [[ "$uid" =~ ^[0-9]+$ ]] && ((uid >= 1000 && uid < 65534)) || continue
    case "$user" in soporte|sara.albarracin|juan.rojas) echo "[CONSERVAR] $user"; continue ;; esac
    grupo=$(awk -F: -v gid="$gid" '$3 == gid {print $1; exit}' "$export_dir/grupos_linux.txt")
    [[ -n "$grupo" ]] || { echo "[!] Falta el grupo primario de $user." >&2; return 1; }
    registro=$(getent group "$grupo") || { echo "[!] Falta $grupo en el destino." >&2; return 1; }
    IFS=: read -r _ _ gid _ <<< "$registro"
    if id "$user" >/dev/null 2>&1; then
      actual=$(id -u "$user") || return 1
      [[ "$actual" == "$uid" ]] || { echo "[!] $user tiene UID $actual; no se cambiará automáticamente a $uid." >&2; return 1; }
      existentes=$((existentes+1))
    else
      sudo useradd -M -u "$uid" -g "$gid" -c "$nombre" -d /nonexistent -s /usr/sbin/nologin "$user" || return 1
      creados=$((creados+1))
    fi
    registrar_usuario_catalogo "$user" || return 1
  done < "$export_dir/usuarios_linux.txt"
  echo "Usuarios: $creados creados, $existentes existentes."
}

importar_grupos_linux() {
  local export_dir="$1" grupo gid registro
  [[ -f "$export_dir/grupos_linux.txt" ]] || return 0
  while IFS=: read -r grupo _ gid _; do
    [[ -z "$grupo" || "$grupo" == \#* ]] && continue
    [[ "$gid" =~ ^[0-9]+$ ]] || return 1
    if ! es_grupo_trabajo "$grupo" && ((gid < 1000 || gid >= 65534)); then continue; fi
    if ! getent group "$grupo" >/dev/null; then
      sudo groupadd -g "$gid" "$grupo" || return 1
    fi
    if es_grupo_trabajo "$grupo"; then
      asegurar_grupo_samba "$grupo" || return 1
      registrar_grupo_catalogo "$grupo" || return 1
    fi
  done < "$export_dir/grupos_linux.txt"
}

importar_membresias() {
  local export_dir="$1" grupo miembros u
  local -a users
  [[ -f "$export_dir/membresias.txt" ]] || return 0
  while IFS=: read -r grupo miembros; do
    es_grupo_trabajo "$grupo" || continue
    IFS=, read -ra users <<< "$miembros"
    for u in "${users[@]}"; do
      u="${u#"${u%%[![:space:]]*}"}"; u="${u%"${u##*[![:space:]]}"}"
      [[ -n "$u" ]] || continue
      case "$u" in soporte|sara.albarracin|juan.rojas) continue ;; esac
      sudo gpasswd -a "$u" "$grupo" || return 1
      registrar_usuario_catalogo "$u" || return 1
    done
  done < "$export_dir/membresias.txt"
}

restaurar_base_samba() {
  local origen="$1" destino="$2" nombre
  nombre=$(basename "$destino")
  [[ -f "$destino" ]] || { echo "[!] No existe $destino; revisa la ruta Samba." >&2; return 1; }
  sudo cp -p "$destino" "$BACKUP_IMPORTACION/$nombre.bak" || return 1
  sudo systemctl stop smbd || return 1
  if ! sudo cp "$origen" "$destino" || ! sudo chmod 600 "$destino" || ! sudo systemctl start smbd; then
    echo "[!] Falló $nombre; restaurando el respaldo conservado." >&2
    sudo cp -p "$BACKUP_IMPORTACION/$nombre.bak" "$destino" || return 1
    sudo systemctl start smbd || return 1
    return 1
  fi
}

importar_samba_hashes() {
  [[ -f "$1/passdb.tdb" ]] || return 0
  restaurar_base_samba "$1/passdb.tdb" /var/lib/samba/private/passdb.tdb || return 1
  echo 'Base Samba restaurada; no se reemplazó secrets.tdb.'
}

opcion_secrets_tdb() {
  advertencia_secrets_tdb
  if confirm '¿Cambiar SID?'; then
    [[ -f "$1/secrets.tdb" ]] || return 1
    restaurar_base_samba "$1/secrets.tdb" /var/lib/samba/private/secrets.tdb || return 1
    echo 'SID cambiado: comprueba los vínculos Samba del destino.'
  fi
  return 0
}

importar_run() {
  require_root
  local export_dir seleccion BACKUP_IMPORTACION
  export_dir=$(seleccionar_export) || return 1
  analizar_migracion "$export_dir" || { echo '[!] Corrige los conflictos antes de importar.' >&2; return 1; }
  seleccion=$(menu_seleccionar_importacion) || return 1
  [[ -n "$seleccion" ]] || return 1
  confirm '¿Aplicar?' || return 0
  mkdir -p "${LOG_DIR:-$REPO_PATH/logs}" || return 1
  BACKUP_IMPORTACION=$(mktemp -d "${LOG_DIR:-$REPO_PATH/logs}/importacion.XXXXXX") || return 1
  chmod 700 "$BACKUP_IMPORTACION" || return 1
  echo "Respaldos conservados: $BACKUP_IMPORTACION"
  cp -p /etc/passwd "$BACKUP_IMPORTACION/passwd.bak" || return 1
  cp -p /etc/group "$BACKUP_IMPORTACION/group.bak" || return 1
  if [[ -f "$DATA_DIR/usuarios.db" ]]; then cp -p "$DATA_DIR/usuarios.db" "$BACKUP_IMPORTACION/usuarios.db" || return 1; fi
  if [[ -f "$DATA_DIR/equipos.db" ]]; then cp -p "$DATA_DIR/equipos.db" "$BACKUP_IMPORTACION/equipos.db" || return 1; fi
  if [[ "$seleccion" == *fstab* ]]; then comparar_fstab "$export_dir/fstab.txt" || return 1; fi
  if [[ "$seleccion" == *grupos* ]]; then importar_grupos_linux "$export_dir" || return 1; fi
  if [[ "$seleccion" == *usuarios* ]]; then importar_usuarios_linux "$export_dir" || return 1; fi
  if [[ "$seleccion" == *membresias* ]]; then importar_membresias "$export_dir" || return 1; fi
  if [[ "$seleccion" == *samba* ]]; then
    importar_samba_hashes "$export_dir" || return 1
    if [[ -f "$export_dir/secrets.tdb" ]]; then opcion_secrets_tdb "$export_dir" || return 1; fi
  fi
  echo 'Importación completada. Los respaldos no se eliminan.'
}
