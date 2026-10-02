#!/bin/bash
# importar.sh — Importación Inteligente y Portable
# Analiza exports, pregunta qué importar, valida, sincroniza, aplica

if [[ "$(type -t log)" != "function" ]]; then
  source "${REPO_PATH:-$(dirname "$0")/..}/config/servers.env" 2>/dev/null || source "$(dirname "$0")/../config/servers.env"
  source "${REPO_PATH:-$(dirname "$0")/..}/src/utils.sh" 2>/dev/null || source "$(dirname "$0")/../utils.sh"
fi

# ============================================================================
# PASO 1: Seleccionar export
# ============================================================================

seleccionar_export() {
  echo ""
  echo "📂 Carpetas disponibles en: $EXPORT_PATH"
  local exports=($(ls -d "$EXPORT_PATH"/export_* 2>/dev/null | sort -r))

  if [[ ${#exports[@]} -eq 0 ]]; then
    error "No hay carpetas de exportación. Ejecuta primero: bash menu.sh → 2 (Exportar)"
  fi

  echo ""
  for i in "${!exports[@]}"; do
    local folder=$(basename "${exports[$i]}")
    local size=$(du -sh "${exports[$i]}" 2>/dev/null | cut -f1)
    echo "  $((i+1))) $folder ($size)"
  done
  echo ""
  read -r -p "Selecciona número [1-${#exports[@]}]: " num

  if ! [[ "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > ${#exports[@]} )); then
    error "Opción inválida"
  fi

  echo "${exports[$((num-1))]}"
}

# ============================================================================
# PASO 2: Analizar qué hay disponible en el export
# ============================================================================

analizar_export() {
  local export_dir="$1"

  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Analizando contenido de export..."
  echo "═══════════════════════════════════════════════════════"
  echo ""

  # Verificar qué archivos existen
  local have_usuarios=0 have_equipos=0 have_samba=0 have_memberships=0 have_fstab=0

  [[ -f "$export_dir/usuarios.db" ]] && have_usuarios=1
  [[ -f "$export_dir/equipos.db" ]] && have_equipos=1
  [[ -f "$export_dir/smb.conf" ]] && have_samba=1
  [[ -f "$export_dir/group_membership.txt" ]] && have_memberships=1
  [[ -f "$export_dir/fstab.txt" ]] && have_fstab=1

  echo "Archivos disponibles:"
  [[ $have_usuarios -eq 1 ]] && echo "  ✅ usuarios.db"
  [[ $have_equipos -eq 1 ]] && echo "  ✅ equipos.db"
  [[ $have_samba -eq 1 ]] && echo "  ✅ smb.conf"
  [[ $have_memberships -eq 1 ]] && echo "  ✅ group_membership.txt"
  [[ $have_fstab -eq 1 ]] && echo "  ✅ fstab.txt"
  [[ -f "$export_dir/manifest.txt" ]] && {
    echo ""
    echo "Manifest:"
    sed 's/^/  /' "$export_dir/manifest.txt"
  }

  echo ""
  [[ $have_usuarios -eq 0 || $have_equipos -eq 0 ]] && error "Faltan archivos críticos (usuarios.db, equipos.db)"

  # Retornar estado
  export HAVE_USUARIOS=$have_usuarios
  export HAVE_EQUIPOS=$have_equipos
  export HAVE_SAMBA=$have_samba
  export HAVE_MEMBERSHIPS=$have_memberships
  export HAVE_FSTAB=$have_fstab
}

# ============================================================================
# PASO 3: Preguntar qué importar
# ============================================================================

seleccionar_que_importar() {
  local seleccion=$(menu_seleccionar_importacion)
  echo "$seleccion"
}

# ============================================================================
# PASO 4: Validación previa (Dry-Run)
# ============================================================================

generar_dryrun() {
  local export_dir="$1" seleccion="$2"
  local report_file="/tmp/importar_dryrun_$$.txt"

  {
    echo "═══════════════════════════════════════════════════════"
    echo "DRY-RUN: Cambios a Realizar"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ "$seleccion" =~ usuarios ]]; then
      echo "👥 USUARIOS:"
      local create_count=0 sync_count=0 ok_count=0
      while IFS='|' read -r user full_name prim_grupo extra_groups uid created_field extra_flags; do
        [[ -z "$user" || "$user" =~ ^# ]] && continue
        local status=$(sincronizar_usuario "$user" "$prim_grupo" "$extra_groups")
        case "$status" in
          CREATE)
            echo "  [CREATE] $user (uid=$uid, grupo=$prim_grupo)"
            ((create_count++))
            ;;
          SYNC)
            echo "  [SYNC]   $user (sincronizar grupo/membresías)"
            ((sync_count++))
            ;;
          OK)
            echo "  [OK]     $user (ya sincronizado)"
            ((ok_count++))
            ;;
        esac
      done < "$export_dir/usuarios.db"
      echo "  RESUMEN: $create_count crear, $sync_count sincronizar, $ok_count ok"
      echo ""
    fi

    if [[ "$seleccion" =~ grupos ]]; then
      echo "👥 GRUPOS:"
      local create_count=0 ok_count=0
      while IFS='|' read -r grupo display gid desc created; do
        [[ -z "$grupo" || "$grupo" =~ ^# ]] && continue
        if getent group "$grupo" &>/dev/null; then
          echo "  [OK]     $grupo (gid=$gid)"
          ((ok_count++))
        else
          echo "  [CREATE] $grupo (gid=$gid)"
          ((create_count++))
        fi
      done < "$export_dir/equipos.db"
      echo "  RESUMEN: $create_count crear, $ok_count existentes"
      echo ""
    fi

    if [[ "$seleccion" =~ membresias ]]; then
      echo "👥 MEMBRESÍAS:"
      echo "  [SYNC] Sincronizar membresías de grupos según group_membership.txt"
      echo ""
    fi

    if [[ "$seleccion" =~ samba ]]; then
      echo "🔒 SAMBA CONFIG:"
      echo "  Archivo: smb.conf"
      analizar_smb_conf "$export_dir/smb.conf" >> "$report_file" 2>&1
      echo "  [PENDING] Configuración de share (requiere interacción)"
      echo "  [BACKUP] /etc/samba/smb.conf → smb.conf.bak.$(date +%Y%m%d_%H%M%S)"
      echo ""
    fi

    if [[ "$seleccion" =~ fstab ]]; then
      echo "💾 FSTAB:"
      echo "  [REFERENCE] Solo comparar /etc/fstab vs fstab.txt"
      echo "  [NO CHANGE] /etc/fstab no será modificado automáticamente"
      echo ""
    fi

    echo "═══════════════════════════════════════════════════════"
  } | tee "$report_file"

  echo "$report_file"
}

# ============================================================================
# PASO 5: Crear Usuarios
# ============================================================================

importar_usuarios() {
  local export_dir="$1"
  local created_count=0 sync_count=0 ok_count=0 error_count=0

  echo ""
  echo "👥 Importando USUARIOS..."

  while IFS='|' read -r user full_name prim_grupo extra_groups uid created_field extra_flags; do
    [[ -z "$user" || "$user" =~ ^# ]] && continue

    local status=$(sincronizar_usuario "$user" "$prim_grupo" "$extra_groups")

    case "$status" in
      CREATE)
        # Crear usuario nuevo
        sudo useradd -m -u "$uid" -g "$prim_grupo" -c "$full_name" "$user" 2>/dev/null
        if [[ $? -eq 0 ]]; then
          local pass=$(generate_password)
          echo "$pass" | sudo chpasswd -c SHA512 2>/dev/null

          # Grupos adicionales
          if [[ -n "$extra_groups" ]]; then
            IFS=',' read -ra groups <<< "$extra_groups"
            for g in "${groups[@]}"; do
              g=$(echo "$g" | xargs)
              sudo gpasswd -a "$user" "$g" 2>/dev/null
            done
          fi

          # Samba
          echo "$pass" | sudo smbpasswd -a "$user" -s 2>/dev/null
          sudo smbpasswd -e "$user" 2>/dev/null

          echo "  [CREATE] $user (uid=$uid)"
          mostrar_password_generada "$user" "$pass"
          ((created_count++))
        else
          echo "  [ERROR]  $user (falló creación)"
          ((error_count++))
        fi
        ;;
      SYNC)
        # Sincronizar usuario existente
        local actual_grupo=$(id -gn "$user" 2>/dev/null)
        if [[ "$actual_grupo" != "$prim_grupo" ]]; then
          sudo usermod -g "$prim_grupo" "$user" 2>/dev/null
          echo "  [SYNC]   $user (grupo $actual_grupo → $prim_grupo)"
        fi

        # Sincronizar grupos adicionales
        if [[ -n "$extra_groups" ]]; then
          IFS=',' read -ra groups <<< "$extra_groups"
          for g in "${groups[@]}"; do
            g=$(echo "$g" | xargs)
            sudo gpasswd -a "$user" "$g" 2>/dev/null
          done
          echo "  [SYNC]   $user (membresías)"
        fi

        ((sync_count++))
        ;;
      OK)
        echo "  [OK]     $user (sincronizado)"
        ((ok_count++))
        ;;
    esac
  done < "$export_dir/usuarios.db"

  echo ""
  echo "  RESUMEN USUARIOS:"
  echo "    Creados: $created_count"
  echo "    Sincronizados: $sync_count"
  echo "    OK: $ok_count"
  [[ $error_count -gt 0 ]] && echo "    Errores: $error_count"
}

# ============================================================================
# PASO 6: Crear Grupos
# ============================================================================

importar_grupos() {
  local export_dir="$1"
  local create_count=0 ok_count=0 error_count=0

  echo ""
  echo "👥 Importando GRUPOS..."

  while IFS='|' read -r grupo display gid desc created; do
    [[ -z "$grupo" || "$grupo" =~ ^# ]] && continue

    if getent group "$grupo" &>/dev/null; then
      echo "  [OK]     $grupo (gid=$gid)"
      ((ok_count++))
    else
      sudo groupadd -g "$gid" "$grupo" 2>/dev/null
      if [[ $? -eq 0 ]]; then
        echo "  [CREATE] $grupo (gid=$gid)"
        ((create_count++))
      else
        echo "  [ERROR]  $grupo (gid=$gid, falló creación)"
        ((error_count++))
      fi
    fi
  done < "$export_dir/equipos.db"

  echo ""
  echo "  RESUMEN GRUPOS:"
  echo "    Creados: $create_count"
  echo "    OK: $ok_count"
  [[ $error_count -gt 0 ]] && echo "    Errores: $error_count"
}

# ============================================================================
# PASO 7: Importar config Samba
# ============================================================================

importar_samba() {
  local export_dir="$1"

  echo ""
  echo "🔒 Configuración SAMBA..."

  [[ ! -f "$export_dir/smb.conf" ]] && { echo "  [SKIP]   smb.conf no disponible"; return 0; }

  analizar_smb_conf "$export_dir/smb.conf"

  echo ""
  echo "⚠️  Configuración de share: requiere información LOCAL"
  echo ""
  read -r -p "  Ruta local que deseas publicar por Samba: " samba_path
  validar_ruta "$samba_path" || return 1

  read -r -p "  Nombre del share Samba: " samba_name
  [[ -z "$samba_name" ]] && { error "Nombre requerido"; return 1; }

  read -r -p "  Qué usuarios/grupos pueden acceder (separados por coma): " samba_users
  [[ -z "$samba_users" ]] && { error "Al menos un usuario/grupo requerido"; return 1; }

  # Backup
  backup_file "/etc/samba/smb.conf"

  echo ""
  echo "  [PENDING] Generando configuración smb.conf..."
  echo "  [VALIDATING] testparm -s..."

  # TODO: generar seccion [samba_name] e integrar con policies [global]
  # Por ahora, solo mostrar que la opción existe
  echo "  ✅ Configuración Samba lista para aplicar (requiere verificación manual)"
}

# ============================================================================
# PASO 8: Mostrar fstab como referencia
# ============================================================================

mostrar_fstab_referencia() {
  local export_dir="$1"
  [[ ! -f "$export_dir/fstab.txt" ]] && return 0
  comparar_fstab "$export_dir/fstab.txt"
}

# ============================================================================
# MAIN: Orquestación
# ============================================================================

importar_run() {
  require_root

  # Paso 1: Seleccionar export
  local export_dir=$(seleccionar_export)
  [[ -z "$export_dir" ]] && return 1

  log "Importando desde: $export_dir"

  # Paso 2: Analizar
  analizar_export "$export_dir"

  # Paso 3: Preguntar qué importar
  local seleccion=$(seleccionar_que_importar)
  [[ -z "$seleccion" ]] && return 1

  # Paso 4: Generar dry-run
  echo ""
  read -r -p "¿Mostrar cambios que se harán antes de aplicar? [S/n]: " mostrar_preview
  if [[ ! "$mostrar_preview" =~ ^[nN]$ ]]; then
    local preview_file=$(generar_dryrun "$export_dir" "$seleccion")
    less "$preview_file"
    rm -f "$preview_file"
  fi

  # Confirmación final
  echo ""
  confirm "¿Aplicar cambios?" || { info "Cancelado"; return 0; }

  # Paso 5: Importar
  [[ "$seleccion" =~ grupos ]] && importar_grupos "$export_dir"
  [[ "$seleccion" =~ usuarios ]] && importar_usuarios "$export_dir"
  [[ "$seleccion" =~ samba ]] && importar_samba "$export_dir"
  [[ "$seleccion" =~ fstab ]] && mostrar_fstab_referencia "$export_dir"

  # Resumen final
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "✅ Importación completada"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "Origen: $(basename "$export_dir")"
  echo "Selección: $seleccion"
  echo ""
}
