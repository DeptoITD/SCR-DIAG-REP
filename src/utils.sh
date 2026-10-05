#!/bin/bash
# Funciones compartidas

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg"
  [[ -n "${LOG_FILE:-}" ]] && echo "$msg" >> "${LOG_FILE}"
}

error() {
  local msg="[ERROR] $1"
  echo "$msg" >&2
  [[ -n "${LOG_FILE:-}" ]] && echo "$msg" >> "${LOG_FILE}"
  exit 1
}

info() {
  local msg="[INFO] $1"
  echo "$msg"
  [[ -n "${LOG_FILE:-}" ]] && echo "$msg" >> "${LOG_FILE}"
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    cp "$file" "${file}.bak.$(date +%s)"
    info "Backup creado: ${file}.bak.$(date +%s)"
  fi
}

set_perms() {
  local path="$1"
  local user="$2"
  [[ -e "$path" ]] && sudo chown -R "$user:$user" "$path"
}

require_root() {
  [[ $(id -u) -eq 0 ]] || error "Este comando requiere privilegios root (sudo)."
}

generate_password() {
  # 16-char alnum, no ambiguous chars
  openssl rand -base64 16 2>/dev/null | tr -dc 'A-Za-z0-9' | head -c16 || \
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c16
}

mostrar_password_generada() {
  local user="$1" pass="$2"
  echo ""
  echo "########################################################"
  echo "#  USUARIO: $user"
  echo "#  PASSWORD (se muestra UNA sola vez, cópiela ahora):"
  echo "#     $pass"
  echo "########################################################"
  echo ""
}

confirm() {
  local prompt="$1" ans
  read -r -p "$prompt [s/N]: " ans
  [[ "$ans" =~ ^[sS]$ ]]
}

pause() {
  read -r -p "Presione Enter para continuar..." _
}

mostrar_instrucciones_transfer() {
  local export_dir="$1"
  local export_name=$(basename "$export_dir")
  local hostname=$(hostname -s)

  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║           EXPORTACIÓN COMPLETADA                              ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "📁 Carpeta generada:"
  echo "   $export_dir"
  echo ""
  echo "📋 Contenido:"
  ls -lh "$export_dir" | tail -n +2 | awk '{print "   " $9 " (" $5 ")"}'
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "SIGUIENTE: Copiar archivos a otro equipo"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "1️⃣  OPCIÓN A: SCP (si tienes acceso SSH a otro equipo)"
  echo "   Desde ESTE equipo, copia a otro:"
  echo ""
  echo "   scp -r '$export_dir' usuario@IP_OTRO_EQUIPO:/opt/scripts/SCR-DIAG-REP/src/export/"
  echo ""
  echo "   Ejemplo:"
  echo "   scp -r '$export_dir' soporte@192.168.1.50:/opt/scripts/SCR-DIAG-REP/src/export/"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "2️⃣  OPCIÓN B: Copia manual (USB, red compartida, etc.)"
  echo "   Copia la carpeta:"
  echo "   $export_dir"
  echo ""
  echo "   Pega en el otro equipo en:"
  echo "   /opt/scripts/SCR-DIAG-REP/src/export/"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "3️⃣  En el OTRO equipo, ejecuta:"
  echo ""
  echo "   cd /opt/scripts/SCR-DIAG-REP"
  echo "   sudo bash src/menu.sh"
  echo "   → Opción 3: Importar / replicar configuración"
  echo "   → Selecciona esta carpeta: $export_name"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# ============================================================================
# FUNCIONES PARA IMPORTACIÓN INTELIGENTE
# ============================================================================

# stdout contiene solo la selección; los menús se muestran por stderr.
seleccionar_registro() {
  local archivo="$1" titulo="$2" modo="${3:-uno}"
  local clave nombre resto entrada numero resultado="" item
  local claves=() numeros=()
  [[ -f "$archivo" ]] || { echo "[!] No existe: $archivo" >&2; return 1; }
  echo "=== $titulo ===" >&2
  while IFS='|' read -r clave nombre resto; do
    [[ -z "$clave" || "$clave" == \#* ]] && continue
    claves+=("$clave")
    printf '%s) %s — %s\n' "${#claves[@]}" "$clave" "$nombre" >&2
  done < "$archivo"
  ((${#claves[@]})) || { echo "[!] No hay registros disponibles" >&2; return 1; }
  [[ "$modo" == todos || "$modo" == varios ]] && echo 'T) Todos' >&2
  [[ "$modo" == varios ]] && echo 'N) Ninguno' >&2
  echo '0) Volver' >&2
  while true; do
    if [[ "$modo" == varios ]]; then
      read -r -p 'Seleccione números separados por coma, T o N: ' entrada || return 1
    else
      read -r -p 'Seleccione una opción: ' entrada || return 1
    fi
    [[ "$entrada" == 0 ]] && return 1
    if [[ "${entrada^^}" == T && "$modo" == todos ]]; then
      echo '__TODOS__'; return 0
    elif [[ "${entrada^^}" == T && "$modo" == varios ]]; then
      (IFS=,; echo "${claves[*]}"); return 0
    elif [[ "${entrada^^}" == N && "$modo" == varios ]]; then
      echo ''; return 0
    fi
    if [[ "$entrada" =~ ^[0-9]+(,[0-9]+)*$ && ( "$modo" == varios || "$entrada" != *,* ) ]]; then
      IFS=, read -ra numeros <<< "$entrada"
      resultado=""
      for numero in "${numeros[@]}"; do
        # Limitar longitud antes de evaluar números ingresados.
        [[ ${#numero} -le 9 ]] || { resultado=""; break; }
        numero=$((10#$numero))
        ((numero >= 1 && numero <= ${#claves[@]})) || { resultado=""; break; }
        item="${claves[$((numero-1))]}"
        [[ ",$resultado," == *",$item,"* ]] || resultado="${resultado:+$resultado,}$item"
      done
      [[ -n "$resultado" ]] && { echo "$resultado"; return 0; }
    fi
    echo '[!] Opción inválida. Elija una de las opciones mostradas.' >&2
  done
}

validar_ruta() {
  local ruta="$1"
  [[ -z "$ruta" ]] && { error "Ruta requerida"; return 1; }
  [[ ! -d "$ruta" ]] && { error "Ruta no existe: $ruta"; return 1; }
  findmnt -T "$ruta" >/dev/null 2>&1 || { error "Ruta no está montada o accesible: $ruta"; return 1; }
  return 0
}

analizar_smb_conf() {
  local archivo="$1"
  [[ ! -f "$archivo" ]] && { error "Archivo no encontrado: $archivo"; return 1; }

  echo "═══════════════════════════════════════════════════════"
  echo "  Análisis smb.conf — Políticas Portables"
  echo "═══════════════════════════════════════════════════════"
  echo ""

  echo "[GLOBAL] — Configuración de seguridad (PORTABLE):"
  grep -E "^\s*(security|acl_xattr|hide unreadable|follow symlinks|unix extensions|smb encrypt)" "$archivo" 2>/dev/null | sed 's/^/  /'

  echo ""
  echo "[SHARES] — Definidas en archivo:"
  grep -E "^\[.*\]" "$archivo" 2>/dev/null | grep -v "^\[global\]" | grep -v "^\[IPC\$\]" | sed 's/^/  /'

  echo ""
  echo "⚠️  IMPORTANTE:"
  echo "  - path, netbios name, server string: NO son portables"
  echo "  - valid users: se configurará interactivamente"
  echo ""
}

sincronizar_usuario() {
  local user="$1" expected_grupo="$2" expected_extra="$3"
  local actual_grupo actual_extra

  if ! id "$user" &>/dev/null; then
    echo "CREATE"
    return 0
  fi

  actual_grupo=$(id -gn "$user" 2>/dev/null)
  actual_extra=$(id -Gn "$user" 2>/dev/null | sed "s/.*$actual_grupo//")

  if [[ "$actual_grupo" == "$expected_grupo" ]] && [[ "$actual_extra" == "$expected_extra" || -z "$expected_extra" ]]; then
    echo "OK"
  else
    echo "SYNC"
  fi
}

comparar_fstab() {
  local fstab_export="$1"
  [[ ! -f "$fstab_export" ]] && return 1

  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Comparación /etc/fstab"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "📁 Sistema ACTUAL (/etc/fstab):"
  grep -v "^#" /etc/fstab 2>/dev/null | grep -v "^$" | head -5
  echo ""
  echo "📁 Sistema ORIGEN (fstab.txt):"
  grep -v "^#" "$fstab_export" 2>/dev/null | grep -v "^$" | head -5
  echo ""
  echo "⚠️  REFERENCIA SOLO. /etc/fstab NO se modificará automáticamente."
  echo ""
}

menu_seleccionar_importacion() {
  local opt
  {
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  ¿QUÉ DESEAS IMPORTAR?"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "1) Solo USUARIOS (crear nuevos, sincronizar UID de existentes)"
  echo "2) USUARIOS + GRUPOS (crear grupos faltantes)"
  echo "3) USUARIOS + GRUPOS + MEMBRESÍAS"
  echo "4) TODO ANTERIOR + CREDENCIALES SAMBA (passdb.tdb)"
  echo "5) TODO (incluyendo fstab como referencia)"
  echo "6) PERSONALIZADO (elige qué elemento)"
  echo ""
  } >&2
  read -r -p "Selecciona [1-6]: " opt || return 1

  case "$opt" in
    1) echo "usuarios" ;;
    2) echo "usuarios,grupos" ;;
    3) echo "usuarios,grupos,membresias" ;;
    4) echo "usuarios,grupos,membresias,samba" ;;
    5) echo "usuarios,grupos,membresias,samba,fstab" ;;
    6) menu_personalizado ;;
    *) error "Opción inválida"; return 1 ;;
  esac
}

menu_personalizado() {
  local seleccion=""
  echo "" >&2
  echo "Marca qué importar (SÍ/NO):" >&2

  confirm "¿Importar USUARIOS?" && seleccion="${seleccion}usuarios,"
  confirm "¿Importar GRUPOS?" && seleccion="${seleccion}grupos,"
  confirm "¿Importar MEMBRESÍAS de grupos?" && seleccion="${seleccion}membresias,"
  confirm "¿Importar CREDENCIALES SAMBA (passdb.tdb)?" && seleccion="${seleccion}samba,"
  confirm "¿Mostrar FSTAB como referencia?" && seleccion="${seleccion}fstab,"

  echo "${seleccion%,}"
}

# ============================================================================
# FUNCIONES PARA MIGRACIÓN SAMBA COMPLETA
# ============================================================================

detectar_samba_sid() {
  local source="${1:-}" output sid
  if [[ -n "$source" ]]; then
    output=$(sed -n 's/^samba_sid=//p' "$source" 2>/dev/null)
  else
    if ! command -v net >/dev/null 2>&1; then
      echo "[AVISO] No se puede leer el SID local: falta el comando net de Samba." >&2
      return 1
    fi
    output=$(net getlocalsid 2>/dev/null) || {
      echo "[AVISO] net getlocalsid no pudo consultar el SID local de Samba." >&2
      return 1
    }
  fi
  sid=$(printf '%s\n' "$output" | grep -oE 'S-1-5-21(-[0-9]+){3}' | head -n 1)
  [[ -n "$sid" ]] || {
    [[ -n "$source" ]] && echo "[AVISO] El manifiesto no contiene un samba_sid válido: $source. Genera una nueva exportación en el origen." >&2
    return 1
  }
  printf '%s\n' "$sid"
}

verificar_conflictos_uid_gid() {
  local export_dir="$1"
  [[ ! -f "$export_dir/usuarios_linux.txt" ]] && return 0

  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Verificación de Conflictos UID/GID"
  echo "═══════════════════════════════════════════════════════"
  echo ""

  local conflictos=0
  while IFS=: read -r user _ uid gid _; do
    [[ -z "$user" ]] && continue
    if getent passwd "$uid" &>/dev/null; then
      local owner=$(getent passwd "$uid" | cut -d: -f1)
      if [[ "$owner" != "$user" ]]; then
        echo "  ⚠️  UID $uid en uso por: $owner (origen: $user)"
        ((conflictos++))
      fi
    fi
  done < "$export_dir/usuarios_linux.txt"

  [[ $conflictos -eq 0 ]] && echo "  ✅ Sin conflictos UID/GID"
  echo ""
  return $conflictos
}

rollback_linux() {
  local backup_dir="${1:-}"
  echo ""
  echo "⚠️  ROLLBACK — Restaurando identidades Linux..."
  [[ -f "$backup_dir/passwd.bak" ]] && { sudo cp "$backup_dir/passwd.bak" /etc/passwd; info "✓ passwd"; }
  [[ -f "$backup_dir/group.bak" ]] && { sudo cp "$backup_dir/group.bak" /etc/group; info "✓ group"; }
  echo ""
}

rollback_samba() {
  local backup_dir="${1:-}"
  echo ""
  echo "⚠️  ROLLBACK — Restaurando Samba..."
  [[ -f "$backup_dir/passdb.tdb.bak" ]] && { sudo cp "$backup_dir/passdb.tdb.bak" /var/lib/samba/private/passdb.tdb; info "✓ passdb.tdb"; }
  sudo systemctl restart smbd 2>/dev/null
  echo ""
}

advertencia_secrets_tdb() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  ⚠️  ADVERTENCIA: CAMBIO DE SID (NO RECOMENDADO)          ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "secrets.tdb contiene SID ÚNICO de máquina."
  echo "Importarlo ROMPE: dominios, réplica, relaciones de confianza."
  echo ""
  echo "✅ RECOMENDADO: Restaurar solo hashes (passdb.tdb)"
  echo "🔴 RIESGO: Importar secrets.tdb solo si SEGURO qué haces"
  echo ""
}
