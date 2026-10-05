# Carga masiva con contraseñas permanentes

Ejecuta `sudo bash src/menu.sh` y elige Usuarios → Carga masiva → Cargar usuarios desde archivo.

El archivo es UTF-8 con separador `|`, seis columnas y cabecera:

```text
usuario|nombre|grupo|dominio|uid|password
```

- `uid` puede quedar vacío para asignación automática. Un UID explícito debe estar libre en el destino.
- `password` es la contraseña definitiva: se conserva exactamente, incluidos espacios. No admite `|`, `:`, saltos de línea ni valor vacío.
- El grupo debe existir en Linux. El dominio es una referencia en la auditoría, no se configura un dominio Samba ni se asigna un grupo adicional con ese valor.
- Se validan todas las filas antes de confirmar. Un error impide aplicar el archivo completo.
- Las cuentas existentes se omiten sin modificar sus credenciales.
- Las nuevas cuentas de carga masiva, creación individual e importación se crean con `-M -d /nonexistent -s /usr/sbin/nologin`: sin carpeta personal y sin sesión de consola, shell SSH o SFTP. Los UID y grupos siguen disponibles para Samba.
- Para cuentas nuevas se establece la misma contraseña en Linux y Samba. Linux no exige cambio al primer ingreso y no establece vencimiento; Samba recibe el indicador de contraseña sin vencimiento (`[X]`). El tipo de cuenta normal se establece al crear la cuenta y no se modifica con `pdbedit -c`.
- La auditoría `src/export/usuarios_entrada.csv` y `config/data/usuarios.db` no contienen contraseñas. El resultado informa errores parciales: revisa esas cuentas antes de repetir la carga.

La opción aplica la carga en el equipo donde se ejecuta; ya no genera instrucciones para scripts de aplicación externos ausentes.

Si una carga anterior falló únicamente con `ERROR_VIGENCIA_SAMBA`, usa la opción **4. Recuperar cuentas con error de vigencia Samba** antes de cargar otro archivo. Lee el último resultado, verifica UID, grupo primario y existencia en Samba, aplica `[X]` y completa el registro sin cambiar contraseñas ni crear cuentas. Conserva un respaldo de la auditoría y evita registros duplicados. Otros errores requieren revisión manual.

El CSV de entrada contiene contraseñas en texto y debe mantenerse con permisos restringidos, por ejemplo `chmod 600 archivo.csv` en Linux.

Referencia de los indicadores Samba: [pdbedit](https://www.samba.org/samba/docs/4.8/man-html/pdbedit.8.html).

## Revisar y convertir cuentas anteriores

En el NAS, después de actualizar los scripts:

```bash
sudo bash src/revisar_acceso_samba.sh
sudo bash src/revisar_acceso_samba.sh --aplicar
```

El primer comando solo muestra la revisión. El segundo convierte las cuentas normales de Samba o `usuarios.db` a `/nonexistent` y `/usr/sbin/nologin`. Preserva siempre `soporte`, `sara.albarracin`, `juan.rojas`, root y la cuenta que ejecuta sudo; no altera la configuración SSH, claves, contraseñas, UID, grupos ni credenciales Samba. Las excepciones Sara y Juan deben existir para aplicar; un nombre equivocado impide los cambios. Se pueden preservar excepciones adicionales con `--preservar nombre1,nombre2`.

Guarda respaldo de `/etc/passwd` y un registro de home/shell anteriores en `logs/acceso-samba.*`. Las carpetas personales previas no se borran ni se mueven: revisa su contenido antes de eliminar datos. La revisión protege cuentas de sistema (UID inferior a 1000 o igual/superior a 65534).
