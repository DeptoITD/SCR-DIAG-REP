#!/bin/bash
# Compatibilidad: el mismo flujo de src/script.sh.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/script.sh" "$@"
