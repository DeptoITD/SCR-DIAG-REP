# Carga masiva con contraseñas permanentes

Ejecuta `sudo bash src/menu.sh` y elige Usuarios → Carga masiva → Cargar usuarios desde archivo.

El archivo es UTF-8 con separador `|`, seis columnas y cabecera:

```text
usuario|nombre|grupo|dominio|uid|password
```

- `uid` puede quedar vacío para asignación automática. Un UID explícito debe estar libre en el destino.
- `password` es la contraseña definitiva: se conserva exactamente, incluidos espacios. No admite `|`, `:`, saltos de línea ni valor vacío.
- Los grupos de trabajo admitidos son `IND_*`, `COR`, `OPE`, `COM` y `GEN`. Si faltan, la carga crea su grupo Linux y lo registra en Samba con `net groupmap add`. El dominio del CSV es una referencia en la auditoría, no configura un dominio Samba ni agrega una membresía.
- Se validan todas las filas antes de confirmar. Un error impide aplicar el archivo completo.
- Las cuentas existentes se omiten sin modificar sus credenciales.
- Las nuevas cuentas de carga masiva, creación individual e importación se crean con `-M -d /nonexistent -s /usr/sbin/nologin`: sin carpeta personal y sin sesión de consola, shell SSH o SFTP. Los UID y grupos siguen disponibles para Samba.
- Para cuentas nuevas se establece la misma contraseña en Linux y Samba. Linux no exige cambio al primer ingreso y no establece vencimiento; Samba recibe el indicador de contraseña sin vencimiento (`[X]`). El tipo de cuenta normal se establece al crear la cuenta y no se modifica con `pdbedit -c`.
- La auditoría `src/export/usuarios_entrada.csv` y `config/data/usuarios.db` no contienen contraseñas. El resultado informa errores parciales: revisa esas cuentas antes de repetir la carga.

La opción aplica la carga en el equipo donde se ejecuta; ya no genera instrucciones para scripts de aplicación externos ausentes.


El CSV de entrada contiene contraseñas en texto y debe mantenerse con permisos restringidos, por ejemplo `chmod 600 archivo.csv` en Linux.

Referencia de los indicadores Samba: [pdbedit](https://www.samba.org/samba/docs/4.8/man-html/pdbedit.8.html).

## Catálogo de grupos

La carga masiva registra los grupos usados en `config/data/equipos.db`, incluso cuando el usuario ya existe. La importación registra cada grupo creado o encontrado, con el GID real del destino. Los nombres visibles, descripciones y fechas existentes se conservan; los grupos nuevos usan su nombre Linux como nombre visible.

Listar equipos o seleccionar grupos incorpora los grupos de trabajo y registra su vínculo en Samba sin duplicar vínculos existentes. Para completar un NAS existente, actualiza el repositorio, ejecuta `sudo bash src/menu.sh` y selecciona **5 → 1**. Los grupos de sistema agregados por la versión anterior se retiran del catálogo, sin borrar ningún grupo del sistema. Se conservan GID, usuarios y contraseñas.

En este servidor de Samba local, el grupo Linux sigue siendo necesario para permisos del sistema de archivos. El registro Samba lo vincula con una identidad Windows; no reemplaza el grupo Linux ni concede acceso a consola. Consulta los vínculos con `sudo net groupmap list`. Referencia: [net groupmap](https://www.samba.org/samba/docs/4.15/man-html/net.8.html).
