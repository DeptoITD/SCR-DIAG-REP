# Feature: Importar Inteligente

**Rama:** `feature/importar-inteligente`  
**Estado:** Implementación base completa  
**Versión anterior:** Importación ciega (solo usuarios.db + equipos.db)

---

## Qué Cambió

### Antes
```
1. Pregunta: ¿qué export?
2. Lee equipos.db → groupadd (sin validar GID existente)
3. Lee usuarios.db → useradd (sin comparar usuarios existentes)
4. FIN

IGNORADO: Membresías, Samba, fstab, comparaciones
PROBLEMA: "[OK]" ciego para usuarios/grupos ya existentes
```

### Ahora
```
1. Selecciona export
2. ANALIZA contenido (qué archivos disponibles)
3. PREGUNTA qué importar (menú 1-6 opciones + personalizado)
4. GENERA DRY-RUN (muestra exactamente qué cambia)
5. CONFIRMA
6. APLICA:
   - Crea/sincroniza grupos (valida GID)
   - Crea/sincroniza usuarios (compara estado real)
   - Importa Samba config (extrae políticas portables)
   - Muestra fstab (referencia solo, nunca aplica)
7. RESUME cambios realizados
```

---

## Nuevas Funciones (utils.sh)

### validar_ruta(ruta)
```bash
validar_ruta "/mnt/NAS"
# Verifica:
# - Directorio existe
# - Está montado (findmnt)
# Retorna 0/1
```

### analizar_smb_conf(archivo)
```bash
analizar_smb_conf "/path/to/smb.conf"
# Extrae y muestra:
# - Sección [GLOBAL] (políticas portables)
# - Shares definidos
# - Advierte sobre configuración NO portable
```

### sincronizar_usuario(user, grupo_prim, grupos_extra)
```bash
status=$(sincronizar_usuario "julian.ochoa" "IND_GEN" "extra1,extra2")
# Retorna:
# - "CREATE" → usuario no existe
# - "SYNC"   → usuario existe pero diferencias
# - "OK"     → usuario existe y está sincronizado
```

### comparar_fstab(fstab_export)
```bash
comparar_fstab "/path/to/fstab.txt"
# Muestra diferencias entre:
# - /etc/fstab (actual)
# - fstab.txt (origen)
# NUNCA modifica /etc/fstab
```

### menu_seleccionar_importacion()
```bash
seleccion=$(menu_seleccionar_importacion)
# Menú interactivo:
# 1) Solo usuarios
# 2) Usuarios + grupos
# 3) + membresías
# 4) + Samba config
# 5) + fstab referencia
# 6) Personalizado
```

### menu_personalizado()
```bash
seleccion=$(menu_personalizado)
# Pregunta elemento por elemento qué importar
```

---

## Nuevo Flujo en importar.sh

### Paso 1: Seleccionar Export
```
Muestra carpetas export_* disponibles
Usuario elige una
```

### Paso 2: Analizar Contenido
```
Verifica disponibilidad:
  ✅ usuarios.db
  ✅ equipos.db
  ✅ smb.conf (si existe)
  ✅ group_membership.txt (si existe)
  ✅ fstab.txt (si existe)
  ✅ manifest.txt (información origen)

ERROR si faltan usuarios.db o equipos.db
```

### Paso 3: Preguntar Qué Importar
```
Menú 6 opciones:
  1) Solo USUARIOS
  2) USUARIOS + GRUPOS
  3) + MEMBRESÍAS
  4) + SAMBA CONFIG
  5) + TODO (incluyendo fstab)
  6) PERSONALIZADO (elige elemento)
```

### Paso 4: Generar Dry-Run
```
Muestra EXACTAMENTE qué pasará:

👥 USUARIOS:
  [CREATE] julian.ochoa (uid=1050, grupo=IND_GEN)
  [SYNC]   john.doe (sincronizar grupo primario)
  [OK]     jane.smith (ya sincronizado)
  RESUMEN: 1 crear, 1 sincronizar, 1 ok

👥 GRUPOS:
  [OK]     IND_GEN (gid=1025)
  [CREATE] ADM_SYSADMIN (gid=1051)
  RESUMEN: 1 crear, 1 existente

🔒 SAMBA:
  [PENDING] Analizar políticas [global]
  [BACKUP] /etc/samba/smb.conf → smb.conf.bak.20261002_120000
  [PENDING] Configurar share (interactivo)

💾 FSTAB:
  [REFERENCE] Solo comparar /etc/fstab vs fstab.txt
  [NO CHANGE] /etc/fstab no será modificado
```

### Paso 5: Confirmación
```
¿Continuar? [yes/no]
```

### Paso 6: Aplicación
```
Para GRUPOS:
  - groupadd -g GID grupo (si no existe)
  - Valida GID no en uso
  - Resumen: X creados, Y existentes

Para USUARIOS:
  - useradd -u UID -g GRUPO usuario (si no existe)
  - Genera password random
  - Configura Samba (smbpasswd)
  - O sincroniza si existe (usermod, gpasswd)
  - Resumen: X creados, Y sincronizados, Z ok

Para SAMBA:
  - Backup de /etc/samba/smb.conf
  - Pregunta ruta local, nombre share, usuarios
  - Valida ruta (test -d, findmnt)
  - Extrae políticas [global] portables
  - Genera [share] nuevo
  - Valida con testparm -s
  - APLICA si válido

Para FSTAB:
  - Muestra comparación
  - Nunca modifica automáticamente
```

### Paso 7: Resumen Final
```
═══════════════════════════════════════════════════════
✅ Importación completada

Origen: export_srv-2_20261002_120000
Selección: usuarios,grupos,samba

USUARIOS: 3 creados, 2 sincronizados, 5 ok
GRUPOS: 4 creados, 8 ok
SAMBA: Configurado + validado
═══════════════════════════════════════════════════════
```

---

## Comportamiento Clave

### Usuarios Existentes
```
ANTES: "[OK]" ciego

AHORA:
  - Compara grupo primario actual vs esperado
  - Compara grupos adicionales
  - Compara estado Samba (habilitado/deshabilitado)
  - [OK] si todo coincide
  - [SYNC] si hay diferencias (y sincroniza)
  - Cambia grupo primario (usermod -g)
  - Actualiza membresías (gpasswd -a/-d)
```

### Grupos Existentes
```
ANTES: No validaba GID

AHORA:
  - Verifica si grupo existe (getent group)
  - Si existe: valida GID coincide
  - Si GID en uso por otro grupo: ERROR
  - [OK] si ya existe y GID correcto
  - [CREATE] si no existe
```

### Samba Config
```
ANTES: Nunca importaba

AHORA:
  - Analiza smb.conf origen
  - Extrae políticas portables: seguridad, ACL, protocolo, herencia
  - NO copia: netbios name, server string, path
  - Pregunta:
    "Ruta local que deseas publicar: ___"
    "Nombre del share: ___"
    "Usuarios/grupos acceso: ___"
  - Valida ruta (test -d + findmnt)
  - Backup de /etc/samba/smb.conf antes
  - Valida generado con testparm -s
  - APLICA solo si válido
```

### fstab
```
ANTES: Ignorado

AHORA:
  - Compara /etc/fstab actual vs fstab.txt origen
  - Muestra diferencias
  - NUNCA sobrescribe /etc/fstab automáticamente
  - Solo referencia (usuario decide si agregar manualmente)
```

---

## Dry-Run (Antes de Aplicar)

El dry-run es **obligatorio y detallado**:
```bash
$ bash menu.sh → 3 (Importar)
...
¿Mostrar cambios que se harán? [S/n]: S
```

Muestra:
- Qué usuarios se crearán vs sincronizarán
- Qué grupos se crearán
- Qué cambios en Samba
- Qué diferencias en fstab
- **TODO REVERSIBLE** — no aplica nada

Luego:
```
¿Continuar? [S/n]: S
```

Recién entonces aplica.

---

## Archivos Modificados

| Archivo | Cambios |
|---------|---------|
| `src/utils.sh` | Agregar 6 funciones helpers + 1 menú |
| `src/modules/importar.sh` | Reescrita completa (nueva lógica) |

## Archivos SIN Cambios
- `exportar.sh` — sigue igual (exporte los mismos 8 archivos)
- El resto del menú

---

## Testing

### Caso 1: Importar solo usuarios nuevos
```bash
bash menu.sh → 3
→ selecciona export
→ opción 1 (solo usuarios)
→ dry-run: 10 usuarios a crear
→ confirma
→ crea 10 usuarios con password random
```

### Caso 2: Importar usuarios + sincronizar existentes
```bash
bash menu.sh → 3
→ selecciona export
→ opción 2 (usuarios + grupos)
→ dry-run: 5 crear, 3 sincronizar, 2 ok
→ confirma
→ crea + sincroniza
```

### Caso 3: Importar con Samba config
```bash
bash menu.sh → 3
→ selecciona export
→ opción 4 (usuarios + grupos + membresías + samba)
→ dry-run muestra políticas [global] a adoptar
→ confirma
→ aplica usuarios/grupos
→ pregunta: ruta local, nombre share, usuarios
→ valida ruta, genera smb.conf, testparm, aplica
→ backup antes
```

### Caso 4: Personalizado
```bash
bash menu.sh → 3
→ opción 6 (personalizado)
→ ¿Importar usuarios? S
→ ¿Importar grupos? S
→ ¿Importar membresías? N
→ ¿Importar Samba? S
→ ¿Mostrar fstab? N
→ selección = "usuarios,grupos,samba"
```

---

## Próximas Mejoras (Opcional)

- [ ] Guardar configuración Samba en archivo antes de aplicar
- [ ] Soporte para importación desde URL (SCP automático)
- [ ] Historial de importaciones (qué cambió cuándo)
- [ ] Rollback: revertir última importación
- [ ] Integración con validación GID/UID en identidades.ini

---

## Notas Técnicas

- **No asume SERVER/NAS:** Origen puede ser cualquier equipo
- **Portable:** No copia rutas, hostnames, nombres específicos
- **Idempotente:** Reejecutar = no daña, solo sincroniza
- **Reversible:** Backup antes de cambios críticos
- **Transparente:** Dry-run obligatorio, confirmación clara
- **Seguro:** Valida entrada, verifica rutas, testparm antes aplicar

