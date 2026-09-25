#!/bin/bash
# 20_crear_identidades_nas.sh
# Crea SOLO usuarios y grupos en NAS desde archivos exportados
# NO toca ACLs ni permisos (ver repo SCR-ACL-REP)
# Uso: bash 20_crear_identidades_nas.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/../config/servers.env"

DRY_RUN="${1:---dry-run}"

[[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"

log "===== INICIO CREACIÓN IDENTIDADES NAS ====="
log "NAS: ${NAS_IP}"
log "Modo: ${DRY_RUN}"

# Validar archivos export
for file in "$EXPORT_GROUP" "$EXPORT_PASSWD" "$EXPORT_SAMBA_USERS"; do
  [[ ! -f "$file" ]] && error "Archivo no encontrado: $file"
done

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
