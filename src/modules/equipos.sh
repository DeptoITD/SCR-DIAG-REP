#!/bin/bash
# equipos.sh — Gestión de equipos (departamentos/grupos Linux+Samba)
# Nota: "equipo" aquí = equipo de trabajo/departamento (IND_ARQ, IND_BIM, etc.)
#       NO = máquina física (eso se llama "máquina/host" en el menú de diagnóstico)

[[ -z "$REPO_PATH" ]] && source "$(dirname "$0")/../config/servers.env"
[[ -z "$log" ]] && source "$(dirname "$0")/../utils.sh"

equipo_listar() {
  local db="${DATA_DIR}/equipos.db"
  [[ ! -f "$db" ]] && { error "No existe: $db"; return 1; }

  echo ""
  echo "=== Equipos (departamentos) ==="
  echo "Grupo        | Display       | GID  | Descripción"
  echo "-------------|---------------|------|------------------------------------------"
  while IFS='|' read -r grupo display gid desc created; do
    [[ -z "$grupo" || "$grupo" =~ ^# ]] && continue
    printf "%-12s | %-13s | %4s | %s\n" "$grupo" "$display" "$gid" "$desc"
  done < "$db"
  echo ""
}

equipo_crear() {
  local db="${DATA_DIR}/equipos.db"
  local grupo display desc gid created

  read -r -p "Nombre del grupo (ej: IND_NUEVO): " grupo
  [[ -z "$grupo" ]] && { error "Nombre requerido"; return 1; }

  grep -q "^${grupo}|" "$db" && { error "Grupo ya existe: $grupo"; return 1; }

  read -r -p "Nombre display (ej: Nuevo Equipo): " display
  read -r -p "Descripción: " desc

  # Obtener próximo GID (máx de la lista + 1)
  gid=$(($(awk -F'|' 'NR>1 {print $3}' "$db" | sort -n | tail -1) + 1))

  sudo groupadd -g "$gid" "$grupo" || { error "Error creando grupo Linux"; return 1; }

  created=$(date +%Y-%m-%d)
  echo "${grupo}|${display}|${gid}|${desc}|${created}" >> "$db"

  info "Grupo creado: $grupo (gid=$gid)"
}

equipo_editar() {
  local db="${DATA_DIR}/equipos.db"
  local grupo old_grupo display gid desc created

  equipo_listar
  read -r -p "Seleccione grupo a editar: " grupo
  [[ -z "$grupo" ]] && return 1

  grep -q "^${grupo}|" "$db" || { error "Grupo no existe: $grupo"; return 1; }

  echo ""
  echo "Opciones: 1) Renombrar, 2) Cambiar descripción, 3) Ver/Editar integrantes, 0) Volver"
  read -r -p "Opción: " opt

  case "$opt" in
    1)  # Renombrar
      read -r -p "Nuevo nombre: " old_grupo
      [[ -z "$old_grupo" ]] && return 1

      # Actualizar Linux
      sudo groupmod -n "$old_grupo" "$grupo" || { error "Error en groupmod"; return 1; }

      # Actualizar DB
      sed -i.bak "s/^${grupo}|/${old_grupo}|/" "$db"

      # Cascada: usuarios.db
      local usuarios_db="${DATA_DIR}/usuarios.db"
      sed -i "s/|${grupo}|/|${old_grupo}|/g" "$usuarios_db"
      sed -i "s/|${grupo}$/|${old_grupo}/" "$usuarios_db"

      info "Grupo renombrado: $grupo → $old_grupo"
      ;;
    2)  # Cambiar descripción
      read -r -p "Nueva descripción: " desc
      # Extraer fila, cambiar desc, reescribir
      local line=$(grep "^${grupo}|" "$db")
      sed -i "s|^${grupo}|.*|${grupo}|$(echo "$line" | cut -d'|' -f2)|$(echo "$line" | cut -d'|' -f3)|${desc}|$(echo "$line" | cut -d'|' -f5)|" "$db"
      info "Descripción actualizada"
      ;;
    3)  # Ver/Editar integrantes
      equipo_ver_integrantes "$grupo"
      ;;
  esac
}

equipo_eliminar() {
  local db="${DATA_DIR}/equipos.db"
  local grupo

  equipo_listar
  read -r -p "Seleccione grupo a eliminar: " grupo
  [[ -z "$grupo" ]] && return 1

  grep -q "^${grupo}|" "$db" || { error "Grupo no existe"; return 1; }

  # Verificar que ningún usuario lo tenga como grupo primario
  if grep -q "|${grupo}|" "${DATA_DIR}/usuarios.db"; then
    error "No se puede eliminar: hay usuarios con este como grupo primario"
    return 1
  fi

  confirm "¿Eliminar grupo $grupo?" || return 1

  sudo groupdel "$grupo" 2>/dev/null || warn "Advertencia: error eliminando grupo Linux"
  sed -i "/^${grupo}|/d" "$db"

  info "Grupo eliminado: $grupo"
}

equipo_ver_integrantes() {
  local grupo="${1:-}"
  local db="${DATA_DIR}/equipos.db"
  local usuarios_db="${DATA_DIR}/usuarios.db"

  if [[ -z "$grupo" ]]; then
    equipo_listar
    read -r -p "Seleccione grupo: " grupo
  fi

  [[ -z "$grupo" ]] && return 1
  grep -q "^${grupo}|" "$db" || { error "Grupo no existe"; return 1; }

  echo ""
  echo "=== Integrantes de $grupo ==="
  echo "Usuario             | Nombre                          | Grupo Primario"
  echo "--------------------|----------------------------------|---------------"

  while IFS='|' read -r user full_name prim_grupo extra_groups uid created extra; do
    [[ -z "$user" || "$user" =~ ^# ]] && continue

    # Listar este usuario si está en el grupo (primario o adicional)
    if [[ "$prim_grupo" == "$grupo" ]] || [[ "$extra_groups" =~ (^|,)${grupo}(,|$) ]]; then
      printf "%-19s | %-32s | %s\n" "$user" "$full_name" "$prim_grupo"
    fi
  done < "$usuarios_db"
  echo ""
}

menu_equipos() {
  while true; do
    echo ""
    echo "=== Gestión de equipos (departamentos) ==="
    echo "1. Listar equipos"
    echo "2. Crear equipo"
    echo "3. Editar equipo"
    echo "4. Eliminar equipo"
    echo "5. Ver integrantes"
    echo "6. Volver"
    read -r -p "Opción: " opt

    case "$opt" in
      1) equipo_listar ;;
      2) equipo_crear ;;
      3) equipo_editar ;;
      4) equipo_eliminar ;;
      5) equipo_ver_integrantes ;;
      6) break ;;
      *) error_soft "Opción inválida" ;;
    esac
  done
}

error_soft() {
  echo "[!] $1" >&2
}
