#!/bin/bash

# Default thresholds
WARNING_THRESHOLD="5,4,3"
CRITICAL_THRESHOLD="10,8,6"

# Function to print usage
usage() {
    echo "Usage: $0 [-w warning_threshold] [-c critical_threshold]"
    echo "  -w: Warning threshold for 1,5,15 minute loads (default: 5,4,3)"
    echo "  -c: Critical threshold for 1,5,15 minute loads (default: 10,8,6)"
    exit 3
}

# Parse command line options
while getopts ":w:c:" opt; do
    case $opt in
        w) WARNING_THRESHOLD=$OPTARG ;;
        c) CRITICAL_THRESHOLD=$OPTARG ;;
        \?) usage ;;
    esac
done

# Get current load averages
LOAD_1=$(cut -d ' ' -f1 /proc/loadavg)
LOAD_5=$(cut -d ' ' -f2 /proc/loadavg)
LOAD_15=$(cut -d ' ' -f3 /proc/loadavg)

# Convert warning and critical thresholds to arrays
IFS=',' read -ra WARN_THRESH <<< "$WARNING_THRESHOLD"
IFS=',' read -ra CRIT_THRESH <<< "$CRITICAL_THRESHOLD"

# Function to compare load against threshold
check_threshold() {
    local load=$1
    local threshold=$2
    awk -v load="$load" -v threshold="$threshold" 'BEGIN {exit (load <= threshold)}'
}

# Check against thresholds
if check_threshold "$LOAD_1" "${CRIT_THRESH[0]}" || \
   check_threshold "$LOAD_5" "${CRIT_THRESH[1]}" || \
   check_threshold "$LOAD_15" "${CRIT_THRESH[2]}"; then
    status="CRITICAL"
    exit_code=2
elif check_threshold "$LOAD_1" "${WARN_THRESH[0]}" || \
     check_threshold "$LOAD_5" "${WARN_THRESH[1]}" || \
     check_threshold "$LOAD_15" "${WARN_THRESH[2]}"; then
    status="WARNING"
    exit_code=1
else
    status="OK"
    exit_code=0
fi

# Prepare output and performance data
output="$status - Load average: $LOAD_1, $LOAD_5, $LOAD_15 | load1=$LOAD_1;${WARN_THRESH[0]};${CRIT_THRESH[0]};0; load5=$LOAD_5;${WARN_THRESH[1]};${CRIT_THRESH[1]};0; load15=$LOAD_15;${WARN_THRESH[2]};${CRIT_THRESH[2]};0;"

echo "$output"
exit $exit_code
