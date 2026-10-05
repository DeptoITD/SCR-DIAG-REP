# SCR-DIAG-REP — Guía de Uso

## Inicio Rápido

```bash
cd /opt/scripts/SCR-DIAG-REP
sudo bash src/main.sh
```

Menú interactivo:
- **1) Diagnóstico** — Estado sistema
- **2) Usuarios** — CRUD usuarios Linux
- **3) Equipos** — Gestión grupos
- **4) Carga masiva** — Importar CSV
- **5) Exportar** — Exportar identidades
- **6) Importar** — Restaurar identidades
- **7) Sincronizar** — Copiar exports

---

## Flujos Principales

### Crear Usuario Manual

```bash
sudo bash src/main.sh
→ 2) Usuarios
→ 2) Crear
```

Ingresa:
- Usuario (ej: juan.perez)
- Nombre completo
- Grupo primario (IND_ITD, IND_ARQ, etc.)
- Dominio (COR, OPE, COM)
- UID (automático si omite)

Resultado: Usuario Linux + Samba con contraseña.

### Carga Masiva desde CSV

Formato CSV:
```
usuario|nombre|grupo|dominio|uid|password
julian.ochoa|Julian Ochoa|IND_GEN|COR|1050|TempPass1234567
sara.albarracin|Sara Albarracín|IND_ITD|OPE|1051|TempPass1234567
```

Ejecución:
```bash
sudo bash src/main.sh
→ 4) Carga masiva
→ Ruta CSV: /ruta/a/usuarios.csv
```

Valida TODO antes de aplicar, dry-run obligatorio.

### Exportar → Importar

Servidor origen:
```bash
sudo bash src/main.sh
→ 5) Exportar
```

Genera `/tmp/export_HOSTNAME_TIMESTAMP/` con:
- usuarios_linux.txt (getent passwd)
- grupos_linux.txt (getent group)
- shadow_export.txt (hashes Linux, perms 600)
- passdb.tdb (credenciales Samba, perms 600)
- manifest.txt (metadata)

Copiar a destino:
```bash
scp -r /tmp/export_* usuario@IP_DESTINO:/tmp/
```

En destino:
```bash
sudo bash src/main.sh
→ 6) Importar
→ Selecciona carpeta
→ DRY-RUN
→ Confirma
→ Rollback si falla
```

---

## Dominios (COR/OPE/COM)

Únicos válidos en este sistema:

| Dominio | Significado | GID |
|---------|------------|-----|
| COR | Administración/Operaciones | 3001 |
| OPE | Operativo | 3002 |
| COM | Comercial | 3003 |

Se usan como grupos secundarios. Ejemplo:
- Usuario `julian.ochoa` es del grupo primario `IND_GEN` (especialidad)
- Dominio `COR` se agrega como grupo secundario

---

## Seguridad

⚠️ **Contraseñas:**
- NO se guardan en archivos
- Se muestran UNA sola vez al crear usuario
- Se leen desde CSV en carga masiva

⚠️ **Hashes:**
- shadow_export.txt tiene perms 600 (solo root)
- passdb.tdb tiene perms 600
- NO mostrar en logs ni console

⚠️ **Rollback:**
- Todos los cambios crean backups automáticos
- Si falla, se pregunta si revertir
- Backups en `/tmp/backup_TIMESTAMP/`

---

## Troubleshooting

**"No existe grupo"**
→ Crear grupo primero en menú Equipos (opción 3)

**"UID ya existe"**
→ Seleccionar otro UID o dejar que asigne automático

**"Falta contraseña en CSV"**
→ CSV debe tener 12 caracteres mínimo en campo password

**"Importación falló"**
→ Usar opción rollback disponible al final
→ Backups guardados en `/tmp/backup_*`

---

## Comandos Directos (Avanzado)

Sin menú interactivo:

```bash
# Crear usuario (llama core)
source src/core/config.sh
source src/core/usuarios_core.sh
crear_usuario "juan.perez" 1050 "IND_ITD" "Juan Perez"
cambiar_contraseña "juan.perez" "MiPassword123456"

# Crear grupo
source src/core/grupos_core.sh
crear_grupo "IND_NUEVO" 2100

# Crear cuenta Samba
source src/core/samba_core.sh
crear_cuenta_samba "juan.perez" "MiPassword123456"
```

---

## Configuración

Archivos clave:

```
config/data/
├── usuarios.db          (registro usuarios)
├── equipos.db           (grupos disponibles)
└── dominios.db          (COR/OPE/COM)
```

NO editar manualmente. Usar menú interactivo.

---

## Support

Issues: GitHub [DeptoITD/SCR-DIAG-REP](https://github.com/DeptoITD/SCR-DIAG-REP)

