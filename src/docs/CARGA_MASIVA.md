# Carga masiva con contraseñas permanentes

Ejecuta `sudo bash src/script.sh carga-masiva /ruta/usuarios.csv`.

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
- La auditoría `src/export/usuarios_entrada.csv` y `src/config/data/usuarios.db` no contienen contraseñas. El resultado informa errores parciales: revisa esas cuentas antes de repetir la carga.

La opción aplica la carga en el equipo donde se ejecuta; ya no genera instrucciones para scripts de aplicación externos ausentes.


El CSV de entrada contiene contraseñas en texto y debe mantenerse con permisos restringidos, por ejemplo `chmod 600 archivo.csv` en Linux.

Referencia de los indicadores Samba: [pdbedit](https://www.samba.org/samba/docs/4.8/man-html/pdbedit.8.html).

## Catálogo de grupos

La carga masiva registra los grupos usados en `src/config/data/equipos.db`, incluso cuando el usuario ya existe. La importación registra cada grupo creado o encontrado, con el GID real del destino. Los nombres visibles, descripciones y fechas existentes se conservan; los grupos nuevos usan su nombre Linux como nombre visible.

Listar equipos o seleccionar grupos incorpora los grupos de trabajo y registra su vínculo en Samba sin duplicar vínculos existentes. Para completar un NAS existente, actualiza el repositorio, ejecuta `sudo bash src/script.sh listar-grupos`. Los grupos de sistema agregados por la versión anterior se retiran del catálogo, sin borrar ningún grupo del sistema. Se conservan GID, usuarios y contraseñas.

En este servidor de Samba local, el grupo Linux sigue siendo necesario para permisos del sistema de archivos. El registro Samba lo vincula con una identidad Windows; no reemplaza el grupo Linux ni concede acceso a consola. Consulta los vínculos con `sudo net groupmap list`. Referencia: [net groupmap](https://www.samba.org/samba/docs/4.15/man-html/net.8.html).

## Comprobar contraseñas guardadas en Samba

El verificador es una utilidad descargable independiente, fuera del repositorio. Copiar `verificar_credenciales_csv.sh` a `/home/soporte/Downloads/` del NAS antes de ejecutar el comando siguiente.

En el NAS, ejecutar:

```bash
sudo bash /home/soporte/Downloads/verificar_credenciales_csv.sh /home/soporte/Downloads/usuarios_contrasenas_permanentes.csv
```

La comprobación compara el hash NT calculado a partir de cada contraseña del CSV con el hash local de Samba. No cambia cuentas, no intenta autenticaciones y no imprime contraseñas ni hashes. Requiere `pdbedit`, `iconv` y OpenSSL con MD4 (proveedor legacy en OpenSSL 3). Informa coincidencias, diferencias, cuentas ausentes y cuentas bloqueadas/deshabilitadas. Su éxito comprueba las contraseñas almacenadas; no comprueba red ni permisos de carpetas.

Para una prueba de acceso real, usar `smbclient -L localhost -U genesis.bustos`: la contraseña se solicita de forma interactiva. Para comprobar permisos, conectarse a una carpeta concreta. No usar la contraseña en los argumentos del comando.

Para Bitwarden, importar el CSV preparado como **Bitwarden (csv)**. Es un archivo de credenciales en texto: almacenarlo fuera del repositorio y eliminar la copia de transferencia cuando ya esté importado. Referencia: [formato CSV de Bitwarden](https://bitwarden.com/es-la/help/condition-bitwarden-import/).

## Errores y respaldos

La creación individual y el cambio de contraseña también establecen credenciales permanentes mediante `chpasswd`, dos entradas para `smbpasswd` y `[X]` en Samba. La creación usa un UID libre asignado por Linux y actualiza `usuarios.db` con las membresías reales.

La importación detiene el flujo si falla un componente y no anuncia éxito. Omite cuentas de sistema y preserva las cuentas administrativas existentes; no cambia automáticamente el UID de una cuenta existente. Resuelve el grupo primario por nombre y usa su GID del destino. Los usuarios y membresías importados actualizan el catálogo. Los respaldos privados de Linux, catálogos y bases Samba se conservan bajo `logs/importacion.*`.

La restauración de una base Samba detiene el servicio antes de copiarla, comprueba el reinicio e intenta restaurar el respaldo ante un fallo. Es una sustitución completa de la base, no una combinación de credenciales; revisar su alcance antes de confirmar. No se promete reversión completa de todas las altas y membresías.

Renombrar equipos actualiza el vínculo Samba por SID y las referencias del catálogo de usuarios; cambiar descripciones también actualiza Samba. La eliminación comprueba miembros reales antes de borrar y conserva la fila del catálogo si falla Linux o Samba.
