# Bitácora — SCR-DIAG-REP

## 2026-10-05 — Verificador como descarga independiente

Por solicitud del usuario, se retiraron del repositorio `src/verificar_credenciales_csv.sh` y su prueba dedicada. Se conserva la utilidad como archivo descargable para ejecutar desde `/home/soporte/Downloads/` del NAS. Las correcciones de administración permanecen en el repositorio. Se actualizaron los comandos de la wiki y de la guía de carga.

## 2026-10-05 — Correcciones de administración y verificación de credenciales

- Creación individual y cambio de contraseña: formato `usuario:password`, doble entrada Samba, vigencia permanente, UID asignado por Linux y catálogo con datos reales.
- Importación: errores propagados sin falso éxito, GID primario resuelto por nombre, cuentas de sistema y administrativas preservadas en Linux/membresías, registro de usuarios actualizado y respaldos privados conservados.
- Bases Samba: copia con servicio detenido, comprobación del reinicio e intento de restauración del respaldo ante fallo. La sustitución de bases completas conserva su alcance explícito.
- Equipos: edición de descripciones sin la expresión sed incorrecta, renombrado de vínculo Samba por SID y cascada de referencias; eliminación condicionada a ausencia de miembros y éxito de Linux/Samba.
- Nuevo verificador de contraseñas CSV mediante comparación local de hashes NT; informa resultados sin exponer contraseñas o hashes. No modifica cuentas ni prueba permisos de carpetas.
- CSV Bitwarden preparado fuera del repositorio con las 21 credenciales originales; comprobada la conservación exacta de usuarios y contraseñas. No se han comprobado remotamente contra el NAS.
- Pruebas de regresión con comandos simulados y comprobación criptográfica de un vector NT conocido con OpenSSL real y entrada UTF-16LE preparada.

## 2026-10-05 — Catálogo y documentación de grupos

Se actualizó `wiki/INICIO.md` para documentar el menú real `src/menu.sh`, la distinción entre grupos de sistema y de trabajo, los registros Linux/Samba y las descripciones actuales. Se retiraron de la guía afirmaciones antiguas de GID fijos, membresía automática por dominio, rutas `/tmp/export_*` y rollback automático que no corresponden al flujo vigente.

Historial verificado de cambios recientes:

| Commit | Cambio |
|---|---|
| 44711eb | Retirada de la opción de recuperación y scripts temporales; permanece la carga corregida |
| b4119c4 | Registro de grupos durante carga/importación y sincronización inicial de todos los grupos Linux |
| 8136529 | Sincronización de grupos de trabajo IND_*, COR, OPE, COM y GEN; vínculos Samba y filtrado de entradas genéricas del sistema |

El catálogo inicial contenía seis departamentos: IND_PMO, IND_ARQ, IND_BIM, IND_GEO, IND_EST e IND_ITD. La falta de otros grupos en el menú no significaba que faltaran en Linux. La primera sincronización completa incluyó también grupos del sistema; el siguiente cambio corrigió esa mezcla.

Los grupos nuevos conservan el nombre Linux como display y `Grupo Linux` como descripción genérica. No hay definiciones confirmadas para todas las siglas: no se inventaron descripciones. Los GID se leen del destino. Los seis nombres y descripciones originales se conservan.

Las pruebas automatizadas usan comandos simulados y cubren filtrado, registro Samba sin duplicados, catálogo con GID reales y conservación de metadatos. La existencia efectiva de los vínculos en cada NAS debe verificarse con `sudo net groupmap list`; esta documentación no certifica una consulta remota al NAS.

## 2026-10-05 — Usuarios y carga masiva

- Corrección de `IFS='|'` al listar usuarios y salida visible de menús numerados.
- Carga CSV con seis columnas, contraseña permanente Linux/Samba y auditoría sin contraseñas.
- Corrección de vigencia Samba: `pdbedit -c '[X]'`, sin intentar modificar el indicador U.
- Altas nuevas sin carpeta personal ni consola: `-M -d /nonexistent -s /usr/sbin/nologin`.
- Detección de SID con `net getlocalsid` y registro en el manifiesto de exportación.
- Recuperación de 21 cuentas confirmada por la salida del NAS: 21 completadas, 0 errores. Luego se retiraron las herramientas temporales de recuperación.
- Las cuentas existentes no se convierten al volver a cargar el CSV. Las carpetas previas se conservan. No se afirma que todas las cuentas del NAS tengan shell bloqueada sin revisión del equipo.
