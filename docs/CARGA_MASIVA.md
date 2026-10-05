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
- Para cuentas nuevas se establece la misma contraseña en Linux y Samba. Linux no exige cambio al primer ingreso y no establece vencimiento; Samba recibe el indicador de contraseña sin vencimiento (`[X]`). El tipo de cuenta normal se establece al crear la cuenta y no se modifica con `pdbedit -c`.
- La auditoría `src/export/usuarios_entrada.csv` y `config/data/usuarios.db` no contienen contraseñas. El resultado informa errores parciales: revisa esas cuentas antes de repetir la carga.

La opción aplica la carga en el equipo donde se ejecuta; ya no genera instrucciones para scripts de aplicación externos ausentes.

Si una carga anterior falló únicamente con `ERROR_VIGENCIA_SAMBA`, usa la opción **4. Recuperar cuentas con error de vigencia Samba** antes de cargar otro archivo. Lee el último resultado, verifica UID, grupo primario y existencia en Samba, aplica `[X]` y completa el registro sin cambiar contraseñas ni crear cuentas. Conserva un respaldo de la auditoría y evita registros duplicados. Otros errores requieren revisión manual.

El CSV de entrada contiene contraseñas en texto y debe mantenerse con permisos restringidos, por ejemplo `chmod 600 archivo.csv` en Linux.

Referencia de los indicadores Samba: [pdbedit](https://www.samba.org/samba/docs/4.8/man-html/pdbedit.8.html).
