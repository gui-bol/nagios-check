#!/bin/bash

# Default values
DEFAULT_STATUS_FILE="/var/run/backup_status"
DEFAULT_MAX_AGE_HOURS=72  # Default to 3 days for weekly schedules
DEFAULT_BACKUP_DAYS="1,3,5"  # Monday, Wednesday, Friday (0=Sunday, 1=Monday, ..., 6=Saturday)
DEFAULT_RESTIC_LOG="/var/log/restic.log"

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
        -d|--days)
            BACKUP_DAYS="$2"
            shift 2
            ;;
        -l|--log)
            RESTIC_LOG="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "  -f, --file FILE      Path to status file (default: $DEFAULT_STATUS_FILE)"
            echo "  -a, --max-age HOURS  Maximum backup age in hours (default: $DEFAULT_MAX_AGE_HOURS or calculated from backup days)"
            echo "  -d, --days DAYS      Comma-separated days of week for backups (0-6, 0=Sunday, e.g. '1,3,5' for Mon,Wed,Fri)"
            echo "  -l, --log FILE       Path to restic log file (default: $DEFAULT_RESTIC_LOG)"
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
: "${RESTIC_LOG:=$DEFAULT_RESTIC_LOG}"
: "${BACKUP_DAYS:=$DEFAULT_BACKUP_DAYS}"

# Determine MAX_AGE. Prioritize explicitly set MAX_AGE_HOURS, then BACKUP_DAYS calculation, then default.
if [[ -n "$MAX_AGE_HOURS" ]]; then
    # Use explicitly provided max age
    MAX_AGE=$((MAX_AGE_HOURS * 3600))
elif [[ -n "$BACKUP_DAYS" ]]; then
    # If backup days are specified, calculate the maximum allowed age
    # Convert comma-separated days to array
    IFS=',' read -ra DAYS_ARRAY <<< "$BACKUP_DAYS"
    
    # Get current day of week (0=Sunday, 1=Monday, ..., 6=Saturday)
    CURRENT_DOW=$(date +%w)
    
    # Find the next backup day
    NEXT_BACKUP_DAY=-1
    for day in "${DAYS_ARRAY[@]}"; do
        if [[ $day -gt $CURRENT_DOW ]]; then
            NEXT_BACKUP_DAY=$day
            break
        fi
    done
    
    # If no next day this week, take the first day of next week
    if [[ $NEXT_BACKUP_DAY -eq -1 ]]; then
        NEXT_BACKUP_DAY=${DAYS_ARRAY[0]}
        DAYS_UNTIL_NEXT=$((7 - CURRENT_DOW + NEXT_BACKUP_DAY))
    else
        DAYS_UNTIL_NEXT=$((NEXT_BACKUP_DAY - CURRENT_DOW))
    fi
    
    # Calculate maximum age in seconds (current time until next backup day + 12 hours grace period)
    MAX_AGE=$(( (DAYS_UNTIL_NEXT * 24 * 3600) + (12 * 3600) ))
else
    # Fall back to fixed hours if no other options are provided
    MAX_AGE=$((DEFAULT_MAX_AGE_HOURS * 3600))
fi

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
    if [[ -f "$RESTIC_LOG" ]]; then
        tail -n 10 "$RESTIC_LOG"
    else
        echo "restic log not found at $RESTIC_LOG"
    fi
    exit 2
elif [[ "$AGE" -gt "$MAX_AGE" ]]; then
    echo "CRITICAL: Last backup is too old ($((AGE / 3600)) hours)"
    exit 2
else
    echo "OK: Last backup was successful ($((AGE / 3600)) hours ago)"
    exit 0
fi
