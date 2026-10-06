#!/bin/bash
# Inicialización compartida; no ejecuta el menú al ser importada.
export REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CONFIG_DIR="$REPO_PATH/src/config"
source "$CONFIG_DIR/servers.env" || return 1
mkdir -p "$LOG_DIR" "$DATA_DIR" "$EXPORT_PATH" || return 1
for catalogo in usuarios.db equipos.db; do
  if [[ ! -f "$DATA_DIR/$catalogo" ]]; then
    if [[ -f "$REPO_PATH/config/data/$catalogo" ]]; then
      cp -p "$REPO_PATH/config/data/$catalogo" "$DATA_DIR/$catalogo" || return 1
    else
      cp "$CONFIG_DIR/defaults/$catalogo" "$DATA_DIR/$catalogo" || return 1
    fi
  fi
done
export LOG_FILE="$LOG_DIR/ejecucion.log"
touch "$LOG_FILE" || return 1
source "$REPO_PATH/src/utils.sh" || return 1
