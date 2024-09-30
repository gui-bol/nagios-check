#!/bin/bash

# Default mount point
MOUNT_POINT="/"

# Function to print usage
usage() {
    echo "Usage: $0 [-m mount_point]"
    echo "  -m: Mount point of the BTRFS filesystem (default: /)"
    exit 3
}

# Parse command line options
while getopts ":m:" opt; do
    case $opt in
        m) MOUNT_POINT=$OPTARG ;;
        \?) usage ;;
    esac
done

# Check if the mount point exists and is a BTRFS filesystem
if ! mountpoint -q "$MOUNT_POINT"; then
    echo "UNKNOWN - $MOUNT_POINT is not a mount point"
    exit 3
fi

if ! grep -qs "$MOUNT_POINT" /proc/mounts | grep -q btrfs; then
    echo "UNKNOWN - $MOUNT_POINT is not a BTRFS filesystem"
    exit 3
fi

# Function to check BTRFS errors
check_btrfs_errors() {
    errors=$(sudo btrfs device stats "$MOUNT_POINT" | awk '$2 != "0" {print $0}')
    if [ -n "$errors" ]; then
        echo "CRITICAL - BTRFS errors detected: $errors"
        return 2
    fi
    return 0
}

# Function to check BTRFS scrub status
check_btrfs_scrub() {
    scrub_status=$(sudo btrfs scrub status "$MOUNT_POINT")
    if echo "$scrub_status" | grep -q "no stats available"; then
        echo "WARNING - No scrub has been run on $MOUNT_POINT"
        return 1
    elif echo "$scrub_status" | grep -q "errors"; then
        echo "CRITICAL - Scrub errors detected on $MOUNT_POINT"
        return 2
    else
        last_scrub=$(echo "$scrub_status" | grep "last completed scrub" | awk '{print $5, $6, $7}')
        echo "OK - Last scrub completed on $last_scrub"
        return 0
    fi
}

# Run checks
errors_result=$(check_btrfs_errors)
errors_exit_code=$?

scrub_result=$(check_btrfs_scrub)
scrub_exit_code=$?

# Determine overall status
if [ $errors_exit_code -eq 2 ] || [ $scrub_exit_code -eq 2 ]; then
    status="CRITICAL"
    exit_code=2
elif [ $errors_exit_code -eq 1 ] || [ $scrub_exit_code -eq 1 ]; then
    status="WARNING"
    exit_code=1
else
    status="OK"
    exit_code=0
fi

# Prepare output
output="$status - BTRFS health check for $MOUNT_POINT | $errors_result; $scrub_result"

echo "$output"
exit $exit_code
