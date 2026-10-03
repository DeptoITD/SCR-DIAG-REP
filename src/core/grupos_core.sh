#!/bin/bash
# core/grupos_core.sh — Primitivas ÚNICAS para grupos Linux

source "$(dirname "$0")/comun.sh"

crear_grupo() {
  local grupo="$1" gid="$2"

  require_root

  getent group "$grupo" &>/dev/null && {
    warn "Grupo ya existe: $grupo"
    return 0
  }

  sudo groupadd -g "$gid" "$grupo" || error "Falló crear grupo: $grupo"
  info "✓ Grupo creado: $grupo (gid=$gid)"
}

eliminar_grupo() {
  local grupo="$1"

  require_root
  getent group "$grupo" &>/dev/null || {
    warn "Grupo no existe: $grupo"
    return 0
  }

  sudo groupdel "$grupo" 2>/dev/null || {
    warn "No se pudo eliminar (usuarios activos): $grupo"
  }
  info "✓ Grupo eliminado: $grupo"
}

grupo_existe() {
  local grupo="$1"
  getent group "$grupo" &>/dev/null
}
