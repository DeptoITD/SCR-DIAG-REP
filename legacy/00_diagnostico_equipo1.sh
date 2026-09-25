#!/usr/bin/env bash
set -uo pipefail
# 00_diagnostico_equipo1.sh — Diagnóstico de Equipo 1 (srv-2)
# Solo lectura: recolecta estado sin modificar nada
# No requiere sudo para --dry-run; requiere sudo para crear logs en /

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/diagnostico_equipo1_$(date +%Y%m%d_%H%M%S).log"

ts() { date +"%Y-%m-%d %H:%M:%S"; }
log_info() { printf "[INFO]  %s %s\n" "$(ts)" "$*" | tee -a "${LOG_FILE}"; }
log_ok()   { printf "[OK]    %s %s\n" "$(ts)" "$*" | tee -a "${LOG_FILE}"; }
log_err()  { printf "[ERROR] %s %s\n" "$(ts)" "$*" | tee -a "${LOG_FILE}"; }

main() {
  log_info "=== DIAGNÓSTICO EQUIPO 1 ($(hostname)) ==="

  log_info "Sistema..."
  log_info "  Hostname: $(hostname)"
  log_info "  Kernel: $(uname -r)"
  log_info "  Distro: $(lsb_release -d | cut -f2)"

  log_info "Samba..."
  smbstatus &>/dev/null && log_ok "  Samba activo" || log_err "  Samba inactivo"
  which pdbedit &>/dev/null && log_ok "  pdbedit disponible" || log_err "  pdbedit NO disponible"

  log_info "Almacenamiento..."
  [[ -d /srv/02_Proyectos ]] && log_ok "  /srv/02_Proyectos existe" || log_err "  /srv/02_Proyectos NO existe"

  log_info "Usuarios..."
  log_info "  UID 0-999 (sistema): $(getent passwd | awk -F: '$3 < 1000' | wc -l)"
  log_info "  UID 1000+ (usuarios): $(getent passwd | awk -F: '$3 >= 1000' | wc -l)"

  log_info "Grupos..."
  log_info "  GID 0-999 (sistema): $(getent group | awk -F: '$3 < 1000' | wc -l)"
  log_info "  GID 1000+ (equipos): $(getent group | awk -F: '$3 >= 1000' | wc -l)"

  log_ok "=== DIAGNÓSTICO COMPLETADO ==="
  log_ok "Log: ${LOG_FILE}"
}

main "$@"
