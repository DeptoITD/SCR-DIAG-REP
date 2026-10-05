#!/bin/bash
# Compara la contraseña del CSV con el hash NT local sin mostrar ninguno.
set +x
set -o pipefail

calcular_hash_nt() {
  local pass="$1" resultado
  resultado=$(printf '%s' "$pass" | iconv -f UTF-8 -t UTF-16LE | openssl dgst -md4 -provider legacy 2>/dev/null) ||
    resultado=$(printf '%s' "$pass" | iconv -f UTF-8 -t UTF-16LE | openssl dgst -md4 2>/dev/null) || return 1
  resultado="${resultado##* }"
  [[ "$resultado" =~ ^[0-9A-Fa-f]{32}$ ]] || return 1
  printf '%s\n' "${resultado^^}"
}

verificar_credenciales_csv() {
  local csv="${1:-}" linea user nombre grupo dominio uid password campos registro hash flags esperado
  local correctas=0 errores=0 numero=0 comando
  [[ $(id -u) == 0 ]] || { echo '[!] Ejecuta con sudo en el NAS.' >&2; return 1; }
  [[ -f "$csv" ]] || { echo 'Uso: sudo bash src/verificar_credenciales_csv.sh /ruta/usuarios.csv' >&2; return 1; }
  for comando in pdbedit openssl iconv; do command -v "$comando" >/dev/null || return 1; done
  while IFS= read -r linea || [[ -n "$linea" ]]; do
    numero=$((numero+1)); linea="${linea%$'\r'}"
    [[ $numero != 1 ]] || linea="${linea#$'\xef\xbb\xbf'}"
    [[ -n "$linea" && "$linea" != \#* && "$linea" != 'usuario|nombre|grupo|dominio|uid|password' ]] || continue
    campos="${linea//[^|]/}"
    [[ ${#campos} == 5 ]] || { echo "[!] Línea $numero: formato incorrecto."; errores=$((errores+1)); continue; }
    IFS='|' read -r user nombre grupo dominio uid password <<< "$linea"
    [[ "$user" =~ ^[a-z_][a-z0-9._-]*$ && -n "$password" ]] || { echo "[!] Línea $numero: usuario o contraseña inválidos."; errores=$((errores+1)); continue; }
    registro=$(pdbedit -L -w -u "$user" 2>/dev/null) || registro=''
    registro=$(printf '%s\n' "$registro" | awk -F: -v user="$user" '$1 == user {print; exit}')
    if [[ -z "$registro" ]]; then
      echo "[NO EXISTE EN SAMBA] $user"; errores=$((errores+1)); continue
    fi
    IFS=: read -r _ _ _ hash flags _ <<< "$registro"
    esperado=$(calcular_hash_nt "$password") || { echo '[!] No se pudo calcular el hash NT; revisa OpenSSL/MD4.' >&2; return 1; }
    if [[ "${hash^^}" != "$esperado" ]]; then
      echo "[NO COINCIDE] $user"; errores=$((errores+1))
    elif [[ "$flags" == *D* || "$flags" == *L* ]]; then
      echo "[COINCIDE, PERO BLOQUEADA/DESHABILITADA] $user"; errores=$((errores+1))
    else
      echo "[COINCIDE] $user"; correctas=$((correctas+1))
    fi
  done < "$csv"
  echo "Verificación: $correctas coinciden y están habilitadas, $errores incidencias."
  ((correctas > 0 && errores == 0))
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then verificar_credenciales_csv "$@"; fi
