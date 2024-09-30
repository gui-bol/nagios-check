#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 -i <interface> -w <warning> -c <critical>"
    echo "  -i: Network interface to monitor (e.g., eth0)"
    echo "  -w: Warning threshold in Mbps"
    echo "  -c: Critical threshold in Mbps"
    exit 3
}

# Function to convert kilobytes per second to megabits per second
kb_to_mbits() {
    echo "scale=2; $1 * 8 / 1000" | bc
}

# Parse command line arguments
while getopts "i:w:c:" opt; do
    case $opt in
        i) INTERFACE=$OPTARG ;;
        w) WARNING=$OPTARG ;;
        c) CRITICAL=$OPTARG ;;
        *) usage ;;
    esac
done

# Check if all required parameters are provided
if [ -z "$INTERFACE" ] || [ -z "$WARNING" ] || [ -z "$CRITICAL" ]; then
    usage
fi

# Run sar command to get network statistics (1 second interval)
SAR_OUTPUT=$(sar -n DEV 1 1 | grep $INTERFACE)

# Check if the interface exists
if [ -z "$SAR_OUTPUT" ]; then
    echo "UNKNOWN: Interface $INTERFACE not found"
    exit 3
fi

# Extract received and transmitted kilobytes per second
RX_KB=$(echo $SAR_OUTPUT | awk '{print $5}')
TX_KB=$(echo $SAR_OUTPUT | awk '{print $6}')

# Convert to Mbps
RX_MBPS=$(kb_to_mbits $RX_KB)
TX_MBPS=$(kb_to_mbits $TX_KB)

# Calculate total Mbps
TOTAL_MBPS=$(echo "$RX_MBPS + $TX_MBPS" | bc)

# Prepare performance data
PERFDATA="rx=$RX_MBPS;$WARNING;$CRITICAL tx=$TX_MBPS;$WARNING;$CRITICAL"

# Check against thresholds and set exit status
if (( $(echo "$TOTAL_MBPS > $CRITICAL" | bc -l) )); then
    echo "CRITICAL: Network traffic on $INTERFACE is $TOTAL_MBPS Mbps | $PERFDATA"
    exit 2
elif (( $(echo "$TOTAL_MBPS > $WARNING" | bc -l) )); then
    echo "WARNING: Network traffic on $INTERFACE is $TOTAL_MBPS Mbps | $PERFDATA"
    exit 1
else
    echo "OK: Network traffic on $INTERFACE is $TOTAL_MBPS Mbps | $PERFDATA"
    exit 0
fi
