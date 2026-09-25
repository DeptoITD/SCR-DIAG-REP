# BITÁCORA — SCR-DIAG-REP
**Categoría:** Script | **Departamento:** IT+D

| Versión | Fecha | Responsable | Tipo | Descripción |
|---|---|---|---|---|
| v0.2 | 2026-09-24 | IT+D | Desarrollo | Estructura completa: scripts exportación, creación identidades, ACLs; config servidores; utils y RUNME orquestador |
| v0.1 | 2026-09-24 | IT+D | Creación | Creación inicial repo SCR-DIAG-REP (plantilla vacía) |

## Cambios v0.2 (2026-09-24)

### Nuevos Archivos
- `config/servers.env` — Configuración centralizada (IPs, rutas, credenciales)
- `src/utils.sh` — Funciones compartidas (log, error, info, backup, permisos)
- `src/scripts/10_exportar_identidades.sh` — Exporta passwd, group, Samba desde servidor
- `src/scripts/20_crear_identidades_nas.sh` — Crea usuarios/grupos en NAS desde archivos
- `src/scripts/30_crear_acls.sh` — Configura permisos y ACLs en NAS
- `src/scripts/RUNME.sh` — Orquestador maestro (--export-server, --create-nas, --acls, --full, --dry-run)

### Mejoras
- Validación de archivos antes de procesamiento
- Backup automático de archivos existentes
- Modo simulación (`--dry-run`) sin cambios reales
- Logging centralizado en `logs/`
- Soporte para grupos, usuarios Linux y Samba

### TODO (v0.3+)
- [ ] Script transferencia SSH de archivos servidor → NAS
- [ ] Validación contraseñas Samba robusta
- [ ] Soporte Active Directory / LDAP
- [ ] Restauración desde backup
- [ ] Pruebas integración en CI/CD
- [ ] Documentación ACLs avanzadas (inheritance, masks)

## Notas de Uso

### Primer Run
```bash
cd /opt/scripts/SCR-DIAG-REP

# 1. Verificar config
nano config/servers.env

# 2. Simulación
bash src/scripts/RUNME.sh --dry-run

# 3. Si todo OK, ejecutar
bash src/scripts/RUNME.sh --full
```

### Flujo típico
1. Servidor exporta → `src/export/srv2_*.txt`
2. NAS recibe archivos (git pull o SCP)
3. NAS crea identidades → logs en `logs/`
4. Verificar: `id usuario` en NAS

### Monitoreo
```bash
# Ver progress real-time
tail -f logs/*.log

# Contar usuarios creados
grep "Usuario creado:" logs/*.log | wc -l

# Buscar errores
grep "ERROR\|Error\|error" logs/*.log
```

---
*Última actualización: 2026-09-24 por IT+D*
