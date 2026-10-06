#!/bin/bash
# Recursos de archivos: conserva [global] y los recursos exclusivos del destino.
samba_secciones() {
  awk '/^[[:space:]]*\[/ {s=$0; sub(/^[[:space:]]*\[/,"",s); sub(/\][[:space:]]*$/,"",s); print s}' "$1"
}
samba_bloque() {
  awk -v nombre="$2" '
    /^[[:space:]]*\[/ {s=$0; sub(/^[[:space:]]*\[/,"",s); sub(/\][[:space:]]*$/,"",s); activo=(tolower(s)==tolower(nombre))}
    activo {print}
  ' "$1"
}
samba_ruta_bloque() {
  awk 'tolower($0) ~ /^[[:space:]]*path[[:space:]]*=/ {s=$0; sub(/^[^=]*=[[:space:]]*/,"",s); sub(/[[:space:]]*$/,"",s); ruta=s} END {print ruta}' "$1"
}
preparar_recursos_samba() {
  local origen="$1" destino="$2" trabajo="$3" nombre ruta ruta_actual elegida
  local bloque="$trabajo/recurso.txt" temporal="$trabajo/mezcla.tmp"
  command -v testparm >/dev/null && command -v smbcontrol >/dev/null || return 1
  [[ -f "$origen" && -f "$destino" ]] || { echo '[!] Falta smb.conf de origen o destino.' >&2; return 1; }
  testparm -s "$origen" > "$trabajo/origen-normalizado.conf" 2> "$trabajo/origen-testparm.log" || return 1
  testparm -s "$destino" > "$trabajo/destino-normalizado.conf" 2> "$trabajo/destino-testparm.log" || return 1
  cp -p "$destino" "$trabajo/smb.conf.candidato" || return 1
  : > "$trabajo/recursos-aplicar.txt"
  while IFS= read -r nombre <&3; do
    case "${nombre,,}" in global|homes|printers|'print$'|'ipc$') continue ;; esac
    samba_bloque "$trabajo/origen-normalizado.conf" "$nombre" > "$bloque" || return 1
    ruta=$(samba_ruta_bloque "$bloque") || return 1
    [[ -n "$ruta" ]] || { echo "[!] [$nombre] no tiene ruta; no se importa." >&2; return 1; }
    samba_bloque "$trabajo/destino-normalizado.conf" "$nombre" > "$trabajo/existente.txt" || return 1
    ruta_actual=$(samba_ruta_bloque "$trabajo/existente.txt") || return 1
    if [[ -s "$trabajo/existente.txt" ]]; then
      echo "[$nombre] ya existe en destino: $ruta_actual"
      if ! confirm '¿Actualizar este recurso desde el origen?'; then echo "[CONSERVADO] [$nombre]"; continue; fi
      # No sobrescribir inadvertidamente un recurso definido en un include.
      if ! samba_secciones "$destino" | awk -v n="$nombre" 'tolower($0)==tolower(n) {found=1} END {exit !found}'; then
        echo "[!] [$nombre] se define fuera del archivo principal; revisa su include." >&2; return 1
      fi
    fi
    echo "Recurso [$nombre], ruta origen: $ruta"
    elegida="${ruta_actual:-$ruta}"
    read -r -p "Ruta absoluta del destino [${elegida}]: " ruta || return 1
    ruta="${ruta:-$elegida}"
    [[ "$ruta" == /* && "$ruta" != *%* && -d "$ruta" && "$ruta" != *$'\r'* ]] || {
      echo "[!] Ruta inexistente o dinámica para [$nombre]: $ruta" >&2; return 1;
    }
    ruta=$(realpath -- "$ruta") || return 1
    # Retirar solo el bloque homónimo del archivo principal.
    awk -v nombre="$nombre" '
      /^[[:space:]]*\[/ {s=$0; sub(/^[[:space:]]*\[/,"",s); sub(/\][[:space:]]*$/,"",s); quitar=(tolower(s)==tolower(nombre))}
      !quitar {print}
    ' "$trabajo/smb.conf.candidato" > "$temporal" || return 1
    mv "$temporal" "$trabajo/smb.conf.candidato" || return 1
    printf '\n' >> "$trabajo/smb.conf.candidato"
    SAMBA_RUTA_IMPORTAR="$ruta" awk '
      tolower($0) ~ /^[[:space:]]*path[[:space:]]*=/ {print "\tpath = " ENVIRON["SAMBA_RUTA_IMPORTAR"]; next}
      {print}
    ' "$bloque" >> "$trabajo/smb.conf.candidato" || return 1
    printf '%s\n' "$nombre" >> "$trabajo/recursos-aplicar.txt" || return 1
    echo "[PREPARADO] [$nombre] -> $ruta"
  done 3< <(samba_secciones "$trabajo/origen-normalizado.conf")
  chmod --reference="$destino" "$trabajo/smb.conf.candidato" || return 1
  testparm -s "$trabajo/smb.conf.candidato" > "$trabajo/candidato-normalizado.conf" 2> "$trabajo/candidato-testparm.log" || {
    echo '[!] Configuración candidata inválida; no se aplica.' >&2; return 1;
  }
}
aplicar_recursos_samba() {
  local destino="$1" trabajo="$2" nombre
  [[ -s "$trabajo/recursos-aplicar.txt" ]] || { echo 'Recursos existentes conservados; no hay cambios de smb.conf.'; return 0; }
  cp -p "$destino" "$trabajo/smb.conf.antes" || return 1
  if ! cp -p "$trabajo/smb.conf.candidato" "$destino" ||
     ! testparm -s "$destino" > "$trabajo/aplicado.conf" 2> "$trabajo/aplicado-testparm.log" ||
     ! smbcontrol all reload-config > "$trabajo/recarga.log" 2>&1; then
    cp -p "$trabajo/smb.conf.antes" "$destino" || { echo '[!] No se pudo restaurar smb.conf.' >&2; return 1; }
    smbcontrol all reload-config >> "$trabajo/recarga.log" 2>&1 || true
    echo '[!] Falló la aplicación/recarga: smb.conf anterior restaurado; revisa el registro.' >&2
    return 1
  fi
  while IFS= read -r nombre; do echo "[CONFIGURADO] [$nombre]"; done < "$trabajo/recursos-aplicar.txt"
  echo 'Configuración validada y recargada. Comprueba acceso y ACL desde un cliente.'
}
