#!/bin/bash
# importar.sh v0.7 — Importación Completa (Samba + Identidades Linux)

if [[ "$(type -t log)" != function ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/iniciar.sh" || return 1
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
    case "$user" in soporte) echo "[CONSERVAR] $user"; continue ;; esac
    grupo=$(awk -F: -v gid="$gid" '$3 == gid {print $1; exit}' "$export_dir/grupos_linux.txt")
    [[ -n "$grupo" ]] || { echo "[!] Falta el grupo primario de $user." >&2; return 1; }
    registro=$(getent group "$grupo") || { echo "[!] Falta $grupo en el destino." >&2; return 1; }
    IFS=: read -r _ _ gid _ <<< "$registro"
    if id "$user" >/dev/null 2>&1; then
      actual=$(id -u "$user") || return 1
      [[ "$actual" == "$uid" ]] || { echo "[!] $user tiene UID $actual; no se cambiará automáticamente a $uid." >&2; return 1; }
      sudo usermod -g "$grupo" -c "$nombre" "$user" || return 1
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
      if getent group "$gid" >/dev/null; then
        sudo groupadd "$grupo" || return 1
      else sudo groupadd -g "$gid" "$grupo" || return 1; fi
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
      case "$u" in soporte) continue ;; esac
      sudo gpasswd -a "$u" "$grupo" || return 1
      registrar_usuario_catalogo "$u" || return 1
    done
  done < "$export_dir/membresias.txt"
}

validar_export_importacion() {
  local dir="$1" usuario uid lm hash flags resto registro gid cred_uid
  for registro in usuarios_linux.txt grupos_linux.txt membresias.txt credenciales_samba.txt; do
    [[ -f "$dir/$registro" ]] || { echo "[!] Falta $registro; genera una exportación actual." >&2; return 1; }
  done
  awk -F: 'NF!=7 || $3 !~ /^[0-9]+$/ || $4 !~ /^[0-9]+$/ || vistos[$1]++ {error=1} END {exit error}' "$dir/usuarios_linux.txt" || { echo '[!] Identidades Linux inválidas.' >&2; return 1; }
  validar_credenciales_samba "$dir/credenciales_samba.txt" || return 1
  # Las exportaciones antiguas/incompletas no pueden importar identidades sin clave.
  awk -F: '
    FILENAME==ARGV[1] { if($1!="soporte") samba[$1]=1; next }
    $3>=1000 && $3<65534 && $1!="soporte" && !($1 in samba) {
      print "[!] Cuenta Linux sin credencial Samba: " $1 > "/dev/stderr"; error=1
    }
    END {exit error}
  ' "$dir/credenciales_samba.txt" "$dir/usuarios_linux.txt" || return 1
  while IFS=: read -r usuario uid lm hash flags resto; do
    [[ "$usuario" != soporte ]] || continue
    registro=$(awk -F: -v u="$usuario" '$1==u {print;exit}' "$dir/usuarios_linux.txt")
    [[ -n "$registro" ]] || { echo "[!] Falta identidad Linux: $usuario" >&2; return 1; }
    cred_uid="$uid"
    IFS=: read -r _ _ uid gid _ <<< "$registro"
    [[ "$cred_uid" == "$uid" ]] || { echo "[!] UID Samba/Linux distinto en origen: $usuario" >&2; return 1; }
    [[ "$uid" =~ ^[0-9]+$ ]] && ((uid>=1000 && uid<65534)) || return 1
    awk -F: -v g="$gid" '$3==g {found=1} END {exit !found}' "$dir/grupos_linux.txt" || return 1
    if [[ "$flags" == *D* || "$flags" == *L* ]]; then
      echo "[!] Cuenta bloqueada/deshabilitada en origen: $usuario" >&2; return 1
    fi
    if id "$usuario" >/dev/null 2>&1 && [[ "$(id -u "$usuario")" != "$uid" ]]; then
      echo "[!] UID distinto para $usuario; resuelve el conflicto antes de importar." >&2; return 1
    fi
  done < "$dir/credenciales_samba.txt"
}

importar_samba_hashes() {
  local dir="$1" usuario uid lm hash flags resto
  local entrada="$BACKUP_IMPORTACION/credenciales-importar.txt"
  (umask 077; awk -F: '$1!="soporte"' "$dir/credenciales_samba.txt" > "$entrada") || return 1
  pdbedit -e "tdbsam:$BACKUP_IMPORTACION/cuentas-antes.tdb" > "$BACKUP_IMPORTACION/respaldo-samba.log" 2>&1 || return 1
  # Se incorporan las cuentas del origen; las exclusivas del destino se conservan.
  if [[ -s "$entrada" ]]; then
    pdbedit -i "smbpasswd:$entrada" > "$BACKUP_IMPORTACION/importacion-samba.log" 2>&1 || {
      echo '[!] Falló Samba; puede existir una importación parcial. Respaldo conservado.' >&2; return 1;
    }
  fi
  while IFS=: read -r usuario uid lm hash flags resto; do
    pdbedit -u "$usuario" -c '[X]' >/dev/null || return 1
    verificar_hash_samba "$usuario" "$hash" || { echo "[!] Credencial no verificada: $usuario" >&2; return 1; }
    echo "[VERIFICADO] $usuario: contraseña del origen, sin vencimiento."
  done < "$entrada"
}
importar_run() {
  require_root
  local export_dir seleccion BACKUP_IMPORTACION
  export_dir="${1:-}"
  if [[ -z "$export_dir" ]]; then export_dir=$(seleccionar_export) || return 1; fi
  [[ -d "$export_dir" && -f "$export_dir/manifest.txt" ]] || { echo "[!] Carpeta de exportación inválida." >&2; return 1; }
  validar_export_importacion "$export_dir" || return 1
  analizar_migracion "$export_dir" || { echo '[!] Corrige los conflictos antes de importar.' >&2; return 1; }
  seleccion="usuarios,grupos,membresias,samba"
  echo "Se incorporan identidades, grupos y credenciales del origen. Se conservan las cuentas exclusivas del destino y su SID."
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

  fi
  echo 'Importación completada. Los respaldos no se eliminan.'
}
