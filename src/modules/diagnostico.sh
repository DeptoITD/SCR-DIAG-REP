#!/bin/bash
# diagnostico.sh — Diagnóstico de máquina (console-only por defecto)

# utils.sh + servers.env already sourced by menu.sh, but allow standalone calls
if [[ "$(type -t log)" != "function" ]]; then
  source "${REPO_PATH:-$(dirname "$0")/..}/config/servers.env" 2>/dev/null || source "$(dirname "$0")/../config/servers.env"
  source "${REPO_PATH:-$(dirname "$0")/..}/src/utils.sh" 2>/dev/null || source "$(dirname "$0")/../utils.sh"
fi

diagnostico_run() {
  local output_file=""

  echo ""
  echo "=== Diagnóstico de Máquina ==="
  echo ""

  # Recolección (no capturar a archivo todavía)
  {
    echo "=== SISTEMA ==="
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "Distro: $(grep PRETTY_NAME /etc/os-release | cut -d'=' -f2 | tr -d '"')"
    echo "Uptime: $(uptime | sed 's/.*up //' | sed 's/,.*load.*//')"
    echo "CPU: $(grep -c ^processor /proc/cpuinfo) cores"
    echo "RAM: $(free -h | grep Mem | awk '{print $2}')"

    echo ""
    echo "=== SERVICIOS CLAVE ==="
    systemctl is-active smbd &>/dev/null && echo "[OK] smbd" || echo "[FAIL] smbd"
    systemctl is-active nfs-server &>/dev/null && echo "[OK] nfs-server" || echo "[OK] nfs-server no habilitado"

    echo ""
    echo "=== USUARIOS Y GRUPOS ==="
    echo "Usuarios proyecto (UID >= 1000):"
    getent passwd | awk -F: '$3 >= 1000 {print "  " $1 " (uid=" $3 ")"}' | head -10
    echo "Total: $(getent passwd | awk -F: '$3 >= 1000' | wc -l)"

    echo ""
    echo "Grupos proyecto:"
    getent group | grep -E "IND_" | awk -F: '{print "  " $1 " (gid=" $3 ", miembros: " $4 ")"}'

    echo ""
    echo "=== USUARIOS SAMBA ==="
    sudo pdbedit -L 2>/dev/null | wc -l | xargs echo "Total usuarios Samba:"

    echo ""
    echo "=== ALMACENAMIENTO ==="
    df -h | grep -E "^/dev|Filesystem"

    echo ""
    echo "=== LVM / RAID ==="
    sudo lvs 2>/dev/null | head -5 || echo "  (no LVM detectado)"

    echo ""
    echo "=== RED ==="
    echo "IPs locales:"
    hostname -I | tr ' ' '\n' | sed 's/^/  /'

    echo ""
    echo "=== MONTAJES NAS/SMB/NFS ==="
    mount | grep -E "cifs|nfs|ntfs" || echo "  (ninguno detectado)"

  } | tee >(cat)  # Mostrar en pantalla

  # Preguntar si guardar
  echo ""
  if confirm "¿Guardar diagnóstico en log?"; then
    output_file="${LOG_DIR}/diagnostico_$(date +%Y%m%d_%H%M%S).log"
    mkdir -p "$(dirname "$output_file")"
    # Volver a correr y guardar
    {
      echo "=== DIAGNÓSTICO - $(date) ==="
      echo ""

      echo "=== SISTEMA ==="
      echo "Hostname: $(hostname)"
      echo "Kernel: $(uname -r)"
      echo "Distro: $(grep PRETTY_NAME /etc/os-release | cut -d'=' -f2 | tr -d '"')"
      echo "Uptime: $(uptime | sed 's/.*up //' | sed 's/,.*load.*//')"
      echo "CPU: $(grep -c ^processor /proc/cpuinfo) cores"
      echo "RAM: $(free -h | grep Mem | awk '{print $2}')"

      echo ""
      echo "=== SERVICIOS CLAVE ==="
      systemctl is-active smbd &>/dev/null && echo "[OK] smbd" || echo "[FAIL] smbd"

      echo ""
      echo "=== USUARIOS Y GRUPOS ==="
      echo "Usuarios proyecto (UID >= 1000): $(getent passwd | awk -F: '$3 >= 1000' | wc -l)"
      getent passwd | awk -F: '$3 >= 1000 {print "  " $1}'

      echo ""
      echo "Grupos:"
      getent group | grep -E "IND_" | awk -F: '{print "  " $1 " (gid=" $3 "): " $4}'

      echo ""
      echo "=== USUARIOS SAMBA ==="
      sudo pdbedit -L 2>/dev/null | head -20

      echo ""
      echo "=== ALMACENAMIENTO ==="
      df -h

      echo ""
      echo "=== MOUNTS ==="
      mount | grep -E "cifs|nfs|ntfs"

    } > "$output_file"
    info "Log guardado: $output_file"
  fi

  echo ""
}
