#!/bin/bash
# =============================================================================
# Script: crear_usuarios_indesco_v4.sh
# Descripción: Crea SOLO los usuarios (los grupos ya existen).
#              Usernames sin dominio. ej: jhonatan.rojas
# Uso: sudo bash ~/Downloads/crear_usuarios_indesco_v4.sh 2>&1 | tee /tmp/resultado_usuarios.log
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

echo ""
info "======================================================"
info "  Creación de usuarios - Grupo Indesco v4"
info "======================================================"
echo ""

# =============================================================================
# FUNCIÓN PARA CREAR USUARIO
# =============================================================================
crear_usuario() {
    local nombre_completo="$1"
    local username="$2"
    local password="$3"
    local grupo="$4"

    info "Procesando: $nombre_completo → $username ($grupo)"

    if id "$username" > /dev/null 2>&1; then
        warn "  '$username' ya existe, se omite."
        return
    fi

    if ! getent group "$grupo" > /dev/null 2>&1; then
        error "  Grupo '$grupo' NO existe. Crea los grupos primero."
        exit 1
    fi

    useradd \
        --create-home \
        --shell /bin/bash \
        --comment "$nombre_completo" \
        --gid "$grupo" \
        "$username"

    echo "$username:$password" | chpasswd
    chage --lastday 0 "$username"

    log "  Creado: $username → $grupo"
}

# =============================================================================
# USUARIOS POR GRUPO
# =============================================================================

info "--- IND_PMO ---"
crear_usuario "Jhonatan Samir Rojas Novoa" "jhonatan.rojas" "Tq9@Lm#2!"  "IND_PMO"
crear_usuario "Camilo Andrés Tibana Monar" "camilo.tibana"  "vR7\$Xp&4*" "IND_PMO"
echo ""

info "--- IND_ARQ ---"
crear_usuario "Jeisson Alexander Suarez Castellanos" "jeisson.suarez"    "Nf3!Za@8%"  "IND_ARQ"
crear_usuario "Carlos Mauricio Acero Guerrero"        "carlos.acero"     "kL5#Yu\$1&" "IND_ARQ"
crear_usuario "Anderson Higuera Vallejo"              "anderson.higuera" "Pw8@Er!6*"  "IND_ARQ"
crear_usuario "Melissa Maria Rubiano Cortes"          "melissa.rubiano"  "dX2&Qm#9!"  "IND_ARQ"
crear_usuario "Ana Maria Diaz Salas"                  "ana.diaz"         "Hj4\$Bn@7%" "IND_ARQ"
echo ""

info "--- IND_BIM ---"
crear_usuario "Yeferson Andrés Rincón Sánchez"  "andres.rincon"       "rT6!Vc#3&"  "IND_BIM"
crear_usuario "Sebastián Rodríguez Quintero"     "sebastian.rodriguez" "Mz1@Ks\$8*" "IND_BIM"
crear_usuario "Maria Paula Castro Tique"         "maria.castro"        "qW9#Lp!5%"  "IND_BIM"
crear_usuario "Jonathan Steven Arevalo Bernal"   "jonathan.arevalo"    "Ya7&Nd@2!"  "IND_BIM"
crear_usuario "Julian David Gonzalez Ruiz"       "juliand.gonzalez"    "cF3\$Rt#6*" "IND_BIM"
crear_usuario "Valentina Soto Escobar"           "valentina.soto"      "Uv8!Gh@4%"  "IND_BIM"
echo ""

info "--- IND_GEO ---"
crear_usuario "Maria Alejandra Pinza Palechor" "alejandra.pinza" "Gt4@Wp#7!"  "IND_GEO"
crear_usuario "Jhon Sebastian Acevedo Perez"   "jhon.acevedo"    "xN8\$Qa&2*" "IND_GEO"
echo ""

info "--- IND_EST ---"
crear_usuario "Santiago Gómez Ayala"            "santiago.gomez"   "Bm1!Zv@9%"  "IND_EST"
crear_usuario "Miguel Angel Rojas Novoa"        "miguel.rojas"     "rK6#Ty\$3&" "IND_EST"
crear_usuario "Laura Daniela Tibata Camargo"    "laura.tibata"     "Hu5@Lc!8*"  "IND_EST"
crear_usuario "Kimberly Tatiana Porras Rivera"  "tatiana.porras"   "pD2&Fs#4!"  "IND_EST"
crear_usuario "Cristian Leonardo Cordero Niño"  "cristian.cordero" "Yw7\$Jn@1%" "IND_EST"
crear_usuario "Sebastián Fernando Pineda Gomez" "sebastian.pineda" "cR9!Xe#6&"  "IND_EST"
crear_usuario "Ronald David Vargas Marulanda"   "david.vargas"     "Va3@Mk\$5*" "IND_EST"
echo ""

info "--- IND_ITD ---"
crear_usuario "Sara Albarracin Niño"    "sara.albarracin" "Ind3\$c024*" "IND_ITD"
crear_usuario "Juan Diego Rojas Vargas" "juan.rojas"      "Ind3\$c024*" "IND_ITD"
echo ""

# =============================================================================
# SOPORTE (superadmin)
# =============================================================================
info "--- Verificando 'soporte' ---"
if id "soporte" > /dev/null 2>&1; then
    log "Usuario 'soporte' ya existe. No se modifica."
    groups soporte | grep -qw sudo && log "  Ya tiene sudo." || { usermod -aG sudo soporte && log "  Sudo agregado."; }
else
    warn "Usuario 'soporte' NO existe. Créalo manualmente:"
    echo "  sudo adduser soporte"
    echo "  sudo usermod -aG sudo soporte"
fi
echo ""

# =============================================================================
# RESUMEN
# =============================================================================
info "======================================================"
info "  RESUMEN"
info "======================================================"

GRUPOS=(IND_PMO IND_ARQ IND_BIM IND_GEO IND_EST IND_ITD)
TOTAL_CREADOS=0

for grupo in "${GRUPOS[@]}"; do
    MIEMBROS=$(getent group "$grupo" | awk -F: '{print $4}')
    COUNT=$(echo "$MIEMBROS" | tr ',' '\n' | grep -c '\S' || true)
    TOTAL_CREADOS=$((TOTAL_CREADOS + COUNT))
    echo ""
    echo -e "${BLUE}$grupo${NC} ($COUNT usuarios):"
    echo "$MIEMBROS" | tr ',' '\n' | sed 's/^/  - /'
done

echo ""
info "Total usuarios creados: $TOTAL_CREADOS / 24"
info "Script finalizado."
echo ""
