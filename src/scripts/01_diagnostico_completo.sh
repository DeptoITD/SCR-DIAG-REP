#!/bin/bash
# 01_diagnostico_completo.sh — Diagnóstico máquina Ubuntu + Samba + Storage
# Recolecta: sistema, servicios, usuarios, grupos, Samba, discos, RAID, LVM, mounts, ACLs, fstab
# Solo lectura. No modifica nada.
# Uso: bash 01_diagnostico_completo.sh

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/diagnostico_$(date +%Y%m%d_%H%M%S).log"

ts() { date +"%Y-%m-%d %H:%M:%S"; }
log_info() { printf "[INFO]  %s %s\n" "$(ts)" "$*" | tee -a "${LOG_FILE}"; }
log_ok()   { printf "[✓]     %s %s\n" "$(ts)" "$*" | tee -a "${LOG_FILE}"; }
log_err()  { printf "[✗]     %s %s\n" "$(ts)" "$*" | tee -a "${LOG_FILE}"; }
log_section() { echo "" | tee -a "${LOG_FILE}"; log_info "=== $1 ==="; }

# SISTEMA
log_section "SISTEMA"
log_info "Hostname: $(hostname)"
log_info "Kernel: $(uname -r)"
log_info "Distro: $(lsb_release -d 2>/dev/null | cut -f2)"
log_info "Uptime: $(uptime -p)"
log_info "CPUs: $(nproc)"
log_info "RAM Total: $(free -h | grep Mem | awk '{print $2}')"
log_info "RAM Disponible: $(free -h | grep Mem | awk '{print $7}')"

# SERVICIOS
log_section "SERVICIOS"
systemctl is-active samba &>/dev/null && log_ok "Samba activo" || log_err "Samba inactivo"
systemctl is-active smbd &>/dev/null && log_ok "smbd activo" || log_err "smbd inactivo"
systemctl is-enabled samba &>/dev/null && log_ok "Samba auto-start" || log_err "Samba sin auto-start"
systemctl is-active nfs-server &>/dev/null && log_ok "NFS activo" || log_err "NFS inactivo"

# SMB SHARES
log_section "SMB SHARES"
if which testparm &>/dev/null; then
  if testparm -s 2>/dev/null | grep "^\[" >/dev/null; then
    testparm -s 2>/dev/null | grep "^\[" | sed 's/\[//;s/\]//' | while read share; do
      log_info "  Share: $share"
    done
  else
    log_info "Sin SMB shares configurados"
  fi
else
  log_err "testparm no disponible"
fi

# USUARIOS LINUX
log_section "USUARIOS LINUX"
sys_users=$(getent passwd | awk -F: '$3 < 1000' | wc -l)
reg_users=$(getent passwd | awk -F: '$3 >= 1000' | wc -l)
log_info "Sistema (UID <1000): $sys_users"
log_info "Usuarios (UID >=1000): $reg_users"
getent passwd | awk -F: '$3 >= 1000 {printf "  %s (uid=%s, gid=%s)\n", $1, $3, $4}' | tee -a "${LOG_FILE}"

# GRUPOS LINUX
log_section "GRUPOS LINUX"
sys_groups=$(getent group | awk -F: '$3 < 1000' | wc -l)
reg_groups=$(getent group | awk -F: '$3 >= 1000' | wc -l)
log_info "Sistema (GID <1000): $sys_groups"
log_info "Grupos (GID >=1000): $reg_groups"
getent group | awk -F: '$3 >= 1000 {printf "  %s (gid=%s)\n", $1, $3}' | tee -a "${LOG_FILE}"

# USUARIOS SAMBA
log_section "USUARIOS SAMBA"
if which pdbedit &>/dev/null; then
  if pdbedit -L 2>/dev/null | grep -q "^"; then
    pdbedit -L 2>/dev/null | while read line; do
      log_info "  $line"
    done
  else
    log_info "Sin usuarios Samba registrados"
  fi
else
  log_err "pdbedit no instalado"
fi

# DISCOS
log_section "DISCOS Y PARTICIONES"
if which lsblk &>/dev/null; then
  lsblk -d -n -o NAME,SIZE,TYPE 2>/dev/null | while read line; do
    log_info "  Disco: $line"
  done
else
  log_err "lsblk no disponible"
fi

# PARTICIONES DETALLADAS
log_section "PARTICIONES DETALLADAS"
if which lsblk &>/dev/null; then
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS 2>/dev/null | tee -a "${LOG_FILE}"
else
  log_err "lsblk no disponible"
fi

# MOUNTS ACTIVOS
log_section "MOUNTS (NFS, CIFS, EXT4, XFS)"
mount | grep -E "(nfs|samba|cifs|ext4|xfs)" | while read line; do
  log_info "  $line"
done || log_info "Sin mounts detectados"

# RAID
log_section "RAID (mdadm)"
if [[ -f /proc/mdstat ]]; then
  if grep -q "^md" /proc/mdstat 2>/dev/null; then
    grep -v "^Personalities\|^$" /proc/mdstat | tee -a "${LOG_FILE}"
  else
    log_info "Sin RAID activo"
  fi
else
  log_info "Sin soporte RAID"
fi

# LVM
log_section "LVM VOLÚMENES"
if which lvs &>/dev/null; then
  if lvs 2>/dev/null | grep -q "LV"; then
    lvs 2>/dev/null | tee -a "${LOG_FILE}"
  else
    log_info "Sin volúmenes LVM"
  fi
else
  log_info "LVM no instalado"
fi

# ESPACIO DISCO
log_section "ESPACIO DISPONIBLE"
df -h | grep -E "(dev|srv|mnt|opt|var)" | while read line; do
  log_info "  $line"
done

# FSTAB
log_section "FSTAB (Mounts persistentes)"
if grep -E "(nfs|samba|cifs|\/srv|\/mnt|\/opt)" /etc/fstab >/dev/null 2>&1; then
  grep -E "(nfs|samba|cifs|\/srv|\/mnt|\/opt)" /etc/fstab | tee -a "${LOG_FILE}"
else
  log_info "Sin mounts NAS en fstab"
fi

# PERMISOS DIRECTORIOS CRÍTICOS
log_section "PERMISOS DIRECTORIOS CRÍTICOS"
for dir in /srv /mnt /opt /var/lib/samba; do
  if [[ -d "$dir" ]]; then
    perms=$(stat -c "%A %U:%G" "$dir" 2>/dev/null)
    log_info "  $dir: $perms"
  fi
done

# ACLs
log_section "ACLs ACTIVOS"
if which getfacl &>/dev/null; then
  for dir in /srv /mnt /opt /var/lib/samba; do
    if [[ -d "$dir" ]]; then
      acls=$(getfacl "$dir" 2>/dev/null | grep -E "^(user|group|other|default)")
      if [[ -n "$acls" ]]; then
        log_info "  ACLs $dir:"
        getfacl "$dir" 2>/dev/null | grep -E "^(user|group|other|default)" | sed 's/^/    /' | tee -a "${LOG_FILE}"
      else
        log_info "  $dir: sin ACLs"
      fi
    fi
  done
else
  log_err "ACL tools no disponibles"
fi

# SAMBA CONFIG (testparm)
log_section "SAMBA CONFIGURACIÓN (primeras 50 líneas)"
if which testparm &>/dev/null; then
  testparm 2>/dev/null | head -50 | tee -a "${LOG_FILE}" || log_err "testparm falló"
else
  log_err "testparm no disponible"
fi

# CONECTIVIDAD
log_section "CONECTIVIDAD (Interfaces IP)"
ip addr | grep "inet " | grep -v "127.0.0.1" | while read line; do
  log_info "  $line"
done

# RESUMEN
log_section "FIN DIAGNÓSTICO"
log_ok "Guardado: $LOG_FILE"
echo ""
echo "Ver completo: tail -f $LOG_FILE"
