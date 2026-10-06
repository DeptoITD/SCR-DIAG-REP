#!/bin/bash
# Entrada principal del repositorio.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/menu.sh" "$@"
