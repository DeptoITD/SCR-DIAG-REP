#!/bin/bash
# =============================================================================
# Script: habilitar_ssh.sh
# Descripción: Instala SSH, habilita autenticación por contraseña y
#              restringe acceso SSH solo a los usuarios: soporte, sara y juan
# Uso: sudo bash habilitar_ssh.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error(){ echo -e "${RED}[ERR]${NC}  $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }

if [[ $EUID -ne 0 ]]; then
    error "Ejecutar como root: sudo bash $0"
    exit 1
fi

# Usuarios que tendrán acceso SSH
SSH_USERS=(
    "soporte"
    "sara.albarracin"
    "juan.rojas"
)

echo ""
info "======================================================"
info "  Configuración SSH - Acceso por contraseña"
info "======================================================"
echo ""

# =============================================================================
# 1. INSTALAR OPENSSH SI NO ESTÁ
# =============================================================================
info "--- Verificando OpenSSH Server ---"
if dpkg -l | grep -q openssh-server; then
    log "openssh-server ya está instalado."
else
    info "Instalando openssh-server..."
    apt-get update -qq
    apt-get install -y openssh-server
    log "openssh-server instalado."
fi

# =============================================================================
# 2. BACKUP DEL sshd_config ORIGINAL
# =============================================================================
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)"

info "--- Haciendo backup de sshd_config ---"
cp "$SSHD_CONFIG" "$BACKUP"
log "Backup guardado en: $BACKUP"

# =============================================================================
# 3. CONFIGURAR sshd_config
# =============================================================================
info "--- Aplicando configuración SSH ---"

# Función para agregar o reemplazar una directiva en sshd_config
set_sshd_option() {
    local key="$1"
    local value="$2"
    if grep -qE "^#?${key}\s" "$SSHD_CONFIG"; then
        sed -i "s|^#\?${key}\s.*|${key} ${value}|" "$SSHD_CONFIG"
    else
        echo "${key} ${value}" >> "$SSHD_CONFIG"
    fi
}

# Habilitar autenticación por contraseña
set_sshd_option "PasswordAuthentication" "yes"

# Deshabilitar login directo como root por SSH
set_sshd_option "PermitRootLogin" "no"

# Deshabilitar autenticación por contraseña vacía
set_sshd_option "PermitEmptyPasswords" "no"

# Puerto estándar
set_sshd_option "Port" "22"

# Protocolo seguro
set_sshd_option "Protocol" "2"

# Tiempo máximo de espera para login
set_sshd_option "LoginGraceTime" "60"

# Intentos máximos de contraseña
set_sshd_option "MaxAuthTries" "4"

# Restringir acceso SOLO a los usuarios autorizados
# Primero quitar cualquier AllowUsers previo
sed -i '/^AllowUsers/d' "$SSHD_CONFIG"

# Armar la línea AllowUsers
ALLOW_LINE="AllowUsers"
for u in "${SSH_USERS[@]}"; do
    # Verificar que el usuario existe antes de agregarlo
    if id "$u" > /dev/null 2>&1; then
        ALLOW_LINE="$ALLOW_LINE $u"
        log "  Usuario '$u' agregado a AllowUsers."
    else
        warn "  Usuario '$u' NO existe en el sistema, se omite de AllowUsers."
    fi
done

echo "$ALLOW_LINE" >> "$SSHD_CONFIG"
log "AllowUsers configurado: $ALLOW_LINE"

# =============================================================================
# 4. VERIFICAR CONFIGURACIÓN
# =============================================================================
info "--- Verificando sintaxis de sshd_config ---"
if sshd -t; then
    log "Configuración válida."
else
    error "Error en sshd_config. Restaurando backup..."
    cp "$BACKUP" "$SSHD_CONFIG"
    error "Backup restaurado. Revisa el archivo manualmente."
    exit 1
fi

# =============================================================================
# 5. HABILITAR Y REINICIAR SSH
# =============================================================================
info "--- Habilitando y reiniciando SSH ---"
systemctl enable ssh
systemctl restart ssh

if systemctl is-active --quiet ssh; then
    log "SSH corriendo correctamente."
else
    error "SSH no pudo iniciar. Revisa: journalctl -xe"
    exit 1
fi

# =============================================================================
# 6. FIREWALL (si ufw está activo)
# =============================================================================
info "--- Verificando firewall (ufw) ---"
if command -v ufw > /dev/null 2>&1; then
    UFW_STATUS=$(ufw status | head -1)
    if echo "$UFW_STATUS" | grep -q "active"; then
        ufw allow 22/tcp comment "SSH Indesco"
        log "Regla SSH agregada a ufw."
    else
        warn "ufw instalado pero inactivo, no se modificó."
    fi
else
    warn "ufw no encontrado, verifica tu firewall manualmente si tienes uno."
fi

# =============================================================================
# 7. RESUMEN
# =============================================================================
echo ""
info "======================================================"
info "  RESUMEN"
info "======================================================"
echo ""
echo -e "${BLUE}SSH Status:${NC}     $(systemctl is-active ssh)"
echo -e "${BLUE}Puerto:${NC}         22"
echo -e "${BLUE}Auth:${NC}           Contraseña"
echo -e "${BLUE}Root login:${NC}     Deshabilitado"
echo ""
echo -e "${BLUE}Usuarios con acceso SSH:${NC}"
for u in "${SSH_USERS[@]}"; do
    if id "$u" > /dev/null 2>&1; then
        echo "  - $u"
    else
        echo -e "  - $u ${RED}(no existe en el sistema)${NC}"
    fi
done
echo ""
echo -e "${BLUE}Para conectarse desde Windows:${NC}"
echo "  ssh soporte@<IP-DEL-SERVIDOR>"
echo "  ssh sara.albarracin@grupoindesco.com@<IP-DEL-SERVIDOR>"
echo "  ssh juan.rojas@grupoindesco.com@<IP-DEL-SERVIDOR>"
echo ""
info "Script finalizado."
echo ""
