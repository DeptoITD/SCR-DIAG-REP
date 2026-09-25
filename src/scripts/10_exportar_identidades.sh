#!/bin/bash
# 10_exportar_identidades.sh
# Exporta identidades (usuarios, grupos, Samba) del servidor origen
# Uso: bash 10_exportar_identidades.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/../config/servers.env"

# Definir LOG_FILE antes de sourcea utils.sh
export LOG_FILE="${LOG_DIR}/exportar_$(date +%Y%m%d_%H%M%S).log"
[[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"

source "${SCRIPT_DIR}/utils.sh"

DRY_RUN="${1:---dry-run}"

log "===== INICIO EXPORTACIÓN IDENTIDADES ====="
log "Servidor origen: ${SERVIDOR_ORIGEN_IP}"
log "Modo: ${DRY_RUN}"

# Crear directorio export si no existe
[[ ! -d "$EXPORT_PATH" ]] && mkdir -p "$EXPORT_PATH" && info "Directorio creado: $EXPORT_PATH"

# Usar hostname local (origen siempre exporta desde su máquina)
HOSTNAME=$(hostname -s)
export_group="${EXPORT_PATH}/${HOSTNAME}_group.txt"
export_passwd="${EXPORT_PATH}/${HOSTNAME}_passwd.txt"
export_samba="${EXPORT_PATH}/${HOSTNAME}_samba_users.txt"
export_smbpass="${EXPORT_PATH}/${HOSTNAME}_smbpasswd.exp"

# Backup previo
backup_file "$export_group"
backup_file "$export_passwd"
backup_file "$export_samba"
backup_file "$export_smbpass"

info "Exportando grupos locales..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  cat /etc/group | grep -v "^#" > "$export_group" || error "No se pudo exportar groups"
  log "Grupos exportados: $(wc -l < "$export_group") líneas"
fi

info "Exportando usuarios locales..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  cat /etc/passwd | grep -v "^#" > "$export_passwd" || error "No se pudo exportar passwd"
  log "Usuarios exportados: $(wc -l < "$export_passwd") líneas"
fi

info "Exportando usuarios Samba..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  pdbedit -L 2>/dev/null > "$export_samba" || info "pdbedit no disponible o sin usuarios"
  log "Usuarios Samba exportados: $(wc -l < "$export_samba") líneas"
fi

info "Exportando contraseñas Samba (ocultas)..."
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  [[ -f /var/lib/samba/private/passdb.tdb ]] && \
    sudo pdbedit -L -w 2>/dev/null > "$export_smbpass" || info "No se pudo exportar smbpasswd"
  chmod 600 "$export_smbpass"
  log "Contraseñas Samba exportadas (protegidas)"
fi

# Exportar configuraciones Samba
info "Exportando configuraciones Samba..."
export_testparm="${EXPORT_PATH}/${HOSTNAME}_testparm.conf"
export_smbconf="${EXPORT_PATH}/${HOSTNAME}_smb.conf"
export_fstab="${EXPORT_PATH}/${HOSTNAME}_fstab.txt"

if [[ "$DRY_RUN" != "--dry-run" ]]; then
  backup_file "$export_testparm"
  testparm -s 2>/dev/null > "$export_testparm" || info "testparm no disponible"

  backup_file "$export_smbconf"
  [[ -f /etc/samba/smb.conf ]] && cp /etc/samba/smb.conf "$export_smbconf"

  backup_file "$export_fstab"
  cat /etc/fstab > "$export_fstab"

  log "Configuraciones exportadas"
fi

# Mostrar resumen
info "===== RESUMEN EXPORTACIÓN ====="
[[ -f "$export_group" ]] && info "✓ Grupos: $export_group ($(wc -l < "$export_group") líneas)"
[[ -f "$export_passwd" ]] && info "✓ Usuarios: $export_passwd ($(wc -l < "$export_passwd") líneas)"
[[ -f "$export_samba" ]] && info "✓ Samba users: $export_samba ($(wc -l < "$export_samba") líneas)"
[[ -f "$export_smbpass" ]] && info "✓ Samba passwd: $export_smbpass (protegido)"
[[ -f "$export_testparm" ]] && info "✓ Testparm: $export_testparm"
[[ -f "$export_smbconf" ]] && info "✓ smb.conf: $export_smbconf"
[[ -f "$export_fstab" ]] && info "✓ fstab: $export_fstab"

log "===== FIN EXPORTACIÓN ====="
