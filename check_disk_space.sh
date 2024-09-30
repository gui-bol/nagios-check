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
    local overall_status=$OK  # Initialize overall status as OK

    # Loop through all mounted file systems using df
    df -h | grep "/" | while read -r line; do
        # Extract the file system, usage, and mount point
        FILESYSTEM=$(echo "$line" | awk '{print $1}')
        USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        MOUNT_POINT=$(echo "$line" | awk '{print $6}')

        # Debugging output (optional)
        echo "Checking $FILESYSTEM at $MOUNT_POINT: Usage = $USAGE%"

        # Determine the plugin status based on usage thresholds
        if [ "$USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
            echo "CRITICAL: $FILESYSTEM is at $USAGE% capacity on $MOUNT_POINT"
            overall_status=$CRITICAL  # Update overall status to CRITICAL
        elif [ "$USAGE" -ge "$WARNING_THRESHOLD" ]; then
            echo "WARNING: $FILESYSTEM is at $USAGE% capacity on $MOUNT_POINT"
            overall_status=$WARNING  # Update overall status to WARNING
        fi
    done

    # Final output based on overall status
    if [ $overall_status -eq $OK ]; then
        echo "OK: All file systems are within safe usage limits."
    fi
    
    exit $overall_status  # Exit with the overall status
}

# Main script execution
check_disk_space