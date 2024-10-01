#!/bin/bash

# Default values
MOUNT_POINT=""
TEST_FILE="/tmp/nfs_test_file_$$"

# Function to print usage
usage() {
    echo "Usage: $0 -m <mount_point>"
    echo "  -m: NFS mount point to check (e.g., /mnt/nfs)"
    exit 3
}

# Parse command-line options
while getopts "m:" opt; do
    case $opt in
        m) MOUNT_POINT=$OPTARG ;;
        *) usage ;;
    esac
done

# Check if mount point is provided
if [ -z "$MOUNT_POINT" ]; then
    usage
fi

# Check if mount point is actually mounted
if ! grep -qs "$MOUNT_POINT" /proc/mounts; then
    echo "CRITICAL: NFS mount point $MOUNT_POINT is not mounted"
    exit 2
fi

# Check if mount point is writable by creating a temporary file
touch "$MOUNT_POINT/$TEST_FILE" &> /dev/null

if [ $? -ne 0 ]; then
    echo "CRITICAL: NFS mount point $MOUNT_POINT is mounted but not writable"
    exit 2
else
    # Clean up the test file
    rm -f "$MOUNT_POINT/$TEST_FILE"
    echo "OK: NFS mount point $MOUNT_POINT is mounted and writable"
    exit 0
fi
