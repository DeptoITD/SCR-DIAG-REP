# Feature: Migración Samba Completa — Estado Actual

**Rama:** `feature/exportar-importar-samba-completo`  
**Estado:** 50% — Exportación completa, Importación en desarrollo

---

## ✅ IMPLEMENTADO

### exportar.sh (v0.6) — Exportación Completa
```
✅ Usuarios Linux (getent passwd → usuarios_linux.txt)
✅ Grupos Linux (getent group → grupos_linux.txt)
✅ Membresías (gpasswd → membresias.txt)
✅ Samba credenciales (passdb.tdb)
✅ Samba secretos (secrets.tdb con advertencia)
✅ Samba configuración (smb.conf)
✅ Detectar SID máquina
✅ Permisos restrictivos (700 export_dir)
✅ Manifest con metadata Samba
✅ README_SEGURIDAD.txt
```

**Archivos generados:**
```
export_HOSTNAME_TIMESTAMP/
├── manifest.txt ← SID, versión Samba, timestamp
├── usuarios_linux.txt ← getent passwd (UID/GID)
├── grupos_linux.txt ← getent group (GID)
├── membresias.txt ← membresías grupos
├── passdb.tdb ← credenciales Samba (CRÍTICO)
├── secrets.tdb ← secretos máquina (ADVERTENCIA)
├── smb.conf ← configuración shares
├── smbusers ← mapeos usuario (si existe)
├── samba_users_detalle.txt ← auditoría legible (pdbedit -L -v)
├── testparm.txt ← validación
├── fstab.txt ← montajes
├── usuarios.db ← DB nuestra (compat)
├── equipos.db ← DB nuestra (compat)
└── README_SEGURIDAD.txt ← advertencias

Permisos: 700 (solo root puede leer)
```

### utils.sh — Funciones Samba Helpers
```
✅ detectar_samba_sid(source) — lee SID origen vs destino
✅ verificar_conflictos_uid_gid(export_dir) — analiza conflictos
✅ rollback_linux(backup_dir) — restaura /etc/passwd, /etc/group
✅ rollback_samba(backup_dir) — restaura passdb.tdb
✅ advertencia_secrets_tdb() — muestra riesgos SID
```

---

## ❌ POR HACER

### importar.sh (v0.7) — Importación Samba Completa

**Flujo a implementar:**

1. **Análisis Previo**
   ```
   - Detectar SID origen vs destino (diferentes)
   - Verificar conflictos UID/GID
   - Listar usuarios a crear vs sincronizar
   - Mostrar reporte SID
   ```

2. **DRY-RUN**
   ```
   - Simular creación usuarios Linux
   - Mostrar mapeo UID (si cambia)
   - Mostrar mapeo Samba (recrear con SID destino)
   - NO aplicar cambios
   ```

3. **Backups**
   ```
   - Backup /etc/passwd → /tmp/backup_/passwd.bak
   - Backup /etc/group → /tmp/backup_/group.bak
   - Backup /var/lib/samba/private/passdb.tdb
   - Backup /var/lib/samba/private/secrets.tdb (NO usar)
   ```

4. **Crear Usuarios Linux**
   ```
   Para cada usuario en usuarios_linux.txt:
     - Si no existe: useradd -u UID -g GID -s SHELL
     - Si existe con UID diferente:
       * Mapear UID viejo → nuevo libre
       * Cambiar UID (usermod -u)
       * Reasignar ficheros (find + chown -R)
     - Aplicar membresías (gpasswd -a)
   ```

5. **Importar Samba (Opción Recomendada)**
   ```
   ESTRATEGIA: Restaurar hashes SIN cambiar SID
   
   - No copiar secrets.tdb (rompe SID)
   - Leer passdb.tdb origen
   - Para cada usuario:
     * Crear en destino: pdbedit -u -a -m usuario
     * Extraer hash NT origen
     * Restaurar hash destino: pdbedit -u usuario -w HASH
   - Resultado: usuarios con SID destino, hashes origen
   ```

6. **Validación**
   ```
   - testparm -s
   - pdbedit -L (listar usuarios creados)
   - id usuario (verificar UID/GID)
   - systemctl restart smbd
   ```

7. **Rollback si Falla**
   ```
   - rollback_linux()
   - rollback_samba()
   - systemctl restart smbd
   - Mostrar estado anterior
   ```

---

## Funciones a Agregar a importar.sh

```bash
# Importar usuarios Linux completo
importar_usuarios_linux_completo()

# Importar grupos Linux
importar_grupos_linux()

# Importar membresías
importar_membresias()

# Importar Samba (restaurar hashes)
importar_samba_hashes()

# Opción experta: cambiar SID (RIESGO)
importar_samba_secrets_cambiar_sid()

# Análisis previo migracion
analizar_migracion_samba()

# Generar reporte conflictos UID
generar_reporte_conflictos()
```

---

## Cambios Próxima Sesión

**Reescribir importar.sh** con:
- Integración SID (detectar destino vs origen)
- Migración usuarios Linux (UID mapeo inteligente)
- Migración Samba hashes (restaurar sin SID origen)
- Opción experta secrets.tdb (con advertencias)
- Análisis previo detallado
- Backups automáticos
- Rollback funcional
- Dry-run obligatorio

**Testing:**
```
SERVER → NAS (usuarios Linux + Samba completo)
NAS → SERVER (ídem)
SERVER → SERVER (migración completa)
```

---

## Decisiones Implementadas

✅ **NO copiar secrets.tdb ciegamente** (rompe SID)  
✅ **Restaurar hashes NT** (portables, SID destino)  
✅ **Mapeo UID inteligente** (detectar conflictos, reasignar)  
✅ **Backups automáticos** (antes de modificar)  
✅ **Rollback funcional** (restaurar estado anterior)  
✅ **Permisos restrictivos** (700 en export)  
✅ **Advertencias claras** (secrets.tdb, SID)  

---

## Próximo Paso

Rama lista para:
1. Reescribir importar.sh (Fase 2)
2. Testing bidireccional (Fase 3)
3. Merge a main (Fase 4)

**Salvar: branch feature/exportar-importar-samba-completo sin merge (WIP)**

