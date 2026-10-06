#!/bin/bash
# exportar.sh — Exportación Completa (Identidades Linux + Samba)
# Genera export portable con usuarios, grupos, credenciales Samba

if [[ "$(type -t log)" != function ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/iniciar.sh" || return 1
fi

exportar_run() {
  require_root
  local host=$(hostname -s)
  local ts=$(date +%Y%m%d_%H%M%S)
  local export_dir="${EXPORT_PATH}/export_${host}_${ts}"

  mkdir -p "$export_dir"
  log "Exportando configuración a: $export_dir"

  # =========================================================================
  # MANIFEST — Información origen
  # =========================================================================
  {
    echo "hostname=${host}"
    echo "export_ts=$(date '+%Y-%m-%d %H:%M:%S')"
    echo "tool_version=0.6"
    echo "export_type=complete"

    # Detectar SID Samba
    local samba_sid=$(detectar_samba_sid)
    [[ -n "$samba_sid" ]] && echo "samba_sid=${samba_sid}"

    # Versión Samba
    local samba_version=$(smbd --version 2>/dev/null | awk '{print $2}')
    [[ -n "$samba_version" ]] && echo "samba_version=${samba_version}"
  } > "$export_dir/manifest.txt"

  # =========================================================================
  # USUARIOS LINUX
  # =========================================================================
  log "Exportando usuarios Linux..."
  getent passwd > "$export_dir/usuarios_linux.txt" 2>/dev/null || info "No se pudo exportar usuarios"
  chmod 600 "$export_dir/usuarios_linux.txt"

  # =========================================================================
  # GRUPOS LINUX
  # =========================================================================
  log "Exportando grupos Linux..."
  getent group > "$export_dir/grupos_linux.txt" 2>/dev/null || info "No se pudo exportar grupos"
  chmod 600 "$export_dir/grupos_linux.txt"

  # =========================================================================
  # MEMBRESÍAS (quién está en qué grupo)
  # =========================================================================
  log "Exportando membresías de grupos..."
  {
    echo "# Membresías de grupos exportadas el $(date)"
    while IFS=: read -r grupo _ _ miembros; do
      [[ -z "$grupo" ]] && continue
      if [[ -n "$miembros" ]]; then
        echo "$grupo: $miembros"
      fi
    done < "$export_dir/grupos_linux.txt"
  } > "$export_dir/membresias.txt"
  chmod 600 "$export_dir/membresias.txt"

  # =========================================================================
  # SAMBA — Base de datos de credenciales
  # =========================================================================
  if [[ -f /var/lib/samba/private/passdb.tdb ]]; then
    log "Exportando base Samba (passdb.tdb)..."
    cp /var/lib/samba/private/passdb.tdb "$export_dir/" 2>/dev/null
    chmod 600 "$export_dir/passdb.tdb"
  else
    info "passdb.tdb no encontrado (Samba no instalado o Backend distinto)"
  fi

  # =========================================================================
  # SAMBA — Secretos de máquina (CRÍTICO, NO COPIAR A PROD)
  # =========================================================================
  if [[ -f /var/lib/samba/private/secrets.tdb ]]; then
    log "⚠️  Exportando secrets.tdb (solo para referencia, NO importar ciegamente)..."
    cp /var/lib/samba/private/secrets.tdb "$export_dir/"
    chmod 600 "$export_dir/secrets.tdb"
    echo "# ⚠️  secrets.tdb NO debe copiarse a destino" > "$export_dir/SAMBA_SECRETS_READONLY.txt"
    echo "# Copiar rompe SID máquina. Solo para auditoría." >> "$export_dir/SAMBA_SECRETS_READONLY.txt"
  fi

  # =========================================================================
  # SAMBA — Mapeos usuario (smbusers)
  # =========================================================================
  if [[ -f /etc/samba/smbusers ]]; then
    log "Exportando mapeos smbusers..."
    cp /etc/samba/smbusers "$export_dir/"
    chmod 644 "$export_dir/smbusers"
  fi

  # =========================================================================
  # SAMBA — Configuración shares
  # =========================================================================
  log "Exportando smb.conf..."
  cp /etc/samba/smb.conf "$export_dir/" 2>/dev/null || info "smb.conf no encontrado"
  chmod 644 "$export_dir/smb.conf"

  # =========================================================================
  # SAMBA — Lista de usuarios (auditoría legible)
  # =========================================================================
  log "Exportando lista de usuarios Samba (auditoría)..."
  {
    echo "# Lista de usuarios Samba (legible, solo auditoría)"
    echo "# Generado: $(date)"
    echo ""
    pdbedit -L -v 2>/dev/null || echo "No access to pdbedit"
  } > "$export_dir/samba_users_detalle.txt"
  chmod 600 "$export_dir/samba_users_detalle.txt"

  # =========================================================================
  # VALIDACIÓN Samba
  # =========================================================================
  log "Validando configuración Samba..."
  testparm -s 2>/dev/null > "$export_dir/testparm.txt" || info "testparm falló"
  chmod 644 "$export_dir/testparm.txt"

  # =========================================================================
  # DATOS INTERNOS (de nuestras bases de datos)
  # =========================================================================
  log "Exportando bases internas..."
  cp "${DATA_DIR}/usuarios.db" "$export_dir/" 2>/dev/null || info "No existe usuarios.db local"
  cp "${DATA_DIR}/equipos.db" "$export_dir/" 2>/dev/null || info "No existe equipos.db local"
  chmod 600 "$export_dir/"*.db 2>/dev/null

  # =========================================================================
  # SISTEMA
  # =========================================================================
  log "Exportando configuración sistema..."
  cp /etc/fstab "$export_dir/fstab.txt" 2>/dev/null
  chmod 644 "$export_dir/fstab.txt"

  # =========================================================================
  # PERMISOS FINALES (Exportación contiene secretos)
  # =========================================================================
  chmod 700 "$export_dir"
  info "✓ Exportación completada con permisos restrictivos (700)"

  # =========================================================================
  # ADVERTENCIA SEGURIDAD
  # =========================================================================
  cat > "$export_dir/README_SEGURIDAD.txt" <<'EOF'
⚠️  ADVERTENCIA DE SEGURIDAD

Este paquete de exportación contiene:
  - passdb.tdb: hashes de contraseñas Samba
  - secrets.tdb: secretos de máquina Samba
  - usuarios_linux.txt: lista de usuarios del sistema
  - grupos_linux.txt: lista de grupos del sistema

NUNCA:
  - Compartir por correo o canales inseguros
  - Dejar en almacenamiento público
  - Hacer copia sin cifrar
  - Importar secrets.tdb en producción

GUARDAR EN LUGAR SEGURO (cifrado preferentemente)

Contactar IT+D si necesitas ayuda con la migración.
EOF

  # =========================================================================
  # INSTRUCCIONES TRANSFER
  # =========================================================================
  mostrar_instrucciones_transfer "$export_dir"

  # =========================================================================
  # RESUMEN
  # =========================================================================
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  ✅ EXPORTACIÓN COMPLETADA"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  echo "📁 Ubicación: $export_dir"
  echo ""
  echo "📋 Contenido:"
  ls -lh "$export_dir" | tail -n +2 | awk '{printf "   %-40s %8s\n", $9, $5}'
  echo ""
  echo "🔐 Permisos: 700 (solo root puede leer)"
  echo ""
  echo "IMPORTANTE:"
  echo "  - Mover a destino de forma SEGURA (SCP, USB cifrado, etc.)"
  echo "  - Importar SOLO en máquina autorizada"
  echo "  - NO importar secrets.tdb a menos que cambies SID"
  echo ""
}
