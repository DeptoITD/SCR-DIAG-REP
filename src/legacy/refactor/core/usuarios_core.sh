#!/bin/bash
# core/usuarios_core.sh — Primitivas ÚNICAS para usuarios Linux

source "$(dirname "$0")/comun.sh"

crear_usuario() {
  local user="$1" uid="$2" grupo="$3" fullname="$4"

  require_root

  id "$user" &>/dev/null && {
    warn "Usuario ya existe: $user"
    return 1
  }

  getent group "$grupo" &>/dev/null || {
    error "Grupo no existe: $grupo"
  }

  sudo useradd -M -d /nonexistent -s /usr/sbin/nologin \
    -u "$uid" -g "$grupo" -c "$fullname" "$user" \
    || error "Falló crear usuario: $user"

  info "✓ Usuario creado: $user (uid=$uid)"
}

cambiar_contraseña() {
  local user="$1" pass="$2"

  require_root
  [[ -z "$pass" ]] && error "Contraseña vacía"

  echo "$user:$pass" | sudo chpasswd || error "Falló contraseña: $user"
  info "✓ Contraseña establecida: $user"
}

cambiar_grupo_primario() {
  local user="$1" grupo="$2"

  require_root
  getent group "$grupo" &>/dev/null || error "Grupo no existe: $grupo"

  sudo usermod -g "$grupo" "$user" || error "Falló cambiar grupo: $user"
  info "✓ Grupo primario: $user → $grupo"
}

agregar_grupo_secundario() {
  local user="$1" grupo="$2"

  require_root
  getent group "$grupo" &>/dev/null || error "Grupo no existe: $grupo"

  sudo gpasswd -a "$user" "$grupo" || error "Falló agregar a grupo: $user → $grupo"
  info "✓ Grupo secundario agregado: $user → $grupo"
}

remover_grupo_secundario() {
  local user="$1" grupo="$2"

  require_root
  sudo gpasswd -d "$user" "$grupo" || warn "No en grupo: $user / $grupo"
  info "✓ Removido de grupo: $user / $grupo"
}

eliminar_usuario() {
  local user="$1"

  require_root
  id "$user" &>/dev/null || {
    warn "Usuario no existe: $user"
    return 0
  }

  sudo userdel -r "$user" 2>/dev/null || true
  info "✓ Usuario eliminado: $user"
}
