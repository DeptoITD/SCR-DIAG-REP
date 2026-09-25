# SCR-DIAG-REP
**Categoría:** Script | **Fecha:** 2026-09-24 | **Depto:** IT+D

## Propósito
Script de replicación de identidades (usuarios, grupos, Samba) del servidor origen al NAS.

**Flujo:**
```
Servidor origen (srv-2)
    ↓
  Exporta: passwd, group, samba_users
    ↓
  Archivos .txt en src/export/
    ↓
NAS (/opt/scripts/SCR-DIAG-REP)
    ↓
  Importa identidades locales + Samba
    ↓
  Configura ACLs y permisos
```

## Archivos Exportados
- `srv2_passwd.txt` — Usuarios Linux (uid, gid, home, shell)
- `srv2_group.txt` — Grupos Linux
- `srv2_samba_users.txt` — Usuarios Samba
- `srv2_smbpasswd.exp` — Contraseñas Samba (protegido)

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

# Editar config/servers.env con IPs correctas
nano config/servers.env

# Ejecutar exportación
bash src/scripts/10_exportar_identidades.sh
```

Archivos generados en `src/export/`:
- `srv2_passwd.txt`
- `srv2_group.txt`
- `srv2_samba_users.txt`
- `srv2_smbpasswd.exp`

### 2. En NAS Destino
```bash
cd /opt/scripts
git clone https://github.com/DeptoITD/SCR-DIAG-REP.git
cd SCR-DIAG-REP

# Editar config/servers.env
nano config/servers.env

# Modo simulación (recomendado primero)
bash src/scripts/RUNME.sh --dry-run

# Crear identidades
bash src/scripts/RUNME.sh --create-nas

# Configurar ACLs
bash src/scripts/RUNME.sh --acls
```

## Uso

### Exportar (Servidor)
```bash
bash src/scripts/10_exportar_identidades.sh
```
Genera archivos en `src/export/hostname_*.txt`

### Crear Identidades (NAS)
```bash
bash src/scripts/20_crear_identidades_nas.sh
```
Lee archivos export → crea usuarios/grupos locales + Samba

### Configurar ACLs (NAS)
```bash
bash src/scripts/30_crear_acls.sh
```
Ajusta permisos y ACLs para usuarios replicados

### Flujo Completo (Simulación)
```bash
bash src/scripts/RUNME.sh --dry-run
```

### Flujo Completo (Ejecución)
```bash
bash src/scripts/RUNME.sh --full
```

## Opciones Script Maestro

| Opción | Función |
|--------|---------|
| `--export-server` | Exportar del servidor |
| `--create-nas` | Crear identidades NAS |
| `--acls` | Configurar ACLs |
| `--full` | Exportar + crear + ACLs |
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
Por defecto usa `sambapass123`. Cambiar en `20_crear_identidades_nas.sh` línea ~60.

## Bitácora
Ver `BITACORA.md` para histórico cambios y versiones.

---
**Autor:** IT+D | **Última actualización:** 2026-09-24
