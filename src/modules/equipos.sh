#!/bin/bash
# equipos.sh — Gestión de equipos (departamentos/grupos Linux+Samba)
# Nota: "equipo" aquí = equipo de trabajo/departamento (IND_ARQ, IND_BIM, etc.)
#       NO = máquina física (eso se llama "máquina/host" en el menú de diagnóstico)

if [[ "$(type -t log)" != "function" ]]; then
  source "${REPO_PATH:-$(dirname "$0")/..}/config/servers.env" 2>/dev/null || source "$(dirname "$0")/../config/servers.env"
  source "${REPO_PATH:-$(dirname "$0")/..}/src/utils.sh" 2>/dev/null || source "$(dirname "$0")/../utils.sh"
fi

equipo_listar() {
  sincronizar_catalogo_grupos || return 1
  local db="${DATA_DIR}/equipos.db"
  [[ ! -f "$db" ]] && { error "No existe: $db"; return 1; }

  echo ""
  echo "=== Grupos de trabajo Samba ==="
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
  es_grupo_trabajo "$grupo" || { echo '[!] Usa IND_NOMBRE, COR, OPE, COM o GEN.' >&2; return 1; }

  grep -q "^${grupo}|" "$db" && { error "Grupo ya existe: $grupo"; return 1; }

  read -r -p "Nombre display (ej: Nuevo Equipo): " display
  read -r -p "Descripción: " desc

  # Linux asigna un GID libre; el catálogo también contiene grupos de sistema.
  sudo groupadd "$grupo" || { error "Error creando grupo Linux"; return 1; }
  gid=$(getent group "$grupo" | cut -d: -f3)
  asegurar_grupo_samba "$grupo" || { echo '[!] Grupo Linux creado, pero falló el registro Samba.' >&2; return 1; }

  created=$(date +%Y-%m-%d)
  echo "${grupo}|${display}|${gid}|${desc}|${created}" >> "$db"

  info "Grupo creado: $grupo (gid=$gid)"
}

equipo_editar() {
  require_root
  local db="$DATA_DIR/equipos.db" grupo nuevo desc opt sid registro
  grupo=$(seleccionar_registro "$db" 'Equipo a editar') || return 1
  echo '1) Renombrar, 2) Cambiar descripción, 3) Ver integrantes, 0) Volver'
  read -r -p 'Opción: ' opt || return 1
  case "$opt" in
    1)
      read -r -p 'Nuevo nombre: ' nuevo || return 1
      [[ "$nuevo" =~ ^[A-Z][A-Z0-9_]*$ ]] && es_grupo_trabajo "$nuevo" || { echo '[!] Nombre de grupo de trabajo inválido.' >&2; return 1; }
      if getent group "$nuevo" >/dev/null; then echo '[!] Ese grupo ya existe.' >&2; return 1; fi
      sid=$(sid_grupo_samba "$grupo") || return 1
      sudo groupmod -n "$nuevo" "$grupo" || return 1
      if ! net groupmap modify "sid=$sid" "unixgroup=$nuevo" "ntgroup=$nuevo"; then
        sudo groupmod -n "$grupo" "$nuevo"
        echo '[!] Falló el cambio Samba; se intentó revertir el nombre Linux.' >&2
        return 1
      fi
      actualizar_campo_db "$db" "$grupo" 1 "$nuevo" || return 1
      actualizar_referencias_grupo "$grupo" "$nuevo" || return 1
      info "Grupo renombrado: $grupo → $nuevo"
      ;;
    2)
      read -r -p 'Nueva descripción: ' desc || return 1
      [[ "$desc" != *'|'* ]] || { echo '[!] La descripción no admite |.' >&2; return 1; }
      sid=$(sid_grupo_samba "$grupo") || return 1
      net groupmap modify "sid=$sid" "comment=$desc" || return 1
      actualizar_campo_db "$db" "$grupo" 4 "$desc" || return 1
      info 'Descripción actualizada en el catálogo y Samba.'
      ;;
    3) equipo_ver_integrantes "$grupo" ;;
    0) return 0 ;;
    *) echo '[!] Opción inválida.' >&2; return 1 ;;
  esac
}

sid_grupo_samba() {
  local mapas sid
  mapas=$(net groupmap list) || return 1
  sid=$(printf '%s\n' "$mapas" | awk -F' -> ' -v grupo="$1" '$2 == grupo {split($1,a,/[()]/); print a[2]; exit}')
  [[ -n "$sid" ]] || { echo '[!] Falta el vínculo Samba del grupo.' >&2; return 1; }
  printf '%s\n' "$sid"
}

actualizar_referencias_grupo() {
  local old="$1" nuevo="$2" db="$DATA_DIR/usuarios.db" temporal
  [[ -f "$db" ]] || return 0
  cp -p "$db" "$db.bak" || return 1
  temporal=$(mktemp "${db}.XXXXXX") || return 1
  awk -F'|' -v OFS='|' -v old="$old" -v nuevo="$nuevo" '
    {if ($3 == old) $3=nuevo; n=split($4,a,","); extra="";
     for(i=1;i<=n;i++) {if(a[i]==old) a[i]=nuevo; if(a[i]!="") extra=extra (extra!="" ? "," : "") a[i]}; $4=extra; print}
  ' "$db" > "$temporal" && chmod --reference="$db" "$temporal" && mv "$temporal" "$db"
}

equipo_eliminar() {
  require_root
  local grupo registro gid miembros sid db="$DATA_DIR/equipos.db" temporal
  grupo=$(seleccionar_registro "$db" 'Equipo a eliminar') || return 1
  registro=$(getent group "$grupo") || return 1
  IFS=: read -r _ _ gid miembros <<< "$registro"
  if [[ -n "$miembros" ]] || getent passwd | awk -F: -v gid="$gid" '$4 == gid {found=1} END {exit !found}'; then
    echo '[!] No se puede eliminar un grupo con miembros primarios o adicionales.' >&2; return 1
  fi
  sid=$(sid_grupo_samba "$grupo") || return 1
  confirm "¿Eliminar $grupo de Linux, Samba y catálogo?" || return 0
  sudo groupdel "$grupo" || return 1
  if ! net groupmap delete "sid=$sid"; then
    sudo groupadd -g "$gid" "$grupo"
    echo '[!] Falló la eliminación Samba; se intentó restaurar el grupo Linux.' >&2; return 1
  fi
  cp -p "$db" "$db.bak" || return 1
  temporal=$(mktemp "${db}.XXXXXX") || return 1
  awk -F'|' -v grupo="$grupo" '$1 != grupo' "$db" > "$temporal" && chmod --reference="$db" "$temporal" && mv "$temporal" "$db" || return 1
  info "Grupo eliminado: $grupo"
}
equipo_ver_integrantes() {
  local grupo="${1:-}"
  local db="${DATA_DIR}/equipos.db"
  local usuarios_db="${DATA_DIR}/usuarios.db"

  if [[ -z "$grupo" ]]; then
    grupo=$(seleccionar_registro "$db" 'Ver integrantes de equipos' todos) || return 1
  fi

  [[ -z "$grupo" ]] && return 1
  if [[ "$grupo" == __TODOS__ ]]; then
    local equipo display resto
    while IFS='|' read -r equipo display resto; do
      [[ -z "$equipo" || "$equipo" == \#* ]] && continue
      equipo_ver_integrantes "$equipo"
    done < "$db"
    return 0
  fi
  grep -q "^${grupo}|" "$db" || { error "Grupo no existe"; return 1; }

  echo ""
  echo "=== Integrantes de $grupo ==="
  echo "Usuario             | Nombre                          | Grupo Primario"
  echo "--------------------|----------------------------------|---------------"

  local user full_name prim_grupo extra_groups uid created extra encontrados=0
  while IFS='|' read -r user full_name prim_grupo extra_groups uid created extra; do
    [[ -z "$user" || "$user" =~ ^# ]] && continue

    # Listar este usuario si está en el grupo (primario o adicional)
    if [[ "$prim_grupo" == "$grupo" ]] || [[ ",$extra_groups," == *",$grupo,"* ]]; then
      printf "%-19s | %-32s | %s\n" "$user" "$full_name" "$prim_grupo"
      encontrados=$((encontrados+1))
    fi
  done < "$usuarios_db"
  ((encontrados)) || echo '  Sin integrantes registrados.'
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
