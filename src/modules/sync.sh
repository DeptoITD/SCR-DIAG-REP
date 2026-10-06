#!/bin/bash
# sync.sh — Listar exportaciones disponibles (sin NAS, copiar manualmente)

if [[ "$(type -t log)" != function ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/iniciar.sh" || return 1
fi

sync_list_all() {
  echo ""
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║         EXPORTACIONES DISPONIBLES                      ║"
  echo "╚════════════════════════════════════════════════════════╝"
  echo ""
  echo "📂 Ubicación: $EXPORT_PATH"
  echo ""

  if [[ -d "$EXPORT_PATH" ]]; then
    local count=$(ls -d "$EXPORT_PATH"/export_* 2>/dev/null | wc -l)
    if [[ $count -gt 0 ]]; then
      ls -lhd "$EXPORT_PATH"/export_* 2>/dev/null | awk '{print "   📁 " $9 " (" $5 ")"}'
      echo ""
      echo "Total: $count exportación/es"
    else
      echo "   (vacío - ejecuta primero: Exportar)"
    fi
  else
    echo "   (carpeta no existe)"
  fi
  echo ""
}

sync_cleanup_old() {
  require_root

  local days=${1:-30}

  echo ""
  info "Buscando exportaciones más antiguas que $days días..."
  echo ""

  local to_delete=($(find "$EXPORT_PATH" -maxdepth 1 -type d -name 'export_*' -mtime +$days 2>/dev/null))

  if [[ ${#to_delete[@]} -eq 0 ]]; then
    echo "   No hay exportaciones antiguas"
    echo ""
    return 0
  fi

  echo "A eliminar:"
  for dir in "${to_delete[@]}"; do
    echo "  🗑️  $dir"
  done
  echo ""

  if confirm "¿Eliminar?"; then
    for dir in "${to_delete[@]}"; do
      rm -rf "$dir" && echo "   [✓] Eliminado"
    done
    info "✓ Limpieza completada"
  fi
  echo ""
}

menu_sync() {
  while true; do
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║      Gestión de Exportaciones         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "1. Listar exportaciones disponibles"
    echo "2. Limpiar exportaciones antiguas"
    echo "3. Volver"
    echo ""
    read -r -p "Seleccione opción: " opt

    case "$opt" in
      1) sync_list_all ;;
      2) sync_cleanup_old 30 ;;
      3) break ;;
      *) echo "[!] Opción inválida" ;;
    esac
  done
}
