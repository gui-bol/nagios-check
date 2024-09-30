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
elif [ $# -eq 1 ]; then
    WARNING_THRESHOLD=$1
fi

# Function to check disk space usage
check_disk_space() {
    local overall_status=$OK
    local output=""
    local performance_data=""

    # Loop through all mounted file systems using df
    while IFS= read -r line; do
        # Extract the file system, usage, and mount point
        FILESYSTEM=$(echo "$line" | awk '{print $1}')
        USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        MOUNT_POINT=$(echo "$line" | awk '{print $6}')

        # Build performance data
        performance_data+="'${MOUNT_POINT}'=${USAGE}%;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;100 "

        # Determine the plugin status based on usage thresholds
        if [ "$USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
            output+="CRITICAL: $FILESYSTEM is at $USAGE% capacity on $MOUNT_POINT. "
            [ $overall_status -lt $CRITICAL ] && overall_status=$CRITICAL
        elif [ "$USAGE" -ge "$WARNING_THRESHOLD" ]; then
            output+="WARNING: $FILESYSTEM is at $USAGE% capacity on $MOUNT_POINT. "
            [ $overall_status -lt $WARNING ] && overall_status=$WARNING
        fi
    done < <(df -h | grep "^/")

    # Final output based on overall status
    if [ $overall_status -eq $OK ]; then
        echo "OK: All file systems are within safe usage limits. | $performance_data"
    else
        echo "${output%?}| $performance_data"
    fi

    return $overall_status
}

# Main script execution
check_disk_space
exit $?