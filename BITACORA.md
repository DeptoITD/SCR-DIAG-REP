# BITÁCORA — SCR-DIAG-REP
**Categoría:** Script | **Departamento:** IT+D

| Versión | Fecha | Responsable | Tipo | Descripción |
|---|---|---|---|---|
| v0.7 | 2026-10-05 | IT+D | Corrección | Menús visibles, SID, lectura de usuarios y carga CSV con contraseñas permanentes |
| v0.7 | 2026-10-05 | IT+D | Corrección | Altas sin home/consola, recuperación de cuentas y posterior retiro de herramientas temporales |
| v0.7 | 2026-10-05 | IT+D | Catálogo | Registro de grupos y GID del destino; posterior filtrado a grupos de trabajo y vínculos Samba |
| v0.7 | 2026-10-05 | IT+D | Documentación | Wiki y explicación de registros Linux/Samba y descripciones de grupos |
| v0.8 | 2026-10-06 | IT+D | Corrección | Creación individual, edición de equipos, registro de importados y respaldos conservados |
| v0.8 | 2026-10-06 | IT+D | Organización | Verificador de credenciales separado como descarga externa |
| v0.8 | 2026-10-06 | IT+D | Reorganización | Raíz src/, logs/, README y bitácora; configuración/documentación/ejemplos/código histórico dentro de src/ |
| v0.8 | 2026-10-06 | IT+D | Flujo | Entrada src/script.sh; main y menu comparten flujo; inicialización de rutas y catálogos sin sobrescribir datos existentes |
| v0.8 | 2026-10-06 | IT+D | Limpieza | Retirada de pruebas del repositorio y de copias generadas del seguimiento de Git; datos y exportaciones locales ignorados |

El historial narrativo anterior se conserva en [src/docs/historico/BITACORA_20261005.md](src/docs/historico/BITACORA_20261005.md). Las fechas de entradas anteriores se conservan allí tal como fueron registradas; esta tabla resume los cambios sin declarar una fecha de creación original no verificada.
| v0.9 | 2026-10-06 | IT+D | Flujo | Una entrada con acciones explícitas; retiro de main/menu duplicados; comandos rápidos servidor/NAS en wiki, rutas directas para CSV e importación |
| v1.0 | 2026-10-06 | IT+D | Credenciales | Exportación validada con hashes portables; importación por cuentas sin reemplazar base/SID y con verificación; carga CSV sincroniza cuentas existentes, excluye soporte y conserva respaldos privados |
| v1.0 | 2026-10-06 | IT+D | Usuarios | Alta manual con grupo único; edición aplica perfil Samba sin home/consola, retira grupos extra, respalda carpetas antiguas y protege cuentas administrativas |
| v1.0 | 2026-10-06 | IT+D | Limpieza | Limpieza confirmada de homes Samba idénticos a /etc/skel para liberar espacio; conserva archivos personales, montajes, enlaces y cuentas administrativas; perfil manual deja de mover homes a logs |
