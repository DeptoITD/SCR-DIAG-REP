#!/bin/bash
# Pruebas sin cambios al sistema ni dependencias de Samba instalado.
set -euo pipefail
cd "$(dirname "$0")/.."
source src/utils.sh
source src/modules/importar.sh
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
export EXPORT_PATH="$temp_dir/exports con espacios"
mkdir -p "$EXPORT_PATH/export_equipo_20261005"
expected="$EXPORT_PATH/export_equipo_20261005"
selected=$(seleccionar_export <<< 1 2>"$temp_dir/menu")
[[ "$selected" == "$expected" ]]
grep -q '1) export_equipo_20261005' "$temp_dir/menu"
if (seleccionar_export <<< 0) > /dev/null 2>&1; then exit 1; fi
if (seleccionar_export <<< abc) > /dev/null 2>&1; then exit 1; fi
for option in 1 2 3 4 5; do
  selected=$(menu_seleccionar_importacion <<< "$option" 2>"$temp_dir/menu")
  [[ "$selected" == usuarios* && "$selected" != *'¿QUÉ'* ]]
  grep -q '1) Solo USUARIOS' "$temp_dir/menu"
  grep -q '6) PERSONALIZADO' "$temp_dir/menu"
done
selected=$(menu_seleccionar_importacion <<< $'6\ns\nn\ns\nn\ns' 2>"$temp_dir/menu")
[[ "$selected" == usuarios,membresias,fstab ]]
grep -q 'Marca qué importar' "$temp_dir/menu"
if (menu_seleccionar_importacion <<< 7) > /dev/null 2>&1; then exit 1; fi
printf 'samba_sid=S-1-5-21-123-456-789\r\n' > "$temp_dir/manifest.txt"
[[ $(detectar_samba_sid "$temp_dir/manifest.txt") == S-1-5-21-123-456-789 ]]
if detectar_samba_sid "$temp_dir/ausente" > /dev/null 2>&1; then exit 1; fi
net() { echo 'SID for domain NAS is: S-1-5-21-987-654-321'; }
[[ $(detectar_samba_sid) == S-1-5-21-987-654-321 ]]
net() { return 1; }
if detectar_samba_sid > /dev/null 2>&1; then exit 1; fi
echo 'OK: menús visibles, selecciones limpias y detección de SID.'
