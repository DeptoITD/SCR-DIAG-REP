#!/bin/bash
# Funciones compartidas

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

error() {
  echo "[ERROR] $1" >&2 | tee -a "${LOG_FILE}"
  exit 1
}

info() {
  echo "[INFO] $1" | tee -a "${LOG_FILE}"
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
