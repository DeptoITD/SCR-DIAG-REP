#!/bin/bash
# Importa cuentas nuevas; nunca imprime ni guarda contraseñas en auditorías.
if [[ "$(type -t log)" != function ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/iniciar.sh" || return 1
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
    elif [[ "$usuario" == soporte ]]; then
      mensaje='soporte se administra fuera de la carga Samba.'
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
    elif [[ -n "$uid" ]] && ((10#$uid < 1000 || 10#$uid >= 65534)); then
      mensaje='UID fuera del rango de cuentas de trabajo (1000..65533).'
    elif id "$usuario" >/dev/null 2>&1 && [[ -n "$uid" ]] && [[ "$(id -u "$usuario")" != "$((10#$uid))" ]]; then
      mensaje="UID distinto para $usuario; no se cambia automáticamente."
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
    id "$usuario" >/dev/null 2>&1 && mensaje='ACTUALIZAR contraseña desde CSV'
    printf '%s | %s | %s | %s | %s | %s\n' "$usuario" "$nombre" "$grupo" "$dominio" "${uid:-automático}" "$mensaje"
  done
}

aplicar_carga_masiva() {
  require_root
  local linea usuario nombre grupo dominio uid password comando estado esperado
  local creados=0 actualizados=0 fallidos=0
  local -a opciones
  for comando in useradd groupadd chpasswd chage smbpasswd pdbedit getent net openssl iconv; do
    command -v "$comando" >/dev/null || { echo "[!] Falta $comando" >&2; return 1; }
  done
  # Comprueba soporte MD4 antes de crear o actualizar cuentas.
  hash_password_nt prueba >/dev/null || { echo '[!] OpenSSL no permite calcular hashes NT.' >&2; return 1; }
  local respaldo auditoria
  respaldo=$(mktemp -d "$LOG_DIR/carga.XXXXXX") || return 1
  chmod 700 "$respaldo" || return 1
  pdbedit -e "tdbsam:$respaldo/cuentas-antes.tdb" > "$respaldo/respaldo.log" 2>&1 || return 1
  cp -p /etc/shadow "$respaldo/shadow-antes" || return 1
  chmod 600 "$respaldo/shadow-antes" || return 1
  auditoria="$EXPORT_PATH/usuarios_entrada.csv"
  (umask 077; printf 'usuario|nombre|grupo|dominio|uid|estado\n' > "$auditoria") || return 1
  for linea in "${USUARIOS_LEIDOS[@]}"; do
    IFS='|' read -r usuario nombre grupo dominio uid password <<< "$linea"
    estado=ACTUALIZADO
    if ! getent group "$grupo" >/dev/null; then groupadd "$grupo" || return 1; fi
    asegurar_grupo_samba "$grupo" || return 1
    registrar_grupo_catalogo "$grupo" || return 1
    if ! id "$usuario" >/dev/null 2>&1; then
      opciones=(-M -d /nonexistent -s /usr/sbin/nologin -g "$grupo" -c "$nombre")
      [[ -z "$uid" ]] || opciones+=(-u "$uid")
      if useradd "${opciones[@]}" "$usuario"; then estado=CREADO; else estado=ERROR_CREACION; fi
    fi
    if [[ "$estado" != ERROR_* ]]; then
      if ! establecer_password_permanente "$usuario" "$password"; then
        estado=ERROR_CREDENCIAL
      elif ! registrar_usuario_catalogo "$usuario"; then estado=ERROR_REGISTRO; fi
    fi
    uid=$(id -u "$usuario" 2>/dev/null) || uid=''
    printf '%s|%s|%s|%s|%s|%s\n' "$usuario" "$nombre" "$grupo" "$dominio" "$uid" "$estado" >> "$auditoria" || return 1
    case "$estado" in
      CREADO) creados=$((creados+1)); echo "[CREADO Y VERIFICADO] $usuario" ;;
      ACTUALIZADO) actualizados=$((actualizados+1)); echo "[ACTUALIZADO Y VERIFICADO] $usuario" ;;
      *) fallidos=$((fallidos+1)); echo "[!] $usuario: $estado; respaldo en $respaldo" >&2 ;;
    esac
  done
  USUARIOS_LEIDOS=()
  echo "Resultado: $creados creados, $actualizados actualizados, $fallidos errores. Respaldo: $respaldo"
  ((fallidos==0))
}
carga_masiva_workflow() {
  local archivo="${1:-}" resultado
  echo '=== Carga Masiva de Usuarios ==='
  echo 'Formato: usuario|nombre|grupo|dominio|uid|password'
  echo 'El UID puede quedar vacío. Las contraseñas se usan tal cual, sin vencimiento.'
  echo 'Los grupos de trabajo faltantes se crean y registran en Samba. El dominio es una referencia.'
  echo 'Las cuentas existentes reciben la contraseña del CSV; se conservan home, shell y grupos actuales.'
  echo 'Las cuentas nuevas son solo para Samba: sin carpeta personal ni consola/SSH.'
  if [[ -z "$archivo" ]]; then
    read -r -p 'Ruta del archivo CSV: ' archivo || return 1
  fi
  archivo="${archivo/#\~/$HOME}"
  leer_csv "$archivo" || return 1
  if confirm "¿Aplicar las contraseñas del CSV a ${#USUARIOS_LEIDOS[@]} cuentas, incluidas las existentes?"; then
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
