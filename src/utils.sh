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
  echo "   bash menu.sh"
  echo "   → Opción 3: Importar / replicar configuración"
  echo "   → Selecciona esta carpeta: $export_name"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# ============================================================================
# FUNCIONES PARA IMPORTACIÓN INTELIGENTE
# ============================================================================

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
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  ¿QUÉ DESEAS IMPORTAR?"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "1) Solo USUARIOS (crear nuevos, dejar existentes)"
  echo "2) USUARIOS + GRUPOS (crear/actualizar)"
  echo "3) USUARIOS + GRUPOS + MEMBRESÍAS"
  echo "4) TODO ANTERIOR + CONFIG SAMBA"
  echo "5) TODO (incluyendo fstab como referencia)"
  echo "6) PERSONALIZADO (elige qué elemento)"
  echo ""
  read -r -p "Selecciona [1-6]: " opt

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
  echo ""
  echo "Marca qué importar (SÍ/NO):"

  confirm "¿Importar USUARIOS?" && seleccion="${seleccion}usuarios,"
  confirm "¿Importar GRUPOS?" && seleccion="${seleccion}grupos,"
  confirm "¿Importar MEMBRESÍAS de grupos?" && seleccion="${seleccion}membresias,"
  confirm "¿Importar CONFIG SAMBA?" && seleccion="${seleccion}samba,"
  confirm "¿Mostrar FSTAB como referencia?" && seleccion="${seleccion}fstab,"

  echo "${seleccion%,}"
}

# ============================================================================
# FUNCIONES PARA MIGRACIÓN SAMBA COMPLETA
# ============================================================================

detectar_samba_sid() {
  local source="${1:-}"
  if [[ -n "$source" ]]; then
    grep "samba_sid=" "$source" 2>/dev/null | cut -d= -f2
  else
    pdbedit -P -v 2>/dev/null | grep "Machine SID" | awk '{print $NF}'
  fi
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
