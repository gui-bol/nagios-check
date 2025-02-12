#!/bin/bash

STATUS_FILE="/var/run/backup_status"
MAX_AGE=$((24 * 3600)) # 24 hours

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
    exit 2
elif [[ "$AGE" -gt "$MAX_AGE" ]]; then
    echo "CRITICAL: Last backup is too old ($((AGE / 3600)) hours)"
    exit 2
else
    echo "OK: Last backup was successful ($((AGE / 3600)) hours ago)"
    exit 0
fi
