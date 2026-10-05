#!/bin/bash
# Importa cuentas nuevas; nunca imprime ni guarda contraseñas en auditorías.
if [[ "$(type -t log)" != function ]]; then
  source "${REPO_PATH:-$(dirname "$0")/..}/config/servers.env" 2>/dev/null || return 1
  source "${REPO_PATH}/src/utils.sh"
fi
leer_csv() {
  local archivo="$1" linea numero=0 usuario nombre grupo dominio uid password mensaje separadores
  local -A vistos=()
  USUARIOS_LEIDOS=(); ERRORES_LEIDOS=()
  [[ -f "$archivo" ]] || { echo '[!] Archivo no encontrado.' >&2; return 1; }
  while IFS= read -r linea || [[ -n "$linea" ]]; do
    numero=$((numero+1))
    linea="${linea%$'\r'}"
    [[ $numero == 1 ]] && linea="${linea#$'\xef\xbb\xbf'}"
    [[ -z "$linea" || "$linea" == \#* ]] && continue
    [[ "$linea" == 'usuario|nombre|grupo|dominio|uid|password' ]] && continue
    separadores="${linea//[^|]/}"
    if [[ ${#separadores} != 5 ]]; then
      ERRORES_LEIDOS+=("Línea $numero: se requieren seis columnas separadas por |."); continue
    fi
    IFS='|' read -r usuario nombre grupo dominio uid password <<< "$linea"
    mensaje=""
    if [[ ! "$usuario" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
      mensaje='Nombre de usuario inválido.'
    elif [[ -n "${vistos[$usuario]:-}" ]]; then
      mensaje='Usuario duplicado en el archivo.'
    elif [[ -z "$nombre" || "$nombre" == *:* ]]; then
      mensaje='Nombre completo vacío o con dos puntos.'
    elif [[ ! "$grupo" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
      mensaje='Grupo inválido.'
    elif ! es_grupo_trabajo "$grupo"; then
      mensaje='Grupo fuera del catálogo Samba: usa IND_NOMBRE, COR, OPE, COM o GEN.'
    elif [[ ! "$dominio" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
      mensaje='Dominio vacío o inválido.'
    elif [[ -n "$uid" && ( ! "$uid" =~ ^[0-9]+$ || ${#uid} -gt 9 ) ]]; then
      mensaje='UID inválido; déjalo vacío para asignación automática.'
    elif [[ -z "$password" || "$password" == *:* ]]; then
      mensaje='Contraseña vacía o con dos puntos; no se admite : ni |.'
    elif [[ -n "$uid" ]] && ((10#$uid == 0)); then
      mensaje='No se permite UID 0.'
    elif ! id "$usuario" >/dev/null 2>&1 && [[ -n "$uid" ]] && getent passwd "$((10#$uid))" >/dev/null 2>&1; then
      mensaje="UID $uid ocupado en el equipo destino."
    fi
    if [[ -n "$mensaje" ]]; then
      ERRORES_LEIDOS+=("Línea $numero: $mensaje"); continue
    fi
    if [[ -n "$uid" ]]; then
      uid=$((10#$uid))
      if [[ -n "${vistos[uid_$uid]:-}" ]]; then
        ERRORES_LEIDOS+=("Línea $numero: UID repetido en el archivo."); continue
      fi
      vistos[uid_$uid]=1
    fi
    vistos[$usuario]=1
    USUARIOS_LEIDOS+=("$usuario|$nombre|$grupo|$dominio|$uid|$password")
  done < "$archivo"
  if ((${#ERRORES_LEIDOS[@]})); then
    printf '[!] %s\n' "${ERRORES_LEIDOS[@]}" >&2
    echo '[!] Corrige todas las filas antes de aplicar.' >&2
    USUARIOS_LEIDOS=(); return 1
  fi
  ((${#USUARIOS_LEIDOS[@]})) || { echo '[!] No hay usuarios en el archivo.' >&2; return 1; }
  echo 'Usuario | Nombre | Grupo | Dominio | UID | Acción'
  for linea in "${USUARIOS_LEIDOS[@]}"; do
    IFS='|' read -r usuario nombre grupo dominio uid password <<< "$linea"
    mensaje=CREAR
    id "$usuario" >/dev/null 2>&1 && mensaje='OMITIR (ya existe)'
    printf '%s | %s | %s | %s | %s | %s\n' "$usuario" "$nombre" "$grupo" "$dominio" "${uid:-automático}" "$mensaje"
  done
}

aplicar_carga_masiva() {
  local linea usuario nombre grupo dominio uid password fecha comando estado
  local creados=0 omitidos=0 fallidos=0
  local -a opciones
  require_root
  for comando in useradd groupadd chpasswd chage smbpasswd pdbedit getent net; do
    command -v "$comando" >/dev/null 2>&1 || { echo "[!] Falta $comando." >&2; return 1; }
  done
  mkdir -p "$DATA_DIR" "$EXPORT_PATH" || return 1
  local auditoria="$EXPORT_PATH/usuarios_entrada.csv"
  (umask 077; printf 'usuario|nombre|grupo|dominio|uid|estado\n' > "$auditoria") || return 1
  chmod 600 "$auditoria" || return 1
  fecha=$(date +%Y-%m-%d)
  for linea in "${USUARIOS_LEIDOS[@]}"; do
    IFS='|' read -r usuario nombre grupo dominio uid password <<< "$linea"
    estado=OMITIDO
    if ! getent group "$grupo" >/dev/null 2>&1; then
      groupadd "$grupo" || { echo "[!] No se pudo crear $grupo." >&2; USUARIOS_LEIDOS=(); return 1; }
    fi
    asegurar_grupo_samba "$grupo" || { echo "[!] No se pudo registrar $grupo en Samba." >&2; USUARIOS_LEIDOS=(); return 1; }
    if ! registrar_grupo_catalogo "$grupo"; then
      echo "[!] No se pudo guardar el grupo $grupo en el catálogo." >&2
      USUARIOS_LEIDOS=()
      return 1
    fi
    if id "$usuario" >/dev/null 2>&1; then
      omitidos=$((omitidos+1))
      echo "[OMITIDO] $usuario ya existe; conserva su contraseña."
    else
      opciones=(-M -d /nonexistent -s /usr/sbin/nologin -g "$grupo" -c "$nombre")
      [[ -n "$uid" ]] && opciones+=(-u "$uid")
      if ! useradd "${opciones[@]}" "$usuario"; then
        estado=ERROR_CREACION
      elif ! printf '%s:%s\n' "$usuario" "$password" | chpasswd; then
        estado=ERROR_PASSWORD_LINUX
      elif ! chage -m 0 -M -1 -I -1 -E -1 -d "$fecha" "$usuario"; then
        estado=ERROR_VIGENCIA
      elif ! printf '%s\n%s\n' "$password" "$password" | smbpasswd -s -a "$usuario"; then
        estado=ERROR_SAMBA
      elif ! smbpasswd -e "$usuario"; then
        estado=ERROR_SAMBA
      elif ! pdbedit -u "$usuario" -c '[X]' >/dev/null; then
        estado=ERROR_VIGENCIA_SAMBA
      else
        uid=$(id -u "$usuario")
        if printf '%s|%s|%s||%s|%s\n' "$usuario" "$nombre" "$grupo" "$uid" "$fecha" >> "$DATA_DIR/usuarios.db"; then
          estado=CREADO; creados=$((creados+1))
          echo "[CREADO] $usuario: contraseña permanente en Linux y Samba."
        else estado=ERROR_REGISTRO; fi
      fi
      if [[ "$estado" == ERROR_* ]]; then
        fallidos=$((fallidos+1))
        echo "[!] $usuario: $estado. Puede haberse creado parcialmente; revisa la cuenta antes de reintentar." >&2
      fi
    fi
    printf '%s|%s|%s|%s|%s|%s\n' "$usuario" "$nombre" "$grupo" "$dominio" "$uid" "$estado" >> "$auditoria" || return 1
  done
  USUARIOS_LEIDOS=()
  echo "Resultado: $creados creados, $omitidos omitidos, $fallidos errores."
  ((fallidos == 0))
}

carga_masiva_workflow() {
  local archivo resultado
  echo '=== Carga Masiva de Usuarios ==='
  echo 'Formato: usuario|nombre|grupo|dominio|uid|password'
  echo 'El UID puede quedar vacío. Las contraseñas se usan tal cual, sin vencimiento.'
  echo 'Los grupos de trabajo faltantes se crean y registran en Samba. El dominio es una referencia.'
  echo 'Los usuarios existentes se omiten y conservan sus contraseñas.'
  echo 'Las cuentas nuevas son solo para Samba: sin carpeta personal ni consola/SSH.'
  read -r -p 'Ruta del archivo CSV: ' archivo || return 1
  archivo="${archivo/#\~/$HOME}"
  leer_csv "$archivo" || return 1
  if confirm "¿Crear ${#USUARIOS_LEIDOS[@]} usuarios del archivo (omitiendo existentes)?"; then
    aplicar_carga_masiva
    resultado=$?
    USUARIOS_LEIDOS=()
    return "$resultado"
  fi
  USUARIOS_LEIDOS=()
  echo 'Cancelado.'
}

menu_carga_masiva() {
  local opt
  while true; do
    echo '=== Carga Masiva ==='
    echo '1. Cargar usuarios desde archivo'
    echo '2. Ver último resultado (sin contraseñas)'
    echo '3. Volver'
    read -r -p 'Opción: ' opt || return 0
    case "$opt" in
      1) carga_masiva_workflow ;;
      2) if [[ -f "$EXPORT_PATH/usuarios_entrada.csv" ]]; then
           cut -d'|' -f1-4 "$EXPORT_PATH/usuarios_entrada.csv" | head -20
         else echo '[!] No hay cargas procesadas.' >&2; fi ;;
      3) return 0 ;;
      *) echo '[!] Opción inválida.' >&2 ;;
    esac
  done
}
