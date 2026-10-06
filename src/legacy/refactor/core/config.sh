#!/bin/bash
# core/config.sh — Parsear y validar configuración

CONFIG_DIR="${CONFIG_DIR:-.}"
USUARIOS_DB="${CONFIG_DIR}/data/usuarios.db"
EQUIPOS_DB="${CONFIG_DIR}/data/equipos.db"
DOMINIOS_DB="${CONFIG_DIR}/data/dominios.db"

validar_config() {
  [[ -f "$USUARIOS_DB" ]] || error "Falta: $USUARIOS_DB"
  [[ -f "$EQUIPOS_DB" ]] || error "Falta: $EQUIPOS_DB"
  [[ -f "$DOMINIOS_DB" ]] || error "Falta: $DOMINIOS_DB"
  log "✓ Config validada"
}

leer_usuarios() {
  grep -v "^#" "$USUARIOS_DB" | grep -v "^$"
}

leer_equipos() {
  grep -v "^#" "$EQUIPOS_DB" | grep -v "^$"
}

leer_dominios() {
  grep -v "^#" "$DOMINIOS_DB" | grep -v "^$"
}

usuario_existe() {
  local user="$1"
  leer_usuarios | cut -d'|' -f1 | grep -q "^${user}$"
}

grupo_existe() {
  local grp="$1"
  leer_equipos | cut -d'|' -f1 | grep -q "^${grp}$"
}

dominio_valido() {
  local dom="$1"
  leer_dominios | cut -d'|' -f1 | grep -q "^${dom}$"
}
