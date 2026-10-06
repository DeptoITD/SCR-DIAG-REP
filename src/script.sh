#!/bin/bash
# Única entrada: una acción explícita por ejecución.
set -o pipefail
uso() {
  cat <<'AYUDA'
Uso: sudo bash src/script.sh ACCION [RUTA]

Flujo de migración: exportar en servidor → copiar carpeta → importar en NAS → verificar.
  diagnostico                 Diagnóstico del equipo
  exportar                    Generar carpeta exportada
  importar [CARPETA]          Validar e incorporar identidades y credenciales
  carga-masiva [CSV]          Crear o sincronizar contraseñas desde CSV
  listar-usuarios             Consultar usuarios
  listar-grupos               Sincronizar y consultar grupos de trabajo
  usuarios                    Administrar usuarios
  equipos                     Administrar equipos e integrantes
  exportaciones               Administrar exportaciones
  ayuda                       Mostrar estos comandos
Guía completa: src/docs/wiki/COMANDOS_RAPIDOS.md
AYUDA
}
accion="${1:-ayuda}"
case "$accion" in
  ayuda|-h|--help) uso; exit 0 ;;
  diagnostico|exportar|importar|carga-masiva|listar-usuarios|listar-grupos|usuarios|equipos|exportaciones) ;;
  *) echo "Acción desconocida: $accion" >&2; uso >&2; exit 2 ;;
esac
shift
if (( $# > 1 )) || { (( $# > 0 )) && [[ "$accion" != importar && "$accion" != carga-masiva ]]; }; then
  uso >&2; exit 2
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/iniciar.sh" || exit 1
require_root
for modulo in diagnostico exportar importar sync equipos usuarios carga_masiva; do
  source "$SCRIPT_DIR/modules/$modulo.sh" || exit 1
done
log "Inicio de acción: $accion" >/dev/null
trap 'printf "[%s] Error: código %s, línea %s\n" "$(date +%Y-%m-%dT%H:%M:%S)" "$?" "$LINENO" >> "$LOG_FILE"' ERR
case "$accion" in
  diagnostico) diagnostico_run ;;
  exportar) exportar_run ;;
  importar) importar_run "$@" ;;
  carga-masiva) carga_masiva_workflow "$@" ;;
  listar-usuarios) usuario_listar ;;
  listar-grupos) equipo_listar ;;
  usuarios) menu_usuarios ;;
  equipos) menu_equipos ;;
  exportaciones) menu_sync ;;
esac
exit "$?"
