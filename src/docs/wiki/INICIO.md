# SCR-DIAG-REP — Guía de uso

Actualizado: 2026-10-06.

## Entrada y menú vigente

```bash
cd /opt/scripts/SCR-DIAG-REP
sudo bash src/script.sh
```

1. Diagnóstico de equipo.
2. Exportar configuración.
3. Importar configuración desde una exportación.
4. Gestión de exportaciones.
5. Gestión de equipos/grupos de trabajo.
6. Gestión de usuarios; incluye carga masiva.
7. Salir.

Esta guía corresponde a `src/menu.sh` y `src/modules/`. `src/main.sh` y `src/menu.sh` son accesos compatibles al mismo flujo; la entrada principal es `src/script.sh`.

## Grupos Linux, de sistema y de trabajo Samba

Todos los grupos locales tienen una identidad Linux para los permisos de archivos. Un grupo de trabajo puede tener además un vínculo Samba (`groupmap`) que le asigna una identidad Windows. Tener nombre `IND_*` no prueba por sí solo que el vínculo exista: comprobar con `sudo net groupmap list`.

| Clase | Ejemplos | Uso |
|---|---|---|
| Sistema/servicios | root, daemon, bin, sys, tty, disk, shadow, systemd-*, _ssh, messagebus, avahi, pulse, lightdm | Operación de Linux y sus servicios; no son departamentos |
| Administración o grupos generales | sudo, adm, users, soporte, sambashare, netdev, plugdev | Privilegios y funciones generales; tampoco son departamentos por su nombre |
| Trabajo admitido por el programa | IND_*, COR, OPE, COM, GEN | Catálogo de equipos y registro de vínculos Samba |

`sambashare` no es una lista de todos los usuarios de Samba. El nombre de un grupo Linux y su GID tampoco demuestran que esté registrado en Samba.

### Por qué cambiaron los listados

1. El catálogo inicial `equipos.db` contenía solo seis departamentos. Los usuarios y Linux ya podían tener otros grupos sin que aparecieran allí.
2. El cambio `b4119c4` incorporó todos los grupos Linux y mostró también los del sistema.
3. El cambio `8136529` limita la sincronización a `IND_*`, `COR`, `OPE`, `COM` y `GEN`, y registra sus vínculos Samba. Retira del catálogo las entradas genéricas de sistema añadidas antes; no borra grupos Linux.

Las filas personalizadas con descripción distinta de `Grupo Linux` se conservan. Los nombres nuevos fuera de la convención anterior requieren adaptar la regla `es_grupo_trabajo` en `src/utils.sh`; no se incluyen automáticamente.

## Dónde quedan registrados

| Registro | Contenido | Consulta |
|---|---|---|
| Linux/NSS, normalmente `/etc/group` | Nombre, GID y miembros adicionales | `getent group NOMBRE` |
| Linux/NSS, normalmente `/etc/passwd` | Usuario y GID primario, home y shell | `getent passwd USUARIO` |
| Base de vínculos Samba, según su backend/configuración | Grupo Windows/SID vinculado al grupo Linux | `sudo net groupmap list` |
| Base de cuentas Samba, según su backend/configuración | Credenciales y propiedades Samba | `sudo pdbedit -L` |
| `src/config/data/equipos.db` | `grupo|display|gid|descripcion|fecha` | Menú 5 → 1 |
| `src/config/data/usuarios.db` | Usuario, nombre, grupo primario, extras, UID y fecha | Menú 6 → 1 |
| `src/export/usuarios_entrada.csv` | Resultado de la última carga, sin contraseñas | Carga masiva → 2 |
| `src/export/export_HOST_FECHA/grupos_linux.txt` | Grupos del origen, incluidos grupos de sistema | Exportación → archivo |

El archivo de grupos Linux no enumera a los miembros primarios en su último campo. Su relación está en el GID del usuario. `id genesis.bustos` sí muestra ambas clases de membresía. El listado de usuarios del programa lee su registro, y los grupos extra allí pueden diferir del sistema si se cambiaron fuera del programa.

## Descripciones actuales

Estas son las descripciones del catálogo inicial y las observadas en el NAS. Los GID del NAS se consultan en Linux; no se asignan a partir de esta tabla.

| Grupo | Nombre visible | Descripción actual |
|---|---|---|
| IND_PMO | Oficina PMO | Gestor de proyectos - solo lectura |
| IND_ARQ | Arquitectura | Equipo de arquitectura |
| IND_BIM | BIM | Equipo BIM - full control WIP |
| IND_GEO | Topografía | Equipo de topografía |
| IND_EST | Estructuras | Equipo de estructuras |
| IND_ITD | IT+D | Equipo IT+Desarrollo |
| COR, OPE, COM, GEN | El mismo nombre del grupo | Grupo Linux |
| IND_GTC, IND_SGI, IND_SVC, IND_TYF, IND_QAB, IND_PROP, IND_BDE, IND_CYM, IND_GTH | El mismo nombre del grupo | Grupo Linux |

`Grupo Linux` es un texto genérico, no una descripción del departamento. No se han inferido los significados de esas siglas. Las descripciones de lectura/control son metadatos: no conceden ni restringen permisos por sí solas. Los permisos efectivos dependen de Samba y las ACL.

## Actualizar y consultar en el NAS

```bash
cd /opt/scripts/SCR-DIAG-REP
git pull --ff-only origin main
sudo bash src/script.sh
```

Selecciona 5 → 1. La sincronización registra los grupos de trabajo que ya existen en Linux y crea sus vínculos Samba si faltan, sin duplicarlos. Si Samba rechaza el registro, el programa informa el error; no asumir que todos están vinculados sin verificar:

```bash
sudo net groupmap list
getent group IND_GTC
id genesis.bustos
```

## Creación y carga masiva

Formato UTF-8, seis columnas separadas por `|`:

```text
usuario|nombre|grupo|dominio|uid|password
```

Menú 6 → 5 → 1. El UID puede quedar vacío para asignación automática. La contraseña se usa exactamente como aparece, sin vencimiento y sin cambio obligatorio al primer ingreso en la carga masiva. El dominio del CSV es una referencia de auditoría; no agrega automáticamente una membresía ni configura un dominio Samba.

La carga crea grupos de trabajo faltantes en Linux, registra el vínculo Samba y guarda el catálogo. Las cuentas nuevas se crean con `-M -d /nonexistent -s /usr/sbin/nologin`; tienen identidad Linux para permisos, sin home nuevo ni consola. Los usuarios existentes se omiten sin cambiar contraseñas ni su shell. Las excepciones administrativas `soporte`, `sara.albarracin` y `juan.rojas` existentes no se convierten por esta carga.

No hay opción de recuperación ni script de conversión: fueron retirados tras la corrección. Las carpetas antiguas no se borran automáticamente.

Ver [detalle de carga masiva](../CARGA_MASIVA.md). El CSV de entrada contiene contraseñas: mantener permisos restringidos. Las auditorías nuevas no las incluyen.

## Exportación e importación

Origen: menú 2. Copia la carpeta `src/export/export_HOST_FECHA/` al mismo directorio de exportaciones del destino. Destino: menú 3 y selección numerada de carpeta y componentes.

`manifest.txt` contiene metadatos y SID; no es un CSV de usuarios. El SID local se consulta con `net getlocalsid`. Una exportación antigua puede carecer de SID y necesitar generarse de nuevo.

Al importar grupos, se utiliza el GID real del destino para el catálogo y se registran en Samba los grupos de trabajo admitidos. Los grupos Linux generales que incluya la exportación no se convierten automáticamente en grupos de trabajo Samba. Los usuarios nuevos importados se crean sin home ni shell interactiva. La referencia fstab no modifica automáticamente `/etc/fstab`.

Antes de aplicar se muestran análisis y confirmación. El flujo vigente no ofrece un rollback automático al final; revisar los errores reportados y los respaldos disponibles. Importar `passdb.tdb` afecta la base de credenciales Samba del destino, y `secrets.tdb` puede cambiar su identidad: revisar cuidadosamente esas opciones.

Las importaciones conservan los respaldos en `logs/importacion.*` y se detienen al fallar un componente. Las cuentas administrativas `soporte`, `sara.albarracin` y `juan.rojas` se omiten en la importación Linux y de membresías. Restaurar una base Samba completa sigue sustituyendo sus credenciales: esa operación no garantiza conservar las contraseñas del destino.

## Comprobar las credenciales del CSV y Bitwarden

Descargar la utilidad independiente `verificar_credenciales_csv.sh` y copiarla a `/home/soporte/Downloads/` del NAS. No se instala mediante `git pull`.

```bash
sudo bash /home/soporte/Downloads/verificar_credenciales_csv.sh /home/soporte/Downloads/usuarios_contrasenas_permanentes.csv
```

El resultado `[COINCIDE]` confirma que la contraseña del CSV coincide con la guardada en Samba y que no hay indicadores de bloqueo/deshabilitación. No muestra secretos ni modifica cuentas. No sustituye una prueba de permisos de carpetas. Ver [comprobación y formato Bitwarden](../CARGA_MASIVA.md).

## Referencias

- [Samba: net groupmap](https://www.samba.org/samba/docs/4.15/man-html/net.8.html).
- [Samba: pdbedit](https://www.samba.org/samba/docs/4.8/man-html/pdbedit.8.html).
- [Bitácora](../../../BITACORA.md).
