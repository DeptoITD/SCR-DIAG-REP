#!/bin/bash
# identidades/carga_masiva.sh v1.0 — Carga masiva CSV (llama core)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/core/comun.sh"
source "$SCRIPT_DIR/core/config.sh"
source "$SCRIPT_DIR/core/usuarios_core.sh"
source "$SCRIPT_DIR/core/grupos_core.sh"
source "$SCRIPT_DIR/core/samba_core.sh"

trim() {
  local var="$*"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

validar_dominio() {
  local dom="$1"
  [[ -z "$dom" ]] && error "Dominio vacío"
  case "$dom" in
    COR|OPE|COM) return 0 ;;
    *) error "Dominio inválido: $dom (válidos: COR/OPE/COM)" ;;
  esac
}

carga_masiva_run() {
  require_root
  validar_config

  echo "=== Carga Masiva Usuarios ==="
  read -r -p "Ruta CSV (usuario|nombre|grupo|dominio|uid|password): " csv
  [[ ! -f "$csv" ]] && error "No existe: $csv"

  echo ""
  echo "[DRY-RUN] Validando archivo..."
  
  local created=0 exist=0 error_cnt=0
  
  while IFS'|' read -r user nombre grupo dominio uid pass; do
    [[ -z "$user" || "$user" =~ ^# ]] && continue
    
    user=$(trim "$user")
    nombre=$(trim "$nombre")
    grupo=$(trim "$grupo")
    dominio=$(trim "$dominio")
    uid=$(trim "$uid")
    pass=$(trim "$pass")

    # Validaciones
    [[ -z "$pass" || ${#pass} -lt 12 ]] && { 
      warn "Línea $user: contraseña < 12 chars"; 
      ((error_cnt++))
      continue 
    }

    if id "$user" &>/dev/null; then
      echo "  [EXISTE] $user"
      ((exist++))
    else
      validar_dominio "$dominio" || { ((error_cnt++)); continue; }
      grupo_existe "$grupo" || { warn "Grupo no existe: $grupo"; ((error_cnt++)); continue; }
      echo "  [CREAR] $user (uid=$uid, dominio=$dominio)"
      ((created++))
    fi
  done < "$csv"

  echo ""
  echo "Resumen:"
  echo "  A crear: $created"
  echo "  Ya existen: $exist"
  echo "  Errores: $error_cnt"
  echo ""
  
  confirm "¿Aplicar?" || return 0

  # Backup
  bak=$(backup_critico)
  log "Backup: $bak"

  # Aplicar
  while IFS'|' read -r user nombre grupo dominio uid pass; do
    [[ -z "$user" || "$user" =~ ^# ]] && continue
    
    user=$(trim "$user")
    nombre=$(trim "$nombre")
    grupo=$(trim "$grupo")
    dominio=$(trim "$dominio")
    uid=$(trim "$uid")
    pass=$(trim "$pass")

    id "$user" &>/dev/null && continue

    # Validar dominio existe como grupo
    validar_dominio "$dominio"
    grupo_existe "$grupo" || { warn "Grupo no existe: $grupo"; continue; }
    grupo_existe "$dominio" || {
      info "Creando grupo dominio: $dominio"
      gid=$(leer_dominios | grep "^${dominio}|" | cut -d'|' -f3)
      crear_grupo "$dominio" "$gid" || true
    }

    # Crear Linux
    crear_usuario "$user" "$uid" "$grupo" "$nombre" || {
      error_cnt=$((error_cnt+1))
      continue
    }

    # Contraseña Linux
    cambiar_contraseña "$user" "$pass"

    # Samba
    crear_cuenta_samba "$user" "$pass"

    # Dominio como grupo secundario
    agregar_grupo_secundario "$user" "$dominio" || true

    info "✓ Usuario completado: $user"
  done < "$csv"

  log "Carga masiva completada"
  confirm "¿Rollback?" && { rollback_linux "$bak"; rollback_samba "$bak"; }
}

carga_masiva_run
