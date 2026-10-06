# Scripts Heredados (Deprecated)

Este directorio contiene scripts que fueron superados por la nueva arquitectura de menú interactivo en `src/menu.sh`. Se conservan aquí únicamente como referencia y auditoría.

## Scripts archivados:

- **00_diagnostico_equipo1.sh** — versión anterior/reducida de diagnóstico (reemplazada por `modules/diagnostico.sh`)
- **10_exportar_identidades.sh** — exportación de identidades (reemplazada por `modules/exportar.sh`, con corrección del bug DRY_RUN)
- **20_crear_identidades_nas.sh** — creación de identidades en NAS (reemplazada por `modules/importar.sh`, con corrección del bug de grupos vacíos)
- **crear_usuarios_indesco_v4.sh** — creación one-off de 24 usuarios hardcodeados (datos migrados a `config/data/usuarios.db`)
- **registrar_samba_usuarios_v2.sh** — registro Samba de 24 usuarios hardcodeados (datos migrados a `config/data/usuarios.db`, lógica reemplazada por `modules/usuarios.sh`)
- **habilitar_ssh.sh** — configuración de SSH (fuera de alcance del nuevo sistema)

## NO usar estos scripts directamente.

Para usar el sistema, ejecutar: `bash src/menu.sh`

Cambios principales en la nueva arquitectura:
- Menú interactivo unificado (elimina flags `--diagnostico`, `--export-server`, etc.)
- Datos de usuarios/equipos en `config/data/` (eliminan hardcoding de contraseñas)
- Corrección del bug de grupos vacíos al importar (membresía preservada en `group_membership.txt`)
- Diagnóstico sin side-effects (console-only por defecto)
