#!/bin/bash

# Default thresholds for Nagios (can be overridden by command-line arguments)
WARNING_THRESHOLD=80
CRITICAL_THRESHOLD=90

# Nagios plugin return codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Check if thresholds were passed as arguments
if [ $# -ge 2 ]; then
    WARNING_THRESHOLD=$1
    CRITICAL_THRESHOLD=$2
elif [ $# -ge 1 ]; then
    WARNING_THRESHOLD=$1
fi

# Function to check disk space usage
check_disk_space() {
    # Loop through all mounted file systems
    df -h | grep "^/" | while read -r line; do
        # Extract the file system, usage, and mount point
        FILESYSTEM=$(echo "$line" | awk '{print $1}')
        USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        MOUNT_POINT=$(echo "$line" | awk '{print $6}')
        
        # Determine the plugin status based on usage thresholds
        if [ "$USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
            echo "CRITICAL: $FILESYSTEM is at $USAGE% capacity on $MOUNT_POINT"
            exit $CRITICAL
        elif [ "$USAGE" -ge "$WARNING_THRESHOLD" ]; then
            echo "WARNING: $FILESYSTEM is at $USAGE% capacity on $MOUNT_POINT"
            exit $WARNING
        fi
    done

    # If all file systems are within safe usage levels
    echo "OK: All file systems are within safe usage limits."
    exit $OK
}

# Main script execution
check_disk_space
