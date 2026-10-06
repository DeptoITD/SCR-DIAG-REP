# REFACTOR — Arquitectura Centralizada

**Estado:** En progreso  
**Objetivo:** Eliminar duplicación, establecer límites responsabilidad  

---

## NUEVA ARQUITECTURA

```
src/
├── core/                       ← Primitivas ÚNICAS
│   ├── comun.sh               (logging, validación)
│   ├── config.sh              (parsear .db)
│   ├── usuarios_core.sh       (ÚNICA implementación useradd/usermod/userdel)
│   ├── grupos_core.sh         (ÚNICA implementación groupadd/groupdel)
│   ├── samba_core.sh          (ÚNICA implementación smbpasswd/pdbedit)
│   └── backup_core.sh         (ÚNICA implementación backups/rollback)
│
├── diagnostico/               ← Solo lectura
│   ├── diagnostico.sh
│   └── diagnostico_samba.sh
│
├── identidades/               ← CRUD interactivo (llama core)
│   ├── usuarios.sh            (refactorizado: llamar usuarios_core)
│   ├── equipos.sh             (refactorizado: llamar grupos_core)
│   └── carga_masiva.sh        (refactorizado: COR/OPE/COM, llamar core)
│
├── migracion/                 ← Exportar/importar (llama core)
│   ├── exportar.sh            (v1.0: exportar hashes, llama backup_core)
│   ├── importar.sh            (v1.0: restaurar, llama usuarios_core + samba_core)
│   └── sync.sh                (SCP/copia exports)
│
├── nas/                       ← Orquestador NAS
│   ├── perfilar_nas.sh        (NUEVO: orquestador)
│   ├── configurar_samba_nas.sh (NUEVO: security=user, passdb, etc.)
│   ├── configurar_firewall_nas.sh (NUEVO: SSH + Samba)
│   └── verificar_nas.sh       (NUEVO: solo lectura)
│
├── main.sh                    ← Dispatcher principal
└── menu.sh                    (refactorizado para nueva estructura)

config/
├── data/
│   ├── usuarios.db            (username|fullname|primary|domain|uid|origin)
│   ├── equipos.db             (group|display|gid)
│   └── dominios.db            (domain|display|gid) [NUEVO]
```

---

## MIGRACIONES POR MÓDULO

### usuarios_core.sh — NUEVA (FUENTE ÚNICA)

Implementa (NADIE MÁS ejecuta estos comandos):
- useradd -M -d /nonexistent -s /usr/sbin/nologin
- usermod
- userdel -r
- chpasswd (de usuarios_core)

Usado por:
- identidades/usuarios.sh (CRUD interactivo)
- identidades/carga_masiva.sh (CSV batch)
- migracion/importar.sh (restaurar existentes)

---

### grupos_core.sh — NUEVA (FUENTE ÚNICA)

Implementa:
- groupadd
- groupdel
- validación existencia

Usado por:
- identidades/equipos.sh (CRUD)
- core/usuarios_core.sh (validar grupo primario)
- migracion/importar.sh

---

### samba_core.sh — NUEVA (FUENTE ÚNICA)

Implementa:
- smbpasswd (crear, cambiar, eliminar)
- pdbedit (validar, restaurar hash)

Usado por:
- identidades/usuarios.sh
- identidades/carga_masiva.sh
- migracion/importar.sh (restaurar hashes)

NUNCA:
- copiar passdb.tdb ciegamente
- cambiar SID sin confirmación explícita

---

### carga_masiva.sh — REFACTORIZADO

ANTES:
```
CSV (usuario|nombre|grupo|dominio|uid|password)
  ↓ 
useradd/chpasswd/smbpasswd inline
```

DESPUÉS:
```
CSV validación completa
  ↓
for each: usuarios_core.crear_usuario()
          usuarios_core.cambiar_contraseña()
          samba_core.crear_cuenta_samba()
          grupos_core.crear_grupo_si_falta()
```

CAMBIOS OBLIGATORIOS:
- Dominios: ADM/PROYECTOS → **COR/OPE/COM ÚNICAMENTE**
- uid debe ser libre (validar ANTES)
- contraseña >= 12 chars
- dry-run obligatorio
- no mostrar passwords en logs

---

### exportar.sh v1.0 — ACTUALIZADO

YA IMPLEMENTADO:
- Exporta shadow_export.txt (perms 600)
- Exporta gshadow_export.txt (perms 600)
- Exporta passdb.tdb (perms 600)
- Genera CSV auditoría sin hashes
- Manifest con SID

UBICACIÓN: `src/migracion/exportar.sh`

---

### importar.sh v1.0 — ACTUALIZADO

NUEVO (reescrito):
1. Análisis previo (SID, conflictos UID)
2. DRY-RUN obligatorio
3. Backup críticos → core/backup_core
4. Para cada usuario:
   - usuarios_core.crear_usuario()
   - usuarios_core.cambiar_contraseña()
   - samba_core.restaurar_hash_samba()
5. Rollback si falla → core/backup_core

UBICACIÓN: `src/migracion/importar.sh`

---

### diagnostico.sh / diagnostico_samba.sh

SOLO LECTURA.
Mueven a `src/diagnostico/`.
Sin cambios en lógica.

---

### sync.sh

UBICACIÓN: `src/migracion/sync.sh`

RESPONSABILIDAD ÚNICA:
- Listar exports
- SCP/copia
- Limpieza rotación
- Validar checksum

NO:
- Crear usuarios
- Importar

---

### perfilar_nas.sh — NUEVO

ORQUESTADOR NAS.

Flujo:
```
1. Detectar host (hostname.ini en config/)
2. Validar NAS (path, servicios, usuarios)
3. Llamar: configurar_samba_nas.sh
4. Llamar: configurar_firewall_nas.sh
5. Llamar: verificar_nas.sh
```

NO:
- Crear usuarios (eso es DIAG)
- Configurar ACL (eso es ACL repo)
- Importar credenciales (eso es importar.sh)

SOLO configura:
- Samba security=user
- passdb backend=tdbsam
- Firewall SSH + Samba

---

### configurar_samba_nas.sh — NUEVO

CONFIG BASE SAMBA.

Setup:
```
[global]
security = user
passdb backend = tdbsam
map to guest = never
unix password sync = no
acl_xattr:ignore system acls = no
```

Validación: testparm

Backup: smb.conf.bak

Rollback: sí

---

### configurar_firewall_nas.sh — NUEVO

Firewall SSH + Samba.

Setup:
```
ufw allow 22/tcp
ufw allow 139/tcp
ufw allow 445/tcp
```

Validación: netstat

Dry-run: sí

---

### verificar_nas.sh — NUEVO

SOLO LECTURA.

Verifica:
- Grupos declarados existen
- Usuarios declarados existen
- UID/GID coherencia
- Shell = nologin
- Home = /nonexistent
- Cuentas Samba activas
- Servicios smbd + nmbd
- Montaje /mnt/NAS
- testparm -s sin errores

NO modifica nada.

---

## CAMBIOS EN config/

ANTES:
```
config/
├── servers.env
└── data/
    ├── usuarios.db
    └── equipos.db
```

DESPUÉS:
```
config/
├── servers.env (MANTENER)
└── data/
    ├── usuarios.db (formato: username|fullname|primary_group|domain|uid|origin)
    ├── equipos.db (formato: group|display|gid)
    └── dominios.db (formato: domain|display|gid) [NUEVO]
```

**IMPORTANTE:** dominios.db es la FUENTE DE VERDAD para COR/OPE/COM.

---

## REGLAS APLICADAS

1. **Sin duplicación:** Cada comando Unix aparece EN UN ÚNICO LUGAR.
   - useradd → usuarios_core.sh
   - groupadd → grupos_core.sh
   - smbpasswd → samba_core.sh

2. **Llamadas NO DIRECTAS:** Todos los scripts llaman funciones del core.
   - usuarios.sh NO hace `useradd` → llama `usuarios_core.crear_usuario()`
   - carga_masiva.sh NO hace `smbpasswd` → llama `samba_core.crear_cuenta_samba()`

3. **Responsabilidades claras:**
   - core/ = primitivas
   - diagnostico/ = lectura
   - identidades/ = CRUD
   - migracion/ = export/import
   - nas/ = orquestación NAS

4. **Seguridad:**
   - Todos los modificadores = dry-run + backup + rollback
   - Usuarios sin home real (/nonexistent, nologin)
   - Credenciales NUNCA en logs
   - Hashes = perms 600

---

## PLAN IMPLEMENTACIÓN

- [ ] ✅ Crear core/ (6 archivos)
- [ ] ✅ Crear dominios.db
- [ ] Mover modulos a nuevos directorios
- [ ] Refactorizar usuarios.sh → llama usuarios_core
- [ ] Refactorizar equipos.sh → llama grupos_core
- [ ] Refactorizar carga_masiva.sh → llama core
- [ ] Mover exportar.sh → src/migracion/
- [ ] Refactorizar importar.sh → llama core
- [ ] Mover sync.sh → src/migracion/
- [ ] Crear perfilar_nas.sh
- [ ] Crear configurar_samba_nas.sh
- [ ] Crear configurar_firewall_nas.sh
- [ ] Crear verificar_nas.sh
- [ ] Refactorizar main.sh
- [ ] Validar: bash -n todos
- [ ] Commits consolidados
- [ ] Testing dry-run

---

## Status Actual

✅ core/ creado (comun, config, usuarios_core, grupos_core, samba_core, backup_core)
✅ dominios.db creado
⏳ Módulos por mover/refactorizar

