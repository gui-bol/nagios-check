#!/bin/bash

# Default values
DEFAULT_MAX_AGE_HOURS=48
DEFAULT_STATUS_FILE="/var/run/backup_status"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            STATUS_FILE="$2"
            shift 2
            ;;
        -a|--max-age)
            MAX_AGE_HOURS="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "  -f, --file FILE      Path to status file (default: $DEFAULT_STATUS_FILE)"
            echo "  -a, --max-age HOURS  Maximum backup age in hours (default: $DEFAULT_MAX_AGE_HOURS)"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            # For backward compatibility, treat first argument as status file
            if [[ -z "$STATUS_FILE" ]]; then
                STATUS_FILE="$1"
            else
                echo "Unknown parameter: $1"
                exit 2
            fi
            shift
            ;;
    esac
done

# Set defaults if not provided
: "${STATUS_FILE:=$DEFAULT_STATUS_FILE}"
: "${MAX_AGE_HOURS:=$DEFAULT_MAX_AGE_HOURS}"

# Convert hours to seconds
MAX_AGE=$((MAX_AGE_HOURS * 3600))

if [[ ! -f "$STATUS_FILE" ]]; then
    echo "CRITICAL: No backup status file found!"
    exit 2
fi

read STATUS TIMESTAMP < "$STATUS_FILE"
CURRENT_TIME=$(date +%s)
AGE=$((CURRENT_TIME - TIMESTAMP))

if [[ "$STATUS" == "running" ]]; then
    echo "WARNING: Backup is still running"
    exit 1
elif [[ "$STATUS" == "fail" ]]; then
    echo "CRITICAL: Backup failed!"
    tail -n 10 /var/log/restic.log
    exit 2
elif [[ "$AGE" -gt "$MAX_AGE" ]]; then
    echo "CRITICAL: Last backup is too old ($((AGE / 3600)) hours)"
    exit 2
else
    echo "OK: Last backup was successful ($((AGE / 3600)) hours ago)"
    exit 0
fi
