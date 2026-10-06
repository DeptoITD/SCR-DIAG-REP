#!/bin/bash
# core/comun.sh — Funciones compartidas (logging, validación, control)

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

warn() {
  local msg="[WARN] $1"
  echo "$msg" >&2
  [[ -n "${LOG_FILE:-}" ]] && echo "$msg" >> "${LOG_FILE}"
}

require_root() {
  [[ $(id -u) -eq 0 ]] || error "Requiere root (sudo)"
}

confirm() {
  local prompt="$1"
  read -r -p "$prompt [s/N]: " ans
  [[ "$ans" =~ ^[sS]$ ]]
}

trim() {
  local var="$1"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  echo "$var"
}

run_cmd() {
  local dry_run="${1:-0}" cmd="$2"
  if [[ $dry_run -eq 1 ]]; then
    echo "[DRY-RUN] $cmd"
  else
    bash -c "$cmd" || error "Falló: $cmd"
  fi
}
