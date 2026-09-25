# Integración SCR-DIAG-REP ↔ SCR-ACL-REP

## Propósito
Documentar cómo `SCR-ACL-REP` consume las exportaciones de `SCR-DIAG-REP`.

---

## Archivos Entrada (SCR-DIAG-REP → SCR-ACL-REP)

### `src/export/srv2_passwd.txt`
**Formato:** Estándar `/etc/passwd` (completo)
```
username:x:uid:gid:comment:home:shell
```

**Usados por SCR-ACL-REP:**
- Extraer UIDs válidos (UID >= 1000)
- Validar usuario existe antes de aplicar ACL
- Generar auditoría de usuarios/especialidades

**Ejemplo:**
```
jhonatan.rojas:x:1001:1002:Jhonatan Rojas:/home/jhonatan.rojas:/bin/bash
camilo.tibana:x:1003:1002:Camilo Tibana:/home/camilo.tibana:/bin/bash
jeisson.suarez:x:1004:1005:Jeisson Suarez:/home/jeisson.suarez:/bin/bash
```

---

### `src/export/srv2_group.txt`
**Formato:** Estándar `/etc/group` (completo)
```
groupname:x:gid:members
```

**Usados por SCR-ACL-REP:**
- Extraer GIDs válidos (GID >= 1000)
- Validar grupo existe
- Asignar permisos por grupo

**Ejemplo:**
```
IND_PMO:x:1002:jhonatan.rojas,camilo.tibana
IND_ARQ:x:1005:jeisson.suarez,carlos.acero,anderson.higuera,melissa.rubiano
IND_BIM:x:1006:santiago.acosta,daniela.torres
```

---

### `src/export/srv2_samba_users.txt`
**Formato:** pdbedit -L (output estándar)
```
username:uid:SAMBA_RIDBASE:SAMBA_RIDBASE+rid:[U]:LCT-timestamp:
```

**Usados por SCR-ACL-REP:**
- Validar que usuario Samba registrado
- Auditoría identidades

---

### `src/export/srv2_testparm.conf`
**Formato:** Output testparm -s (config Samba)

**Usados por SCR-ACL-REP:**
- Referencia de shares existentes
- Validar configuración Samba actual
- Auditoría shares

---

## Flujo Consumo SCR-ACL-REP

```
1. SCR-DIAG-REP ejecuta:
   bash src/scripts/RUNME.sh --export-server

2. Genera en src/export/:
   ├─ srv2_passwd.txt
   ├─ srv2_group.txt
   └─ srv2_samba_users.txt

3. Transferir (git push / SCP)

4. SCR-ACL-REP lee:
   while IFS=: read -r user x uid gid ...; do
     # Procesar usuario con UID >= 1000
   done < src/export/srv2_passwd.txt

5. SCR-ACL-REP valida:
   - UID existe en NAS
   - Grupo GID existe
   - Usuario Samba registrado (si aplica)

6. SCR-ACL-REP aplica:
   setfacl -m "u:usuario:rwx" /srv/02_Proyectos/proyecto/...
```

---

## Validaciones Críticas

### En SCR-DIAG-REP (creación identidades)
- ✅ Grupo existe antes de crear usuario (GID validado)
- ✅ Usuario UID único
- ✅ Formato passwd.txt estándar (no cortado)

### En SCR-ACL-REP (aplicar ACLs)
- ✅ Usuario existe en Linux (`id username`)
- ✅ Grupo existe (`getent group gid`)
- ✅ Directorio target existe (`[[ -d /srv/... ]]`)
- ✅ DENY-by-default: lo no declarado = `---`
- ✅ Backup automático antes de aplicar setfacl

---

## Ejemplo: Usuario Nuevo

### 1. Exportar (SCR-DIAG-REP)
```bash
# srv2_passwd.txt línea nueva:
juan.gonzalez:x:1025:1010:Juan Gonzalez:/home/juan.gonzalez:/bin/bash

# srv2_group.txt línea nueva:
IND_ARQ:x:1010:jeisson.suarez,carlos.acero,juan.gonzalez
```

### 2. Crear identidades (SCR-DIAG-REP en NAS)
```bash
bash src/scripts/20_crear_identidades_nas.sh

# Output:
# [OK] Grupo IND_ARQ existente
# [OK] Usuario juan.gonzalez creado (uid=1025)
# [OK] Usuario Samba juan.gonzalez agregado
```

### 3. Perfilar usuario (SCR-ACL-REP)
```bash
# SCR-ACL-REP lee src/export/srv2_passwd.txt
# Detecta juan.gonzalez UID=1025, GID=1010 (IND_ARQ)
# Aplica ACLs según config:
# setfacl -m "u:juan.gonzalez:rwx" /srv/02_Proyectos/A_ARQ/...
```

---

## Cambios Futuros

**v1.0 Integración:**
- [ ] SCR-ACL-REP importa directamente de `src/export/srv2_passwd.txt`
- [ ] Validación automática UID/GID antes de aplicar ACLs
- [ ] Script de sincronización: detectar usuarios nuevos en export

**v2.0 Escalabilidad:**
- [ ] Soportar múltiples servidores (no solo srv-2)
- [ ] Config centralizada: `config/acls.ini` + `config/identidades.ini`
- [ ] Audit trail: quién, qué, cuándo en ACLs

---

*Última actualización: 2026-09-24*
