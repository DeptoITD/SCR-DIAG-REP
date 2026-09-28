#!/bin/bash
# sync.sh — Gestión de sincronización con NAS

[[ -z "$REPO_PATH" ]] && source "$(dirname "$0")/../config/servers.env"
[[ -z "$log" ]] && source "$(dirname "$0")/../utils.sh"

sync_check_nas() {
  if [[ ! -d "$NAS_MOUNT_POINT" ]]; then
    error "NAS no montado en: $NAS_MOUNT_POINT"
    return 1
  fi

  if ! touch "$NAS_EXPORT_PATH"/.test 2>/dev/null; then
    error "NAS no escribible. Verificar permisos en: $NAS_EXPORT_PATH"
    return 1
  fi
  rm -f "$NAS_EXPORT_PATH"/.test

  info "✓ NAS accesible y escribible: $NAS_EXPORT_PATH"
  return 0
}

sync_push_local_to_nas() {
  require_root

  sync_check_nas || return 1

  if [[ ! -d "$EXPORT_PATH" ]] || [[ -z "$(ls -d "$EXPORT_PATH"/export_* 2>/dev/null)" ]]; then
    warn "No hay exportaciones locales para sincronizar"
    return 0
  fi

  info "Sincronizando exportaciones locales → NAS..."
  local count=0

  for export_dir in "$EXPORT_PATH"/export_*; do
    [[ ! -d "$export_dir" ]] && continue

    local export_name=$(basename "$export_dir")
    if ! [[ -d "$NAS_EXPORT_PATH/$export_name" ]]; then
      cp -r "$export_dir" "$NAS_EXPORT_PATH/" && ((count++))
      echo "  [✓] $export_name"
    fi
  done

  info "Sincronizadas: $count exportaciones nuevas"
}

sync_list_all() {
  echo ""
  echo "=== EXPORTACIONES LOCALES ==="
  if [[ -d "$EXPORT_PATH" ]]; then
    ls -lhd "$EXPORT_PATH"/export_* 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    echo "  Total local: $(ls -d "$EXPORT_PATH"/export_* 2>/dev/null | wc -l)"
  else
    echo "  (ninguna)"
  fi

  echo ""
  echo "=== EXPORTACIONES NAS ==="
  if [[ -d "$NAS_EXPORT_PATH" ]]; then
    ls -lhd "$NAS_EXPORT_PATH"/export_* 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    echo "  Total NAS: $(ls -d "$NAS_EXPORT_PATH"/export_* 2>/dev/null | wc -l)"
  else
    warn "NAS no accesible o sin exportaciones"
  fi
  echo ""
}

sync_cleanup_old() {
  require_root

  local days=${1:-30}

  echo ""
  info "Buscando exportaciones más antiguas que $days días..."
  echo ""

  # Local
  echo "Locales a eliminar:"
  find "$EXPORT_PATH" -maxdepth 1 -type d -name 'export_*' -mtime +$days 2>/dev/null | while read dir; do
    echo "  $dir"
  done

  # NAS
  echo "NAS a eliminar:"
  find "$NAS_EXPORT_PATH" -maxdepth 1 -type d -name 'export_*' -mtime +$days 2>/dev/null | while read dir; do
    echo "  $dir"
  done

  echo ""
  if confirm "¿Eliminar estos directorios?"; then
    find "$EXPORT_PATH" -maxdepth 1 -type d -name 'export_*' -mtime +$days -exec rm -rf {} \; 2>/dev/null
    find "$NAS_EXPORT_PATH" -maxdepth 1 -type d -name 'export_*' -mtime +$days -exec rm -rf {} \; 2>/dev/null
    info "✓ Limpieza completada"
  fi
  echo ""
}

menu_sync() {
  while true; do
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  Gestión NAS & Sincronización         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "1. Verificar estado NAS"
    echo "2. Sincronizar local → NAS"
    echo "3. Listar todas las exportaciones"
    echo "4. Limpiar exportaciones antiguas"
    echo "5. Volver"
    echo ""
    read -r -p "Seleccione opción: " opt

    case "$opt" in
      1) sync_check_nas ;;
      2) sync_push_local_to_nas ;;
      3) sync_list_all ;;
      4) sync_cleanup_old 30 ;;
      5) break ;;
      *) echo "[!] Opción inválida" ;;
    esac
  done
}
