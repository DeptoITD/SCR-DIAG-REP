#!/bin/bash
# =============================================================================
# Script: registrar_samba_usuarios_v2.sh
# Descripción: Registra los 24 usuarios en Samba con smbpasswd.
#              Grupos: IND_PMO, IND_ARQ, IND_BIM, IND_GEO, IND_EST, IND_ITD
# Uso: sudo bash ~/Downloads/registrar_samba_usuarios_v2.sh 2>&1 | tee /tmp/resultado_samba.log
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

if ! command -v smbpasswd > /dev/null 2>&1; then
    error "smbpasswd no encontrado. Instala Samba: sudo apt-get install -y samba"
    exit 1
fi

echo ""
info "======================================================"
info "  Registro de usuarios en Samba - Grupo Indesco v2"
info "======================================================"
echo ""

# =============================================================================
# FUNCIÓN
# =============================================================================
registrar_smb() {
    local username="$1"
    local password="$2"
    local grupo="$3"

    if ! id "$username" > /dev/null 2>&1; then
        warn "  '$username' no existe en Linux, se omite."
        return
    fi

    # Registrar con smbpasswd (-s = sin prompt, -a = agregar)
    printf '%s\n%s\n' "$password" "$password" | smbpasswd -s -a "$username" > /dev/null 2>&1
    smbpasswd -e "$username" > /dev/null 2>&1

    log "  $username ($grupo) → OK"
}

# =============================================================================
# IND_PMO — visor de todo, solo lectura
# =============================================================================
info "--- IND_PMO (visor) ---"
registrar_smb "jhonatan.rojas" "Tq9@Lm#2!"  "IND_PMO"
registrar_smb "camilo.tibana"  "vR7\$Xp&4*" "IND_PMO"
echo ""

# =============================================================================
# IND_ARQ — rwx en: A_ARQ, O_LEV, YAC_ACU, YPA_PAT, YPM_PTR, YSE_SEN, YSH_SGH
# =============================================================================
info "--- IND_ARQ (Arquitectura) ---"
registrar_smb "jeisson.suarez"   "Nf3!Za@8%"  "IND_ARQ"
registrar_smb "carlos.acero"     "kL5#Yu\$1&" "IND_ARQ"
registrar_smb "anderson.higuera" "Pw8@Er!6*"  "IND_ARQ"
registrar_smb "melissa.rubiano"  "dX2&Qm#9!"  "IND_ARQ"
registrar_smb "ana.diaz"         "Hj4\$Bn@7%" "IND_ARQ"
echo ""

# =============================================================================
# IND_BIM — rwx en todo 01_WIP
# =============================================================================
info "--- IND_BIM (BIM - full control WIP) ---"
registrar_smb "andres.rincon"       "rT6!Vc#3&"  "IND_BIM"
registrar_smb "sebastian.rodriguez" "Mz1@Ks\$8*" "IND_BIM"
registrar_smb "maria.castro"        "qW9#Lp!5%"  "IND_BIM"
registrar_smb "jonathan.arevalo"    "Ya7&Nd@2!"  "IND_BIM"
registrar_smb "juliand.gonzalez"    "cF3\$Rt#6*" "IND_BIM"
registrar_smb "valentina.soto"      "Uv8!Gh@4%"  "IND_BIM"
echo ""

# =============================================================================
# IND_GEO — rwx en: YTP_TOP, A_ARQ, O_LEV, YAC_ACU, YPA_PAT, YPM_PTR, YSE_SEN, YSH_SGH, E_EST
# =============================================================================
info "--- IND_GEO (Topografía) ---"
registrar_smb "alejandra.pinza" "Gt4@Wp#7!"  "IND_GEO"
registrar_smb "jhon.acevedo"    "xN8\$Qa&2*" "IND_GEO"
echo ""

# =============================================================================
# IND_EST — rwx en: E_EST, O_LEV
# =============================================================================
info "--- IND_EST (Estructuras) ---"
registrar_smb "santiago.gomez"   "Bm1!Zv@9%"  "IND_EST"
registrar_smb "miguel.rojas"     "rK6#Ty\$3&" "IND_EST"
registrar_smb "laura.tibata"     "Hu5@Lc!8*"  "IND_EST"
registrar_smb "tatiana.porras"   "pD2&Fs#4!"  "IND_EST"
registrar_smb "cristian.cordero" "Yw7\$Jn@1%" "IND_EST"
registrar_smb "sebastian.pineda" "cR9!Xe#6&"  "IND_EST"
registrar_smb "david.vargas"     "Va3@Mk\$5*" "IND_EST"
echo ""

# =============================================================================
# IND_ITD — rwx en todo 01_WIP (lectura y escritura toda la estructura)
# =============================================================================
info "--- IND_ITD (ITD) ---"
registrar_smb "sara.albarracin" "Ind3\$c024*" "IND_ITD"
registrar_smb "juan.rojas"      "Ind3\$c024*" "IND_ITD"
echo ""

# =============================================================================
# SOPORTE — superadmin, contraseña manual
# =============================================================================
info "--- soporte (superadmin) ---"
if id "soporte" > /dev/null 2>&1; then
    warn "Configura la contraseña Samba de soporte manualmente:"
    echo "  sudo smbpasswd -a soporte"
else
    warn "Usuario 'soporte' no existe en Linux."
fi
echo ""

# =============================================================================
# RESUMEN
# =============================================================================
info "======================================================"
info "  RESUMEN"
info "======================================================"
echo ""
TOTAL=$(pdbedit -L 2>/dev/null | wc -l)
info "Total usuarios registrados en Samba: $TOTAL / 24"
echo ""
pdbedit -L 2>/dev/null | awk -F: '{print "  - " $1}' | sort
echo ""
info "Script finalizado."
echo ""
