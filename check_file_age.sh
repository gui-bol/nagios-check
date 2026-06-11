#!/bin/bash

# Nagios check : âge du fichier le plus récent correspondant à un motif dans un
# dossier. Sert à vérifier qu'une sauvegarde récente existe bien (on contrôle le
# RÉSULTAT, pas le mécanisme : attrape job échoué, planificateur arrêté, etc.).
#
# Usage: check_file_age.sh -d <dossier> -p <motif> -w <warn_heures> -c <crit_heures>
#   -d  dossier à inspecter (obligatoire)
#   -p  motif glob des fichiers (def: *)
#   -w  seuil warning en heures (def: 26)
#   -c  seuil critical en heures (def: 30)

DIR=""
PATTERN="*"
WARN=26
CRIT=30

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir) DIR="$2"; shift 2;;
        -p|--pattern) PATTERN="$2"; shift 2;;
        -w|--warning) WARN="$2"; shift 2;;
        -c|--critical) CRIT="$2"; shift 2;;
        -h|--help)
            echo "Usage: $0 -d <dir> -p <pattern> -w <warn_hours> -c <crit_hours>"
            exit 3;;
        *) echo "UNKNOWN: paramètre inconnu: $1"; exit 3;;
    esac
done

if [[ -z "$DIR" ]]; then
    echo "UNKNOWN: dossier (-d) requis"
    exit 3
fi
if [[ ! -d "$DIR" ]]; then
    echo "CRITICAL: dossier $DIR introuvable"
    exit 2
fi

# Fichier le plus récent correspondant au motif (epoch + chemin).
newest=$(find "$DIR" -maxdepth 1 -type f -name "$PATTERN" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1)
if [[ -z "$newest" ]]; then
    echo "CRITICAL: aucun fichier '$PATTERN' dans $DIR"
    exit 2
fi

mtime=${newest%% *}
mtime=${mtime%.*}
file=${newest#* }
base=$(basename "$file")
now=$(date +%s)
age_h=$(( (now - mtime) / 3600 ))

if (( age_h >= CRIT )); then
    echo "CRITICAL: dernière sauvegarde $base date de ${age_h}h (seuil ${CRIT}h)"
    exit 2
elif (( age_h >= WARN )); then
    echo "WARNING: dernière sauvegarde $base date de ${age_h}h (seuil ${WARN}h)"
    exit 1
else
    echo "OK: dernière sauvegarde $base date de ${age_h}h"
    exit 0
fi
