#!/bin/bash
# Revisa cuentas normales de Samba y del registro del proyecto.
# Requiere nombres exactos de las excepciones antes de aplicar cambios.
samba_shell_disponible() { [[ -x /usr/sbin/nologin ]]; }

revisar_acceso_samba() {
  local aplicar=0 preservar='sara.albarracin,juan.rojas' arg user registro uid home shell resto
  local base="${REPO_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  local db="${DATA_DIR:-$base/config/data}/usuarios.db" backup fecha
  local corregidos=0 errores=0
  local -A protegidos=([root]=1 [soporte]=1 [sara.albarracin]=1 [juan.rojas]=1) vistos=()
  while (($#)); do
    arg="$1"; shift
    case "$arg" in
      --aplicar) aplicar=1 ;;
      --preservar) (($#)) || return 1; preservar="$1"; shift ;;
      *) echo 'Uso: sudo bash src/revisar_acceso_samba.sh --preservar usuarioSara,usuarioJuan [--aplicar]' >&2; return 1 ;;
    esac
  done
  if ((aplicar)) && [[ -z "$preservar" ]]; then
    echo '[!] Para aplicar debes indicar los nombres exactos de Sara y Juan con --preservar.' >&2; return 1
  fi
  local -a excepciones=()
  IFS=, read -ra excepciones <<< "$preservar"
  for user in "${excepciones[@]}"; do
    [[ "$user" =~ ^[a-z_][a-z0-9._-]*$ ]] && getent passwd "$user" >/dev/null || {
      echo "[!] La excepción no existe o es inválida: $user" >&2; return 1;
    }
    protegidos[$user]=1
  done
  [[ -z "${SUDO_USER:-}" ]] || protegidos[$SUDO_USER]=1
  if ((aplicar)); then
    [[ $(id -u) == 0 ]] || { echo '[!] Ejecuta con sudo.' >&2; return 1; }
    samba_shell_disponible || { echo '[!] Falta /usr/sbin/nologin.' >&2; return 1; }
    mkdir -p "$base/logs" || return 1
    backup=$(mktemp -d "$base/logs/acceso-samba.XXXXXX") || return 1
    chmod 700 "$backup" || return 1
    cp -p /etc/passwd "$backup/passwd" || return 1
    echo "Respaldo y cambios: $backup"
  fi
  echo 'Usuario | UID | Home | Shell | Acción'
  local cuentas_samba
  cuentas_samba=$(pdbedit -L) || { echo '[!] No se pudo listar Samba; no se modificó ninguna cuenta.' >&2; return 1; }
  while IFS= read -r user; do
    [[ -z "$user" || "$user" == \#* || -n "${vistos[$user]:-}" ]] && continue
    vistos[$user]=1
    registro=$(getent passwd "$user") || { echo "[!] Cuenta sin entrada Linux: $user" >&2; continue; }
    IFS=: read -r user resto uid resto resto home shell <<< "$registro"
    if [[ -n "${protegidos[$user]:-}" ]]; then
      printf '%s | %s | %s | %s | CONSERVAR\n' "$user" "$uid" "$home" "$shell"
      continue
    fi
    [[ "$uid" =~ ^[0-9]+$ ]] && ((uid >= 1000 && uid < 65534)) || continue
    if [[ "$home" == /nonexistent && "$shell" == /usr/sbin/nologin ]]; then
      printf '%s | %s | %s | %s | YA SOLO SAMBA\n' "$user" "$uid" "$home" "$shell"
      continue
    fi
    printf '%s | %s | %s | %s | CONVERTIR A SOLO SAMBA\n' "$user" "$uid" "$home" "$shell"
    if ((aplicar)); then
      if usermod -d /nonexistent -s /usr/sbin/nologin "$user"; then
        printf '%s|%s|%s\n' "$user" "$home" "$shell" >> "$backup/cambios.txt"
        corregidos=$((corregidos+1))
      else errores=$((errores+1)); fi
    fi
  done < <({ printf '%s\n' "$cuentas_samba" | cut -d: -f1; [[ ! -f "$db" ]] || cut -d'|' -f1 "$db"; } | sort -u)
  if ((aplicar)); then
    echo "Resultado: $corregidos corregidos, $errores errores. Las carpetas previas se conservan para revisar su contenido."
  else echo 'Solo revisión. Agrega --aplicar para cambiar las cuentas mostradas.'; fi
  ((errores == 0))
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  revisar_acceso_samba "$@"
fi
