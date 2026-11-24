#!/usr/bin/env bash
# informe-lab.sh - Genera un informe HTML con el estado de srv-ubuntu-lab
set -uo pipefail
export LC_ALL=C

DESTINO=/var/www/estado
SALIDA="$DESTINO/index.html"
mkdir -p "$DESTINO"
TMP=$(mktemp)

# --- Datos del sistema ---
HOST=$(hostname)
FECHA=$(date '+%d/%m/%Y %H:%M:%S')
SO=$(. /etc/os-release && echo "$PRETTY_NAME")
KERNEL=$(uname -r)
read -r SEG _ < /proc/uptime; SEG=${SEG%.*}
ACTIVO="$((SEG/86400)) d $((SEG%86400/3600)) h $((SEG%3600/60)) min"
CARGA=$(cut -d' ' -f1-3 /proc/loadavg)
CPUS=$(nproc)

read -r MEM_TOTAL MEM_USADA < <(free -m | awk '/^Mem:/ {print $2, $3}')
MEM_PCT=$(( MEM_USADA * 100 / MEM_TOTAL ))
DISCO_PCT=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
DISCO_TXT=$(df -hP / | awk 'NR==2 {print $3 " de " $2}')

IP_LAB=$(ip -4 -o addr show enp0s8 | awk '{print $4}')
IP_NAT=$(ip -4 -o addr show enp0s3 | awk '{print $4}')

ACTUALIZACIONES=$(apt list --upgradable 2>/dev/null | grep -c 'upgradable from')
UFW_ESTADO=$(ufw status | awk 'NR==1 {print $2}')
BAN_AHORA=$(fail2ban-client status sshd 2>/dev/null | awk -F: '/Currently banned/ {gsub(/ /,"",$2); print $2}')
BAN_TOTAL=$(fail2ban-client status sshd 2>/dev/null | awk -F: '/Total banned/ {gsub(/ /,"",$2); print $2}')
ULTIMA_COPIA=$(grep 'FIN OK' /var/log/backup-lab.log 2>/dev/null | tail -1 | sed -E 's/^\[([^]]+)\] FIN OK \((.*)\)/\1 · \2/')
[ -z "$ULTIMA_COPIA" ] && ULTIMA_COPIA="Sin copias"

# --- Presentación: verde <80 %, ámbar <90 %, rojo >=90 % ---
clase() { if [ "$1" -ge 90 ]; then echo mal; elif [ "$1" -ge 80 ]; then echo aviso; else echo bien; fi; }
[ "$UFW_ESTADO" = "active" ] && UFW_CLASE=bien || UFW_CLASE=mal

SERVICIOS=""
for s in ssh nginx fail2ban chrony cron unattended-upgrades; do
  estado=$(systemctl is-active "$s")
  [ "$estado" = "active" ] && c=bien || c=mal
  SERVICIOS+="<tr><td>$s</td><td class=\"$c\">$estado</td></tr>"
done

cat > "$TMP" <<HTML
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="60">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Estado · $HOST</title>
<style>
  body { font-family: system-ui, sans-serif; background:#1e1b18; color:#f3ece4; margin:0; padding:24px; }
  h1 { margin:0 0 4px; font-size:1.6rem; }
  .sub { color:#b8a99a; margin-bottom:24px; }
  .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(240px,1fr)); gap:16px; }
  .card { background:#2a2521; border-radius:12px; padding:16px; }
  .card h2 { font-size:.85rem; text-transform:uppercase; letter-spacing:.05em; color:#e8833a; margin:0 0 10px; }
  .big { font-size:1.8rem; font-weight:700; }
  .barra { background:#3a332d; border-radius:6px; height:10px; margin-top:8px; overflow:hidden; }
  .barra span { display:block; height:100%; }
  .bien { color:#7bc47f; } .aviso { color:#e8b33a; } .mal { color:#e5534b; }
  .barra .bien { background:#7bc47f; } .barra .aviso { background:#e8b33a; } .barra .mal { background:#e5534b; }
  table { width:100%; border-collapse:collapse; }
  td { padding:5px 0; border-bottom:1px solid #3a332d; }
  td:last-child { text-align:right; font-weight:600; }
  footer { margin-top:24px; color:#8a7c6f; font-size:.8rem; }
</style>
</head>
<body>
<h1>🐿️ $HOST</h1>
<div class="sub">$SO · kernel $KERNEL · actualizado el $FECHA</div>
<div class="grid">
  <div class="card"><h2>Sistema</h2>
    <table><tr><td>Encendido</td><td>$ACTIVO</td></tr>
    <tr><td>Carga (1/5/15 min)</td><td>$CARGA</td></tr>
    <tr><td>CPUs</td><td>$CPUS</td></tr></table></div>
  <div class="card"><h2>Memoria</h2>
    <div class="big $(clase $MEM_PCT)">$MEM_PCT %</div>
    <div>$MEM_USADA MB de $MEM_TOTAL MB</div>
    <div class="barra"><span class="$(clase $MEM_PCT)" style="width:$MEM_PCT%"></span></div></div>
  <div class="card"><h2>Disco /</h2>
    <div class="big $(clase $DISCO_PCT)">$DISCO_PCT %</div>
    <div>$DISCO_TXT (LVM)</div>
    <div class="barra"><span class="$(clase $DISCO_PCT)" style="width:$DISCO_PCT%"></span></div></div>
  <div class="card"><h2>Red</h2>
    <table><tr><td>Laboratorio (enp0s8)</td><td>$IP_LAB</td></tr>
    <tr><td>NAT (enp0s3)</td><td>$IP_NAT</td></tr></table></div>
  <div class="card"><h2>Seguridad</h2>
    <table><tr><td>Firewall UFW</td><td class="$UFW_CLASE">$UFW_ESTADO</td></tr>
    <tr><td>IPs bloqueadas ahora</td><td>$BAN_AHORA</td></tr>
    <tr><td>Bloqueos totales</td><td>$BAN_TOTAL</td></tr>
    <tr><td>Actualizaciones pendientes</td><td>$ACTUALIZACIONES</td></tr></table></div>
  <div class="card"><h2>Servicios</h2><table>$SERVICIOS</table></div>
  <div class="card"><h2>Última copia de seguridad</h2><div>$ULTIMA_COPIA</div></div>
</div>
<footer>Generado por informe-lab.sh · se actualiza cada 5 minutos · laboratorio de Naike</footer>
</body>
</html>
HTML

mv "$TMP" "$SALIDA"
chmod 644 "$SALIDA"
