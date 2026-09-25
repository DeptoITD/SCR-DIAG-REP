# SCR-DIAG-REP
**Categoría:** Script | **Fecha:** 2026-09-24 | **Depto:** IT+D

## Propósito
Replicar identidades (usuarios, grupos, Samba) + diagnosticar máquina (SMB, ACLs, storage, RAID, LVM).

**Flujo:**
```
Servidor Origen (srv-2)
  ├─ 01_diagnostico_completo.sh  → Recolecta estado máquina (SMB, storage, ACLs, RAID, LVM)
  ├─ 10_exportar_identidades.sh  → passwd, group, Samba, config (testparm, smb.conf, fstab)
  └─ Archivos export en src/export/
       ↓ (git push / SCP)
       ↓
NAS Destino (/opt/scripts/SCR-DIAG-REP)
  ├─ 20_crear_identidades_nas.sh → useradd, groupadd, smbpasswd (solo usuarios/grupos)
  └─ Siguiente: ACLs en repo SCR-ACL-REP (perfiles, especialidades, permisos)
```

**Integración con SCR-ACL-REP:**
- **SCR-DIAG-REP:** Setup inicial equipo + replicar identidades
- **SCR-ACL-REP:** Configurar ACLs, perfiles, especialidades (después de crear identidades)
- **Entrada ACL-REP:** `src/export/srv2_passwd.txt`, `src/export/srv2_group.txt` (UIDs/GIDs)

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

## Instalación

### 1. En Servidor Origen (srv-2)
```bash
cd /opt/scripts
git clone https://github.com/DeptoITD/SCR-DIAG-REP.git
cd SCR-DIAG-REP

# Editar config/servers.env
nano config/servers.env

# Diagnóstico (solo lectura, recolecta estado)
bash src/scripts/01_diagnostico_completo.sh

# Exportar identidades + config
bash src/scripts/10_exportar_identidades.sh
```

**Genera en `src/export/`:**
- `srv2_passwd.txt` — usuarios Linux
- `srv2_group.txt` — grupos Linux  
- `srv2_samba_users.txt` — usuarios Samba
- `srv2_testparm.conf` — config Samba
- `srv2_smbconf.txt` — backup smb.conf
- `srv2_fstab.txt` — mounts

### 2. En NAS Destino
```bash
cd /opt/scripts
git clone https://github.com/DeptoITD/SCR-DIAG-REP.git
cd SCR-DIAG-REP

# Editar config/servers.env
nano config/servers.env

# Modo simulación
bash src/scripts/RUNME.sh --dry-run

# Crear SOLO usuarios y grupos (no ACLs)
bash src/scripts/RUNME.sh --create-nas
```

**Nota:** ACLs configuradas en repo `SCR-ACL-REP` (separado)

## Uso

### Diagnóstico (Servidor)
```bash
bash src/scripts/01_diagnostico_completo.sh
```
Recolecta: sistema, servicios, usuarios, grupos, Samba, discos, RAID, LVM, mounts, ACLs, fstab.  
**Solo lectura, sin cambios.**

### Exportar (Servidor)
```bash
bash src/scripts/10_exportar_identidades.sh
```
Genera archivos en `src/export/hostname_*.txt`:
- passwd, group, Samba users, testparm config, smb.conf, fstab

### Crear Identidades (NAS)
```bash
bash src/scripts/20_crear_identidades_nas.sh
```
Lee export → crea **solo usuarios/grupos** locales + Samba.  
**No toca permisos ni ACLs.**

### Flujo Completo
```bash
# Simulación
bash src/scripts/RUNME.sh --dry-run

# Exportar
bash src/scripts/RUNME.sh --export-server

# Crear en NAS
bash src/scripts/RUNME.sh --create-nas

# Flujo completo (exportar + crear)
bash src/scripts/RUNME.sh --full
```

## Opciones Script Maestro (RUNME.sh)

| Opción | Función |
|--------|---------|
| `--export-server` | Exportar usuarios/grupos/Samba/config desde servidor |
| `--create-nas` | Crear usuarios y grupos en NAS (desde export) |
| `--acls` | ⚠️ AVISO: ACLs en repo `SCR-ACL-REP` (no usar aquí) |
| `--full` | Exportar + crear (no ACLs) |
| `--dry-run` | Simular sin cambios |
| `--help` | Mostrar ayuda |

## Configuración (servers.env)

```bash
# Servidor origen
SERVIDOR_ORIGEN_IP="192.168.x.x"
SERVIDOR_ORIGEN_USER="root"

# NAS destino
NAS_IP="192.168.x.x"
NAS_USER="soporte"
NAS_PATH="/opt/scripts/SCR-DIAG-REP"
```

## Logs
```bash
# Ver últimos logs
tail -f logs/*.log

# Buscar errores
grep ERROR logs/*.log
```

## Troubleshooting

### Permisos Denegados en Export
```bash
sudo chown -R soporte:soporte /opt/scripts/SCR-DIAG-REP/src/export
sudo chmod -R 755 /opt/scripts/SCR-DIAG-REP/src/export
```

### Usuario/Grupo Duplicado
Scripts validan existencia antes de crear. Si falla, revisar logs:
```bash
tail -20 logs/*.log
```

### Contraseña Samba
Por defecto usa `sambapass123`. Cambiar en `20_crear_identidades_nas.sh` línea ~76.

### ACLs y Permisos
**No aplicar ACLs aquí.** Usar repo `SCR-ACL-REP`:
- Define ACLs por compartir (share-level)
- Aplica setfacl por usuario/grupo
- Gestiona inheritance y masks

---

## Integración Repos

### SCR-DIAG-REP (Este)
**Cuándo usar:**
- ✅ Setup inicial nuevo equipo
- ✅ Diagnóstico estado máquina
- ✅ Replicar identidades servidor → NAS

**Salida (exports):**
- `src/export/srv2_passwd.txt` → UIDs/GIDs (entrada SCR-ACL-REP)
- `src/export/srv2_group.txt` → Grupos (entrada SCR-ACL-REP)
- `src/export/srv2_samba_users.txt` → Usuarios Samba
- `src/export/srv2_testparm.conf` → Config Samba
- `src/export/srv2_smb.conf` → Backup smb.conf
- `src/export/srv2_fstab.txt` → Mounts

### SCR-ACL-REP (Otro Repo)
**Cuándo usar:**
- ✅ Configurar perfiles y especialidades
- ✅ Cambio de accesos usuario (entra/sale proyecto)
- ✅ Aplicar permisos por compartir

**Entrada:**
- `SCR-DIAG-REP/src/export/srv2_passwd.txt`
- `SCR-DIAG-REP/src/export/srv2_group.txt`

**Salida:**
- ACLs POSIX aplicados (`setfacl`)
- Logs auditoría

### Secuencia Correcta
1. **SCR-DIAG-REP** → Exportar identidades
2. **SCR-DIAG-REP** → Crear usuarios/grupos en NAS
3. **SCR-ACL-REP** → Aplicar ACLs y perfiles (consume export de SCR-DIAG-REP)

## Bitácora
Ver `BITACORA.md` para histórico cambios y versiones.

---
**Autor:** IT+D | **Última actualización:** 2026-09-24
