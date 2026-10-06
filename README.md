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
bash src/script.sh ayuda
sudo bash src/script.sh exportar
# En la NAS, después de copiar la carpeta:
sudo bash src/script.sh importar /home/soporte/export_srv-2_FECHA_HORA
sudo bash src/script.sh listar-grupos
sudo bash src/script.sh listar-usuarios
```

Flujo fijo: **exportar en servidor → copiar carpeta completa → importar en NAS → verificar → gestionar ACL en su repositorio**.

[Comandos rápidos y flujo completo servidor/NAS](src/docs/wiki/COMANDOS_RAPIDOS.md).

Para carga masiva: `sudo bash src/script.sh carga-masiva /ruta/usuarios.csv`.
Formato UTF-8: `usuario|nombre|grupo|dominio|uid|password`. El UID puede quedar vacío. Las cuentas existentes se omiten y conservan sus credenciales; el dominio es referencia de auditoría.

La única entrada es `src/script.sh ACCION`. Sin argumentos muestra ayuda. `usuarios`, `equipos` y `exportaciones` abren su administración específica. No existe un menú principal duplicado ni scripts de pruebas en el flujo.

Importar bases Samba completas sustituye sus credenciales; revisa el análisis antes de confirmar. Los respaldos se conservan en `logs/importacion.*`.

## Diagrama de secuencia (Entradas y Salidas)

```text
[Acción / CSV / carpeta exportada]
              ↓
[src/script.sh ACCION → módulo seleccionado]
              ↓
[Identidades Linux + Samba / src/config/data / src/export / logs]
```

## Estructura del repositorio

```text
SCR-DIAG-REP/
├── src/
│   ├── script.sh          ← Entrada principal
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
│   └── legacy/            ← Código anterior, fuera del flujo funcional
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
sudo bash src/script.sh ayuda
```

Ejecutar cada comando solo si el anterior termina correctamente. No aplicar `git stash pop` sobre las rutas antiguas: la copia respaldada ya quedó en las rutas nuevas. Esta migración no recrea cuentas Linux/Samba ni cambia contraseñas.

Si el equipo ya tiene la nueva estructura, basta `git pull --ff-only origin main` y `sudo bash src/script.sh ayuda`.

## Documentación

- [Wiki](src/docs/wiki/INICIO.md).
- [Carga masiva y grupos Samba](src/docs/CARGA_MASIVA.md).
- [Bitácora](BITACORA.md).

El verificador de credenciales es una descarga independiente, ejecutada desde Downloads; no es parte del repositorio. Los archivos de entrada con contraseñas se mantienen fuera de Git.
