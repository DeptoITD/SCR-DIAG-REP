# COMANDOS RÁPIDOS — Servidor y NAS
Actualizado: 2026-10-06. Única entrada: `src/script.sh ACCION`.
Sin argumentos muestra ayuda; cada acción termina al completarse. Los comandos `usuarios`, `equipos` y `exportaciones` abren únicamente su gestión específica.

## 1. Preparar ambos equipos
```bash
cd /opt/scripts/SCR-DIAG-REP
git pull --ff-only origin main
bash src/script.sh ayuda
```
Si todavía tienes `config/data` en la estructura anterior, aplica primero la migración de catálogos del README.

## 2. Exportar en srv-2
```bash
sudo bash src/script.sh diagnostico
sudo bash src/script.sh exportar
```
Anota la carpeta exacta que muestra el programa, dentro de `src/export/export_srv-2_FECHA_HORA`. El resultado contiene datos sensibles y bases de credenciales; no se sube a Git.

## 3. Copiar la carpeta completa a la NAS
Usa transferencia de archivos de RustDesk o USB. Copia la carpeta exacta mostrada al exportar a `/home/soporte/` del destino. El paquete contiene hashes sensibles y debe permanecer privado. El propietario de la exportación es el usuario que ejecutó sudo, para permitir la transferencia sin abrir permisos a otros usuarios.

## 4. Importar en la NAS
```bash
cd /opt/scripts/SCR-DIAG-REP
sudo bash src/script.sh importar /home/soporte/export_srv-2_FECHA_HORA
```
Revisa SID y conflictos UID y confirma. El flujo prepara los recursos de smb.conf y pide sus rutas del destino, incorpora grupos, usuarios y membresías; aplica las credenciales del origen y las verifica. Valida la configuración y recarga Samba; conserva los recursos exclusivos y la configuración global del destino. Conserva las cuentas exclusivas del destino, excluye `soporte` y conserva el SID del destino. No importa `secrets.tdb` ni sustituye una base completa. Respalda en `logs/importacion.*`. Un UID ocupado o distinto detiene el proceso antes de aplicar. Exportaciones antiguas sin `credenciales_samba.txt` se rechazan: regenera en el origen.

## 5. Comprobar en la NAS
```bash
sudo bash src/script.sh listar-grupos
sudo bash src/script.sh listar-usuarios
sudo net groupmap list
sudo pdbedit -L
id genesis.bustos
getent passwd genesis.bustos
sudo pdbedit -Lv genesis.bustos
sudo systemctl status smbd --no-pager
```
El listado de grupos sincroniza el catálogo de trabajo y sus vínculos Samba. `IND_*`, `COR`, `OPE`, `COM` y `GEN` son grupos de trabajo; los grupos de sistema no son departamentos. Los GID se consultan en el destino: no se asignan por una tabla fija.

Las cuentas nuevas de carga/importación usan `/nonexistent` y `nologin`. Las contraseñas de las cuentas existentes se sincronizan desde el CSV; su home y shell se conservan. `soporte` conserva administración local; La importación no habilita SSH ni cambia las shells de cuentas existentes. Los grupos Linux respaldan los permisos de archivos de Samba; no son cuentas de consola por sí mismos.

Para verificar que las contraseñas corresponden al CSV, conserva el CSV original en la NAS y ejecuta el verificador independiente descargado:
```bash
sudo bash /home/soporte/Downloads/verificar_credenciales_csv.sh /home/soporte/Downloads/usuarios_contrasenas_permanentes.csv
```
Ambos archivos deben existir. `pdbedit -L` comprueba cuentas, pero no prueba que su contraseña coincida con el CSV.

## Carga masiva independiente de la migración
```bash
sudo bash src/script.sh carga-masiva /home/soporte/Downloads/usuarios_contrasenas_permanentes.csv
```
Formato UTF-8: `usuario|nombre|grupo|dominio|uid|password`. No uses `manifest.txt`. La validación ocurre antes de confirmar las altas. Usuarios existentes reciben la contraseña del CSV después de confirmar. El dominio es un dato de referencia; no genera membresías secundarias automáticamente.

## Administración directa
```bash
sudo bash src/script.sh usuarios
sudo bash src/script.sh equipos
sudo bash src/script.sh exportaciones
```
Para recuperar acceso administrativo, comprueba antes la situación actual:
```bash
id soporte
sudo -l
sudo whoami
```
En el equipo mostrado, `soporte` ya tiene sudo completo; no necesita recrearse ni cambiarse de grupo primario.

## ACL y proyectos: siguiente fase externa
Después de verificar identidades, administra permisos y proyectos en `SCR-ACLs_Indesco`. Ese repositorio y sus comandos no forman parte de SCR-DIAG-REP: consulta su README en servidor y NAS antes de ejecutar sus operaciones.
Puedes consultar permisos existentes con:
```bash
getfacl /srv/02_Proyectos
getfacl /mnt/NAS/NasIndesco
```
Usa únicamente la ruta que exista en el equipo correspondiente. La exportación de identidades no demuestra que las ACL del almacenamiento sean correctas.

## Registros y archivos
- `logs/ejecucion.log`: registro de ejecución.
- `logs/importacion.*`: respaldos de importación.
- `src/config/data/equipos.db`: catálogo local de grupos.
- `src/config/data/usuarios.db`: catálogo local de usuarios, sin contraseñas.
- `src/export/`: exportaciones y resultados locales; no se versionan.

No se utilizan las rutas antiguas `src/identidades`, `src/migracion`, `src/main.sh` ni `src/menu.sh`. El código histórico permanece en `src/legacy` como referencia.
