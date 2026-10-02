# WIKI — SCR-DIAG-REP v0.5

Guía completa: logs, troubleshooting, arquitectura, FAQ.

---

## Logs

### Ubicación
```
/opt/scripts/SCR-DIAG-REP/logs/
├── script_20261002_120000.log
├── script_20261002_120500.log
└── ...
```

Cada ejecución genera un log con timestamp: `script_YYYYMMDD_HHMMSS.log`

### Estructura Log
```
[2026-10-02 12:00:00] [INFO] Exportando configuración a: /opt/scripts/SCR-DIAG-REP/src/export/export_srv2_20261002_120000/
[2026-10-02 12:00:01] [INFO] ✓ Exportación completada: /opt/scripts/SCR-DIAG-REP/src/export/export_srv2_20261002_120000/
[2026-10-02 12:05:00] [INFO] Importando desde: /opt/scripts/SCR-DIAG-REP/src/export/export_srv2_20261002_120000/
[2026-10-02 12:05:02] [OK] Usuario creado: jhonatan.rojas (uid=1001)
[2026-10-02 12:05:03] [ERROR] Grupo IND_ARQ no existe
```

### Leer Logs

**Archivo más reciente:**
```bash
cat logs/$(ls -t logs/script_*.log | head -1)
```

**Seguir en tiempo real:**
```bash
tail -f logs/script_*.log
```

**Últimas 50 líneas:**
```bash
tail -50 logs/script_*.log
```

**Primeras 20 líneas (inicio de sesión):**
```bash
head -20 logs/script_*.log
```

### Filtrar Logs

**Solo errores:**
```bash
grep "\[ERROR\]" logs/script_*.log
```

**Eventos de usuario:**
```bash
grep "Usuario" logs/script_*.log
```

**Eventos de grupo:**
```bash
grep "Grupo" logs/script_*.log
```

**Eventos Samba:**
```bash
grep "Samba\|pdbedit" logs/script_*.log
```

**Línea y contexto (5 líneas antes/después):**
```bash
grep -C 5 "ERROR" logs/script_*.log
```

### Estadísticas

**Total líneas en log actual:**
```bash
wc -l logs/script_*.log
```

**Usuarios creados:**
```bash
grep -c "Usuario creado" logs/script_*.log
```

**Grupos creados:**
```bash
grep -c "Grupo creado" logs/script_*.log
```

**Errores totales:**
```bash
grep -c "\[ERROR\]" logs/script_*.log
```

**Timeline (hora de cada evento):**
```bash
grep -o "\[2026.*\]" logs/script_*.log | sort | uniq -c
```

---

## Troubleshooting

### Error: "Permission denied" en exportar

**Log:**
```
[ERROR] Permission denied al escribir en /opt/scripts/SCR-DIAG-REP/src/export/
```

**Causa:** Usuario no tiene permisos en directorio.

**Solución:**
```bash
sudo chown -R soporte:soporte /opt/scripts/SCR-DIAG-REP
sudo chmod -R 755 /opt/scripts/SCR-DIAG-REP/src/export
```

### Error: "require_root: Este comando requiere privilegios root"

**Log:**
```
[ERROR] Este comando requiere privilegios root (sudo).
```

**Causa:** Exportar/importar requiere sudo.

**Solución:**
```bash
sudo su
bash src/menu.sh
```

O configurar sudoers:
```bash
sudo visudo
# Agregar:
soporte ALL=(ALL) NOPASSWD: /opt/scripts/SCR-DIAG-REP/src/modules/*
```

### Error: "Falta usuarios.db" en importar

**Log:**
```
[ERROR] Falta usuarios.db
```

**Causa:** Exportación sin archivo usuarios.db.

**Solución:**
1. Crear usuarios primero: `bash src/menu.sh → 6: Gestión de usuarios`
2. Volver a exportar: `bash src/menu.sh → 2: Exportar`

### Error: "Usuario/Grupo duplicado"

**Log:**
```
[!] Usuario user1 ya existe
[OK] Usuario existente: user1
```

**Cause:** Usuario ya está en sistema.

**Solución:** Script lo detecta y salta. Sin acción requerida.

### Log vacío / No se crean archivos

**Causa:** LOG_FILE no está definido o logs/ no existe.

**Solución:**
```bash
mkdir -p /opt/scripts/SCR-DIAG-REP/logs
chmod 755 /opt/scripts/SCR-DIAG-REP/logs
```

---

## Arquitectura

### Flujo Exportar

```
menu.sh (src/menu.sh)
  └─ Opción 2: exportar_run()
     ├─ Crea export_hostname_YYYYMMDD_HHMMSS/
     ├─ Copia usuarios.db, equipos.db
     ├─ Copia config (smb.conf, testparm, fstab)
     ├─ Crea manifest.txt
     └─ Llamar mostrar_instrucciones_transfer()
        └─ Muestra SCP + qué correr en otro equipo
```

### Flujo Importar

```
menu.sh (src/menu.sh)
  └─ Opción 3: importar_run()
     ├─ Buscar export_* en src/export/
     ├─ Seleccionar carpeta
     ├─ Leer usuarios.db → crear usuarios Linux
     ├─ Leer equipos.db → crear grupos Linux
     └─ Llamar funciones usuarios.sh + equipos.sh
```

### Módulos

| Módulo | Función |
|--------|---------|
| **src/menu.sh** | Entry point, menú interactivo |
| **src/utils.sh** | Funciones compartidas (log, error, info, etc.) |
| **src/modules/diagnostico.sh** | Diagnóstico sistema (solo lectura) |
| **src/modules/exportar.sh** | Exportar config + usuarios + equipos |
| **src/modules/importar.sh** | Importar users/groups desde export |
| **src/modules/sync.sh** | Listar/limpiar exportaciones |
| **src/modules/equipos.sh** | CRUD equipos/grupos |
| **src/modules/usuarios.sh** | CRUD usuarios |

### Bases Datos

**usuarios.db:** `config/data/usuarios.db`
```
usuario|Nombre Completo|grupo_primario|grupos_adicionales|uid|fecha_creacion|flags
jhonatan.rojas|Jhonatan Rojas|IND_PMO|IND_ARQ|1001|2026-10-02|active
```

**equipos.db:** `config/data/equipos.db`
```
grupo|Nombre Grupo|gid|descripción|fecha_creacion
IND_PMO|Equipo PMO|1002|Project Management Office|2026-10-02
IND_ARQ|Equipo Arquitectura|1005|Arquitectos e Ingenieros|2026-10-02
```

---

## FAQ

### ¿Dónde quedan los usuarios creados?

En el sistema local (Linux):
```bash
getent passwd | grep -E "1[0-9]{3}:"     # Ver usuarios creados
getent group | grep -E "1[0-9]{3}:"      # Ver grupos creados
id jhonatan.rojas                        # Ver grupos de usuario
```

En Samba:
```bash
pdbedit -L                               # Ver usuarios Samba
```

### ¿Puedo exportar/importar múltiples veces?

**Sí.** Script valida duplicados:
- Si usuario existe → salta (no error)
- Si grupo existe → salta
- Idempotente (seguro repetir)

### ¿Qué pasa si exporto vacío (sin usuarios)?

Se crea carpeta export con:
- manifest.txt ✓
- usuarios.db ✗ (si no hay usuarios, archivo mínimo)
- equipos.db ✗ (si no hay equipos, archivo mínimo)
- Configs Samba ✓

Importar te alertará si faltan db.

### ¿Cómo cambio contraseña Samba?

**v0.5 no maneja contraseñas directamente.** Contraseña por defecto se usa en importar:

En `src/modules/importar.sh`, busca:
```bash
smbpasswd -a -e "usuario" 2>/dev/null <<< "sambapass123"
```

Cambiar `sambapass123` por tu contraseña.

### ¿Puedo usar solo diagnóstico sin exportar?

**Sí.** Opción 1 es solo lectura:
```bash
bash src/menu.sh → 1: Diagnóstico → Ver estado sistema
```

No modifica nada.

### ¿ACLs se configuran aquí?

**No.** ACLs están en repo `SCR-ACL-REP` (separado).

Este repo solo:
1. Diagnostica
2. Exporta config
3. Crea usuarios/grupos

`SCR-ACL-REP` luego:
1. Lee usuarios/grupos
2. Aplica permisos (setfacl)

---

## Comandos Útiles

**Monitoreo en vivo:**
```bash
watch -n 1 'tail -20 logs/script_*.log | grep -E "Usuario|Grupo|ERROR"'
```

**Contar por tipo de evento:**
```bash
for event in "Usuario creado" "Grupo creado" "ERROR" "OK"; do
  echo "$event: $(grep -c "$event" logs/script_*.log)"
done
```

**Exportar logs a archivo:**
```bash
cat logs/script_*.log > export_logs_$(date +%Y%m%d).txt
```

**Buscar por rango de tiempo:**
```bash
sed -n '/2026-10-02 12:00/,/2026-10-02 12:05/p' logs/script_*.log
```

---

## Versiones & Cambios

Ver `BITACORA.md` para histórico completo de versiones y cambios.

**Resumen:**
- **v0.5** (actual): Simplificado, menú interactivo, sin SSH
- **v0.3**: Con SSH automático, config centralizada
- **v0.2**: Scripts separados + RUNME.sh
- **v0.1**: Plantilla inicial

---

**Última actualización:** 2026-10-02 v0.5
**Autor:** IT+D
