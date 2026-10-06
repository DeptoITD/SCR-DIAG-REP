#!/bin/bash
# usuarios.sh — Gestión de usuarios (CRUD)
# Reutilizado por importar.sh para replicar usuarios

if [[ "$(type -t log)" != function ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/iniciar.sh" || return 1
fi

usuario_listar() {
  local db="${DATA_DIR}/usuarios.db"
  [[ ! -f "$db" ]] && { error "No existe: $db"; return 1; }

  echo ""
  echo "=== Usuarios ==="
  echo "Usuario             | Nombre                          | Grupo Primario | Grupos Extra"
  echo "--------------------|----------------------------------|----------------|------------------------------------------"

  while IFS='|' read -r user full_name prim_grupo extra_groups uid created extra; do
    [[ -z "$user" || "$user" =~ ^# ]] && continue
    printf "%-19s | %-32s | %-14s | %s\n" "$user" "$full_name" "$prim_grupo" "${extra_groups:--(ninguno)}"
  done < "$db"
  echo ""
}

usuario_crear() {
  require_root
  local db="${DATA_DIR}/usuarios.db"
  local usuarios_db="${DATA_DIR}/usuarios.db"
  local equipos_db="${DATA_DIR}/equipos.db"
  local user full_name prim_grupo extra_groups pass uid created

  read -r -p "Nombre de usuario (ej: john.doe): " user
  [[ -z "$user" ]] && return 1

  id "$user" &>/dev/null && { error "Usuario ya existe"; return 1; }

  read -r -p "Nombre completo: " full_name
  [[ "$full_name" != *'|'* && "$full_name" != *:* ]] || { echo '[!] Nombre completo inválido.' >&2; return 1; }
  prim_grupo=$(seleccionar_registro "$equipos_db" 'Grupo primario') || return 1

  # Validar grupo
  grep -q "^${prim_grupo}|" "$equipos_db" || { error "Grupo no existe: $prim_grupo"; return 1; }

  extra_groups=$(seleccionar_registro "$equipos_db" 'Grupos adicionales' varios) || return 1

  # Obtener próximo UID
  # Linux asigna un UID libre; no se calcula a partir de un catálogo parcial.

  # Crear grupo si no existe
  if ! getent group "$prim_grupo" &>/dev/null; then
    local gid=$(grep "^${prim_grupo}|" "$equipos_db" | cut -d'|' -f3)
    sudo groupadd -g "$gid" "$prim_grupo" || warn "Advertencia: error creando grupo $prim_grupo"
  fi

  # Crear usuario Linux
  sudo useradd -M -d /nonexistent -s /usr/sbin/nologin -g "$prim_grupo" -c "$full_name" "$user" || { error "Error creando usuario Linux"; return 1; }
  uid=$(id -u "$user") || return 1

  # Generar password
  pass=$(generate_password)
  establecer_password_permanente "$user" "$pass" || { echo '[!] La cuenta se creó parcialmente; falló la contraseña o Samba.' >&2; return 1; }

  # Agregar grupos adicionales
  if [[ -n "$extra_groups" ]]; then
    IFS=',' read -ra groups <<< "$extra_groups"
    for g in "${groups[@]}"; do
      g=$(echo "$g" | xargs)  # trim
      sudo gpasswd -a "$user" "$g" || return 1
    done
  fi

  # Registrar en Samba

  # Registrar en DB
  created=$(date +%Y-%m-%d)
  registrar_usuario_catalogo "$user" || return 1

  info "Usuario creado: $user (uid=$uid)"
  mostrar_password_generada "$user" "$pass"
}

usuario_editar() {
  require_root
  local db="${DATA_DIR}/usuarios.db"
  local user line full_name prim_grupo extra_groups opt

  user=$(seleccionar_registro "$db" 'Usuario a editar') || return 1

  line=$(awk -F'|' -v user="$user" '$1 == user {print; exit}' "$db")
  [[ -n "$line" ]] || return 1

  echo ""
  echo "Opciones: 1) Nombre, 2) Contraseña, 3) Grupo primario, 4) Grupos adicionales, 0) Volver"
  read -r -p "Opción: " opt

  case "$opt" in
    1)  # Nombre
      read -r -p "Nuevo nombre: " full_name
      [[ "$full_name" != *'|'* ]] || return 1
      sudo usermod -c "$full_name" "$user" || return 1
      registrar_usuario_catalogo "$user" || return 1
      info "Nombre actualizado"
      ;;
    2)  # Contraseña
      local pass=$(generate_password)
      establecer_password_permanente "$user" "$pass" || return 1
      info "Contraseña actualizada"
      mostrar_password_generada "$user" "$pass"
      ;;
    3)  # Grupo primario
      local new_grupo
      new_grupo=$(seleccionar_registro "${DATA_DIR}/equipos.db" 'Nuevo grupo primario') || return 1
      grep -q "^${new_grupo}|" "${DATA_DIR}/equipos.db" || { error "Grupo no existe"; return 1; }
      sudo usermod -g "$new_grupo" "$user" || return 1
      registrar_usuario_catalogo "$user" || return 1
      info "Grupo actualizado"
      ;;
    4)  # Grupos adicionales
      local new_extra
      new_extra=$(seleccionar_registro "${DATA_DIR}/equipos.db" 'Nuevos grupos adicionales' varios) || return 1

      # Remover de viejos, agregar a nuevos
      local old_extra=$(echo "$line" | cut -d'|' -f4)
      if [[ -n "$old_extra" ]]; then
        IFS=',' read -ra old_groups <<< "$old_extra"
        for g in "${old_groups[@]}"; do
          g=$(echo "$g" | xargs)
          sudo gpasswd -d "$user" "$g" || return 1
        done
      fi

      if [[ -n "$new_extra" ]]; then
        IFS=',' read -ra new_groups <<< "$new_extra"
        for g in "${new_groups[@]}"; do
          g=$(echo "$g" | xargs)
          sudo gpasswd -a "$user" "$g" || return 1
        done
      fi

      registrar_usuario_catalogo "$user" || return 1
      info "Grupos actualizados"
      ;;
  esac
}

usuario_eliminar() {
  require_root
  local db="${DATA_DIR}/usuarios.db"
  local user line

  user=$(seleccionar_registro "$db" 'Usuario a eliminar') || return 1

  line=$(awk -F'|' -v user="$user" '$1 == user {print; exit}' "$db")
  [[ -n "$line" ]] || return 1

  echo ""
  echo "Perfil del usuario:"
  id "$user" 2>/dev/null || echo "  No existe en Linux"
  echo "  Datos DB: $line"
  echo ""

  confirm "¿Eliminar usuario $user?" || return 1

  # Eliminar
  sudo userdel -r "$user" 2>/dev/null || warn "Error eliminando usuario Linux"
  sudo smbpasswd -x "$user" 2>/dev/null || warn "Error eliminando Samba"
  sed -i "/^${user}|/d" "$db"

  info "Usuario eliminado: $user"
}

menu_usuarios() {
  while true; do
    echo ""
    echo "=== Gestión de usuarios ==="
    echo "1. Listar usuarios"
    echo "2. Crear usuario"
    echo "3. Editar usuario"
    echo "4. Eliminar usuario"
    echo "5. Carga masiva de usuarios"
    echo "6. Volver"
    read -r -p "Opción: " opt

    case "$opt" in
      1) usuario_listar ;;
      2) usuario_crear ;;
      3) usuario_editar ;;
      4) usuario_eliminar ;;
      5) menu_carga_masiva ;;
      6) break ;;
      *) error_soft "Opción inválida" ;;
    esac
  done
}

error_soft() {
  echo "[!] $1" >&2
}
