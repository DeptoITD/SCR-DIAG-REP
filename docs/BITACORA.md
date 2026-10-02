# BITACORA — Decisiones Arquitectónicas y Flujos

**Última actualización:** 2026-10-02  
**Sesión:** Implementación Carga Masiva + Importación Inteligente + Samba Completo

---

## Decisión 1: Carga Masiva de Usuarios (CSV → JSON)

**Problema:** Crear múltiples usuarios manualmente, repetitivo en servidor y NAS.

**Solución Implementada:**
- Módulo `carga_masiva.sh` lee CSV (usuario|nombre|grupo|dominio)
- Valida contra equipos.db local
- **Genera JSONs SEPARADOS** para servidor y NAS
- No duplica archivos entrada (mismo CSV para ambos)

**Justificación:**
- Reutiliza validaciones existentes (equipos.db)
- Genera outputs portables (JSON) para consumir en scripts remotos
- Servidor y NAS usan mismo JSON input pero aplican perfilamiento diferente
- Idempotente: validación antes de crear

**Decisión:** JSON outputs en lugar de directamente crear usuarios → permite dry-run y auditabilidad

---

## Decisión 2: Importación Inteligente (Multi-elemento)

**Problema:** `importar.sh` original importaba usuarios.db ciegamente, ignoraba Samba, fstab, sincronización.

**Solución Implementada:**
- Menú interactivo: elige qué importar (1-6 opciones)
- Análisis previo: detecta archivos disponibles
- DRY-RUN obligatorio (muestra cambios antes de aplicar)
- Sincronización usuarios existentes: compara grupo_prim, extra_groups, Samba
- **NO copia rutas/hostnames**: extrae políticas [global] portables
- fstab: referencia solo, NUNCA toca /etc/fstab

**Justificación:**
- **No asumir SERVER/NAS:** origen puede ser cualquier equipo
- **Transparencia:** dry-run obligatorio previene sorpresas
- **Seguridad:** sincronizar en lugar de crear duplicados
- **Portabilidad:** Samba config es específica del host (rutas, nombres)

**Decisión:** Menú + dry-run + sincronización en lugar de importación ciega

---

## Decisión 3: Migración Samba Segura (No Copiar SID)

**Problema:** passdb.tdb + secrets.tdb tienen datos específicos de máquina (SID), copiarlos rompe identidad.

**Análisis Realizado:**
```
SID = Security ID único por máquina
  - secrets.tdb: contiene SID máquina + machine account
  - passdb.tdb: contiene hashes contraseñas + UID/GID mapping
  
Si copias secrets.tdb a destino:
  ❌ Cambia SID destino → rompe relaciones de confianza
  ❌ Rompe sincronización con otros servidores
  ❌ Incompatible con réplica
```

**Solución Implementada:**

**OPCIÓN RECOMENDADA (por defecto):**
```
- Copiar passdb.tdb origen a destino
- NO copiar secrets.tdb
- Resultado: usuarios con SID destino, hashes origen
- Usuarios pueden autenticarse, confianzas intactas
```

**OPCIÓN EXPERTA (con advertencias):**
```
- Permitir cambiar SID (copiar secrets.tdb)
- Mostrar advertencia gigante
- Solo si usuario confirma explícitamente
- Caso de uso: replicar máquina idéntica
```

**Justificación:**
- **Seguridad:** no romper identidad máquina por defecto
- **Portabilidad:** SID destino es único, no reutilizable
- **Opción experta:** permite migración identidad para clusters
- **Educativo:** advertencias enseñan qué es SID

**Decisión:** Restaurar hashes SIN cambiar SID destino (opción experta disponible)

---

## Decisión 4: Mapeo UID Inteligente (Evitar Conflictos)

**Problema:** UID 1050 en origen ¿ocupa lugar en destino?

**Solución Implementada:**
```
Verificación previa:
  - Escanear todos UIDs origen
  - Detectar conflictos en destino
  - Reportar quién ocupa ese UID

Si UID libre → reutilizar
Si UID ocupado → opciones:
  A) Asignar siguiente UID libre (mapeo automático)
  B) Abortar e informar al operador
```

**Justificación:**
- **Idempotencia:** mismo UID = mismo usuario (importante para archivos)
- **Auditoría:** registrar mapeos UID viejo → nuevo
- **Seguridad:** no silenciosamente crear conflictos

**Decisión:** Verificar UIDs, permitir mapeo pero avisar cambios

---

## Decisión 5: Backups Automáticos Antes de Modificar

**Solución Implementada:**
```
Antes de aplicar cambios:
  - /etc/passwd → /tmp/backup_$$/passwd.bak
  - /etc/group → /tmp/backup_$$/group.bak
  - /var/lib/samba/private/passdb.tdb → passdb.tdb.bak

Rollback disponible:
  - rollback_linux() → restaura passwd+group
  - rollback_samba() → restaura passdb.tdb + reinicia smbd
```

**Justificación:**
- **Reversibilidad:** error no es catástrofe
- **Aprendizaje:** usuario puede revertir y revisar logs
- **Producción-ready:** backup automático es estándar

**Decisión:** Backups antes de tocar ficheros críticos

---

## Decisión 6: Permisos Restrictivos en Export (700)

**Solución Implementada:**
```
Exportación contiene:
  - passdb.tdb (hashes contraseñas)
  - secrets.tdb (secretos máquina)
  - usuarios_linux.txt (lista usuarios)

Permisos aplicados:
  - export_dir: 700 (solo root)
  - *.tdb: 600 (solo root)
  - README_SEGURIDAD.txt: advertencias
```

**Justificación:**
- **Seguridad:** no exponer credenciales a usuarios
- **Cumplimiento:** línea de base de seguridad
- **Educativo:** README enseña riesgos

**Decisión:** Permisos restrictivos + advertencias claras

---

## Decisión 7: No Asumir SERVER/NAS en Importación

**Problema:** Viejo importar.sh: "si origen es NAS, hace X; si es servidor, hace Y"

**Solución Implementada:**
```
Importación agnóstica:
  - No valida si origen/destino es SERVER/NAS
  - Usuarios+grupos funcionan igual en cualquier máquina
  - Samba config requiere pregunta interactiva (ruta local)
  - Resultado: bidireccional (SERVER↔NAS, SERVER↔SERVER, etc.)
```

**Justificación:**
- **Flexibilidad:** permite migraciones inesperadas
- **Mantenimiento:** menos casos especiales en código
- **Realidad:** usuario sabe mejor que script qué hace

**Decisión:** Flujo único agnóstico a tipo máquina

---

## Flujo Final: Export → Import Bidireccional

```
[ORIGEN cualquier tipo]
└─ bash menu.sh → 2: Exportar
   └─ exportar.sh v0.6
      ├─ usuarios_linux.txt (getent passwd)
      ├─ grupos_linux.txt (getent group)
      ├─ membresias.txt
      ├─ passdb.tdb (credenciales Samba)
      ├─ secrets.tdb (advertencia)
      ├─ smb.conf
      ├─ SID detected (manifest)
      └─ README_SEGURIDAD.txt
      Permisos: 700

[TRANSFER manual]
├─ SCP: scp -r export_* usuario@IP:path/
└─ USB/Samba manual

[DESTINO cualquier tipo]
└─ bash menu.sh → 3: Importar
   └─ importar.sh v0.7
      ├─ Analizar: SID origen vs destino
      ├─ Verificar: conflictos UID/GID
      ├─ Menú: qué importar (1-6 opciones)
      ├─ DRY-RUN: muestra cambios
      ├─ Confirmar
      ├─ Backups: passwd, group, passdb.tdb
      ├─ Aplicar:
      │  ├─ Crear/sincronizar usuarios Linux
      │  ├─ Crear/sincronizar grupos Linux
      │  ├─ Sincronizar membresías (gpasswd)
      │  └─ Restaurar hashes Samba (SID destino)
      ├─ Opción experta: cambiar SID si necesario
      └─ Rollback disponible si falla
      Resultado: usuarios + credenciales migradas
```

---

## Cambios de Comportamiento

| Aspecto | Antes | Ahora |
|---------|-------|-------|
| Usuarios existentes | [OK] ciego | Compara grupo/Samba, sincroniza |
| Samba | Ignorado | Importa hashes, preserva SID destino |
| fstab | Ignorado | Referencia, nunca toca /etc/fstab |
| smb.conf | No copia | Extrae políticas [global], pregunta rutas |
| Dry-run | No existe | Obligatorio antes de aplicar |
| Backups | No | Automáticos antes de cambios |
| Permisos export | Normal | 700 (secretos dentro) |

---

## Archivos Modificados (Feature Completa)

```
SCR-DIAG-REP/
├── src/modules/
│   ├── exportar.sh v0.6 (reescrito)
│   └── importar.sh v0.7 (reescrito)
├── src/utils.sh (+ helpers Samba)
├── src/modules/carga_masiva.sh (nuevo)
├── src/modules/usuarios.sh (menú + opción)
├── src/menu.sh (cargar módulos)
├── examples/usuarios_ejemplo.csv (nuevo)
├── FEATURE_CARGA_MASIVA.md
├── FEATURE_IMPORTAR_INTELIGENTE.md
├── FEATURE_SAMBA_MIGRACION_STATUS.md
└── docs/BITACORA.md (este archivo)
```

---

## Testing Realizado (Manual)

✅ Exportación completa: usuarios, grupos, Samba, SID  
✅ Verificación permisos (700)  
✅ Análisis SID origen vs destino  
✅ Menú interactivo 1-6 opciones  
✅ DRY-RUN output legible  
✅ Backups automáticos  
✅ Rollback functions  

**Pendiente:**
- Testing bidireccional real (SERVER→NAS, NAS→SERVER)
- Validación cambio SID (opción experta)
- Performance con 100+ usuarios

---

## Guía para Próximas Mejoras

### Corto Plazo
1. Completar testing bidireccional
2. Documentar guía operador (stepwise)
3. Logging detallado (qué cambió cuándo)

### Mediano Plazo
1. Soporte importación desde URL (SCP automático)
2. Historial importaciones
3. Auditoría de cambios

### Largo Plazo
1. Integración con Ansible/Terraform
2. Sincronización bidireccional continua (rsync identity)
3. Federación de árboles LDAP/AD

