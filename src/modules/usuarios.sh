#!/bin/bash
# usuarios.sh — Gestión de usuarios (CRUD)
# Reutilizado por importar.sh para replicar usuarios

if [[ "$(type -t log)" != "function" ]]; then
  source "${REPO_PATH:-$(dirname "$0")/..}/config/servers.env" 2>/dev/null || source "$(dirname "$0")/../config/servers.env"
  source "${REPO_PATH:-$(dirname "$0")/..}/src/utils.sh" 2>/dev/null || source "$(dirname "$0")/../utils.sh"
fi

usuario_listar() {
  local db="${DATA_DIR}/usuarios.db"
  [[ ! -f "$db" ]] && { error "No existe: $db"; return 1; }

  echo ""
  echo "=== Usuarios ==="
  echo "Usuario             | Nombre                          | Grupo Primario | Grupos Extra"
  echo "--------------------|----------------------------------|----------------|------------------------------------------"

  while IFS'|' read -r user full_name prim_grupo extra_groups uid created extra; do
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
  read -r -p "Grupo primario (ej: IND_ARQ): " prim_grupo

  # Validar grupo
  grep -q "^${prim_grupo}|" "$equipos_db" || { error "Grupo no existe: $prim_grupo"; return 1; }

  read -r -p "Grupos adicionales (separados por coma, opcional): " extra_groups

  # Obtener próximo UID
  uid=$(($(awk -F'|' 'NR>1 {print $5}' "$usuarios_db" | sort -n | tail -1) + 1))

  # Crear grupo si no existe
  if ! getent group "$prim_grupo" &>/dev/null; then
    local gid=$(grep "^${prim_grupo}|" "$equipos_db" | cut -d'|' -f3)
    sudo groupadd -g "$gid" "$prim_grupo" || warn "Advertencia: error creando grupo $prim_grupo"
  fi

  # Crear usuario Linux
  sudo useradd -m -u "$uid" -g "$prim_grupo" -c "$full_name" "$user" || { error "Error creando usuario Linux"; return 1; }

  # Generar password
  pass=$(generate_password)
  echo "$pass" | sudo chpasswd -c SHA512 || { error "Error configurando contraseña"; return 1; }
  sudo chage -d 0 "$user" || warn "Advertencia: error en chage"

  # Agregar grupos adicionales
  if [[ -n "$extra_groups" ]]; then
    IFS=',' read -ra groups <<< "$extra_groups"
    for g in "${groups[@]}"; do
      g=$(echo "$g" | xargs)  # trim
      sudo gpasswd -a "$user" "$g" 2>/dev/null || warn "No se pudo agregar a $g"
    done
  fi

  # Registrar en Samba
  echo "$pass" | sudo smbpasswd -a "$user" -s 2>/dev/null || warn "Advertencia: error en Samba"
  sudo smbpasswd -e "$user" 2>/dev/null

  # Registrar en DB
  created=$(date +%Y-%m-%d)
  echo "${user}|${full_name}|${prim_grupo}|${extra_groups}|${uid}|${created}" >> "$db"

  info "Usuario creado: $user (uid=$uid)"
  mostrar_password_generada "$user" "$pass"
}

usuario_editar() {
  require_root
  local db="${DATA_DIR}/usuarios.db"
  local user line full_name prim_grupo extra_groups opt

  usuario_listar
  read -r -p "Seleccione usuario a editar: " user
  [[ -z "$user" ]] && return 1

  line=$(grep "^${user}|" "$db") || { error "Usuario no existe"; return 1; }

  echo ""
  echo "Opciones: 1) Nombre, 2) Contraseña, 3) Grupo primario, 4) Grupos adicionales, 0) Volver"
  read -r -p "Opción: " opt

  case "$opt" in
    1)  # Nombre
      read -r -p "Nuevo nombre: " full_name
      sed -i "s/^${user}|\([^|]*\)|/&${full_name}|/" "$db"
      sudo usermod -c "$full_name" "$user"
      info "Nombre actualizado"
      ;;
    2)  # Contraseña
      local pass=$(generate_password)
      echo "$pass" | sudo chpasswd -c SHA512 || { error "Error"; return 1; }
      echo "$pass" | sudo smbpasswd -a "$user" -s 2>/dev/null
      info "Contraseña actualizada"
      mostrar_password_generada "$user" "$pass"
      ;;
    3)  # Grupo primario
      local new_grupo
      read -r -p "Nuevo grupo primario: " new_grupo
      grep -q "^${new_grupo}|" "${DATA_DIR}/equipos.db" || { error "Grupo no existe"; return 1; }
      sudo usermod -g "$new_grupo" "$user"
      sed -i "s/^${user}|\([^|]*\)|\([^|]*\)|/${user}|\1|${new_grupo}|/" "$db"
      info "Grupo actualizado"
      ;;
    4)  # Grupos adicionales
      local new_extra
      read -r -p "Nuevos grupos adicionales (separados por coma): " new_extra

      # Remover de viejos, agregar a nuevos
      local old_extra=$(echo "$line" | cut -d'|' -f4)
      if [[ -n "$old_extra" ]]; then
        IFS=',' read -ra old_groups <<< "$old_extra"
        for g in "${old_groups[@]}"; do
          g=$(echo "$g" | xargs)
          sudo gpasswd -d "$user" "$g" 2>/dev/null
        done
      fi

      if [[ -n "$new_extra" ]]; then
        IFS=',' read -ra new_groups <<< "$new_extra"
        for g in "${new_groups[@]}"; do
          g=$(echo "$g" | xargs)
          sudo gpasswd -a "$user" "$g" 2>/dev/null
        done
      fi

      sed -i "s/^${user}|\([^|]*\)|\([^|]*\)|\([^|]*\)|/${user}|\1|\2|${new_extra}|/" "$db"
      info "Grupos actualizados"
      ;;
  esac
}

usuario_eliminar() {
  require_root
  local db="${DATA_DIR}/usuarios.db"
  local user line

  usuario_listar
  read -r -p "Seleccione usuario a eliminar: " user
  [[ -z "$user" ]] && return 1

  line=$(grep "^${user}|" "$db") || { error "Usuario no existe"; return 1; }

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
    echo "5. Volver"
    read -r -p "Opción: " opt

    case "$opt" in
      1) usuario_listar ;;
      2) usuario_crear ;;
      3) usuario_editar ;;
      4) usuario_eliminar ;;
      5) break ;;
      *) error_soft "Opción inválida" ;;
    esac
  done
}

error_soft() {
  echo "[!] $1" >&2
}
