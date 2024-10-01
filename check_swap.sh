#!/bin/bash

# Default thresholds (in percentage)
WARNING_THRESHOLD=50
CRITICAL_THRESHOLD=80

# Function to print usage
usage() {
    echo "Usage: $0 -w <warning_threshold> -c <critical_threshold>"
    echo "  -w: Warning threshold in percentage (default: 50)"
    echo "  -c: Critical threshold in percentage (default: 80)"
    exit 3
}

# Parse command-line options
while getopts ":w:c:" opt; do
    case $opt in
        w) WARNING_THRESHOLD=$OPTARG ;;
        c) CRITICAL_THRESHOLD=$OPTARG ;;
        *) usage ;;
    esac
done

# Get total and used swap from `free` command in bytes
swap_info=$(free -b | awk '/Swap:/ {print $2 " " $3}')

# Extract total and used swap
total_swap=$(echo $swap_info | cut -d' ' -f1)
used_swap=$(echo $swap_info | cut -d' ' -f2)

# Check if swap is available (non-zero total)
if [ "$total_swap" -eq 0 ]; then
    echo "OK: No swap space configured"
    exit 0
fi

# Calculate used swap percentage
used_percent=$(awk "BEGIN {printf \"%.2f\", $used_swap / $total_swap * 100}")

# Convert bytes to human-readable format
hr_total_swap=$(numfmt --to=iec-i --suffix=B --format="%.2f" $total_swap)
hr_used_swap=$(numfmt --to=iec-i --suffix=B --format="%.2f" $used_swap)

# Prepare performance data
perfdata="swap_used=${used_percent}%;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;100 total=${hr_total_swap} used=${hr_used_swap}"

# Check thresholds and exit with appropriate status
if (( $(awk 'BEGIN {print ('"$used_percent"' >= '"$CRITICAL_THRESHOLD"') ? 1 : 0}') )); then
    echo "CRITICAL: Swap usage is ${used_percent}% | $perfdata"
    exit 2
elif (( $(awk 'BEGIN {print ('"$used_percent"' >= '"$WARNING_THRESHOLD"') ? 1 : 0}') )); then
    echo "WARNING: Swap usage is ${used_percent}% | $perfdata"
    exit 1
else
    echo "OK: Swap usage is ${used_percent}% | $perfdata"
    exit 0
fi
