# SCR-DIAG-REP
**Categoría:** Script | **Fecha:** 2026-09-24 | **Depto:** IT+D

## Propósito
Replicar identidades (usuarios, grupos, Samba) + diagnosticar máquina (SMB, ACLs, storage, RAID, LVM).

**Flujo Simple:**
```
1. EQUIPO A (Origen)
   └─ bash menu.sh → 2: Exportar
      └─ Genera: src/export/export_hostname_timestamp/
         └─ Muestra instrucciones: qué copiar + qué correr en otro equipo

2. COPIA MANUAL (USB, SCP, Samba, etc.)
   └─ Copia carpeta export_* a otro equipo
      └─ En: /opt/scripts/SCR-DIAG-REP/src/export/

3. EQUIPO B (Destino)
   └─ bash menu.sh → 3: Importar
      └─ Selecciona export_* 
      └─ Crea usuarios, grupos, Samba locales
```

**Integración con SCR-ACL-REP:**
- **SCR-DIAG-REP:** Exportar identidades + crear en destino
- **SCR-ACL-REP:** Configurar ACLs, perfiles, especialidades (después de este repo)
- **Entrada ACL-REP:** `src/export/usuarios.db`, `src/export/equipos.db`

## Archivos Exportados
- `srv2_passwd.txt` — Usuarios Linux (uid, gid, home, shell)
- `srv2_group.txt` — Grupos Linux
- `srv2_samba_users.txt` — Usuarios Samba (pdbedit -L)
- `srv2_testparm.conf` — Config Samba (testparm -s)
- `srv2_smbconf.txt` — Backup smb.conf
- `srv2_fstab.txt` — Mounts persistentes

## Estructura
```
SCR-DIAG-REP/
├── config/
│   └── servers.env          ← Configuración IPs, rutas, credenciales
├── src/
│   ├── scripts/
│   │   ├── 10_exportar_identidades.sh      ← Exporta del servidor
│   │   ├── 20_crear_identidades_nas.sh     ← Crea en NAS
│   │   ├── 30_crear_acls.sh                ← Configura permisos
│   │   └── RUNME.sh                        ← Orquestador maestro
│   ├── export/              ← Archivos exportados (srv2_*.txt)
│   └── utils.sh             ← Funciones compartidas
├── logs/                    ← Registros ejecución
├── BITACORA.md              ← Histórico cambios
└── README.md
```

## Instalación Rápida

### Cualquier Equipo (igual proceso)
```bash
cd /opt/scripts
git clone https://github.com/DeptoITD/SCR-DIAG-REP.git
cd SCR-DIAG-REP

# Listo. No necesitas editar servers.env si usas /opt/scripts/SCR-DIAG-REP
bash menu.sh
```

**Eso es todo.** El repo es agnóstico y funciona en cualquier máquina.

## Uso (Menú Interactivo)

```bash
bash menu.sh
```

### 1. Diagnóstico
```
→ 1: Diagnóstico de equipo
```
Recolecta (solo lectura): sistema, servicios, usuarios, grupos, Samba, discos, RAID, LVM, mounts, ACLs, fstab.

### 2. Exportar
```
→ 2: Exportar configuración
```
Genera: `src/export/export_hostname_YYYYMMDD_HHMMSS/`

**Al terminar muestra:**
- Dónde está la carpeta
- Cómo copiarla a otro equipo (SCP o manual)
- Qué comando correr en el otro equipo para importar

### 3. Importar
```
→ 3: Importar configuración
```
- Busca carpetas en `src/export/`
- Selecciona una
- Crea usuarios, grupos, Samba locales

### 4. Gestión de Exportaciones
```
→ 4: Gestión de exportaciones
   → 1: Listar disponibles
   → 2: Limpiar antiguas (>30 días)
```

## Configuración (servers.env)

**Mínima (por defecto, funciona así):**
```bash
REPO_PATH="/opt/scripts/SCR-DIAG-REP"
EXPORT_PATH="${REPO_PATH}/src/export"
LOG_DIR="${REPO_PATH}/logs"
DATA_DIR="${REPO_PATH}/config/data"
```

No necesitas IPs, SSH, ni permisos especiales.  
**Si clonas en otro path:** actualiza `REPO_PATH` en servers.env.

## Logs
```bash
tail -f logs/*.log        # Ver en tiempo real
grep ERROR logs/*.log     # Buscar errores
```

## Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| `Permission denied` en export | Permisos en `src/export/` | `sudo chown -R $USER: src/export` |
| Usuario/Grupo duplicado | Ya existe en sistema | Script detecta y salta. Revisar logs |
| Archivo export vacío | `usuarios.db` no existe | Crear primero en Gestión de usuarios (opción 6) |
| Importar muestra (vacío) | Sin carpetas en `src/export/` | Ejecutar Exportar primero (opción 2) |

**Ver logs:**
```bash
tail -50 logs/*.log
```

### ACLs y Permisos
**No aplicar aquí.** Usar repo `SCR-ACL-REP` después:
- Define ACLs por proyecto/especialidad
- Aplica setfacl por usuario/grupo
- Gestiona inheritance y masks

---

## Integración con SCR-ACL-REP

Después de replicar identidades aquí, usa `SCR-ACL-REP` para:
1. Configurar perfiles y especialidades
2. Aplicar ACLs por proyecto
3. Auditoría de accesos

**Entrada SCR-ACL-REP:**
- `src/export/usuarios.db`
- `src/export/equipos.db`

**Ver:** `INTEGRACION.md` para detalles técnicos.

---
**Autor:** IT+D | **Última actualización:** 2026-09-30
