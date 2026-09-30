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
