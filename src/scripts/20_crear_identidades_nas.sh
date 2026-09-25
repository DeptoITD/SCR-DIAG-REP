#!/bin/bash
# 20_crear_identidades_nas.sh
# Crea SOLO usuarios y grupos en NAS desde archivos exportados
# NO toca ACLs ni permisos (ver repo SCR-ACL-REP)
# Uso: bash 20_crear_identidades_nas.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/../config/servers.env"

# Definir LOG_FILE antes de sourcear utils.sh
export LOG_FILE="${LOG_DIR}/crear_$(date +%Y%m%d_%H%M%S).log"
[[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"

source "${SCRIPT_DIR}/utils.sh"

DRY_RUN="${1:---dry-run}"

log "===== INICIO CREACIÓN IDENTIDADES NAS ====="
log "Modo: ${DRY_RUN}"

# Auto-detectar archivos export (buscar *_group.txt, *_passwd.txt)
EXPORT_GROUP=$(ls "${EXPORT_PATH}"/*_group.txt 2>/dev/null | head -1)
EXPORT_PASSWD=$(ls "${EXPORT_PATH}"/*_passwd.txt 2>/dev/null | head -1)
EXPORT_SAMBA_USERS=$(ls "${EXPORT_PATH}"/*_samba_users.txt 2>/dev/null | head -1)

# Validar archivos encontrados
[[ -z "$EXPORT_GROUP" ]] && error "No encontrado: *_group.txt en ${EXPORT_PATH}"
[[ -z "$EXPORT_PASSWD" ]] && error "No encontrado: *_passwd.txt en ${EXPORT_PATH}"
[[ -z "$EXPORT_SAMBA_USERS" ]] && info "Nota: no encontrado *_samba_users.txt (opcional)"

log "Archivos detectados:"
log "  Group: $(basename "$EXPORT_GROUP")"
log "  Passwd: $(basename "$EXPORT_PASSWD")"
[[ -n "$EXPORT_SAMBA_USERS" ]] && log "  Samba: $(basename "$EXPORT_SAMBA_USERS")"

# Crear grupos
info "Creando grupos locales..."
while IFS=: read -r grupo x gid resto; do
  [[ "$grupo" =~ ^# ]] && continue
  [[ -z "$grupo" ]] && continue

  if getent group "$grupo" > /dev/null 2>&1; then
    info "  ✓ Grupo existente: $grupo"
  else
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      sudo groupadd -g "$gid" "$grupo" 2>/dev/null || info "  ! Error creando grupo $grupo"
      log "  ✓ Grupo creado: $grupo (gid=$gid)"
    else
      info "  [DRY] Crear grupo: $grupo (gid=$gid)"
    fi
  fi
done < "$EXPORT_GROUP"

# Crear usuarios
info "Creando usuarios locales..."
while IFS=: read -r usuario x uid gid nombre home shell; do
  [[ "$usuario" =~ ^# ]] && continue
  [[ -z "$usuario" ]] && continue

  # Filtrar usuarios del sistema (uid < 1000)
  [[ "$uid" -lt 1000 ]] && continue

  # Validar que grupo existe (debe estar creado antes)
  if ! getent group "$gid" > /dev/null 2>&1; then
    info "  ✗ Grupo GID=$gid no existe para usuario $usuario (crear grupos primero)"
    continue
  fi

  if id "$usuario" > /dev/null 2>&1; then
    info "  ✓ Usuario existente: $usuario"
  else
    if [[ "$DRY_RUN" != "--dry-run" ]]; then
      sudo useradd -u "$uid" -g "$gid" -c "$nombre" -d "$home" -s "$shell" "$usuario" 2>/dev/null || \
        info "  ! Error creando usuario $usuario"
      log "  ✓ Usuario creado: $usuario (uid=$uid)"
    else
      info "  [DRY] Crear usuario: $usuario (uid=$uid, gid=$gid)"
    fi
  fi
done < "$EXPORT_PASSWD"

# Crear usuarios Samba
info "Creando usuarios Samba..."
[[ -f "$EXPORT_SAMBA_USERS" ]] && {
  while IFS= read -r linea; do
    [[ -z "$linea" ]] && continue
    user=$(echo "$linea" | cut -d: -f1)

    if smbpasswd -L "$user" > /dev/null 2>&1; then
      info "  ✓ Usuario Samba existente: $user"
    else
      if [[ "$DRY_RUN" != "--dry-run" ]]; then
        echo "${SAMBA_PASSWORD}" | sudo smbpasswd -a "$user" 2>/dev/null || \
          info "  ! Error agregando usuario Samba $user"
        log "  ✓ Usuario Samba agregado: $user"
      else
        info "  [DRY] Agregar usuario Samba: $user"
      fi
    fi
  done < "$EXPORT_SAMBA_USERS"
}

info "===== RESUMEN CREACIÓN ====="
log "Grupos creados: $(grep -cv "^#" "$EXPORT_GROUP" || echo 0)"
log "Usuarios creados: $(grep -cv "^#" "$EXPORT_PASSWD" || echo 0)"
log "===== FIN CREACIÓN ====="
