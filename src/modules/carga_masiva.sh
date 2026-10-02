#!/bin/bash
# carga_masiva.sh — Carga masiva de usuarios desde archivo
# Lee CSV/JSON, valida contra identidades.ini, genera outputs para servidor/NAS
# Integrado a menu.sh → menu_usuarios → opción nueva

if [[ "$(type -t log)" != "function" ]]; then
  source "${REPO_PATH:-$(dirname "$0")/..}/config/servers.env" 2>/dev/null || source "$(dirname "$0")/../config/servers.env"
  source "${REPO_PATH:-$(dirname "$0")/..}/src/utils.sh" 2>/dev/null || source "$(dirname "$0")/../utils.sh"
fi

# ============================================================================
# Helpers CSV → JSON
# ============================================================================

trim() {
  local var="$*"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

# Parsea CSV minimalista: campo1|campo2|campo3
# Ignora líneas vacías y comentarios (#)
parse_csv_line() {
  local line="$1"
  [[ -z "$line" || "$line" =~ ^# ]] && return 1
  echo "$line"
}

# ============================================================================
# Validación
# ============================================================================

validar_usuario() {
  local user="$1"
  [[ -z "$user" ]] && { echo "Usuario vacío"; return 1; }
  [[ ! "$user" =~ ^[a-z0-9._-]+$ ]] && { echo "Usuario inválido (caracteres): $user"; return 1; }
  return 0
}

validar_grupo() {
  local grupo="$1" equipos_db="${2:-${DATA_DIR}/equipos.db}"
  [[ -z "$grupo" ]] && { echo "Grupo vacío"; return 1; }
  # Buscar en equipos.db (líneas que no sean comentario ni vacías)
  grep -v '^#' "$equipos_db" | grep -v '^$' | cut -d'|' -f1 | grep -q "^${grupo}$" && return 0
  echo "Grupo no existe en equipos.db: $grupo"
  return 1
}

validar_dominio() {
  local dominio="$1"
  [[ -z "$dominio" ]] && { echo "Dominio vacío"; return 1; }
  # Dominios válidos por ahora: PROYECTOS, ADM, COM (expandible)
  case "$dominio" in
    PROYECTOS|ADM|COM) return 0 ;;
    *) echo "Dominio desconocido: $dominio (válidos: PROYECTOS, ADM, COM)"; return 1 ;;
  esac
}

# ============================================================================
# Lectura de archivo
# ============================================================================

leer_csv() {
  local archivo="$1"
  [[ ! -f "$archivo" ]] && { error "Archivo no encontrado: $archivo"; return 1; }

  echo ""
  echo "=== Lectura de archivo: $archivo ==="
  echo ""

  local linea_num=0
  local usuarios_leidos=0
  declare -a usuarios=()
  declare -a errores=()

  while IFS= read -r linea; do
    ((linea_num++))

    # Saltar vacías y comentarios
    linea=$(trim "$linea")
    [[ -z "$linea" || "$linea" =~ ^# ]] && continue

    # Parse CSV: usuario|nombre|grupo|dominio (campos mínimos)
    IFS='|' read -r usuario nombre grupo dominio <<< "$linea"

    usuario=$(trim "$usuario")
    nombre=$(trim "$nombre")
    grupo=$(trim "$grupo")
    dominio=$(trim "$dominio")

    # Validación
    validar_usuario "$usuario" || { errores+=("Línea $linea_num: usuario $usuario — $(validar_usuario "$usuario")"); continue; }
    validar_grupo "$grupo" || { errores+=("Línea $linea_num: grupo $grupo — $(validar_grupo "$grupo")"); continue; }
    validar_dominio "$dominio" || { errores+=("Línea $linea_num: dominio $dominio — $(validar_dominio "$dominio")"); continue; }

    # Usuario ya existe en Linux?
    if id "$usuario" &>/dev/null; then
      warn "Línea $linea_num: $usuario ya existe en Linux. Se saltará en aplicación."
    fi

    usuarios+=("$usuario|$nombre|$grupo|$dominio")
    ((usuarios_leidos++))
  done < "$archivo"

  # Resumen
  if [[ ${#errores[@]} -gt 0 ]]; then
    echo "[!] Errores encontrados:"
    printf '  %s\n' "${errores[@]}"
    echo ""
  fi

  echo "[+] Usuarios leídos: $usuarios_leidos"
  echo ""

  if [[ $usuarios_leidos -eq 0 ]]; then
    error "Ningún usuario válido en archivo"
    return 1
  fi

  # Mostrar resumen
  echo "Usuarios a procesar:"
  printf "%-20s | %-30s | %-15s | %-12s\n" "Usuario" "Nombre" "Grupo" "Dominio"
  printf "%-20s | %-30s | %-15s | %-12s\n" "$(printf '=%.0s' {1..19})" "$(printf '=%.0s' {1..29})" "$(printf '=%.0s' {1..14})" "$(printf '=%.0s' {1..11})"
  for u in "${usuarios[@]}"; do
    IFS='|' read -r user name grp dom <<< "$u"
    printf "%-20s | %-30s | %-15s | %-12s\n" "$user" "$name" "$grp" "$dom"
  done
  echo ""

  # Exportar array a variable global
  USUARIOS_LEIDOS=("${usuarios[@]}")
  ERRORES_LEIDOS=("${errores[@]}")
  return 0
}

# ============================================================================
# Generación JSON para servidor/NAS
# ============================================================================

generar_json_servidor() {
  local archivo_out="$1"
  shift
  local usuarios=("$@")

  cat > "$archivo_out" <<'EOF'
{
  "target": "servidor",
  "usuarios": [
EOF

  local primero=1
  for u in "${usuarios[@]}"; do
    IFS='|' read -r usuario nombre grupo dominio <<< "$u"

    [[ $primero -eq 0 ]] && echo "," >> "$archivo_out"
    cat >> "$archivo_out" <<EOJSON
    {
      "usuario": "$usuario",
      "nombre": "$nombre",
      "grupo_primario": "$grupo",
      "dominio": "$dominio"
    }
EOJSON
    primero=0
  done

  cat >> "$archivo_out" <<'EOF'
  ]
}
EOF

  info "JSON servidor: $archivo_out"
}

generar_json_nas() {
  local archivo_out="$1"
  shift
  local usuarios=("$@")

  cat > "$archivo_out" <<'EOF'
{
  "target": "nas",
  "usuarios": [
EOF

  local primero=1
  for u in "${usuarios[@]}"; do
    IFS='|' read -r usuario nombre grupo dominio <<< "$u"

    [[ $primero -eq 0 ]] && echo "," >> "$archivo_out"
    cat >> "$archivo_out" <<EOJSON
    {
      "usuario": "$usuario",
      "nombre": "$nombre",
      "grupo_primario": "$grupo",
      "dominio": "$dominio"
    }
EOJSON
    primero=0
  done

  cat >> "$archivo_out" <<'EOF'
  ]
}
EOF

  info "JSON NAS: $archivo_out"
}

# ============================================================================
# Workflow principal
# ============================================================================

carga_masiva_workflow() {
  local archivo csv_out json_servidor json_nas

  echo ""
  echo "=== Carga Masiva de Usuarios ==="
  echo ""
  echo "Formato entrada: CSV con columnas:"
  echo "  usuario|nombre|grupo|dominio"
  echo ""
  echo "Ejemplo:"
  echo "  julian.ochoa|Julian Ochoa|IND_GEN|PROYECTOS"
  echo "  maria.admin|Maria Admin|ADM_SYSADMIN|ADM"
  echo ""

  read -r -p "Ruta del archivo CSV: " archivo
  [[ -z "$archivo" ]] && { error "Archivo requerido"; return 1; }

  # Expandir ~
  archivo="${archivo/#\~/$HOME}"

  leer_csv "$archivo" || return 1

  # Confirmar
  echo ""
  confirm "¿Proceder con carga masiva de ${#USUARIOS_LEIDOS[@]} usuarios?" || { info "Cancelado"; return 0; }

  # Generar JSON outputs
  csv_out="${EXPORT_PATH}/usuarios_entrada.csv"
  json_servidor="${EXPORT_PATH}/usuarios_servidor.json"
  json_nas="${EXPORT_PATH}/usuarios_nas.json"

  mkdir -p "$EXPORT_PATH"

  # Guardar CSV procesado (auditoría)
  {
    echo "# Entrada procesada — $(date)"
    echo "usuario|nombre|grupo|dominio"
    printf '%s\n' "${USUARIOS_LEIDOS[@]}"
  } > "$csv_out"
  info "CSV procesado: $csv_out"

  # Generar JSONs
  generar_json_servidor "$json_servidor" "${USUARIOS_LEIDOS[@]}"
  generar_json_nas "$json_nas" "${USUARIOS_LEIDOS[@]}"

  # Instrucciones siguientes
  echo ""
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║  PRÓXIMO PASO: Aplicar en Servidor y/o NAS            ║"
  echo "╚════════════════════════════════════════════════════════╝"
  echo ""
  echo "1. SERVIDOR (srv-2):"
  echo "   Copiar: $json_servidor → /tmp/usuarios_servidor.json"
  echo "   Ejecutar: sudo bash src/servidor/carga_masiva_aplicar.sh /tmp/usuarios_servidor.json --dry-run"
  echo ""
  echo "2. NAS:"
  echo "   Copiar: $json_nas → /tmp/usuarios_nas.json"
  echo "   Ejecutar: sudo bash src/nas/carga_masiva_aplicar.sh /tmp/usuarios_nas.json --dry-run"
  echo ""
  echo "Archivos generados en: $EXPORT_PATH"
  echo ""
}

menu_carga_masiva() {
  while true; do
    echo ""
    echo "=== Carga Masiva ==="
    echo "1. Cargar usuarios desde archivo"
    echo "2. Ver último CSV procesado"
    echo "3. Volver"
    read -r -p "Opción: " opt

    case "$opt" in
      1) carga_masiva_workflow ;;
      2)
        local csv_out="${EXPORT_PATH}/usuarios_entrada.csv"
        if [[ -f "$csv_out" ]]; then
          head -20 "$csv_out"
          echo ""
          echo "(primeras 20 líneas)"
        else
          error "No hay CSV procesado"
        fi
        ;;
      3) break ;;
      *) error_soft "Opción inválida" ;;
    esac
  done
}

error_soft() {
  echo "[!] $1" >&2
}
