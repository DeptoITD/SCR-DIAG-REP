# BITÁCORA — SCR-DIAG-REP
**Categoría:** Script | **Departamento:** IT+D

| Versión | Fecha | Responsable | Tipo | Descripción |
|---|---|---|---|---|
| v0.5 | 2026-09-30 | IT+D | Simplificación | Sin SSH/NAS automático. Flujo: Exportar → Copiar manual → Importar. Menú interactivo. |
| v0.3 | 2026-09-24 | IT+D | Docs | Diagnóstico mejorado; Exportar config Samba; Crear solo usuarios/grupos; ACLs en repo separado |
| v0.2 | 2026-09-24 | IT+D | Desarrollo | Estructura: diagnóstico, exportación, creación identidades, ACLs; utils y RUNME |
| v0.1 | 2026-09-24 | IT+D | Creación | Creación inicial repo SCR-DIAG-REP (plantilla) |

## Cambios v0.5 (2026-09-30) — Simplificación Flujo

### Cambios Principales
- **Sin SSH automático** → Usuario copia archivos manualmente (SCP, USB, Samba, etc.)
- **Sin SSH automático** → Instrucciones copy-paste al terminar exportar
- **servers.env mínimo** → Solo paths locales, sin IPs ni configuración SSH
- **Menú simplificado** → Opción 4 ahora es "Gestión de exportaciones" (listar, limpiar)
- **Flujo agnóstico** → Funciona igual en cualquier máquina en `/opt/scripts/SCR-DIAG-REP`

### Archivos Modificados
- **config/servers.env** — Remover NAS, solo paths locales. Agregar comentario sobre copia manual.
- **src/utils.sh** — Agregar `mostrar_instrucciones_transfer()` con SCP + qué correr en otro equipo
- **src/modules/exportar.sh** — Remover NAS sync. Llamar a `mostrar_instrucciones_transfer()` al final.
- **src/modules/importar.sh** — Simplificar: buscar solo locales, mejor UI para seleccionar
- **src/modules/sync.sh** — Remover SSH/NAS. Solo: listar exportaciones + limpiar antiguas
- **src/menu.sh** — Actualizar títulos: opción 4 = "Gestión de exportaciones"
- **README.md** — Flujo simplificado, instalación rápida, uso interactivo, troubleshooting mini

### Ventajas
- ✅ Sin dependencias SSH
- ✅ Sin permisos sudoers
- ✅ Sin configuración de NAS
- ✅ Más fácil de entender ("copiar archivo, importar")
- ✅ Funciona incluso desconectado de red (después de copiar)

### Cómo Usar (Nuevo)
1. Equipo A: `bash src/menu.sh → 2: Exportar` → Ve instrucciones
2. Copia manual: `scp -r export_* otro_equipo:/opt/scripts/SCR-DIAG-REP/src/export/`
3. Equipo B: `bash src/menu.sh → 3: Importar` → Selecciona carpeta → Crea usuarios/grupos

### Diferencias v3 → v5 (Qué cambió de documentos/flujo)

| Aspecto | v0.3 | v0.5 |
|---------|------|------|
| **Entrada usuario** | RUNME.sh con flags (--export, --create, --acls) | Menú interactivo (bash src/menu.sh) |
| **Archivos generados** | srv2_passwd.txt, srv2_group.txt, srv2_samba_users.txt, srv2_testparm.conf, srv2_smb.conf, srv2_fstab.txt | usuarios.db, equipos.db, group_membership.txt, manifest.txt, smb.conf, testparm.txt, fstab.txt, samba_users.txt |
| **Transferencia** | Automática SSH + NAS (si configurado) | Manual (SCP, USB, Samba) + instrucciones copy-paste |
| **Config** | servers.env con IPs, SSH, NAS | servers.env solo paths locales |
| **ACLs** | Aquí mismo (30_crear_acls.sh) | Repo separado (SCR-ACL-REP) |
| **Permisos** | Requiere sudoers config | No requiere (copia manual) |
| **Agnóstico** | No (asume srv-2) | Sí (funciona cualquier máquina) |

### Traza v3 (Archivos que ya NO se generan en v5)
- ❌ `srv2_passwd.txt` — Reemplazado por `usuarios.db` (binaria)
- ❌ `srv2_group.txt` — Reemplazado por `equipos.db` (binaria)
- ❌ `srv2_smbpasswd.exp` — Ya no se genera (contraseñas en config/servers.env)
- ✅ `srv2_samba_users.txt` → Renombrado `samba_users.txt` (sin prefijo)
- ✅ `srv2_testparm.conf` → Renombrado `testparm.txt` (sin prefijo, sin .conf)
- ✅ `srv2_smb.conf` → Ahora `smb.conf` (sin prefijo srv2_)
- ✅ `srv2_fstab.txt` → Ahora `fstab.txt` (sin prefijo srv2_)
- ✅ NUEVO: `usuarios.db` (base datos usuarios)
- ✅ NUEVO: `equipos.db` (base datos equipos/grupos)
- ✅ NUEVO: `group_membership.txt` (membresía grupos generada)
- ✅ NUEVO: `manifest.txt` (metadata exportación)

---

## Cambios v0.3 (2026-09-24) — Integración SCR-ACL-REP

### Alineación con SCR-ACL-REP
- Formato exports estándar: passwd/group completos (compatible SCR-ACL-REP)
- Validaciones: GID existe antes de crear usuario
- Config centralizada: SAMBA_PASSWORD en servers.env
- Documentación: INTEGRACION.md explica flujo consumo

### Documentación
- README: flujo claro + sección Integración Repos
- INTEGRACION.md: qué consume SCR-ACL-REP de cada export
- Diagnóstico mejorado: SMB, RAID, LVM, ACLs, fstab
- ACLs referenciadas a repo `SCR-ACL-REP` (separado)

### Funcionalidad
- 01_diagnostico_completo.sh: recolecta TODO (sistema, SMB, storage, ACLs)
- 10_exportar_identidades.sh: passwd/group en formato estándar + config Samba
- 20_crear_identidades_nas.sh: usuarios/grupos idempotentes, Samba desde config
- RUNME.sh: --diagnostico, --full, --acls DEPRECATED

### Scripts Modificados v0.3
- **01_diagnostico_completo.sh** — NUEVO. Diagnostica: sistema, servicios, usuarios, grupos, Samba, discos, RAID, LVM, mounts, ACLs, fstab
- **10_exportar_identidades.sh** — Formato passwd/group estándar (completo); Agregado export de testparm.conf, smb.conf, fstab
- **20_crear_identidades_nas.sh** — Valida GID existe antes de crear usuario; Samba password desde config/servers.env
- **30_crear_acls.sh** — Marcado DEPRECATED. Referencia a repo SCR-ACL-REP
- **RUNME.sh** — Agregado --diagnostico, actualizado --full, --acls marcado DEPRECATED
- **config/servers.env** — Agregado SAMBA_PASSWORD variable
- **INTEGRACION.md** — NUEVO. Documentación consumo exports para SCR-ACL-REP

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

## Notas de Uso (v0.5)

### Primer Run
```bash
cd /opt/scripts/SCR-DIAG-REP
sudo su
bash src/menu.sh

# 1. Opción 1: Diagnóstico (opcional, solo lectura)
# 2. Opción 2: Exportar (genera export_hostname_YYYYMMDD_HHMMSS/)
# 3. Sigue instrucciones en pantalla: copia manual a otro equipo
# 4. En otro equipo: Opción 3: Importar
```

### Flujo típico
1. Servidor exporta → `src/export/export_srv2_20261002_120000/` (con instrucciones)
2. Copia manual: `scp -r export_* nas:/opt/scripts/SCR-DIAG-REP/src/export/`
3. NAS importa → `bash src/menu.sh → 3: Importar` → Selecciona export → Crea usuarios
4. Verificar: `getent passwd | grep -E "1[0-9]{3}:"` (ver usuarios creados)

### Monitoreo & Logs
**Ver logs en tiempo real:**
```bash
tail -f logs/script_*.log
```

**Buscar errores:**
```bash
grep ERROR logs/script_*.log
grep "require_root\|Permission denied" logs/script_*.log
```

**Ver detalle de importación:**
```bash
grep "Usuario\|Grupo\|Samba" logs/script_*.log
```

**Ver últimas operaciones:**
```bash
ls -lht logs/ | head -5
cat logs/$(ls -t logs/script_*.log | head -1)
```

---
**Última actualización:** 2026-10-02 v0.5 (Wiki + Logs + Comparativa v3→v5)
