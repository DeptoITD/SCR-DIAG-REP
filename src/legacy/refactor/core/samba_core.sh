#!/bin/bash
# core/samba_core.sh — Primitivas ÚNICAS para Samba

source "$(dirname "$0")/comun.sh"

crear_cuenta_samba() {
  local user="$1" pass="$2"

  require_root

  pdbedit -L -a "$user" 2>/dev/null && {
    warn "Cuenta Samba ya existe: $user"
    return 0
  }

  echo -e "$pass\n$pass" | sudo smbpasswd -a -s "$user" \
    || error "Falló crear Samba: $user"

  info "✓ Cuenta Samba creada: $user"
}

cambiar_contraseña_samba() {
  local user="$1" pass="$2"

  require_root
  [[ -z "$pass" ]] && error "Contraseña vacía"

  echo -e "$pass\n$pass" | sudo smbpasswd -s "$user" \
    || error "Falló cambiar Samba: $user"

  info "✓ Contraseña Samba: $user"
}

eliminar_cuenta_samba() {
  local user="$1"

  require_root
  pdbedit -L -a "$user" 2>/dev/null || {
    warn "Cuenta no existe: $user"
    return 0
  }

  sudo smbpasswd -x "$user" 2>/dev/null || true
  info "✓ Cuenta Samba eliminada: $user"
}

restaurar_hash_samba() {
  local user="$1" nt_hash="$2"

  require_root
  [[ -z "$nt_hash" ]] && error "Hash vacío: $user"

  sudo pdbedit -u "$user" -w "$nt_hash" \
    || error "Falló restaurar hash: $user"

  info "✓ Hash Samba restaurado: $user"
}
