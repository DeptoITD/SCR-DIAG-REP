#!/bin/bash
# usuarios.sh — Gestión de usuarios (CRUD)
# Reutilizado por importar.sh para replicar usuarios

if [[ "$(type -t log)" != function ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/iniciar.sh" || return 1
fi

usuario_listar() {
  local db="${DATA_DIR}/usuarios.db"
  [[ ! -f "$db" ]] && { error "No existe: $db"; return 1; }

  echo ""
  echo "=== Usuarios ==="
  echo "Usuario             | Nombre                          | Grupo Primario | Grupos Extra"
  echo "--------------------|----------------------------------|----------------|------------------------------------------"

  while IFS='|' read -r user full_name prim_grupo extra_groups uid created extra; do
    [[ -z "$user" || "$user" =~ ^# ]] && continue
    printf "%-19s | %-32s | %-14s | %s\n" "$user" "$full_name" "$prim_grupo" "${extra_groups:--(ninguno)}"
  done < "$db"
  echo ""
}

# Solo permite eliminar archivos idénticos al esqueleto inicial y carpetas vacías.
home_solo_inicial() {
  local ruta="$1" skel="${2:-/etc/skel}" item relativo enlace_actual enlace_inicial
  [[ -d "$ruta" && ! -L "$ruta" && -d "$skel" ]] || return 1
  while IFS= read -r -d '' item; do
    relativo="${item#"$ruta"/}"
    if [[ -L "$item" ]]; then
      [[ -L "$skel/$relativo" ]] || return 1
      enlace_actual=$(readlink -- "$item") || return 1
      enlace_inicial=$(readlink -- "$skel/$relativo") || return 1
      [[ "$enlace_actual" == "$enlace_inicial" ]] || return 1
    elif [[ -f "$item" ]]; then
      [[ -f "$skel/$relativo" && ! -L "$skel/$relativo" ]] || return 1
      cmp -s -- "$item" "$skel/$relativo" || return 1
    elif [[ -d "$item" ]]; then
      [[ -d "$skel/$relativo" && ! -L "$skel/$relativo" ]] || return 1
    else return 1; fi
  done < <(find -P "$ruta" -mindepth 1 -print0)
}

home_ruta_segura() {
  local user="$1" ruta="/home/$1" mounts
  [[ "$user" =~ ^[a-z_][a-z0-9._-]*$ && -d "$ruta" && ! -L "$ruta" ]] || return 1
  [[ "$(realpath "$ruta")" == "$ruta" ]] || return 1
  mounts=$(findmnt -rn -o TARGET) || return 1
  ! printf '%s\n' "$mounts" | awk -v p="$ruta" '$0==p || index($0,p"/")==1 {found=1} END {exit !found}' || return 1
  home_solo_inicial "$ruta"
}

usuarios_limpiar_homes() {
  require_root
  local ruta user registro uid home respaldo fallos=0
  local -a candidatos=()
  for ruta in /home/*; do
    [[ -d "$ruta" || -L "$ruta" ]] || continue
    user="${ruta##*/}"
    case "$user" in soporte|sara.albarracin|juan.rojas) echo "[PROTEGIDO] $user"; continue ;; esac
    registro=$(getent passwd "$user") || continue
    IFS=: read -r _ _ uid _ _ home _ <<< "$registro"
    [[ "$uid" =~ ^[0-9]+$ ]] && ((uid>=1000 && uid<65534)) || continue
    [[ "$home" == "$ruta" || "$home" == /nonexistent ]] || continue
    pdbedit -L -u "$user" | awk -F: -v u="$user" '$1==u {found=1} END {exit !found}' || continue
    if home_ruta_segura "$user"; then
      candidatos+=("$user"); echo "[ELIMINAR HOME INICIAL] $ruta"
    else echo "[CONSERVADO] $ruta: contenido distinto, enlace o montaje; requiere revisión."; fi
  done
  ((${#candidatos[@]})) || { echo 'No hay homes iniciales elegibles.'; return 0; }
  confirm "¿Eliminar definitivamente ${#candidatos[@]} homes iniciales y poner sus cuentas sin consola? No cambia grupos ni contraseñas." || return 0
  respaldo=$(mktemp -d "$LOG_DIR/limpieza-homes.XXXXXX") || return 1
  chmod 700 "$respaldo" || return 1
  cp -p /etc/passwd /etc/group /etc/shadow "$respaldo/" || return 1
  chmod 600 "$respaldo/"* || return 1
  for user in "${candidatos[@]}"; do
    # Revalidar antes de eliminar: no usar una comprobación antigua.
    if ! home_ruta_segura "$user"; then echo "[CONSERVADO] $user: la carpeta cambió."; fallos=$((fallos+1)); continue; fi
    if ! usermod -d /nonexistent -s /usr/sbin/nologin "$user" ||
       ! find -P "/home/$user" -xdev -depth -delete ||
       ! registrar_usuario_catalogo "$user"; then
      echo "[ERROR] $user: puede haber cambios parciales." >&2; fallos=$((fallos+1)); continue
    fi
    echo "[LIMPIADO] $user: sin home ni consola; grupos y credenciales conservados."
  done
  echo "Registros Linux anteriores: $respaldo. Incidencias: $fallos"
  ((fallos==0))
}
# Perfil para cuentas de trabajo; mantiene intactas las cuentas administrativas.
usuario_perfil_samba() {
  local user="$1" grupo="$2" registro uid home shell respaldo ruta mounts
  case "$user" in soporte|sara.albarracin|juan.rojas)
    echo '[!] Cuenta administrativa protegida; no se convierte desde esta opción.' >&2; return 1 ;;
  esac
  [[ "$user" =~ ^[a-z_][a-z0-9._-]*$ ]] || return 1
  es_grupo_trabajo "$grupo" || return 1
  registro=$(getent passwd "$user") || return 1
  IFS=: read -r _ _ uid _ _ home shell <<< "$registro"
  ((uid>=1000 && uid<65534)) || return 1
  getent group "$grupo" >/dev/null || return 1
  pdbedit -L -u "$user" | awk -F: -v u="$user" '$1==u {found=1} END {exit !found}' || { echo '[!] Falta la cuenta Samba; carga sus credenciales antes de convertirla.' >&2; return 1; }
  ruta="/home/$user"
  # No mover enlaces, homes compartidos ni árboles que contengan montajes.
  [[ "$home" == "$ruta" || "$home" == /nonexistent ]] || {
    echo "[!] Home no estándar: $home. Revisa antes de convertir." >&2; return 1;
  }
  [[ ! -L "$ruta" ]] || { echo '[!] Home es un enlace; requiere revisión.' >&2; return 1; }
  if [[ -e "$ruta" ]]; then
    [[ -d "$ruta" && "$(realpath "$ruta")" == "$ruta" ]] || return 1
    mounts=$(findmnt -rn -o TARGET) || return 1
    if printf '%s\n' "$mounts" | awk -v p="$ruta" '$0==p || index($0,p"/")==1 {found=1} END {exit !found}'; then
      echo '[!] Home contiene un montaje; no se modifica.' >&2; return 1
    fi
  fi
  if [[ -d "$ruta" ]] && ! home_solo_inicial "$ruta"; then
    echo '[!] Home contiene archivos modificados o personales; se conserva y no se aplica el perfil.' >&2; return 1
  fi
  asegurar_grupo_samba "$grupo" || return 1
  registrar_grupo_catalogo "$grupo" || return 1
  echo "Perfil de $user: grupo único $grupo, /nonexistent y nologin."
  [[ ! -d "$ruta" ]] || echo "Se eliminará definitivamente $ruta: solo contiene archivos iniciales iguales a /etc/skel."
  confirm '¿Aplicar el perfil, retirar grupos adicionales y eliminar el home inicial si existe?' || return 0
  respaldo=$(mktemp -d "$LOG_DIR/perfil-samba.XXXXXX") || return 1
  chmod 700 "$respaldo" || return 1
  cp -p /etc/passwd /etc/group /etc/shadow "$respaldo/" || return 1
  chmod 600 "$respaldo/"* || return 1
  printf '%s\n' "$registro" > "$respaldo/usuario-antes.txt" || return 1
  sudo usermod -g "$grupo" -G '' -d /nonexistent -s /usr/sbin/nologin "$user" || return 1
  if [[ -d "$ruta" ]]; then
    home_ruta_segura "$user" && sudo find -P "$ruta" -xdev -depth -delete || {
      echo "[!] Perfil cambiado; no se pudo eliminar el home inicial. Revisa $ruta y $respaldo." >&2; return 1;
    }
  fi
  registrar_usuario_catalogo "$user" || return 1
  [[ "$(id -gn "$user")" == "$grupo" && "$(id -Gn "$user")" == "$grupo" ]] || return 1
  registro=$(getent passwd "$user") || return 1
  [[ "$registro" == *':/nonexistent:/usr/sbin/nologin' && ! -e "$ruta" ]] || return 1
  echo "[VERIFICADO] $user: solo $grupo, sin home ni consola. Respaldo: $respaldo"
  echo 'El grupo privado antiguo se conserva si existe: eliminarlo puede afectar archivos o ACL fuera del home.'
}
usuario_crear() {
  require_root
  local db="${DATA_DIR}/usuarios.db"
  local usuarios_db="${DATA_DIR}/usuarios.db"
  local equipos_db="${DATA_DIR}/equipos.db"
  local user full_name prim_grupo extra_groups pass uid created

  read -r -p "Nombre de usuario (ej: john.doe): " user
  [[ "$user" =~ ^[a-z_][a-z0-9._-]*$ && "$user" != soporte ]] || { echo '[!] Usuario inválido o protegido.' >&2; return 1; }

  id "$user" &>/dev/null && { error "Usuario ya existe"; return 1; }
  [[ ! -e "/home/$user" && ! -L "/home/$user" ]] || { echo '[!] Ya existe una carpeta antigua para ese nombre; revísala antes del alta.' >&2; return 1; }

  read -r -p "Nombre completo: " full_name
  [[ "$full_name" != *'|'* && "$full_name" != *:* ]] || { echo '[!] Nombre completo inválido.' >&2; return 1; }
  prim_grupo=$(seleccionar_registro "$equipos_db" 'Grupo primario') || return 1

  # Validar grupo
  grep -q "^${prim_grupo}|" "$equipos_db" || { error "Grupo no existe: $prim_grupo"; return 1; }

  extra_groups="" # Altas de trabajo: solo grupo primario.

  # Obtener próximo UID
  # Linux asigna un UID libre; no se calcula a partir de un catálogo parcial.

  # Crear grupo si no existe
  if ! getent group "$prim_grupo" &>/dev/null; then
    local gid=$(grep "^${prim_grupo}|" "$equipos_db" | cut -d'|' -f3)
    sudo groupadd -g "$gid" "$prim_grupo" || return 1
  fi

  asegurar_grupo_samba "$prim_grupo" || return 1
  registrar_grupo_catalogo "$prim_grupo" || return 1
  # Crear usuario Linux
  sudo useradd -M -d /nonexistent -s /usr/sbin/nologin -g "$prim_grupo" -c "$full_name" "$user" || { error "Error creando usuario Linux"; return 1; }
  uid=$(id -u "$user") || return 1

  # Generar password
  pass=$(generate_password)
  establecer_password_permanente "$user" "$pass" || { echo '[!] La cuenta se creó parcialmente; falló la contraseña o Samba.' >&2; return 1; }

  # Registrar en Samba

  # Registrar en DB
  created=$(date +%Y-%m-%d)
  registrar_usuario_catalogo "$user" || return 1

  info "Usuario creado: $user (uid=$uid)"
  mostrar_password_generada "$user" "$pass"
}

usuario_editar() {
  require_root
  local db="${DATA_DIR}/usuarios.db"
  local user line full_name prim_grupo extra_groups opt

  user=$(seleccionar_registro "$db" 'Usuario a editar') || return 1

  line=$(awk -F'|' -v user="$user" '$1 == user {print; exit}' "$db")
  [[ -n "$line" ]] || return 1

  echo ""
  echo "Opciones: 1) Nombre, 2) Contraseña, 3) Grupo único y perfil Samba, 4) Aplicar perfil Samba al grupo actual, 0) Volver"
  read -r -p "Opción: " opt

  case "$opt" in
    1)  # Nombre
      read -r -p "Nuevo nombre: " full_name
      [[ "$full_name" != *'|'* ]] || return 1
      sudo usermod -c "$full_name" "$user" || return 1
      registrar_usuario_catalogo "$user" || return 1
      info "Nombre actualizado"
      ;;
    2)  # Contraseña
      local pass=$(generate_password)
      establecer_password_permanente "$user" "$pass" || return 1
      info "Contraseña actualizada"
      mostrar_password_generada "$user" "$pass"
      ;;
    3)  # Grupo primario
      local new_grupo
      new_grupo=$(seleccionar_registro "${DATA_DIR}/equipos.db" 'Nuevo grupo primario') || return 1
      grep -q "^${new_grupo}|" "${DATA_DIR}/equipos.db" || { error "Grupo no existe"; return 1; }
      usuario_perfil_samba "$user" "$new_grupo" || return 1
      ;;
    4)
      prim_grupo=$(id -gn "$user") || return 1
      usuario_perfil_samba "$user" "$prim_grupo" || return 1
      ;;
  esac
}

usuario_eliminar() {
  require_root
  local db="${DATA_DIR}/usuarios.db"
  local user line

  user=$(seleccionar_registro "$db" 'Usuario a eliminar') || return 1

  line=$(awk -F'|' -v user="$user" '$1 == user {print; exit}' "$db")
  [[ -n "$line" ]] || return 1

  echo ""
  echo "Perfil del usuario:"
  id "$user" 2>/dev/null || echo "  No existe en Linux"
  echo "  Datos DB: $line"
  echo ""

  confirm "¿Eliminar usuario $user?" || return 1

  # Eliminar
  sudo userdel -r "$user" 2>/dev/null || warn "Error eliminando usuario Linux"
  sudo smbpasswd -x "$user" 2>/dev/null || warn "Error eliminando Samba"
  sed -i "/^${user}|/d" "$db"

  info "Usuario eliminado: $user"
}

menu_usuarios() {
  while true; do
    echo ""
    echo "=== Gestión de usuarios ==="
    echo "1. Listar usuarios"
    echo "2. Crear usuario"
    echo "3. Editar usuario"
    echo "4. Eliminar usuario"
    echo "5. Carga masiva de usuarios"
    echo "6. Volver"
    read -r -p "Opción: " opt

    case "$opt" in
      1) usuario_listar ;;
      2) usuario_crear ;;
      3) usuario_editar ;;
      4) usuario_eliminar ;;
      5) menu_carga_masiva ;;
      6) break ;;
      *) error_soft "Opción inválida" ;;
    esac
  done
}

error_soft() {
  echo "[!] $1" >&2
}
