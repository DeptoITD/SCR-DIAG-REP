#!/bin/bash
# importar.sh — Importar/replicar configuración (CORRIGE BUG DE GRUPOS VACÍOS)

[[ -z "$REPO_PATH" ]] && source "$(dirname "$0")/../config/servers.env"
[[ -z "$log" ]] && source "$(dirname "$0")/../utils.sh"

importar_run() {
  require_root
  source "$(dirname "$0")/equipos.sh"
  source "$(dirname "$0")/usuarios.sh"

  local export_dir
  local from_nas=false

  # Opción: local o NAS
  echo ""
  if [[ "$NAS_ENABLED" == "true" && -d "$NAS_EXPORT_PATH" ]]; then
    echo "Fuentes disponibles:"
    echo "  1) Local ($EXPORT_PATH)"
    echo "  2) NAS ($NAS_EXPORT_PATH)"
    read -r -p "Seleccione fuente [1|2]: " source_opt
    if [[ "$source_opt" == "2" ]]; then
      from_nas=true
      export_base="$NAS_EXPORT_PATH"
    else
      export_base="$EXPORT_PATH"
    fi
  else
    export_base="$EXPORT_PATH"
  fi

  # Seleccionar carpeta
  echo ""
  echo "Carpetas disponibles en $export_base:"
  ls -d "$export_base"/export_* 2>/dev/null | nl
  read -r -p "Seleccione número de carpeta: " num
  export_dir=$(ls -d "$export_base"/export_* 2>/dev/null | sed -n "${num}p")

  [[ -d "$export_dir" ]] || { error "Carpeta no válida"; return 1; }

  log "Importando desde: $export_dir"

  # Verificar archivos
  [[ -f "$export_dir/usuarios.db" ]] || { error "Falta usuarios.db"; return 1; }
  [[ -f "$export_dir/equipos.db" ]] || { error "Falta equipos.db"; return 1; }

  # Crear grupos (de equipos.db exportado)
  echo ""
  info "Creando grupos..."
  while IFS='|' read -r grupo display gid desc created; do
    [[ -z "$grupo" || "$grupo" =~ ^# ]] && continue

    if getent group "$grupo" &>/dev/null; then
      echo "  [OK] Grupo existente: $grupo"
    else
      sudo groupadd -g "$gid" "$grupo" 2>/dev/null && echo "  [OK] Grupo creado: $grupo" || echo "  [!] Error en $grupo"
    fi
  done < "$export_dir/equipos.db"

  # Crear usuarios (DE usuarios.db exportado, usando las funciones de usuarios.sh)
  echo ""
  info "Creando usuarios..."
  local created_count=0 existing_count=0 error_count=0

  while IFS='|' read -r user full_name prim_grupo extra_groups uid created_field extra_flags; do
    [[ -z "$user" || "$user" =~ ^# ]] && continue

    if id "$user" &>/dev/null; then
      echo "  [OK] Usuario existente: $user"
      ((existing_count++))
    else
      # Crear usuario
      sudo useradd -m -u "$uid" -g "$prim_grupo" -c "$full_name" "$user" 2>/dev/null
      if [[ $? -eq 0 ]]; then
        # Password random
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

        echo "  [OK] Usuario creado: $user (uid=$uid)"
        mostrar_password_generada "$user" "$pass"
        ((created_count++))
      else
        echo "  [!] Error creando: $user"
        ((error_count++))
      fi
    fi
  done < "$export_dir/usuarios.db"

  echo ""
  echo "=== RESUMEN IMPORTACIÓN ==="
  echo "Usuarios creados: $created_count"
  echo "Usuarios ya existentes: $existing_count"
  echo "Errores: $error_count"
  echo ""

  if [[ "$from_nas" == "true" ]]; then
    info "✓ Importación desde NAS completada (replicación distribuida)"
  else
    info "✓ Importación local completada"
  fi

  info "Exportación origen: $(basename $export_dir)"
}
