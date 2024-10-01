#!/bin/bash

# Default values
MOUNT_POINT=""
TEST_FILE="nfs_test_file_$$.tmp"

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

# Check if mount point is mounted by verifying its existence in /proc/mounts
if ! grep -qs "$MOUNT_POINT" /proc/mounts; then
    echo "CRITICAL: NFS mount point $MOUNT_POINT is not mounted"
    exit 2
fi

# Try to create a test file using dd command to verify write access
dd if=/dev/zero of="$MOUNT_POINT/$TEST_FILE" bs=1 count=1 &> /dev/null

# Check if the file was successfully written
if [ $? -ne 0 ]; then
    echo "CRITICAL: NFS mount point $MOUNT_POINT is mounted but not writable"
    exit 2
else
    # If successful, remove the test file and output success
    rm -f "$MOUNT_POINT/$TEST_FILE"
    echo "OK: NFS mount point $MOUNT_POINT is mounted and writable"
    exit 0
fi
