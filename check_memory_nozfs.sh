#!/bin/bash

# Default thresholds (in percentage)
WARNING_THRESHOLD=80
CRITICAL_THRESHOLD=90

# Function to print usage
usage() {
    echo "Usage: $0 [-w warning_threshold] [-c critical_threshold]"
    echo "  -w: Warning threshold in percentage (default: 80)"
    echo "  -c: Critical threshold in percentage (default: 90)"
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

# Get total memory
total_memory=$(free -b | awk '/^Mem:/{print $2}')

# Get used memory (excluding buffers/cache)
used_memory=$(free -b | awk '/^Mem:/{print $3}')

# Calculate usage percentage
used_percent=$(awk "BEGIN {printf \"%.2f\", $used_memory / $total_memory * 100}")

# Convert bytes to human-readable format
hr_total_memory=$(numfmt --to=iec-i --suffix=B --format="%.2f" $total_memory)
hr_used_memory=$(numfmt --to=iec-i --suffix=B --format="%.2f" $used_memory)

# Prepare performance data
perfdata="used=${used_percent}%;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;100 total=${hr_total_memory} used=${hr_used_memory}"

# Check against thresholds and exit with appropriate status
if (( $(awk 'BEGIN {print ('"$used_percent"' >= '"$CRITICAL_THRESHOLD"') ? 1 : 0}') )); then
    echo "CRITICAL - Memory usage at ${used_percent}% | $perfdata"
    exit 2
elif (( $(awk 'BEGIN {print ('"$used_percent"' >= '"$WARNING_THRESHOLD"') ? 1 : 0}') )); then
    echo "WARNING - Memory usage at ${used_percent}% | $perfdata"
    exit 1
else
    echo "OK - Memory usage at ${used_percent}% | $perfdata"
    exit 0
fi
