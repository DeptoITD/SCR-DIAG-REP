# SCR-DIAG-REP — Guía de uso

Actualizado: 2026-10-06.

## Entrada y flujo vigente

Única entrada: `src/script.sh ACCION`. Consulta [Comandos rápidos — servidor y NAS](COMANDOS_RAPIDOS.md) para el flujo fijo exportar → copiar → importar → verificar y los comandos actuales.

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
| `src/config/data/equipos.db` | `grupo|display|gid|descripcion|fecha` | `listar-grupos` |
| `src/config/data/usuarios.db` | Usuario, nombre, grupo primario, extras, UID y fecha | `listar-usuarios` |
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
sudo bash src/script.sh listar-grupos
```

La sincronización registra los grupos de trabajo que ya existen en Linux y crea sus vínculos Samba si faltan, sin duplicarlos. Si Samba rechaza el registro, el programa informa el error; no asumir que todos están vinculados sin verificar:

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

Ejecuta `sudo bash src/script.sh carga-masiva /ruta/usuarios.csv`. El UID puede quedar vacío para asignación automática. La contraseña se usa exactamente como aparece, sin vencimiento y sin cambio obligatorio al primer ingreso en la carga masiva. El dominio del CSV es una referencia de auditoría; no agrega automáticamente una membresía ni configura un dominio Samba.

La carga crea grupos de trabajo faltantes en Linux, registra el vínculo Samba y guarda el catálogo. Las cuentas nuevas se crean con `-M -d /nonexistent -s /usr/sbin/nologin`; tienen identidad Linux para permisos, sin home nuevo ni consola. Las cuentas existentes reciben la contraseña del CSV y se verifican; home y shell existentes se conservan. `soporte` se excluye de la carga y migración Samba.

No hay opción de recuperación ni script de conversión: fueron retirados tras la corrección. Las carpetas antiguas no se borran automáticamente.

Ver [detalle de carga masiva](../CARGA_MASIVA.md). El CSV de entrada contiene contraseñas: mantener permisos restringidos. Las auditorías nuevas no las incluyen.

## Exportación e importación

Ejecuta `sudo bash src/script.sh exportar`, transfiere la carpeta completa mediante RustDesk o USB y ejecuta `sudo bash src/script.sh importar /ruta/carpeta` en el destino.

El paquete v1.0 incluye `credenciales_samba.txt` con hashes, identidades Linux, grupos y membresías. Se valida antes de crear el manifiesto de exportación completa. Una cuenta de trabajo Linux sin credencial Samba impide dar la exportación por válida. El archivo de credenciales no debe publicarse ni pegarse en conversaciones.

La importación valida todos los archivos antes de confirmar, incorpora grupos y cuentas faltantes, sincroniza el nombre y grupo primario de las existentes y agrega membresías. Resuelve grupos por nombre y GID del destino; un conflicto UID requiere resolución previa. Las cuentas nuevas no generan home ni consola; las existentes conservan home y shell.

Las contraseñas compartidas se toman del origen. Las cuentas exclusivas del destino se conservan. `soporte` se excluye de Samba, aunque su administración Linux permanece. Cada credencial se verifica por hash y estado habilitado; no se muestra el hash. Se establece contraseña Samba sin vencimiento.

No se copia `passdb.tdb` sobre la base del destino ni se importa `secrets.tdb`: se conserva su SID. No se modifica fstab ni la configuración de recursos compartidos. Las exportaciones v0.5 sin credenciales deben regenerarse.

Los respaldos quedan en `logs/importacion.*`. Una falla detiene el flujo y no anuncia éxito; puede haber cambios parciales y se conserva el respaldo para revisarlos. Las ACL deben comprobarse en el almacenamiento por separado.

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

## Grupo único y perfil Samba desde Gestión de usuarios

Ejecuta `sudo bash src/script.sh usuarios`. Crear usuario asigna únicamente el grupo primario seleccionado, sin grupos adicionales, home ni consola.

En Editar usuario, opción 3 selecciona el grupo único y aplica `/nonexistent` y `nologin`; opción 4 aplica el mismo perfil usando el grupo primario actual. Se muestra el cambio y se confirma antes de retirar todas las membresías adicionales. Las contraseñas Samba no se cambian por esta operación.

Una carpeta antigua `/home/usuario` se elimina definitivamente después de confirmar, únicamente si todos sus archivos son idénticos a los iniciales de `/etc/skel`. Se conservan respaldos privados de los registros Linux, no una copia de la carpeta. Si hay archivos personales o modificados, se rechaza la conversión y se conserva el home. Se rechazan enlaces, rutas personales no estándar y montajes. Las cuentas soporte, sara.albarracin y juan.rojas están protegidas de esta conversión.

El grupo privado antiguo no se elimina automáticamente porque puede existir como propietario de archivos o ACL en otros sitios. Puede permanecer como grupo sin pertenencias; `id usuario` debe mostrar únicamente el grupo asignado.

Este perfil se aplica desde la gestión manual. La importación y la carga CSV conservan home y shell de cuentas existentes; las nuevas se crean sin home y con nologin.

## Liberar espacio de homes antiguos

En servidor y NAS, ejecuta `sudo bash src/script.sh limpiar-homes`. Muestra candidatos y pide confirmación antes de borrar. Solo considera cuentas Samba que existen en Linux y carpetas `/home/usuario` sin enlaces ni montajes. Todos los archivos deben coincidir byte a byte con `/etc/skel`; contenido adicional o modificado se conserva para revisión.

Después de confirmar, elimina los homes iniciales y establece `/nonexistent` y `nologin`. Conserva grupos y contraseñas. Excluye soporte, sara.albarracin y juan.rojas. Los respaldos de registros Linux se conservan en `logs/limpieza-homes.*`; no se respalda el contenido eliminado. Una falla puede dejar cambios parciales y se informa como incidencia.

Las carpetas mostradas de 24 KB liberan poco espacio: no se debe borrar el home administrativo para aumentar ese ahorro. Esta opción no elimina respaldos de homes generados por versiones anteriores.
