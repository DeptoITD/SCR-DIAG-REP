# Feature: Carga Masiva de Usuarios

**Rama:** `feature/carga-masiva-usuarios`
**Estado:** Implementación inicial
**Integración:** Menú "Gestión de usuarios" → opción 5

## Descripción

Extensión de SCR-DIAG-REP para cargar múltiples usuarios desde archivo CSV.

Flujo:
1. Operador proporciona ruta archivo CSV
2. Sistema valida usuarios, grupos, dominios
3. Genera JSON para servidor y NAS (outputs separados)
4. Copia archivos JSON a equipos destino
5. Equipos ejecutan `carga_masiva_aplicar.sh` (a implementar en SCR-ACLs_Indesco)

## Ficheros Nuevos

- `src/modules/carga_masiva.sh` — módulo principal
- `examples/usuarios_ejemplo.csv` — CSV de referencia
- Este documento

## Cambios Existentes

- `src/menu.sh` — carga módulo `carga_masiva.sh`
- `src/modules/usuarios.sh` — menú incluye opción "Carga masiva"

## Formato CSV Entrada

```
usuario|nombre|grupo|dominio
```

Ejemplo:
```csv
julian.ochoa|Julian Ochoa|IND_GEN|PROYECTOS
maria.admin|Maria Admin|ADM_SYSADMIN|ADM
carlos.sales|Carlos Sales|COM_SALES|COM
```

**Validaciones:**
- Usuario: caracteres válidos (a-z, 0-9, ., -, _)
- Grupo: debe existir en `config/data/equipos.db`
- Dominio: PROYECTOS, ADM o COM (extensible)
- Líneas vacías y comentarios (#) ignorados

## Outputs Generados

Ubicación: `config/export/`

1. **usuarios_entrada.csv** — CSV procesado (auditoría)
2. **usuarios_servidor.json** — Input para servidor (formato pre-especificado)
3. **usuarios_nas.json** — Input para NAS (formato pre-especificado)

Ejemplo JSON:
```json
{
  "target": "nas",
  "usuarios": [
    {
      "usuario": "julian.ochoa",
      "nombre": "Julian Ochoa",
      "grupo_primario": "IND_GEN",
      "dominio": "PROYECTOS"
    },
    {
      "usuario": "maria.admin",
      "nombre": "Maria Admin",
      "grupo_primario": "ADM_SYSADMIN",
      "dominio": "ADM"
    }
  ]
}
```

## Uso

Ejecutar en **cualquier equipo Linux con acceso a este repositorio**:

```bash
cd /opt/scripts/SCR-DIAG-REP  # o ruta local
bash src/menu.sh

→ opción 6 (Gestión de usuarios)
→ opción 5 (Carga masiva)
→ ingresar ruta archivo CSV
→ confirmar
→ archivos JSON generados en config/export/
```

Luego, **copiar JSONs a equipos destino:**
- `config/export/usuarios_servidor.json` → `/tmp/` en srv-2
- `config/export/usuarios_nas.json` → `/tmp/` en nas

## Próximos Pasos (SCR-ACLs_Indesco)

Implementar scripts consumidores:
- `src/nas/carga_masiva_aplicar.sh` — crea usuarios/grupos en NAS según JSON
- `src/servidor/carga_masiva_aplicar.sh` — crea usuarios/grupos en servidor según JSON

Ambos:
- Leen JSON input
- Validan contra identidades.ini
- Crean identidades (idempotente)
- Aplican perfilamiento (grupos, ACL)
- Soportan `--dry-run`

## Notas Técnicas

- Módulo es agnóstico a servidor/NAS (valida localmente)
- Detecta usuarios ya existentes en Linux → warning, no error
- Genera dos JSONs separados (servidor/NAS pueden procesarse independientemente)
- Compatible con estructura de dominios (expandible a más dominios)
- No crea identidades, solo valida y genera entrada para scripts remotos

## Testing

Ver `examples/usuarios_ejemplo.csv` para CSV pre-construido.

```bash
# Simulación:
bash src/menu.sh
→ opción 6 → opción 5
→ ruta: examples/usuarios_ejemplo.csv
→ confirmar
→ revisar outputs en config/export/
```

Luego, cuando `carga_masiva_aplicar.sh` esté disponible:
```bash
# En servidor:
sudo bash src/servidor/carga_masiva_aplicar.sh /tmp/usuarios_servidor.json --dry-run

# En NAS:
sudo bash src/nas/carga_masiva_aplicar.sh /tmp/usuarios_nas.json --dry-run
```
