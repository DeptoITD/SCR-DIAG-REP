#!/bin/bash
# identidades/usuarios.sh v1.0 — CRUD usuarios (llama core)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/core/comun.sh"
source "$SCRIPT_DIR/core/config.sh"
source "$SCRIPT_DIR/core/usuarios_core.sh"
source "$SCRIPT_DIR/core/grupos_core.sh"
source "$SCRIPT_DIR/core/samba_core.sh"

usuario_listar() {
  echo ""
  echo "=== Usuarios ==="
  leer_usuarios | cut -d'|' -f1,2,3,4 | column -t -s'|'
  echo ""
}

usuario_crear() {
  require_root
  validar_config

  echo ""
  echo "=== Crear Usuario ==="
  read -r -p "Usuario: " user
  read -r -p "Nombre completo: " nombre
  read -r -p "Grupo primario ($(leer_equipos | cut -d'|' -f1 | tr '\n' '/')): " grupo
  read -r -p "Dominio (COR/OPE/COM): " dominio
  read -r -p "UID: " uid

  grupo_existe "$grupo" || error "Grupo no existe: $grupo"
  [[ "$dominio" =~ ^(COR|OPE|COM)$ ]] || error "Dominio inválido: $dominio"

  crear_usuario "$user" "$uid" "$grupo" "$nombre" || return 1

  # Contraseña
  pass=$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 16)
  cambiar_contraseña "$user" "$pass"
  crear_cuenta_samba "$user" "$pass"
  agregar_grupo_secundario "$user" "$dominio" || true

  echo ""
  echo "=========================================="
  echo "Usuario: $user"
  echo "Password: $pass"
  echo "=========================================="
  echo ""
}

usuario_eliminar() {
  require_root
  usuario_listar
  read -r -p "Usuario a eliminar: " user
  confirm "¿Eliminar $user?" && eliminar_usuario "$user"
}

menu_usuarios() {
  while true; do
    echo ""
    echo "=== Usuarios ==="
    echo "1) Listar"
    echo "2) Crear"
    echo "3) Eliminar"
    echo "0) Volver"
    read -r -p "Opción: " opt

    case "$opt" in
      1) usuario_listar ;;
      2) usuario_crear ;;
      3) usuario_eliminar ;;
      0) break ;;
      *) warn "Inválido" ;;
    esac
  done
}

menu_usuarios
