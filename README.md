# SCR-DIAG-REP
**Categoría:** Script
**Fecha de actualización:** 2026-10-06
**Departamento:** IT+D

## Propósito
Gestionar usuarios y grupos de trabajo para Samba; cargar credenciales desde CSV y exportar/importar identidades entre servidor y NAS.

## Descripción técnica
Bash 4 o superior sobre Linux, con sudo, herramientas de usuarios/grupos, Samba (`net`, `pdbedit`, `smbpasswd`) y systemd para restaurar bases Samba. El repositorio calcula sus rutas desde su ubicación: no exige estar instalado en `/opt/scripts`.

Las altas nuevas se crean sin carpeta personal ni consola (`/nonexistent`, `nologin`). La carga masiva usa contraseñas permanentes del CSV. Los grupos de trabajo `IND_*`, `COR`, `OPE`, `COM` y `GEN` se vinculan con Samba y se registran en el catálogo.

## Instrucciones de uso

```bash
cd /opt/scripts/SCR-DIAG-REP
sudo bash src/script.sh
```

1. Diagnóstico.
2. Exportar configuración.
3. Importar una exportación.
4. Gestión de exportaciones.
5. Gestión de equipos/grupos de trabajo.
6. Gestión de usuarios, incluida carga masiva.
7. Salir.

`src/menu.sh` y `src/main.sh` conservan acceso al mismo menú. No hay scripts de pruebas en el flujo funcional.

Carga CSV: menú 6 → 5 → 1, formato UTF-8:

```text
usuario|nombre|grupo|dominio|uid|password
```

UID vacío permite asignación automática. Los usuarios existentes se omiten; sus credenciales no se cambian. El dominio es referencia de auditoría. Las importaciones preservan respaldos en `logs/importacion.*` y no anuncian éxito si falla un componente. Restaurar bases Samba completas sustituye sus credenciales: revisar antes de confirmar.

## Diagrama de secuencia (Entradas y Salidas)

```text
[Menú / CSV / carpeta exportada]
              ↓
[src/script.sh → menú → módulo seleccionado]
              ↓
[Identidades Linux + Samba / src/config/data / src/export / logs]
```

## Estructura del repositorio

```text
SCR-DIAG-REP/
├── src/
│   ├── script.sh          ← Entrada principal
│   ├── menu.sh            ← Menú común
│   ├── main.sh            ← Acceso compatible
│   ├── iniciar.sh         ← Rutas, catálogos y registro
│   ├── utils.sh           ← Funciones compartidas
│   ├── modules/           ← Operaciones funcionales
│   ├── config/
│   │   ├── servers.env    ← Rutas relativas al repositorio
│   │   ├── defaults/      ← Catálogos iniciales versionados
│   │   └── data/          ← Catálogos locales, fuera de Git
│   ├── export/            ← Exportaciones locales, fuera de Git
│   ├── docs/              ← Wiki, guías e historial
│   ├── examples/          ← Ejemplos de entrada
│   └── legacy/            ← Código anterior, no cargado por el menú
├── logs/                  ← Registros y respaldos, fuera de Git
├── BITACORA.md
└── README.md
```

El arranque crea los directorios de ejecución y `logs/ejecucion.log`. Solo inicializa catálogos cuando no existen; conserva los existentes. Para una instalación anterior puede copiar `config/data/*.db` al nuevo directorio. Las actualizaciones futuras no versionan los catálogos de cada equipo.

## Actualizar un NAS con la estructura anterior

Antes del primer pull de esta reorganización, respaldar los catálogos locales. Si Git tiene cambios en esos archivos, guardarlos antes de descargar los cambios; no sobrescribirlos con los ejemplos.

```bash
cd /opt/scripts/SCR-DIAG-REP
respaldo="$HOME/SCR-DIAG-REP-config-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$respaldo"
sudo cp -a config/data "$respaldo/data"
git stash push -m "Catalogos anteriores antes de reorganizar" -- config/data/usuarios.db config/data/equipos.db
git pull --ff-only origin main
sudo mkdir -p src/config/data
sudo cp -a "$respaldo/data/." src/config/data/
sudo bash src/script.sh
```

Ejecutar cada comando solo si el anterior termina correctamente. No aplicar `git stash pop` sobre las rutas antiguas: la copia respaldada ya quedó en las rutas nuevas. Esta migración no recrea cuentas Linux/Samba ni cambia contraseñas.

Si el equipo ya tiene la nueva estructura, basta `git pull --ff-only origin main` y `sudo bash src/script.sh`.

## Documentación

- [Wiki](src/docs/wiki/INICIO.md).
- [Carga masiva y grupos Samba](src/docs/CARGA_MASIVA.md).
- [Bitácora](BITACORA.md).

El verificador de credenciales es una descarga independiente, ejecutada desde Downloads; no es parte del repositorio. Los archivos de entrada con contraseñas se mantienen fuera de Git.
