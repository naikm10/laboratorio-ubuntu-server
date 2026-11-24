#!/usr/bin/env bash
# backup-lab.sh - Copia de seguridad incremental de srv-ubuntu-lab
set -euo pipefail

ORIGENES=(/etc /var/www /srv/proyectos /home)
DESTINO=/var/backups/lab
RETENCION_DIAS=7
LOG=/var/log/backup-lab.log
FECHA=$(date +%F_%H%M)
NUEVA="$DESTINO/$FECHA"
ULTIMA="$DESTINO/latest"

mkdir -p "$DESTINO"
echo "[$(date '+%F %T')] INICIO -> $NUEVA" >> "$LOG"

# Si ya hay copia anterior, los ficheros sin cambios se enlazan (no ocupan espacio)
LINK=()
[ -d "$ULTIMA" ] && LINK=(--link-dest="$ULTIMA")

rsync -aAXR --delete "${LINK[@]}" "${ORIGENES[@]}" "$NUEVA"/ >> "$LOG" 2>&1
ln -sfn "$NUEVA" "$ULTIMA"

# Borra copias de más de RETENCION_DIAS días
find "$DESTINO" -mindepth 1 -maxdepth 1 -type d -name '20*' -mtime +"$RETENCION_DIAS" -exec rm -rf {} +

echo "[$(date '+%F %T')] FIN OK ($(du -sh "$NUEVA" | cut -f1))" >> "$LOG"
