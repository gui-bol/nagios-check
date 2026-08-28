#!/bin/bash
# check_gpu_nvidia.sh — santé GPU NVIDIA via nvidia-smi (P400 & co.)
# CRITICAL si nvidia-smi échoue (driver KO = plus de transcode HW / detect Frigate).
# Seuils sur la VRAM utilisée (%) et la température (°C).
# Usage: check_gpu_nvidia.sh [-w vram_warn%] [-c vram_crit%] [-t temp_warn] [-T temp_crit]

NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_CRITICAL=2
NAGIOS_UNKNOWN=3

VRAM_WARN=85
VRAM_CRIT=95
TEMP_WARN=80
TEMP_CRIT=90

while getopts "w:c:t:T:" opt; do
  case $opt in
    w) VRAM_WARN=$OPTARG ;;
    c) VRAM_CRIT=$OPTARG ;;
    t) TEMP_WARN=$OPTARG ;;
    T) TEMP_CRIT=$OPTARG ;;
    *) echo "UNKNOWN: option invalide"; exit $NAGIOS_UNKNOWN ;;
  esac
done

OUT=$(nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>&1)
if [ $? -ne 0 ] || [ -z "$OUT" ]; then
  echo "CRITICAL: nvidia-smi a échoué (driver/GPU KO ?) — $OUT"
  exit $NAGIOS_CRITICAL
fi

# une seule carte attendue; on prend la première ligne
IFS=',' read -r NAME UTIL MEM_USED MEM_TOTAL TEMP <<< "$(echo "$OUT" | head -1)"
NAME=$(echo "$NAME" | xargs); UTIL=$(echo "$UTIL" | xargs)
MEM_USED=$(echo "$MEM_USED" | xargs); MEM_TOTAL=$(echo "$MEM_TOTAL" | xargs)
TEMP=$(echo "$TEMP" | xargs)

VRAM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))
PERF="vram_pct=${VRAM_PCT}%;${VRAM_WARN};${VRAM_CRIT};0;100 vram_mb=${MEM_USED}MB;;;0;${MEM_TOTAL} gpu_util=${UTIL}%;;;0;100 temp=${TEMP};${TEMP_WARN};${TEMP_CRIT}"
MSG="$NAME: VRAM ${MEM_USED}/${MEM_TOTAL} Mo (${VRAM_PCT}%), util ${UTIL}%, ${TEMP}C"

if [ "$VRAM_PCT" -ge "$VRAM_CRIT" ] || [ "$TEMP" -ge "$TEMP_CRIT" ]; then
  echo "CRITICAL: $MSG|$PERF"; exit $NAGIOS_CRITICAL
elif [ "$VRAM_PCT" -ge "$VRAM_WARN" ] || [ "$TEMP" -ge "$TEMP_WARN" ]; then
  echo "WARNING: $MSG|$PERF"; exit $NAGIOS_WARNING
fi
echo "OK: $MSG|$PERF"
exit $NAGIOS_OK
