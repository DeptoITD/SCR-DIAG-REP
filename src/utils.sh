#!/bin/bash
# Funciones compartidas

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg"
  [[ -n "${LOG_FILE:-}" ]] && echo "$msg" >> "${LOG_FILE}"
}

error() {
  local msg="[ERROR] $1"
  echo "$msg" >&2
  [[ -n "${LOG_FILE:-}" ]] && echo "$msg" >> "${LOG_FILE}"
  exit 1
}

info() {
  local msg="[INFO] $1"
  echo "$msg"
  [[ -n "${LOG_FILE:-}" ]] && echo "$msg" >> "${LOG_FILE}"
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    cp "$file" "${file}.bak.$(date +%s)"
    info "Backup creado: ${file}.bak.$(date +%s)"
  fi
}

set_perms() {
  local path="$1"
  local user="$2"
  [[ -e "$path" ]] && sudo chown -R "$user:$user" "$path"
}
